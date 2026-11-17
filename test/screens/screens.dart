import 'package:flutter_base/src/config/di/di.dart';
import 'package:flutter_base/src/core/backup/backup_codec.dart';
import 'package:flutter_base/src/core/focus/focus_service.dart';
import 'package:flutter_base/src/data/repositories/backup_repository.dart';
import 'package:flutter_base/src/gen/l18n/app_localizations.dart';
import 'package:flutter_base/src/presentation/backup/backup_screen.dart';
import 'package:flutter_base/src/presentation/backup/restore_sheet.dart';
import 'package:flutter_base/src/presentation/completed/completed_screen.dart';
import 'package:flutter_base/src/presentation/focus/focus_screen.dart';
import 'package:flutter_base/src/presentation/lists/list_detail_screen.dart';
import 'package:flutter_base/src/presentation/lists/lists_tab.dart';
import 'package:flutter_base/src/presentation/planner/day_plan_screen.dart';
import 'package:flutter_base/src/presentation/reminders/alarm_screen.dart';
import 'package:flutter_base/src/presentation/reminders/reminder_check_screen.dart';
import 'package:flutter_base/src/presentation/reminders/reminder_sheet.dart';
import 'package:flutter_base/src/presentation/search/search_screen.dart';
import 'package:flutter_base/src/presentation/setting/setting_screen.dart';
import 'package:flutter_base/src/presentation/stats/stats_screen.dart';
import 'package:flutter_base/src/presentation/tasks/quick_add_sheet.dart';
import 'package:flutter_base/src/presentation/tasks/task_editor_sheet.dart';
import 'package:flutter_base/src/presentation/today/today_tab.dart';
import 'package:flutter_base/src/presentation/upcoming/upcoming_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

/// A blank page with one button that opens something (a sheet, a route)
Widget opener(Future<void> Function(BuildContext context) open) => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: TextButton(
        key: const Key('open'),
        onPressed: () => open(context),
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> tapOpen(WidgetTester tester) =>
    tester.tap(find.byKey(const Key('open')));

void main() {
  useApp();

  testWidgets('today', (tester) async {
    await prepare(tester);
    await shoot(
      tester,
      '01_today',
      () => Builder(
        builder: (context) =>
            shell(context, 0, TodayTab(actions: homeActions(context))),
      ),
    );
  });

  testWidgets('today, empty', (tester) async {
    await prepare(tester, empty: true);
    await shoot(
      tester,
      '02_today_empty',
      () => Builder(
        builder: (context) =>
            shell(context, 0, TodayTab(actions: homeActions(context))),
      ),
    );
  });

  testWidgets('upcoming list', (tester) async {
    await prepare(tester);
    await shoot(
      tester,
      '03_upcoming',
      () => Builder(
        builder: (context) =>
            shell(context, 1, UpcomingTab(actions: homeActions(context))),
      ),
    );
  });

  testWidgets('upcoming month', (tester) async {
    await prepare(tester);
    await shoot(
      tester,
      '04_month',
      () => Builder(
        builder: (context) =>
            shell(context, 1, UpcomingTab(actions: homeActions(context))),
      ),
      after: (tester) async {
        final l10n = lookupAppLocalizations(const Locale('vi'));
        await tester.tap(find.byTooltip(l10n.calendarView));
      },
    );
  });

  testWidgets('lists', (tester) async {
    await prepare(tester);
    await shoot(
      tester,
      '05_lists',
      () => Builder(
        builder: (context) =>
            shell(context, 2, ListsTab(actions: homeActions(context))),
      ),
    );
  });

  testWidgets('list detail', (tester) async {
    await prepare(tester);
    final id = (await tester.runAsync(
      () => lists.watchLists().first,
    ))!.first.list.id;
    await shoot(tester, '06_list_detail', () => ListDetailScreen(listId: id));
  });

  testWidgets('completed', (tester) async {
    await prepare(tester);
    await shoot(tester, '07_completed', () => const CompletedScreen());
  });

  testWidgets('stats', (tester) async {
    await prepare(tester);
    await shoot(tester, '08_stats', () => const StatsScreen());
  });

  testWidgets('focus', (tester) async {
    await prepare(tester);
    await shoot(tester, '09_focus', () => const FocusScreen());
  });

  testWidgets('focus, running', (tester) async {
    await prepare(tester);
    final task = (await tester.runAsync(
      () => tasks.watchDueBy(today).first,
    ))!.firstWhere((t) => t.dueTime == 9 * 60);
    await tester.runAsync(
      () => getIt<FocusService>().startFocus(taskId: task.id),
    );
    await shoot(tester, '10_focus_running', () => const FocusScreen());
    await tester.runAsync(() => getIt<FocusService>().stop());
  });

  testWidgets('day plan', (tester) async {
    await prepare(tester);
    await shoot(tester, '11_day_plan', () => DayPlanScreen(day: today));
  });

  testWidgets('settings', (tester) async {
    await prepare(tester);
    await shoot(tester, '12_settings', () => const SettingScreen());
  });

  testWidgets('reminder check', (tester) async {
    await prepare(tester);
    await shoot(tester, '13_reminder_check', () => const ReminderCheckScreen());
  });

  testWidgets('backup', (tester) async {
    await prepare(tester);
    await shoot(tester, '14_backup', () => const BackupScreen());
  });

  testWidgets('search', (tester) async {
    await prepare(tester);
    await shoot(tester, '15_search', () => const SearchScreen());
  });

  testWidgets('task editor', (tester) async {
    await prepare(tester);
    final task = (await tester.runAsync(
      () => tasks.watchDueBy(today).first,
    ))!.firstWhere((t) => t.dueTime == 9 * 60);
    await shoot(
      tester,
      '16_editor',
      () => opener((context) => TaskEditorSheet.show(context, task.id)),
      after: tapOpen,
    );
  });

  testWidgets('quick add', (tester) async {
    await prepare(tester);
    await shoot(
      tester,
      '17_quick_add',
      () => opener(QuickAddSheet.show),
      after: (tester) async {
        await tapOpen(tester);
        await settle(tester);
        await tester.enterText(
          find.byType(TextField),
          'Họp phụ huynh thứ 6 9h !!',
        );
      },
    );
  });

  testWidgets('reminders sheet', (tester) async {
    await prepare(tester);
    final task = (await tester.runAsync(
      () => tasks.watchDueBy(today).first,
    ))!.firstWhere((t) => t.dueTime == 9 * 60);
    await shoot(
      tester,
      '18_reminders',
      () => opener((context) => ReminderSheet.show(context, task)),
      after: tapOpen,
    );
  });

  testWidgets('alarm', (tester) async {
    await prepare(tester);
    final task = (await tester.runAsync(
      () => tasks.watchDueBy(today).first,
    ))!.firstWhere((t) => t.dueTime == 18 * 60);
    await shoot(tester, '19_alarm', () => AlarmScreen(task: task));
  });

  testWidgets('restore sheet', (tester) async {
    await prepare(tester);
    final data = (await tester.runAsync(
      () => getIt<BackupRepository>().snapshot(),
    ))!;
    await shoot(
      tester,
      '20_restore',
      () => opener((context) async {
        await RestoreSheet.show(
          context,
          BackupCodec.decode(BackupCodec.encode(data)),
        );
      }),
      after: tapOpen,
    );
  });
}
