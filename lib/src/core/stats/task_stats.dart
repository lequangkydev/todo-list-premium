import 'package:flutter/foundation.dart';

import '../../data/local/database/app_database.dart';
import '../date/dates.dart';

/// One day of the week chart
@immutable
class DayStat {
  const DayStat(this.day, {required this.done, required this.focusMinutes});

  final DateTime day;
  final int done;
  final int focusMinutes;
}

/// How a list is going: done in the last 30 days against what's still open
@immutable
class ListStat {
  const ListStat({
    required this.listId,
    required this.done,
    required this.open,
  });

  /// null = Inbox
  final String? listId;
  final int done;
  final int open;

  int get total => done + open;

  double get rate => total == 0 ? 0 : done / total;
}

/// Everything the stats screen shows, from plain data. Nothing here is a
/// score: no streaks, no "you broke your streak" — only days with activity.
@immutable
class TaskStats {
  const TaskStats({
    required this.week,
    required this.heatmap,
    required this.activeDays,
    required this.lists,
    required this.bestHour,
    required this.focusSessions,
  });

  /// Last 7 days, oldest first, today last
  final List<DayStat> week;

  /// Completions per day (from the activity table), for the heatmap
  final Map<DateTime, int> heatmap;

  /// Days with at least one completion in the last [periodDays]
  final int activeDays;

  /// Lists with anything done or open, busiest first
  final List<ListStat> lists;

  /// Start of the two-hour window most tasks get done in, when one clearly
  /// stands out
  final int? bestHour;

  /// Focus sessions in the last 7 days
  final int focusSessions;

  static const periodDays = 30;

  int get weekDone => week.fold(0, (sum, d) => sum + d.done);

  int get weekFocusMinutes => week.fold(0, (sum, d) => sum + d.focusMinutes);

  bool get isEmpty =>
      weekDone == 0 &&
      weekFocusMinutes == 0 &&
      heatmap.isEmpty &&
      lists.isEmpty;

  /// [done] are completed top-level tasks (at least the last
  /// [periodDays]), [open] the open top-level tasks
  static TaskStats compute({
    required DateTime today,
    required List<Task> done,
    required List<Task> open,
    required List<ActivityDay> activity,
    required List<FocusSession> sessions,
  }) {
    final day0 = Dates.dateOnly(today);
    final weekStart = Dates.addDays(day0, -6);
    final periodStart = Dates.addDays(day0, -(periodDays - 1));

    final doneByDay = <DateTime, int>{};
    final doneByList = <String?, int>{};
    final byHour = List.filled(24, 0);
    var inPeriod = 0;
    for (final task in done) {
      final at = task.doneAt;
      if (at == null || task.parentId != null) {
        continue;
      }
      final day = Dates.dateOnly(at);
      if (day.isBefore(periodStart) || day.isAfter(day0)) {
        continue;
      }
      inPeriod++;
      doneByDay[day] = (doneByDay[day] ?? 0) + 1;
      doneByList[task.listId] = (doneByList[task.listId] ?? 0) + 1;
      byHour[at.hour]++;
    }

    final focusByDay = <DateTime, int>{};
    var sessionsThisWeek = 0;
    for (final s in sessions) {
      final day = Dates.dateOnly(s.startedAt);
      if (day.isBefore(weekStart) || day.isAfter(day0)) {
        continue;
      }
      sessionsThisWeek++;
      focusByDay[day] = (focusByDay[day] ?? 0) + s.focusMinutes;
    }

    final week = [
      for (var i = 0; i < 7; i++)
        DayStat(
          Dates.addDays(weekStart, i),
          done: doneByDay[Dates.addDays(weekStart, i)] ?? 0,
          focusMinutes: focusByDay[Dates.addDays(weekStart, i)] ?? 0,
        ),
    ];

    final heatmap = <DateTime, int>{
      for (final a in activity)
        if (a.completedCount > 0) Dates.dateOnly(a.day): a.completedCount,
    };
    final activeDays = heatmap.keys
        .where((d) => !d.isBefore(periodStart) && !d.isAfter(day0))
        .length;

    final openByList = <String?, int>{};
    for (final task in open) {
      if (task.isDone || task.deletedAt != null || task.parentId != null) {
        continue;
      }
      openByList[task.listId] = (openByList[task.listId] ?? 0) + 1;
    }
    final lists = [
      for (final id in {...doneByList.keys, ...openByList.keys})
        ListStat(
          listId: id,
          done: doneByList[id] ?? 0,
          open: openByList[id] ?? 0,
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));

    return TaskStats(
      week: week,
      heatmap: heatmap,
      activeDays: activeDays,
      lists: lists,
      bestHour: _bestWindow(byHour, inPeriod),
      focusSessions: sessionsThisWeek,
    );
  }

  /// The two-hour window with the most completions, if it holds at least 5
  /// and a quarter of them — otherwise there's no pattern worth saying
  static int? _bestWindow(List<int> byHour, int total) {
    var best = -1;
    var bestCount = 0;
    for (var h = 0; h < 23; h++) {
      final count = byHour[h] + byHour[h + 1];
      if (count > bestCount) {
        best = h;
        bestCount = count;
      }
    }
    return best >= 0 && bestCount >= 5 && bestCount * 4 >= total ? best : null;
  }
}
