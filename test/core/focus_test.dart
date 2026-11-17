import 'package:drift/native.dart';
import 'package:flutter_base/src/core/focus/focus_service.dart';
import 'package:flutter_base/src/core/focus/focus_timer.dart';
import 'package:flutter_base/src/core/stats/task_stats.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/repositories/focus_repository.dart';
import 'package:flutter_base/src/data/repositories/task_repository.dart';
import 'package:flutter_base/src/shared/cubit/language_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements Storage {
  final _data = <String, dynamic>{};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> close() async {}
}

final t0 = DateTime(2026, 11, 17, 9);

DateTime at(int minutes, [int seconds = 0]) =>
    t0.add(Duration(minutes: minutes, seconds: seconds));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('timer rules', () {
    test('a block that runs out is recorded in full and waits', () {
      final running = FocusTimer.start(t0, minutes: 25, taskId: 'a');
      expect(running.remainingAt(at(10)), const Duration(minutes: 15));
      expect(running.progressAt(at(10)), closeTo(.4, 1e-9));
      // Not yet
      expect(FocusTimer.tick(running, at(24, 59)).record, isNull);

      final step = FocusTimer.tick(running, at(31));
      expect(step.state.phase, FocusPhase.focusDone);
      expect(step.state.taskId, 'a');
      final record = step.record!;
      expect(record.focusMinutes, 25);
      expect(record.completed, isTrue);
      // Ended when the block did, not when the app noticed
      expect(record.endedAt, at(25));
    });

    test('paused time is not focus time', () {
      var s = FocusTimer.start(t0, minutes: 25);
      s = FocusTimer.pause(s, at(10));
      expect(s.phase, FocusPhase.paused);
      expect(s.remainingAt(at(40)), const Duration(minutes: 15));
      // A paused block never runs out by itself
      expect(FocusTimer.tick(s, at(120)).state, s);

      s = FocusTimer.resume(s, at(40));
      expect(s.endsAt, at(55));
      final stopped = FocusTimer.stop(s, at(45));
      expect(stopped.state, FocusState.idle);
      expect(stopped.record!.focusMinutes, 15);
      expect(stopped.record!.completed, isFalse);
    });

    test('stopping within the first minute records nothing', () {
      final s = FocusTimer.start(t0, minutes: 25);
      expect(FocusTimer.stop(s, at(0, 40)).record, isNull);
    });

    test('stopping after it ran out counts as finished', () {
      final s = FocusTimer.start(t0, minutes: 25);
      final stopped = FocusTimer.stop(s, at(90));
      expect(stopped.record!.completed, isTrue);
      expect(stopped.record!.focusMinutes, 25);
    });

    test('a break ends by itself and is never recorded', () {
      final rest = FocusTimer.startBreak(t0, minutes: 5);
      expect(FocusTimer.tick(rest, at(4)).state, rest);
      final done = FocusTimer.tick(rest, at(5));
      expect(done.state, FocusState.idle);
      expect(done.record, isNull);
      expect(FocusTimer.stop(rest, at(2)).record, isNull);
    });

    test('state survives being saved, and bad data starts over', () {
      final running = FocusTimer.start(t0, minutes: 50, taskId: 'a');
      expect(FocusState.fromJson(running.toJson()), running);
      final paused = FocusTimer.pause(running, at(20));
      expect(FocusState.fromJson(paused.toJson()), paused);
      expect(FocusState.fromJson(const {'phase': 'nope'}), FocusState.idle);
      expect(FocusState.fromJson(const {'phase': 'focus'}), FocusState.idle);
    });
  });

  group('service', () {
    late AppDatabase db;
    late FocusService service;
    late DateTime now;

    FocusService create() =>
        FocusService(FocusRepository(db), TaskRepository(db), LanguageCubit())
          ..clock = (() => now)
          ..notifications = false;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      HydratedBloc.storage = _MemoryStorage();
      db = AppDatabase(NativeDatabase.memory());
      now = t0;
      service = create();
    });

    tearDown(() async {
      service.dispose();
      await db.close();
    });

    Future<List<FocusSession>> sessions() =>
        FocusRepository(db).watchSince(DateTime(2026)).first;

    test('a block that finished while the app was closed is kept', () async {
      final id = await TaskRepository(
        db,
      ).create(const TaskDraft(title: 'Write report'));
      await service.start();
      await service.startFocus(taskId: id);
      expect(service.state.value.phase, FocusPhase.focus);
      expect(service.taskTitle.value, 'Write report');
      service.dispose();

      // The app comes back 40 minutes later
      now = at(40);
      service = create();
      await service.start();
      expect(service.state.value.phase, FocusPhase.focusDone);
      final saved = (await sessions()).single;
      expect(saved.taskId, id);
      expect(saved.focusMinutes, 25);
      expect(saved.completed, isTrue);

      // And isn't recorded a second time on the next start
      service.dispose();
      service = create();
      await service.start();
      expect(await sessions(), hasLength(1));
    });

    test('chosen lengths are used and remembered', () async {
      await service.start();
      await service.setSettings(focus: 50, rest: 10);
      await service.startFocus();
      expect(service.state.value.plannedMinutes, 50);
      now = at(50);
      await service.stop();
      await service.startBreak();
      expect(service.state.value.endsAt, at(60));
      await service.stop();

      service.dispose();
      service = create();
      await service.start();
      expect(service.settings.value, (focus: 50, rest: 10));
      expect(service.state.value, FocusState.idle);
    });
  });

  group('stats', () {
    final today = DateTime(2026, 11, 17);
    var n = 0;

    Task task({DateTime? doneAt, String? list, String? parent}) => Task(
      id: 't${n++}',
      listId: list,
      parentId: parent,
      title: 't',
      priority: 0,
      isDone: doneAt != null,
      doneAt: doneAt,
      reminders: '',
      alarm: false,
      sortOrder: 0,
      createdAt: today,
      updatedAt: today,
    );

    FocusSession session(DateTime start, int minutes) => FocusSession(
      id: 's${n++}',
      startedAt: start,
      endedAt: start.add(Duration(minutes: minutes)),
      focusMinutes: minutes,
      plannedMinutes: 25,
      completed: true,
    );

    test('week, active days, lists and focus time', () {
      final stats = TaskStats.compute(
        today: today,
        done: [
          task(doneAt: DateTime(2026, 11, 17, 9), list: 'work'),
          task(doneAt: DateTime(2026, 11, 17, 10), list: 'work'),
          task(doneAt: DateTime(2026, 11, 15, 20)),
          // Outside the week, inside the 30 days
          task(doneAt: DateTime(2026, 11, 1, 9), list: 'work'),
          // Too old, and a subtask: neither counts
          task(doneAt: DateTime(2026, 9, 1, 9), list: 'work'),
          task(doneAt: DateTime(2026, 11, 17, 9), parent: 'x'),
        ],
        open: [
          task(list: 'work'),
          task(),
          task(list: 'home'),
        ],
        activity: [
          ActivityDay(day: DateTime(2026, 11, 17), completedCount: 2),
          ActivityDay(day: DateTime(2026, 11, 15), completedCount: 1),
          ActivityDay(day: DateTime(2026, 9), completedCount: 4),
          ActivityDay(day: DateTime(2026, 11, 10), completedCount: 0),
        ],
        sessions: [
          session(DateTime(2026, 11, 17, 8), 25),
          session(DateTime(2026, 11, 16, 14), 50),
          session(DateTime(2026, 11, 1, 8), 25),
        ],
      );
      expect(stats.week.map((d) => d.done), [0, 0, 0, 0, 1, 0, 2]);
      expect(stats.week.last.day, today);
      expect(stats.weekDone, 3);
      expect(stats.weekFocusMinutes, 75);
      expect(stats.focusSessions, 2);
      // Days with nothing done aren't "active"; old ones are outside 30 days
      expect(stats.activeDays, 2);
      expect(stats.heatmap[DateTime(2026, 9)], 4);
      final work = stats.lists.first;
      expect((work.listId, work.done, work.open), ('work', 3, 1));
      expect(work.rate, .75);
      final inbox = stats.lists.firstWhere((l) => l.listId == null);
      expect((inbox.done, inbox.open), (1, 1));
      expect(stats.isEmpty, isFalse);
    });

    test('a best time is named only when one stands out', () {
      TaskStats of(List<int> hours) => TaskStats.compute(
        today: today,
        done: [for (final h in hours) task(doneAt: DateTime(2026, 11, 16, h))],
        open: const [],
        activity: const [],
        sessions: const [],
      );
      expect(of([9, 9, 10, 10, 10, 15]).bestHour, 9);
      // Too few to call it a pattern
      expect(of([9, 10]).bestHour, isNull);
      // Spread evenly through the day
      expect(of([for (var h = 0; h < 24; h++) h]).bestHour, isNull);
    });

    test('nothing yet', () {
      final stats = TaskStats.compute(
        today: today,
        done: const [],
        open: const [],
        activity: const [],
        sessions: const [],
      );
      expect(stats.isEmpty, isTrue);
      expect(stats.week, hasLength(7));
    });
  });
}
