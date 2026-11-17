import 'package:drift/native.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_base/src/config/di/di.dart';
import 'package:flutter_base/src/config/theme/app_theme.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/repositories/task_repository.dart';
import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_base/src/presentation/tasks/widgets/task_tile.dart';
import 'package:flutter_base/src/shared/cubit/haptics_cubit.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Widget child, {bool reducedMotion = false}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Widget _group(List<String> ids, {bool reducedMotion = false}) => _app(
  TaskGroup(
    children: [
      for (final id in ids)
        SizedBox(key: ValueKey(id), height: 40, child: Text(id)),
    ],
  ),
  reducedMotion: reducedMotion,
);

double _sizeFactor(WidgetTester tester, String id) {
  final transition = tester.widget<SizeTransition>(
    find.ancestor(of: find.text(id), matching: find.byType(SizeTransition)),
  );
  return transition.sizeFactor.value;
}

Task _task({bool done = false}) => Task(
  id: 't1',
  title: 'Water the plants',
  priority: 0,
  isDone: done,
  reminders: const [],
  alarm: false,
  sortOrder: 1,
  createdAt: DateTime(2026, 11, 13),
  updatedAt: DateTime(2026, 11, 13),
);

/// Keeps hydrated state in memory for tests
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
  group('TaskGroup', () {
    testWidgets('rows present on first build do not animate', (tester) async {
      await tester.pumpWidget(_group(['a', 'b']));
      expect(_sizeFactor(tester, 'a'), 1);
      expect(_sizeFactor(tester, 'b'), 1);
    });

    testWidgets('a new row grows in', (tester) async {
      await tester.pumpWidget(_group(['a']));
      await tester.pumpWidget(_group(['a', 'b']));
      expect(_sizeFactor(tester, 'b'), 0);
      await tester.pump(const Duration(milliseconds: 140));
      expect(_sizeFactor(tester, 'b'), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_sizeFactor(tester, 'b'), 1);
    });

    testWidgets('a removed row collapses in place, then goes', (tester) async {
      await tester.pumpWidget(_group(['a', 'b', 'c']));
      await tester.pumpWidget(_group(['a', 'c']));
      // Still there, between a and c, while it leaves
      expect(find.text('b'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('b')).dy,
        lessThan(tester.getTopLeft(find.text('c')).dy),
      );
      await tester.pumpAndSettle();
      expect(find.text('b'), findsNothing);
      expect(find.text('a'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
    });

    testWidgets('a row coming back while leaving grows back (Undo)', (
      tester,
    ) async {
      await tester.pumpWidget(_group(['a', 'b']));
      await tester.pumpWidget(_group(['a']));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_group(['a', 'b']));
      await tester.pumpAndSettle();
      expect(find.text('b'), findsOneWidget);
      expect(_sizeFactor(tester, 'b'), 1);
    });

    testWidgets('reduced motion adds and removes instantly', (tester) async {
      await tester.pumpWidget(_group(['a', 'b'], reducedMotion: true));
      await tester.pumpWidget(_group(['a'], reducedMotion: true));
      await tester.pump();
      expect(find.text('b'), findsNothing);
      await tester.pumpWidget(_group(['a', 'c'], reducedMotion: true));
      expect(_sizeFactor(tester, 'c'), 1);
    });
  });

  group('StrikeText', () {
    CustomPaint paintOf(WidgetTester tester) => tester.widget<CustomPaint>(
      find
          .ancestor(
            of: find.text('Buy milk'),
            matching: find.byType(CustomPaint),
          )
          .first,
    );

    Widget strike(bool struck, {bool reducedMotion = false}) => _app(
      StrikeText(
        'Buy milk',
        struck: struck,
        style: const TextStyle(fontSize: 16),
        color: Colors.black,
      ),
      reducedMotion: reducedMotion,
    );

    testWidgets('draws the line in over time', (tester) async {
      await tester.pumpWidget(strike(false));
      expect(paintOf(tester).foregroundPainter, isNull);
      await tester.pumpWidget(strike(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(paintOf(tester).foregroundPainter, isNotNull);
      await tester.pumpAndSettle();
      expect(paintOf(tester).foregroundPainter, isNotNull);
    });

    testWidgets('starts struck without animating', (tester) async {
      await tester.pumpWidget(strike(true));
      expect(paintOf(tester).foregroundPainter, isNotNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('TaskTile', () {
    testWidgets('offers swipe actions to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          TaskGroup(
            children: [
              TaskTile(
                key: const ValueKey('t1'),
                task: _task(),
                today: DateTime(2026, 11, 13),
                showDate: false,
              ),
            ],
          ),
        ),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(TaskTile)));
      final node = tester.getSemantics(
        find
            .ancestor(
              of: find.byType(Slidable),
              matching: find.byType(Semantics),
            )
            .first,
      );
      final labels = node.getSemanticsData().customSemanticsActionIds!.map(
        (id) => CustomSemanticsAction.getAction(id)!.label,
      );
      expect(
        labels,
        containsAll([l10n.actionDone, l10n.tomorrow, l10n.delete]),
      );
      handle.dispose();
    });

    testWidgets('a done task can only be deleted', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          TaskGroup(
            children: [
              TaskTile(
                key: const ValueKey('t1'),
                task: _task(done: true),
                today: DateTime(2026, 11, 13),
                showDate: false,
              ),
            ],
          ),
        ),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(TaskTile)));
      final node = tester.getSemantics(
        find
            .ancestor(
              of: find.byType(Slidable),
              matching: find.byType(Semantics),
            )
            .first,
      );
      final labels = node
          .getSemanticsData()
          .customSemanticsActionIds!
          .map((id) => CustomSemanticsAction.getAction(id)!.label)
          .toList();
      expect(labels, [l10n.delete]);
      handle.dispose();
    });
  });

  group('swipe to complete', () {
    late AppDatabase db;
    late TaskRepository repo;

    setUp(() {
      HydratedBloc.storage = _MemoryStorage();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = TaskRepository(db);
      getIt
        ..registerSingleton<TaskRepository>(repo)
        ..registerSingleton<HapticsCubit>(HapticsCubit());
    });

    tearDown(() async {
      await getIt.reset();
      await db.close();
    });

    testWidgets('completes the task and leaves the row visible', (
      tester,
    ) async {
      final task = await tester.runAsync(() async {
        final id = await repo.create(const TaskDraft(title: 'Stretch'));
        return repo.getTask(id);
      });
      await tester.pumpWidget(
        _app(
          TaskGroup(
            children: [
              TaskTile(
                key: ValueKey(task!.id),
                task: task,
                today: DateTime(2026, 11, 13),
                showDate: false,
              ),
            ],
          ),
        ),
      );
      final height = tester.getSize(find.byType(TaskTile)).height;
      // Move in steps with frames in between, like a real finger
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Stretch')),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(50, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      // Let the in-memory database finish the write
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      final saved = await tester.runAsync(() => repo.getTask(task.id));
      expect(saved!.isDone, isTrue);
      // The pane closed again instead of collapsing the row
      expect(tester.getSize(find.byType(TaskTile)).height, height);
    });
  });
}
