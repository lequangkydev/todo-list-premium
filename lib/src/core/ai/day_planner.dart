import 'package:flutter/foundation.dart';

import '../../data/local/database/app_database.dart';
import '../date/dates.dart';

@immutable
class PlannedTask {
  const PlannedTask({
    required this.task,
    required this.start,
    required this.minutes,
    required this.fixed,
  });

  final Task task;

  /// Minutes after midnight
  final int start;
  final int minutes;

  /// Already had a time today; the plan works around it
  final bool fixed;

  int get end => start + minutes;
}

@immutable
class DayPlan {
  const DayPlan({required this.items, required this.later});

  /// Today's tasks in time order, timed ones and newly placed ones
  final List<PlannedTask> items;

  /// Tasks that don't fit before the end of the day
  final List<Task> later;

  /// Tasks that would get a new time
  Iterable<PlannedTask> get placed => items.where((i) => !i.fixed);
}

/// Fits today's untimed (and overdue) tasks around the ones that already
/// have a time: most important first, then oldest, then shortest. Nothing
/// is saved; the caller decides whether to apply it.
class DayPlanner {
  DayPlanner._();

  static const defaultMinutes = 30;
  static const _step = 15;
  static const _earliest = 6 * 60;
  static const _dayEnd = 22 * 60;

  static DayPlan plan({
    required List<Task> tasks,
    required DateTime now,
    required int? Function(Task task) estimateOf,
  }) {
    final today = Dates.dateOnly(now);
    int minutesOf(Task t) => (estimateOf(t) ?? defaultMinutes).clamp(5, 8 * 60);

    final fixed = <PlannedTask>[];
    final flexible = <Task>[];
    for (final task in tasks) {
      final due = task.dueDate;
      if (task.isDone || due == null || due.isAfter(today)) {
        continue;
      }
      if (task.dueTime != null && Dates.isSameDay(due, today)) {
        fixed.add(
          PlannedTask(
            task: task,
            start: task.dueTime!,
            minutes: minutesOf(task),
            fixed: true,
          ),
        );
      } else {
        flexible.add(task);
      }
    }
    fixed.sort((a, b) => a.start.compareTo(b.start));
    flexible.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) {
        return byPriority;
      }
      final byDue = a.dueDate!.compareTo(b.dueDate!);
      if (byDue != 0) {
        return byDue;
      }
      final byLength = minutesOf(a).compareTo(minutesOf(b));
      return byLength != 0 ? byLength : a.sortOrder.compareTo(b.sortOrder);
    });

    final nowMinutes = now.hour * 60 + now.minute;
    var cursor = ((nowMinutes + _step - 1) ~/ _step) * _step;
    if (cursor < _earliest) {
      cursor = _earliest;
    }
    final placed = <PlannedTask>[];
    final later = <Task>[];
    for (final task in flexible) {
      final minutes = minutesOf(task);
      var start = cursor;
      // Skip past any timed task this would overlap
      for (final f in fixed) {
        if (start < f.end && f.start < start + minutes) {
          start = f.end;
        }
      }
      if (start + minutes > _dayEnd) {
        later.add(task);
        continue;
      }
      placed.add(
        PlannedTask(task: task, start: start, minutes: minutes, fixed: false),
      );
      cursor = start + minutes;
    }
    final items = [...fixed, ...placed]
      ..sort((a, b) => a.start.compareTo(b.start));
    return DayPlan(items: items, later: later);
  }
}
