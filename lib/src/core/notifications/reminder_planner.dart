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

enum DigestKind {
  /// "Today: 5 tasks", in the morning
  morning,

  /// "3 tasks tomorrow", in the evening
  evening,

  /// "You finished 12 tasks this week", on Sunday evening
  weekly,
}

/// A summary notification on [day]: the morning's tasks, the evening's look
/// at tomorrow, or the week's recap
class PlannedDigest {
  const PlannedDigest({
    required this.notificationId,
    required this.day,
    required this.fireAt,
    required this.due,
    required this.overdue,
    this.kind = DigestKind.morning,
    this.done = 0,
  });

  final int notificationId;
  final DateTime day;
  final DateTime fireAt;
  final DigestKind kind;

  /// Morning: open tasks due that day, by time. Evening: due the day after.
  final List<Task> due;

  /// Morning: open tasks due before that day. Evening: still open from that
  /// day or earlier.
  final List<Task> overdue;

  /// Weekly: tasks finished this week
  final int done;

  int get count => due.length + overdue.length;

  PlannedDigest _withId(int id) => PlannedDigest(
    notificationId: id,
    day: day,
    fireAt: fireAt,
    due: due,
    overdue: overdue,
    kind: kind,
    done: done,
  );
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

  /// The weekly recap comes on Sunday at this time
  static const weeklyMinutes = 18 * 60;

  /// Plans the nearest [maxPending] notifications: every reminder of every
  /// task in [tasks] and snoozes, plus the summaries that are turned on —
  /// a morning summary ([digestMinutes]) and an evening look at tomorrow
  /// ([eveningMinutes]) for each of the next [digestDays] days that has
  /// something to say, and this Sunday's recap when [weekDone] tasks were
  /// finished since Monday. Empty days and empty weeks stay quiet.
  static ReminderPlan plan(
    List<Task> tasks,
    DateTime now, {
    int? digestMinutes,
    int? eveningMinutes,
    int? weekDone,
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
    final digests = [
      if (digestMinutes != null)
        ..._digests(tasks, now, digestMinutes, DigestKind.morning),
      if (eveningMinutes != null)
        ..._digests(tasks, now, eveningMinutes, DigestKind.evening),
      if (weekDone != null) ?_weekly(now, weekDone),
    ];

    // Nearest first, across both kinds, within the budget
    final all =
        <({DateTime at, String key, Object item})>[
          for (final r in reminders)
            (at: r.fireAt, key: '${r.task.id}${r.snoozed}', item: r),
          for (final d in digests) (at: d.fireAt, key: d.kind.name, item: d),
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
          keptDigests.add(d._withId(unique(d.notificationId)));
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
    for (final offset in task.reminderOffsets)
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

  /// This week's recap, on its Sunday — unless that has passed (the new
  /// week's is planned once it has something to count) or nothing was done
  static PlannedDigest? _weekly(DateTime now, int done) {
    final sunday = Dates.addDays(Dates.startOfWeek(now), 6);
    final fireAt = Dates.atMinutes(sunday, weeklyMinutes);
    if (done <= 0 || !fireAt.isAfter(now)) {
      return null;
    }
    return PlannedDigest(
      notificationId: notificationIdOf(
        'weekly:${sunday.year}-${sunday.month}-${sunday.day}',
      ),
      day: sunday,
      fireAt: fireAt,
      due: const [],
      overdue: const [],
      kind: DigestKind.weekly,
      done: done,
    );
  }

  static List<PlannedDigest> _digests(
    List<Task> tasks,
    DateTime now,
    int minutes,
    DigestKind kind,
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
      // The morning looks at its own day; the evening at the day after,
      // and at what's still open by then
      final evening = kind == DigestKind.evening;
      final target = evening ? Dates.addDays(day, 1) : day;
      final due = [
        for (final t in open)
          if (Dates.isSameDay(t.dueDate!, target)) t,
      ]..sort(_byTime);
      final overdue = [
        for (final t in open)
          if (t.dueDate!.isBefore(target)) t,
      ];
      // Nothing to say that day: no notification at all
      if (due.isEmpty && overdue.isEmpty) {
        continue;
      }
      digests.add(
        PlannedDigest(
          notificationId: notificationIdOf(
            '${evening ? 'evening' : 'digest'}:'
            '${day.year}-${day.month}-${day.day}',
          ),
          day: day,
          fireAt: fireAt,
          due: due,
          overdue: overdue,
          kind: kind,
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
    for (final offset in task.reminderOffsets)
      notificationIdOf('${task.id}:$offset'),
    notificationIdOf('${task.id}:snooze'),
  ];
}
