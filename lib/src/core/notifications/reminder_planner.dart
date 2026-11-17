import '../../data/local/database/app_database.dart';
import '../date/dates.dart';

/// A task reminder (or its snooze) due to be shown at [fireAt]
class PlannedReminder {
  const PlannedReminder({
    required this.notificationId,
    required this.task,
    required this.fireAt,
    this.snoozed = false,
  });

  final int notificationId;
  final Task task;
  final DateTime fireAt;

  /// The user snoozed this task; not one of its regular reminders
  final bool snoozed;
}

/// "Today: 5 tasks" on the morning of [day]
class PlannedDigest {
  const PlannedDigest({
    required this.notificationId,
    required this.day,
    required this.fireAt,
    required this.due,
    required this.overdue,
  });

  final int notificationId;
  final DateTime day;
  final DateTime fireAt;

  /// Open tasks due that day, then by time
  final List<Task> due;

  /// Open tasks due before that day
  final List<Task> overdue;

  int get count => due.length + overdue.length;
}

class ReminderPlan {
  const ReminderPlan(this.reminders, this.digests);

  final List<PlannedReminder> reminders;
  final List<PlannedDigest> digests;

  Set<int> get ids => {
    for (final r in reminders) r.notificationId,
    for (final d in digests) d.notificationId,
  };
}

/// Decides which notifications should be pending right now.
class ReminderPlanner {
  ReminderPlanner._();

  /// iOS keeps at most 64 pending notifications and silently drops the
  /// rest; staying well under it also keeps Samsung's ~500 alarm cap safe.
  /// Leaves room for the test notification.
  static const maxPending = 60;

  /// Reminders for all-day tasks fire relative to this time on the due day
  static const allDayMinutes = 9 * 60;

  /// Morning summaries are scheduled this many days ahead (the app re-plans
  /// whenever it runs, so this only matters if it isn't opened for a while)
  static const digestDays = 7;

  /// Plans the nearest [maxPending] notifications: every reminder of every
  /// task in [tasks], snoozes, and (when [digestMinutes] is set) a morning
  /// summary for each of the next [digestDays] days that has something due.
  static ReminderPlan plan(
    List<Task> tasks,
    DateTime now, {
    int? digestMinutes,
  }) {
    final reminders = <PlannedReminder>[];
    for (final task in tasks) {
      final snooze = snoozeTimeOf(task, now);
      if (snooze != null) {
        reminders.add(
          PlannedReminder(
            notificationId: notificationIdOf('${task.id}:snooze'),
            task: task,
            fireAt: snooze,
            snoozed: true,
          ),
        );
      }
      for (final (offset, fireAt) in fireTimesOf(task, now)) {
        // Snoozed to the minute another reminder rings: ring once
        if (snooze != null && _sameMinute(snooze, fireAt)) {
          continue;
        }
        reminders.add(
          PlannedReminder(
            notificationId: notificationIdOf('${task.id}:$offset'),
            task: task,
            fireAt: fireAt,
          ),
        );
      }
    }
    final digests = digestMinutes == null
        ? const <PlannedDigest>[]
        : _digests(tasks, now, digestMinutes);

    // Nearest first, across both kinds, within the budget
    final all =
        <({DateTime at, String key, Object item})>[
          for (final r in reminders)
            (at: r.fireAt, key: '${r.task.id}${r.snoozed}', item: r),
          for (final d in digests) (at: d.fireAt, key: '', item: d),
        ]..sort((a, b) {
          final byTime = a.at.compareTo(b.at);
          return byTime != 0 ? byTime : a.key.compareTo(b.key);
        });
    final kept = all.take(maxPending);

    // Two keys hashing to one id would replace each other: move the later
    // one to the next free id (deterministic, since the order is)
    final used = <int>{};
    int unique(int id) {
      var candidate = id;
      while (!used.add(candidate)) {
        candidate = (candidate + 1) & 0x7FFFFFFF;
      }
      return candidate;
    }

    final keptReminders = <PlannedReminder>[];
    final keptDigests = <PlannedDigest>[];
    for (final entry in kept) {
      switch (entry.item) {
        case final PlannedReminder r:
          keptReminders.add(
            PlannedReminder(
              notificationId: unique(r.notificationId),
              task: r.task,
              fireAt: r.fireAt,
              snoozed: r.snoozed,
            ),
          );
        case final PlannedDigest d:
          keptDigests.add(
            PlannedDigest(
              notificationId: unique(d.notificationId),
              day: d.day,
              fireAt: d.fireAt,
              due: d.due,
              overdue: d.overdue,
            ),
          );
      }
    }
    return ReminderPlan(keptReminders, keptDigests);
  }

  /// When an open task wants a notification for its reminder [offset]
  static DateTime? fireTimeOf(Task task, int offset, DateTime now) {
    if (task.isDone || task.deletedAt != null) {
      return null;
    }
    final due = task.dueDate;
    if (due == null) {
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

  /// Future fire times of all the task's reminders, as (offset, time)
  static List<(int, DateTime)> fireTimesOf(Task task, DateTime now) => [
    for (final offset in task.reminders)
      if (fireTimeOf(task, offset, now) case final at?) (offset, at),
  ];

  /// The pending snooze of an open task, if any
  static DateTime? snoozeTimeOf(Task task, DateTime now) {
    final snoozed = task.snoozedUntil;
    if (task.isDone || task.deletedAt != null || snoozed == null) {
      return null;
    }
    return snoozed.isAfter(now) ? snoozed : null;
  }

  static List<PlannedDigest> _digests(
    List<Task> tasks,
    DateTime now,
    int minutes,
  ) {
    final open = [
      for (final t in tasks)
        if (!t.isDone &&
            t.deletedAt == null &&
            t.parentId == null &&
            t.dueDate != null)
          t,
    ];
    final today = Dates.dateOnly(now);
    final digests = <PlannedDigest>[];
    for (var i = 0; i < digestDays; i++) {
      final day = Dates.addDays(today, i);
      final fireAt = Dates.atMinutes(day, minutes);
      if (!fireAt.isAfter(now)) {
        continue;
      }
      final due = [
        for (final t in open)
          if (Dates.isSameDay(t.dueDate!, day)) t,
      ]..sort(_byTime);
      final overdue = [
        for (final t in open)
          if (t.dueDate!.isBefore(day)) t,
      ];
      // Nothing to do that day: no notification at all
      if (due.isEmpty && overdue.isEmpty) {
        continue;
      }
      digests.add(
        PlannedDigest(
          notificationId: notificationIdOf(
            'digest:${day.year}-${day.month}-'
            '${day.day}',
          ),
          day: day,
          fireAt: fireAt,
          due: due,
          overdue: overdue,
        ),
      );
    }
    return digests;
  }

  static int _byTime(Task a, Task b) {
    final byTime = (a.dueTime ?? -1).compareTo(b.dueTime ?? -1);
    return byTime != 0 ? byTime : b.priority.compareTo(a.priority);
  }

  static bool _sameMinute(DateTime a, DateTime b) =>
      a.difference(b).inMinutes.abs() < 1;

  /// Stable 31-bit id per key (FNV-1a), so rescheduling replaces in place
  static int notificationIdOf(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Every id a task's notifications may use, e.g. to cancel them when the
  /// task is ticked on a widget
  static List<int> notificationIdsOf(Task task) => [
    for (final offset in task.reminders) notificationIdOf('${task.id}:$offset'),
    notificationIdOf('${task.id}:snooze'),
  ];
}
