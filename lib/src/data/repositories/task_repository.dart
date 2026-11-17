import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../core/date/dates.dart';
import '../../core/recurrence/recurrence.dart';
import '../local/database/app_database.dart';
import '../local/database/converters.dart';

/// Undo callback returned by destructive/complete actions
typedef Undo = Future<void> Function();

/// Fields for a new task
class TaskDraft {
  const TaskDraft({
    required this.title,
    this.listId,
    this.parentId,
    this.note,
    this.dueDate,
    this.dueTime,
    this.priority = 0,
    this.rrule,
    this.reminders = const [],
    this.alarm = false,
    this.estimateMinutes,
  });

  final String title;
  final String? listId;
  final String? parentId;
  final String? note;
  final DateTime? dueDate;
  final int? dueTime;
  final int priority;
  final String? rrule;

  /// Minutes before the due moment (see `Tasks.reminders`)
  final List<int> reminders;
  final bool alarm;
  final int? estimateMinutes;
}

/// Subtask progress for a parent task
class SubtaskCount {
  const SubtaskCount(this.done, this.total);

  final int done;
  final int total;
}

@lazySingleton
class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  $TasksTable get _t => _db.tasks;

  Expression<bool> _alive($TasksTable t) => t.deletedAt.isNull();

  Expression<bool> _openTopLevel($TasksTable t) =>
      _alive(t) & t.isDone.equals(false) & t.parentId.isNull();

  static final List<OrderClauseGenerator<$TasksTable>> _byDueThenOrder = [
    (t) => OrderingTerm.asc(t.dueDate, nulls: NullsOrder.last),
    (t) => OrderingTerm.asc(t.dueTime, nulls: NullsOrder.first),
    (t) => OrderingTerm.desc(t.priority),
    (t) => OrderingTerm.asc(t.sortOrder),
  ];

  String _day(DateTime d) => const LocalDateConverter().toSql(d);

  // ---------------------------------------------------------------- queries

  /// Open tasks due on or before [today] (overdue + today)
  Stream<List<Task>> watchDueBy(DateTime today) {
    return (_db.select(_t)
          ..where(
            (t) =>
                _openTopLevel(t) &
                t.dueDate.isNotNull() &
                t.dueDate.isSmallerOrEqualValue(_day(today)),
          )
          ..orderBy(_byDueThenOrder))
        .watch();
  }

  /// Open tasks due after [today]
  Stream<List<Task>> watchUpcoming(DateTime today) {
    return (_db.select(_t)
          ..where(
            (t) =>
                _openTopLevel(t) &
                t.dueDate.isNotNull() &
                t.dueDate.isBiggerThanValue(_day(today)),
          )
          ..orderBy(_byDueThenOrder))
        .watch();
  }

  /// Open tasks due between [from] and [to] (inclusive) — a calendar page
  Stream<List<Task>> watchRange(DateTime from, DateTime to) {
    return (_db.select(_t)
          ..where(
            (t) =>
                _openTopLevel(t) &
                t.dueDate.isBiggerOrEqualValue(_day(from)) &
                t.dueDate.isSmallerOrEqualValue(_day(to)),
          )
          ..orderBy(_byDueThenOrder))
        .watch();
  }

  /// Open tasks in a list (null = Inbox), in manual order
  Stream<List<Task>> watchList(String? listId) {
    return (_db.select(_t)
          ..where(
            (t) =>
                _openTopLevel(t) &
                (listId == null ? t.listId.isNull() : t.listId.equals(listId)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Stream<List<Task>> watchCompleted({int limit = 500}) {
    return (_db.select(_t)
          ..where(
            (t) => _alive(t) & t.isDone.equals(true) & t.parentId.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.doneAt)])
          ..limit(limit))
        .watch();
  }

  Stream<int> watchDoneOn(DateTime day) {
    final start = Dates.dateOnly(day);
    final end = Dates.addDays(start, 1);
    final count = _t.id.count();
    return (_db.selectOnly(_t)
          ..addColumns([count])
          ..where(
            _alive(_t) &
                _t.isDone.equals(true) &
                _t.parentId.isNull() &
                _t.doneAt.isBiggerOrEqualValue(start) &
                _t.doneAt.isSmallerThanValue(end),
          ))
        .map((row) => row.read(count) ?? 0)
        .watchSingle();
  }

  Stream<List<Task>> search(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      return Stream.value(const []);
    }
    final escaped = q
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';
    return (_db.select(_t)
          ..where(
            (t) =>
                _alive(t) &
                (t.title.like(pattern, escapeChar: r'\') |
                    t.note.like(pattern, escapeChar: r'\')),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.isDone),
            (t) => OrderingTerm.desc(t.updatedAt),
          ])
          ..limit(100))
        .watch();
  }

  Stream<Task?> watchTask(String id) =>
      (_db.select(_t)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<List<Task>> watchSubtasks(String parentId) {
    return (_db.select(_t)
          ..where((t) => _alive(t) & t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// parentId → done/total of its subtasks
  Stream<Map<String, SubtaskCount>> watchSubtaskCounts() {
    final total = _t.id.count();
    final done = _t.id.count(filter: _t.isDone.equals(true));
    return (_db.selectOnly(_t)
          ..addColumns([_t.parentId, total, done])
          ..where(_alive(_t) & _t.parentId.isNotNull())
          ..groupBy([_t.parentId]))
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read(_t.parentId)!: SubtaskCount(
                row.read(done) ?? 0,
                row.read(total) ?? 0,
              ),
          },
        );
  }

  /// Open top-level tasks with high priority
  Stream<List<Task>> watchHighPriority() {
    return (_db.select(_t)
          ..where((t) => _openTopLevel(t) & t.priority.equals(3))
          ..orderBy(_byDueThenOrder))
        .watch();
  }

  /// Open tasks with at least one reminder (search filter)
  Stream<List<Task>> watchWithReminders() {
    return (_db.select(_t)
          ..where(
            (t) =>
                _alive(t) &
                t.isDone.equals(false) &
                t.dueDate.isNotNull() &
                t.reminders.equals('').not(),
          )
          ..orderBy(_byDueThenOrder))
        .watch();
  }

  /// Open tasks with a due date: what reminders, snoozes and the morning
  /// summary are planned from
  Stream<List<Task>> watchForNotifications() {
    return (_db.select(_t)..where(
          (t) => _alive(t) & t.isDone.equals(false) & t.dueDate.isNotNull(),
        ))
        .watch();
  }

  /// Top-level tasks, newest first — what the suggestion engine learns from
  Stream<List<Task>> watchHistory({int limit = 2000}) {
    return (_db.select(_t)
          ..where((t) => _alive(t) & t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit))
        .watch();
  }

  Future<Task?> getTask(String id) =>
      (_db.select(_t)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ---------------------------------------------------------------- writes

  Future<String> create(TaskDraft draft) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    var due = draft.dueDate;
    final rule = Recurrence.tryParse(draft.rrule);
    if (due == null && rule != null) {
      due = rule.firstOnOrAfter(now);
    }
    await _db
        .into(_t)
        .insert(
          TasksCompanion.insert(
            id: id,
            listId: Value(draft.listId),
            parentId: Value(draft.parentId),
            title: draft.title.trim(),
            note: Value(_blankToNull(draft.note)),
            dueDate: Value(due),
            dueTime: Value(due == null ? null : draft.dueTime),
            priority: Value(draft.priority),
            rrule: Value(rule?.toRule()),
            reminders: Value(
              due == null ? '' : ReminderOffsets.format(draft.reminders),
            ),
            alarm: Value(draft.alarm),
            estimateMinutes: Value(draft.estimateMinutes),
            sortOrder: await _nextSortOrder(draft.listId, draft.parentId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<double> _nextSortOrder(String? listId, String? parentId) async {
    final max = _t.sortOrder.max();
    final query = _db.selectOnly(_t)..addColumns([max]);
    if (parentId != null) {
      query.where(_t.parentId.equals(parentId));
    } else {
      query.where(
        _t.parentId.isNull() &
            (listId == null ? _t.listId.isNull() : _t.listId.equals(listId)),
      );
    }
    final value = await query.map((r) => r.read(max)).getSingleOrNull();
    return (value ?? 0) + 1;
  }

  Future<void> updateTask(Task task) {
    return _db.update(_t).replace(task.copyWith(updatedAt: DateTime.now()));
  }

  /// Applies [changes] to the task, keeping dependent fields consistent
  Future<void> patch(String id, TasksCompanion changes) {
    return (_db.update(_t)..where((t) => t.id.equals(id))).write(
      changes.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> setDue(String id, DateTime? date, int? time) {
    return patch(
      id,
      TasksCompanion(
        dueDate: Value(date),
        dueTime: Value(date == null ? null : time),
        snoozedUntil: const Value(null),
        // A reminder without a date makes no sense
        reminders: date == null ? const Value('') : const Value.absent(),
        rrule: date == null ? const Value(null) : const Value.absent(),
      ),
    );
  }

  /// Completes [task]. A recurring task moves to its next occurrence and a
  /// completed copy is kept for history.
  Future<Undo> complete(Task task, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final rule = Recurrence.tryParse(task.rrule);
    final due = task.dueDate;
    if (rule != null && due != null && task.parentId == null) {
      final historyId = _uuid.v4();
      final next = rule.nextDueAfterCompletion(due, at);
      await _db.transaction(() async {
        await _db
            .into(_t)
            .insert(
              task
                  .copyWith(
                    id: historyId,
                    isDone: true,
                    doneAt: Value(at),
                    rrule: const Value(null),
                    reminders: '',
                    alarm: false,
                    snoozedUntil: const Value(null),
                    updatedAt: at,
                  )
                  .toCompanion(true),
            );
        await patch(
          task.id,
          TasksCompanion(dueDate: Value(next), snoozedUntil: const Value(null)),
        );
        // Recurring subtasks reset for the next round
        await (_db.update(_t)..where((t) => t.parentId.equals(task.id))).write(
          const TasksCompanion(isDone: Value(false), doneAt: Value(null)),
        );
        await _bumpActivity(at, 1);
      });
      return () => _db.transaction(() async {
        await (_db.delete(_t)..where((t) => t.id.equals(historyId))).go();
        await _db.update(_t).replace(task);
        await _bumpActivity(at, -1);
      });
    }
    await _db.transaction(() async {
      await patch(
        task.id,
        TasksCompanion(
          isDone: const Value(true),
          doneAt: Value(at),
          snoozedUntil: const Value(null),
        ),
      );
      if (task.parentId == null) {
        await _bumpActivity(at, 1);
      }
    });
    return () => _db.transaction(() async {
      await _db.update(_t).replace(task);
      if (task.parentId == null) {
        await _bumpActivity(at, -1);
      }
    });
  }

  Future<void> reopen(Task task) async {
    await _db.transaction(() async {
      await patch(
        task.id,
        const TasksCompanion(isDone: Value(false), doneAt: Value(null)),
      );
      final doneAt = task.doneAt;
      if (doneAt != null && task.parentId == null) {
        await _bumpActivity(doneAt, -1);
      }
    });
  }

  Future<Undo> delete(String id) async {
    final at = DateTime.now();
    await (_db.update(_t)
          ..where((t) => t.id.equals(id) | t.parentId.equals(id)))
        .write(TasksCompanion(deletedAt: Value(at)));
    return () async {
      await (_db.update(_t)..where(
            (t) =>
                (t.id.equals(id) | t.parentId.equals(id)) &
                t.deletedAt.equals(at),
          ))
          .write(const TasksCompanion(deletedAt: Value(null)));
    };
  }

  /// Moves every overdue open task to [today]
  Future<void> rescheduleOverdue(DateTime today) {
    return (_db.update(_t)..where(
          (t) => _openTopLevel(t) & t.dueDate.isSmallerThanValue(_day(today)),
        ))
        .write(
          TasksCompanion(
            dueDate: Value(Dates.dateOnly(today)),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Persists a manual order (list detail drag & drop)
  Future<void> reorder(List<Task> ordered) {
    return _db.batch((b) {
      for (var i = 0; i < ordered.length; i++) {
        b.update(
          _t,
          TasksCompanion(sortOrder: Value(i.toDouble())),
          where: (t) => t.id.equals(ordered[i].id),
        );
      }
    });
  }

  /// Gives each task its planned day and time in one transaction. Undo
  /// puts the tasks back exactly as they were.
  Future<Undo> schedule(Map<Task, ({DateTime date, int time})> slots) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      for (final MapEntry(key: task, value: slot) in slots.entries) {
        await (_db.update(_t)..where((t) => t.id.equals(task.id))).write(
          TasksCompanion(
            dueDate: Value(Dates.dateOnly(slot.date)),
            dueTime: Value(slot.time),
            snoozedUntil: const Value(null),
            updatedAt: Value(now),
          ),
        );
      }
    });
    return () => _db.transaction(() async {
      for (final task in slots.keys) {
        await _db.update(_t).replace(task);
      }
    });
  }

  /// Rings the task's reminder again at [until]
  Future<void> snoozeUntil(String id, DateTime until) {
    return patch(id, TasksCompanion(snoozedUntil: Value(until)));
  }

  /// Replaces the task's reminders (minutes before it is due) and, when
  /// given, whether they ring like an alarm
  Future<void> setReminders(String id, List<int> offsets, {bool? alarm}) {
    return patch(
      id,
      TasksCompanion(
        reminders: Value(ReminderOffsets.format(offsets)),
        alarm: alarm == null ? const Value.absent() : Value(alarm),
        snoozedUntil: const Value(null),
      ),
    );
  }

  Future<void> _bumpActivity(DateTime at, int delta) async {
    final day = Dates.dateOnly(at);
    final table = _db.activityDays;
    final existing = await (_db.select(
      table,
    )..where((a) => a.day.equalsValue(day))).getSingleOrNull();
    final count = ((existing?.completedCount ?? 0) + delta).clamp(0, 1 << 30);
    await _db
        .into(table)
        .insertOnConflictUpdate(
          ActivityDaysCompanion.insert(day: day, completedCount: Value(count)),
        );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
