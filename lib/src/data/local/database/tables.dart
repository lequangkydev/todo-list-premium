import 'package:drift/drift.dart';

import 'converters.dart';

/// User lists. Tasks with `listId == null` live in the Inbox.
@DataClassName('TaskList')
class TaskLists extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  IntColumn get colorValue => integer()();

  RealColumn get sortOrder => real()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete — kept so the delete can be undone
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Task')
@TableIndex(name: 'idx_tasks_due', columns: {#dueDate, #isDone, #deletedAt})
@TableIndex(name: 'idx_tasks_list', columns: {#listId})
@TableIndex(name: 'idx_tasks_parent', columns: {#parentId})
class Tasks extends Table {
  TextColumn get id => text()();

  /// null = Inbox
  TextColumn get listId => text().nullable().references(TaskLists, #id)();

  /// Set for subtasks (one level deep)
  TextColumn get parentId => text().nullable()();

  TextColumn get title => text()();

  TextColumn get note => text().nullable()();

  TextColumn get dueDate => text().nullable().map(const LocalDateConverter())();

  /// Minutes after midnight; null = all-day
  IntColumn get dueTime => integer().nullable()();

  /// 0 = none, 1 = low, 2 = medium, 3 = high
  IntColumn get priority => integer().withDefault(const Constant(0))();

  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  DateTimeColumn get doneAt => dateTime().nullable()();

  /// RFC 5545 subset, e.g. `FREQ=WEEKLY;BYDAY=MO,WE` (see Recurrence)
  TextColumn get rrule => text().nullable()();

  /// When to remind, as minutes before the due moment (all-day tasks: before
  /// 9:00 on the day), e.g. `0,60` (see `ReminderOffsets`,
  /// `Task.reminderOffsets`); empty = no reminder. Replaced the single
  /// `remind_offset` in schema v3.
  TextColumn get reminders => text().withDefault(const Constant(''))();

  /// Remind like an alarm clock: alarm sound until handled, full screen on
  /// a locked Android phone, breaks through Focus on iOS (schema v3)
  BoolColumn get alarm => boolean().withDefault(const Constant(false))();

  /// How long the task takes, in minutes; null = unknown. Used to plan the
  /// day (schema v2).
  IntColumn get estimateMinutes => integer().nullable()();

  /// Set by "Snooze" on a notification; overrides the computed fire time
  DateTimeColumn get snoozedUntil => dateTime().nullable()();

  RealColumn get sortOrder => real()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One row per day with at least one completion — powers the (streak-free)
/// activity grid.
class ActivityDays extends Table {
  TextColumn get day => text().map(const LocalDateConverter())();

  IntColumn get completedCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

/// One block of focused time (schema v4). Only the focused minutes count:
/// time spent paused isn't in [focusMinutes].
@DataClassName('FocusSession')
@TableIndex(name: 'idx_focus_started', columns: {#startedAt})
class FocusSessions extends Table {
  TextColumn get id => text()();

  /// The task it was for, if any (kept when the task is deleted)
  TextColumn get taskId => text().nullable()();

  DateTimeColumn get startedAt => dateTime()();

  DateTimeColumn get endedAt => dateTime()();

  IntColumn get focusMinutes => integer()();

  IntColumn get plannedMinutes => integer()();

  /// Ran its full length (not stopped early)
  BoolColumn get completed => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
