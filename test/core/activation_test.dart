import 'package:drift/native.dart';
import 'package:flutter_base/src/core/activation/setup_guide.dart';
import 'package:flutter_base/src/core/analytics/app_events.dart';
import 'package:flutter_base/src/core/notifications/reminder_service.dart';
import 'package:flutter_base/src/core/notifications/reminder_settings.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TaskRepository tasks;
  late List<(String, Map<String, Object>)> events;

  List<String> names() => [for (final e in events) e.$1];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HydratedBloc.storage = _MemoryStorage();
    db = AppDatabase(NativeDatabase.memory());
    tasks = TaskRepository(db);
    events = [];
    AppEvents.sink = (name, params) => events.add((name, params));
  });

  tearDown(() async {
    AppEvents.sink = null;
    await db.close();
  });

  group('events', () {
    test('creating and completing tasks, with flags not text', () async {
      final id = await tasks.create(
        TaskDraft(
          title: 'Secret plan',
          dueDate: DateTime(2030, 1, 7),
          dueTime: 540,
          reminders: const [0, 15],
          rrule: 'FREQ=DAILY',
        ),
      );
      await tasks.create(const TaskDraft(title: 'Someday'));
      await tasks.complete((await tasks.getTask(id))!);
      await tasks.setReminders(id, [0], alarm: true);

      expect(names(), [
        'task_created',
        'task_created',
        'task_completed',
        'reminder_set',
      ]);
      expect(events[0].$2, {
        'has_date': 1,
        'has_time': 1,
        'reminders': 2,
        'recurring': 1,
        'subtask': 0,
      });
      expect(events[1].$2['has_date'], 0);
      expect(events[2].$2, {'recurring': 1, 'subtask': 0});
      expect(events[3].$2, {'count': 1, 'alarm': 1});
      // Nothing the user typed leaves the phone
      expect(events.toString(), isNot(contains('Secret')));
    });

    test('no sink, or a failing one, never breaks the app', () async {
      AppEvents.sink = null;
      await tasks.create(const TaskDraft(title: 'Quiet'));
      AppEvents.sink = (_, _) => throw StateError('analytics down');
      await tasks.create(const TaskDraft(title: 'Still fine'));
      expect(await tasks.watchHasAnyTask().first, isTrue);
    });
  });

  group('getting started', () {
    late SetupGuide guide;
    var notifications = false;
    var widgets = 0;

    SetupGuide create() {
      final language = LanguageCubit();
      final settings = ReminderSettings();
      return SetupGuide(tasks, ReminderService(tasks, language, settings))
        ..notificationsEnabled = (() async => notifications)
        ..installedWidgets = (() async => widgets);
    }

    /// Lets the task stream and queued updates land
    Future<void> settle() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await guide.refresh();
    }

    setUp(() {
      notifications = false;
      widgets = 0;
      guide = create();
    });

    tearDown(() => guide.dispose());

    test('steps tick themselves off; done hides it for good', () async {
      await guide.start();
      await settle();
      expect(guide.state.value.visible, isTrue);
      expect(guide.state.value.doneCount, 0);

      await tasks.create(const TaskDraft(title: 'First'));
      await settle();
      expect(guide.state.value.hasTask, isTrue);
      expect(guide.state.value.doneCount, 1);
      expect(names(), containsAll(['first_task_created', 'setup_step']));

      notifications = true;
      await settle();
      expect(guide.state.value.doneCount, 2);
      expect(guide.state.value.visible, isTrue);

      widgets = 1;
      await settle();
      expect(guide.state.value.visible, isFalse);
      expect(names().where((n) => n == 'setup_done'), hasLength(1));
      // Each step was reported exactly once
      expect(
        [
          for (final e in events)
            if (e.$1 == 'setup_step') e.$2['step'],
        ],
        ['task', 'notifications', 'widget'],
      );

      // The widget is removed later: the card stays away
      widgets = 0;
      await guide.dispose();
      guide = create();
      await guide.start();
      await settle();
      expect(guide.state.value.visible, isFalse);
      expect(names().where((n) => n == 'first_task_created'), hasLength(1));
    });

    test('hiding it sticks, and says how far the user got', () async {
      await guide.start();
      await tasks.create(const TaskDraft(title: 'First'));
      await settle();
      await guide.dismiss();
      expect(guide.state.value.visible, isFalse);
      expect(events.last.$1, 'setup_dismissed');
      expect(events.last.$2, {'steps_done': 1});

      await guide.dispose();
      guide = create();
      await guide.start();
      await settle();
      expect(guide.state.value.visible, isFalse);
    });

    test('nothing shows before it has loaded', () {
      expect(const SetupState().visible, isFalse);
      expect(const SetupState(hidden: false, hasTask: true).visible, isTrue);
    });
  });
}
