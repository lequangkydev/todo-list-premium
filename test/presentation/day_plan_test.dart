import 'package:drift/native.dart';
import 'package:flutter_base/src/config/di/di.dart';
import 'package:flutter_base/src/config/theme/app_theme.dart';
import 'package:flutter_base/src/core/ai/smart_suggestions.dart';
import 'package:flutter_base/src/core/date/dates.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/repositories/task_repository.dart';
import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_base/src/presentation/planner/day_plan_screen.dart';
import 'package:flutter_base/src/shared/cubit/haptics_cubit.dart';
import 'package:flutter_base/src/shared/cubit/smart_suggestions_cubit.dart';
import 'package:flutter_base/src/shared/helpers/day_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

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

final l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  late AppDatabase db;
  late TaskRepository tasks;
  final today = Dates.today();
  final tomorrow = Dates.addDays(today, 1);

  setUpAll(() => initializeDateFormatting());

  setUp(() {
    HydratedBloc.storage = _MemoryStorage();
    db = AppDatabase(NativeDatabase.memory());
    tasks = TaskRepository(db);
    final smartCubit = SmartSuggestionsCubit();
    getIt
      ..registerSingleton<TaskRepository>(tasks)
      ..registerSingleton<HapticsCubit>(HapticsCubit())
      ..registerSingleton<SmartSuggestionsCubit>(smartCubit)
      ..registerSingleton<DayClock>(DayClock())
      ..registerLazySingleton<SmartSuggestions>(
        () => SmartSuggestions(tasks, smartCubit),
      );
  });

  tearDown(() async {
    getIt<DayClock>().dispose();
    await getIt.reset(dispose: false);
    await db.close();
  });

  Future<void> pump(WidgetTester tester, DateTime day) async {
    // Tall enough to see the morning without scrolling
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Open the database and start the suggestion engine in the real zone:
    // neither completes under the test's fake clock
    await tester.runAsync(() async {
      await tasks.getTask('-');
      getIt<SmartSuggestions>();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: DayPlanScreen(day: day),
      ),
    );
    await settle(tester);
  }

  testWidgets('timed tasks are blocks, untimed wait in the tray', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tasks.create(
        TaskDraft(title: 'Standup', dueDate: tomorrow, dueTime: 9 * 60),
      );
      await tasks.create(
        TaskDraft(title: 'Review', dueDate: tomorrow, dueTime: 9 * 60 + 15),
      );
      await tasks.create(TaskDraft(title: 'Laundry', dueDate: tomorrow));
    });
    await pump(tester, tomorrow);

    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('${l10n.unscheduled} · 1'), findsOneWidget);
    expect(find.text(l10n.unscheduledHint), findsOneWidget);
    // Overlapping tasks share the width instead of covering each other
    final standup = tester.getRect(find.text('Standup'));
    final review = tester.getRect(find.text('Review'));
    expect(review.left, greaterThan(standup.left + 40));
    expect(review.top, greaterThan(standup.top));
    await finish(tester);
  });

  testWidgets('"Arrange for me" gives untimed tasks a time, with undo', (
    tester,
  ) async {
    late String laundry;
    await tester.runAsync(() async {
      await tasks.create(
        TaskDraft(title: 'Standup', dueDate: tomorrow, dueTime: 8 * 60),
      );
      laundry = await tasks.create(
        TaskDraft(title: 'Laundry', dueDate: tomorrow),
      );
    });
    await pump(tester, tomorrow);

    await tester.tap(find.text(l10n.arrangeForMe));
    await settle(tester);

    // Planned from the morning, after the 8:00 task
    final saved = await tester.runAsync(() => tasks.getTask(laundry));
    expect(saved!.dueTime, 8 * 60 + 30);
    expect(find.text('${l10n.unscheduled} · 1'), findsNothing);
    expect(find.text(l10n.planApplied(1)), findsOneWidget);

    await tester.tap(find.text(l10n.undo));
    await settle(tester);
    expect(
      (await tester.runAsync(() => tasks.getTask(laundry)))!.dueTime,
      isNull,
    );
    await finish(tester);
  });

  testWidgets('planning tomorrow: what is still open today can move over', (
    tester,
  ) async {
    late String old;
    await tester.runAsync(() async {
      old = await tasks.create(TaskDraft(title: 'Unfinished', dueDate: today));
      await tasks.create(TaskDraft(title: 'Planned', dueDate: tomorrow));
    });
    await pump(tester, tomorrow);

    expect(find.text(l10n.leftoverCount(1)), findsOneWidget);
    await tester.tap(find.text(l10n.moveHere));
    await settle(tester);

    expect(
      (await tester.runAsync(() => tasks.getTask(old)))!.dueDate,
      tomorrow,
    );
    expect(find.text(l10n.leftoverCount(1)), findsNothing);
    expect(find.text('${l10n.unscheduled} · 2'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('an empty day says so', (tester) async {
    await pump(tester, tomorrow);
    expect(find.text(l10n.dayPlanEmpty), findsOneWidget);
    await finish(tester);
  });
}

/// Lets the in-memory database finish, then the UI
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pumpAndSettle();
}

Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  // Drift closes cancelled streams on a zero-length timer
  await tester.pump(const Duration(milliseconds: 1));
  await tester.runAsync(() => getIt<SmartSuggestions>().dispose());
}
