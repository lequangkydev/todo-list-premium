import '../../data/local/database/app_database.dart';
import '../date/dates.dart';

class PlannedReminder {
  const PlannedReminder({
    required this.notificationId,
    required this.task,
    required this.fireAt,
  });

  final int notificationId;
  final Task task;
  final DateTime fireAt;
}

/// Decides which notifications should be pending right now.
class ReminderPlanner {
  ReminderPlanner._();

  /// iOS keeps at most 64 pending notifications and silently drops the
  /// rest; staying well under it also keeps Samsung's ~500 alarm cap safe.
  static const maxPending = 60;

  /// Reminders for all-day tasks fire at this time on the due day
  static const allDayMinutes = 9 * 60;

  static List<PlannedReminder> plan(List<Task> tasks, DateTime now) {
    final planned = <PlannedReminder>[];
    for (final task in tasks) {
      final fireAt = fireTimeOf(task, now);
      if (fireAt != null) {
        planned.add(
          PlannedReminder(
            notificationId: notificationIdOf(task.id),
            task: task,
            fireAt: fireAt,
          ),
        );
      }
    }
    planned.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return planned.take(maxPending).toList();
  }

  /// Next fire time in the future, or null
  static DateTime? fireTimeOf(Task task, DateTime now) {
    if (task.isDone || task.deletedAt != null) {
      return null;
    }
    final snoozed = task.snoozedUntil;
    if (snoozed != null && snoozed.isAfter(now)) {
      return snoozed;
    }
    final due = task.dueDate;
    final offset = task.remindOffset;
    if (due == null || offset == null) {
      return null;
    }
    final dueAt = Dates.atMinutes(due, task.dueTime ?? allDayMinutes);
    final fireAt = DateTime(
      dueAt.year,
      dueAt.month,
      dueAt.day,
      dueAt.hour,
      dueAt.minute - offset,
    );
    return fireAt.isAfter(now) ? fireAt : null;
  }

  /// Stable 31-bit id per task (FNV-1a), so rescheduling replaces in place
  static int notificationIdOf(String taskId) {
    var hash = 0x811c9dc5;
    for (final unit in taskId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
