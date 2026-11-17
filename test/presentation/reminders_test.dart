import 'package:drift/native.dart';
import 'package:flutter_base/src/config/di/di.dart';
import 'package:flutter_base/src/config/theme/app_theme.dart';
import 'package:flutter_base/src/core/notifications/reminder_service.dart';
import 'package:flutter_base/src/core/notifications/reminder_settings.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/repositories/task_repository.dart';
import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_base/src/presentation/reminders/alarm_screen.dart';
import 'package:flutter_base/src/presentation/reminders/reminder_sheet.dart';
import 'package:flutter_base/src/presentation/reminders/snooze_sheet.dart';
import 'package:flutter_base/src/shared/cubit/haptics_cubit.dart';
import 'package:flutter_base/src/shared/cubit/language_cubit.dart';
import 'package:flutter_base/src/shared/helpers/day_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
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

final l10n = lookupAppLocalizations(const Locale('en'));

/// The notification plugin has no platform in tests: record instead
class _FakeReminderService extends ReminderService {
  _FakeReminderService(super.repo, super.language, super.settings);

  final dismissed = <String>[];

  @override
  Future<void> dismissShown(Task task) async => dismissed.add(task.id);
}

void main() {
  late AppDatabase db;
  late TaskRepository repo;

  setUpAll(() => initializeDateFormatting());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HydratedBloc.storage = _MemoryStorage();
    db = AppDatabase(NativeDatabase.memory());
    repo = TaskRepository(db);
    final settings = ReminderSettings();
    final language = LanguageCubit();
    getIt
      ..registerSingleton<TaskRepository>(repo)
      ..registerSingleton<HapticsCubit>(HapticsCubit())
      ..registerSingleton<LanguageCubit>(language)
      ..registerSingleton<DayClock>(DayClock())
      ..registerSingleton<ReminderSettings>(settings)
      ..registerSingleton<ReminderService>(
        _FakeReminderService(repo, language, settings),
      );
  });

  tearDown(() async {
    getIt<DayClock>().dispose();
    await getIt.reset(dispose: false);
    await db.close();
  });

  /// A button that opens [open]; animations off so pulses don't keep
  /// pumpAndSettle waiting
  Future<void> pumpOpener(
    WidgetTester tester,
    Future<void> Function(BuildContext context) open,
  ) async {
    // Tall enough for every reminder choice without scrolling
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  /// Lets the in-memory database finish, then the UI
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<Task> seed(WidgetTester tester, TaskDraft draft) async {
    final task = await tester.runAsync(() async {
      final id = await repo.create(draft);
      return repo.getTask(id);
    });
    return task!;
  }

  Future<Task> reload(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => repo.getTask(id)))!;

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Drift closes cancelled streams on a zero-length timer
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('picks several reminders and the alarm style', (tester) async {
    final task = await seed(
      tester,
      TaskDraft(
        title: 'Dentist',
        dueDate: DateTime(2030, 1, 7),
        dueTime: 17 * 60,
        reminders: const [0],
      ),
    );
    await pumpOpener(tester, (context) => ReminderSheet.show(context, task));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Timed task: minute and hour offsets on offer, at-time already ticked
    expect(find.text(l10n.reminderMinutesBefore(15)), findsOneWidget);
    expect(find.text(l10n.reminderAllDayHint), findsNothing);
    await tester.tap(find.text(l10n.reminderMinutesBefore(15)));
    await settle(tester);
    await tester.tap(find.text(l10n.reminderDaysBefore(1)));
    await settle(tester);
    await tester.tap(find.text(l10n.alarmStyle));
    await settle(tester);

    var saved = await reload(tester, task.id);
    expect(saved.reminderOffsets, [0, 15, 1440]);
    expect(saved.alarm, isTrue);

    // Unticking all of them turns the alarm switch off-limits
    for (final offset in [0, 15, 1440]) {
      await tester.tap(find.text(_label(offset)));
      await settle(tester);
    }
    final alarm = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(alarm.onChanged, isNull);
    saved = await reload(tester, task.id);
    expect(saved.reminderOffsets, isEmpty);

    await tester.tap(find.text(l10n.actionDone));
    await settle(tester);
    expect(find.byType(ReminderSheet), findsNothing);
    await finish(tester);
  });

  testWidgets('all-day tasks offer day-level reminders and say when', (
    tester,
  ) async {
    final task = await seed(
      tester,
      TaskDraft(title: 'Taxes', dueDate: DateTime(2030, 1, 7)),
    );
    await pumpOpener(tester, (context) => ReminderSheet.show(context, task));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reminderMinutesBefore(15)), findsNothing);
    expect(find.text(l10n.reminderDaysBefore(7)), findsOneWidget);
    expect(find.text(l10n.reminderAllDayHint), findsOneWidget);
    await finish(tester);
  });

  testWidgets('alarm screen: Done completes the task and closes', (
    tester,
  ) async {
    final task = await seed(
      tester,
      TaskDraft(
        title: 'Take medicine',
        dueDate: DateTime(2030, 1, 7),
        dueTime: 8 * 60,
        reminders: const [0],
        alarm: true,
      ),
    );
    await pumpOpener(tester, (context) => AlarmScreen.show(context, task.id));
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(find.byType(AlarmScreen), findsOneWidget);
    expect(find.text('Take medicine'), findsOneWidget);
    await tester.tap(find.text(l10n.actionDone));
    await settle(tester);

    expect(find.byType(AlarmScreen), findsNothing);
    expect((await reload(tester, task.id)).isDone, isTrue);
    // Leaving the screen stops the ringing
    expect((getIt<ReminderService>() as _FakeReminderService).dismissed, [
      task.id,
    ]);
    await finish(tester);
  });

  testWidgets('alarm screen: snoozing rings again later and says when', (
    tester,
  ) async {
    final task = await seed(
      tester,
      TaskDraft(
        title: 'Call mum',
        dueDate: DateTime(2030, 1, 7),
        dueTime: 8 * 60,
        reminders: const [0],
        alarm: true,
      ),
    );
    await pumpOpener(tester, (context) => AlarmScreen.show(context, task.id));
    await tester.tap(find.text('open'));
    await settle(tester);

    final before = DateTime.now();
    await tester.tap(find.text(l10n.snoozeTenMinutes));
    await settle(tester);

    expect(find.byType(AlarmScreen), findsNothing);
    final until = (await reload(tester, task.id)).snoozedUntil!;
    expect(until.difference(before).inMinutes, inInclusiveRange(9, 10));
    expect(find.textContaining('Snoozed until'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a task done meanwhile shows no alarm screen', (tester) async {
    final task = await seed(
      tester,
      TaskDraft(title: 'Gone', dueDate: DateTime(2030, 1, 7)),
    );
    await tester.runAsync(() => repo.complete(task));
    await pumpOpener(tester, (context) => AlarmScreen.show(context, task.id));
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.byType(AlarmScreen), findsNothing);
    await finish(tester);
  });

  testWidgets('snooze sheet: the choices, tomorrow morning at 8:00', (
    tester,
  ) async {
    final task = await seed(
      tester,
      TaskDraft(title: 'Water plants', dueDate: DateTime(2030, 1, 7)),
    );
    await pumpOpener(tester, (context) => SnoozeSheet.show(context, task.id));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.snoozeTitle), findsOneWidget);
    expect(find.text(l10n.snoozeOneHour), findsOneWidget);
    expect(find.text(l10n.snoozeTomorrowMorning), findsOneWidget);
    expect(find.text(l10n.snoozePickTime), findsOneWidget);

    await tester.tap(find.text(l10n.snoozeTomorrowMorning));
    await settle(tester);
    final until = (await reload(tester, task.id)).snoozedUntil!;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect((until.day, until.hour, until.minute), (tomorrow.day, 8, 0));
    await finish(tester);
  });
}

String _label(int offset) => switch (offset) {
  0 => l10n.reminderAtTime,
  1440 => l10n.reminderDaysBefore(1),
  _ => l10n.reminderMinutesBefore(offset),
};
