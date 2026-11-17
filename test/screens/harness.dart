// Renders real screens to PNG for a visual review, without a device:
//
//   fvm flutter test test/screens/screens.dart --update-goldens
//
// writes test/screens/out/<screen>_<light|dark>.png (git-ignored). The file
// isn't named *_test.dart, so the normal suite doesn't run it. Not a
// regression test: nothing is compared, the images are for looking at.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/src/config/di/di.dart';
import 'package:flutter_base/src/config/theme/app_theme.dart';
import 'package:flutter_base/src/core/activation/setup_guide.dart';
import 'package:flutter_base/src/core/ai/smart_suggestions.dart';
import 'package:flutter_base/src/core/backup/backup_folder.dart';
import 'package:flutter_base/src/core/backup/backup_service.dart';
import 'package:flutter_base/src/core/date/dates.dart';
import 'package:flutter_base/src/core/focus/focus_service.dart';
import 'package:flutter_base/src/core/focus/focus_timer.dart';
import 'package:flutter_base/src/core/notifications/reminder_service.dart';
import 'package:flutter_base/src/core/notifications/reminder_settings.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/repositories/backup_repository.dart';
import 'package:flutter_base/src/data/repositories/focus_repository.dart';
import 'package:flutter_base/src/data/repositories/list_repository.dart';
import 'package:flutter_base/src/data/repositories/task_repository.dart';
import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_base/src/shared/cubit/haptics_cubit.dart';
import 'package:flutter_base/src/shared/cubit/language_cubit.dart';
import 'package:flutter_base/src/shared/cubit/lunar_cubit.dart';
import 'package:flutter_base/src/shared/cubit/smart_suggestions_cubit.dart';
import 'package:flutter_base/src/shared/cubit/theme_mode_cubit.dart';
import 'package:flutter_base/src/shared/enum/language.dart';
import 'package:flutter_base/src/shared/helpers/day_clock.dart';
import 'package:flutter_base/src/shared/l10n/app_delegates.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class _NoNotifications extends ReminderService {
  _NoNotifications(super.repo, super.language, super.settings);

  @override
  Future<bool> notificationsEnabled() async => false;

  @override
  Future<bool> exactAlarmsAllowed() async => true;

  @override
  Future<int> pendingCount() async => 12;

  @override
  Future<void> dismissShown(Task task) async {}
}

class _NoFolder implements BackupFolder {
  @override
  Future<String?> name() async => 'Drive / Sao lưu To-do';

  @override
  Future<String?> pick() async => null;

  @override
  Future<void> clear() async {}

  @override
  Future<bool> write(String fileName, Uint8List bytes) async => true;

  @override
  Future<void> prune(String prefix, int keep) async {}
}

/// Phone-sized canvas, 2x so text is readable in the PNG
const screenSize = Size(390, 844);

late AppDatabase db;
late TaskRepository tasks;
late ListRepository lists;

final today = Dates.today();

DateTime day(int offset) => Dates.addDays(today, offset);

Future<void> loadFonts() async {
  Future<ByteData> bytes(String path) async =>
      ByteData.view((await File(path).readAsBytes()).buffer);
  final jakarta = FontLoader('PlusJakartaSans');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jakarta.addFont(
      bytes('assets/fonts/plus_jakarta_sans/PlusJakartaSans-$weight.ttf'),
    );
  }
  await jakarta.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      bytes(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
  await icons.load();
}

/// Everything the screens look up, backed by an in-memory database
void registerApp() {
  SharedPreferences.setMockInitialValues({});
  HydratedBloc.storage = _MemoryStorage();
  db = AppDatabase(NativeDatabase.memory());
  tasks = TaskRepository(db);
  lists = ListRepository(db);
  final language = LanguageCubit()..update(Language.vietnamese);
  final smartCubit = SmartSuggestionsCubit();
  final settings = ReminderSettings();
  final reminders = _NoNotifications(tasks, language, settings);
  final focusRepo = FocusRepository(db);
  final backupRepo = BackupRepository(db);
  getIt
    ..registerSingleton<AppDatabase>(db)
    ..registerSingleton<TaskRepository>(tasks)
    ..registerSingleton<ListRepository>(lists)
    ..registerSingleton<FocusRepository>(focusRepo)
    ..registerSingleton<BackupRepository>(backupRepo)
    ..registerSingleton<LanguageCubit>(language)
    ..registerSingleton<ThemeModeCubit>(ThemeModeCubit())
    ..registerSingleton<HapticsCubit>(HapticsCubit())
    ..registerSingleton<LunarCubit>(LunarCubit())
    ..registerSingleton<SmartSuggestionsCubit>(smartCubit)
    ..registerSingleton<DayClock>(DayClock())
    ..registerSingleton<ReminderSettings>(settings)
    ..registerSingleton<ReminderService>(reminders)
    ..registerSingleton<SetupGuide>(
      SetupGuide(tasks, reminders)
        ..notificationsEnabled = (() async => false)
        ..installedWidgets = (() async => 0),
    )
    ..registerSingleton<BackupService>(
      BackupService(backupRepo)
        ..folder = _NoFolder()
        ..directory = (() async => Directory.systemTemp.createTemp('shots')),
    )
    ..registerSingleton<FocusService>(
      FocusService(focusRepo, tasks, language)..notifications = false,
    )
    ..registerLazySingleton<SmartSuggestions>(
      () => SmartSuggestions(tasks, smartCubit),
    );
}

Future<void> unregisterApp() async {
  getIt<DayClock>().dispose();
  getIt<FocusService>().dispose();
  await getIt<SetupGuide>().dispose();
  await getIt.reset(dispose: false);
  await db.close();
}

/// A believable week of one person's tasks
Future<void> seed() async {
  final work = await lists.create('Công việc', 0xFF0F766E);
  final home = await lists.create('Nhà cửa', 0xFFC2410C);
  final health = await lists.create('Sức khoẻ', 0xFF2563EB);
  await lists.create('Đọc sách', 0xFF7C3AED);

  // Today
  final meeting = await tasks.create(
    TaskDraft(
      title: 'Họp nhóm dự án quý 4',
      listId: work,
      dueDate: today,
      dueTime: 9 * 60,
      priority: 3,
      reminders: const [0, 15],
      estimateMinutes: 45,
      note: 'Phòng họp tầng 3',
    ),
  );
  await tasks.create(TaskDraft(title: 'Chuẩn bị slide', parentId: meeting));
  await tasks.create(
    TaskDraft(title: 'Gửi lịch cho cả nhóm', parentId: meeting),
  );
  await tasks.create(
    TaskDraft(
      title: 'Gửi báo cáo tuần cho anh Minh',
      listId: work,
      dueDate: today,
      dueTime: 11 * 60,
      priority: 2,
      reminders: const [0],
    ),
  );
  await tasks.create(
    TaskDraft(title: 'Đi chợ mua rau củ', listId: home, dueDate: today),
  );
  await tasks.create(
    TaskDraft(
      title: 'Chạy bộ 5 km',
      listId: health,
      dueDate: today,
      dueTime: 18 * 60,
      rrule: 'FREQ=DAILY',
      reminders: const [0],
      alarm: true,
      estimateMinutes: 40,
    ),
  );
  await tasks.create(
    TaskDraft(title: 'Gọi điện cho mẹ', dueDate: today, priority: 1),
  );

  // Overdue
  await tasks.create(
    TaskDraft(
      title: 'Đóng tiền điện tháng này',
      listId: home,
      dueDate: day(-1),
      priority: 3,
    ),
  );
  await tasks.create(TaskDraft(title: 'Trả sách thư viện', dueDate: day(-3)));

  // Upcoming
  await tasks.create(
    TaskDraft(
      title: 'Khám răng định kỳ',
      listId: health,
      dueDate: day(1),
      dueTime: 8 * 60 + 30,
      reminders: const [60, 1440],
    ),
  );
  await tasks.create(
    TaskDraft(
      title: 'Nộp hồ sơ thuế',
      listId: work,
      dueDate: day(1),
      priority: 3,
    ),
  );
  await tasks.create(
    TaskDraft(title: 'Sinh nhật Lan', dueDate: day(3), rrule: 'FREQ=YEARLY'),
  );
  await tasks.create(
    TaskDraft(
      title: 'Dọn nhà đón Tết',
      listId: home,
      dueDate: day(6),
      priority: 2,
    ),
  );
  await tasks.create(
    TaskDraft(title: 'Đặt vé về quê', dueDate: day(9), priority: 2),
  );
  await tasks.create(const TaskDraft(title: 'Ý tưởng: học đàn guitar'));
  await tasks.create(const TaskDraft(title: 'Tìm hiểu khoá học tiếng Nhật'));

  // Finished over the last days, at different hours
  Future<void> finished(
    String title,
    int daysAgo,
    int hour, {
    String? list,
  }) async {
    final id = await tasks.create(
      TaskDraft(title: title, listId: list, dueDate: day(-daysAgo)),
    );
    await tasks.complete(
      (await tasks.getTask(id))!,
      now: day(-daysAgo).add(Duration(hours: hour, minutes: 20)),
    );
  }

  await finished('Trả lời email khách hàng', 0, 8, list: work);
  await finished('Tưới cây', 0, 7, list: home);
  await finished('Review code của Hùng', 1, 10, list: work);
  await finished('Tập yoga buổi sáng', 1, 6, list: health);
  await finished('Lên kế hoạch sprint', 1, 9, list: work);
  await finished('Giặt đồ', 2, 20, list: home);
  await finished('Viết tài liệu API', 3, 10, list: work);
  await finished('Đi bộ 30 phút', 3, 18, list: health);
  await finished('Thanh toán internet', 4, 9, list: home);
  await finished('Họp khách hàng', 5, 14, list: work);
  await finished('Mua quà sinh nhật', 6, 19);
  for (var i = 8; i < 60; i += 2) {
    await finished('Việc cũ $i', i, 9 + i % 5, list: i.isEven ? work : home);
  }

  // Focus time
  final focus = getIt<FocusRepository>();
  for (final (daysAgo, hour, minutes) in [
    (0, 8, 25),
    (1, 9, 25),
    (1, 14, 50),
    (2, 10, 25),
    (4, 9, 25),
  ]) {
    final start = day(-daysAgo).add(Duration(hours: hour));
    await focus.add(
      FocusRecord(
        taskId: meeting,
        startedAt: start,
        endedAt: start.add(Duration(minutes: minutes)),
        focusMinutes: minutes,
        plannedMinutes: minutes,
        completed: true,
      ),
    );
  }
}

Widget app(Widget home, Brightness brightness) {
  return MultiBlocProvider(
    providers: [
      BlocProvider.value(value: getIt<LanguageCubit>()),
      BlocProvider.value(value: getIt<ThemeModeCubit>()),
      BlocProvider.value(value: getIt<HapticsCubit>()),
      BlocProvider.value(value: getIt<SmartSuggestionsCubit>()),
      BlocProvider.value(value: getIt<LunarCubit>()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness),
      locale: const Locale('vi'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// Lets database streams deliver and entrance animations finish
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 700));
}

/// Renders [build] in both themes and saves the pictures. [after] runs once
/// the screen is up, e.g. to open a sheet.
Future<void> shoot(
  WidgetTester tester,
  String name,
  Widget Function() build, {
  Future<void> Function(WidgetTester tester)? after,
}) async {
  tester.view
    ..physicalSize = screenSize * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  // Real shadows instead of the test framework's solid blocks
  debugDisableShadows = false;
  try {
    await _shootBoth(tester, name, build, after);
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _shootBoth(
  WidgetTester tester,
  String name,
  Widget Function() build,
  Future<void> Function(WidgetTester tester)? after,
) async {
  for (final brightness in Brightness.values) {
    await tester.pumpWidget(
      KeyedSubtree(key: UniqueKey(), child: app(build(), brightness)),
    );
    await settle(tester);
    if (after != null) {
      await after(tester);
      await settle(tester);
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/${name}_${brightness.name}.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }
}

/// Database, fonts and services for one screenshot test
void useApp() {
  setUpAll(() async {
    await initializeDateFormatting();
    await loadFonts();
  });
  setUp(registerApp);
  tearDown(unregisterApp);
}

/// Opens the database and seeds it in the real zone (neither completes
/// under the test's fake clock), then starts what the screens listen to
Future<void> prepare(WidgetTester tester, {bool empty = false}) async {
  await tester.runAsync(() async {
    if (!empty) {
      await seed();
    } else {
      await tasks.getTask('-');
    }
    getIt<SmartSuggestions>();
    await getIt<ReminderSettings>().load();
    await getIt<SetupGuide>().start();
    await getIt<BackupService>().backupNow();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}

/// The bottom bar Home shows, so tabs are seen in context
Widget shell(BuildContext context, int index, Widget tab) {
  final l10n = AppLocalizations.of(context);
  return Scaffold(
    body: tab,
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.wb_sunny_outlined),
          selectedIcon: const Icon(Icons.wb_sunny_rounded),
          label: l10n.today,
        ),
        NavigationDestination(
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month_rounded),
          label: l10n.upcoming,
        ),
        NavigationDestination(
          icon: const Icon(Icons.format_list_bulleted_rounded),
          selectedIcon: const Icon(Icons.view_list_rounded),
          label: l10n.lists,
        ),
      ],
    ),
  );
}

/// The app bar icons Home passes to each tab
List<Widget> homeActions(BuildContext context) => [
  IconButton(icon: const Icon(Icons.timer_outlined), onPressed: () {}),
  IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
  IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
];
