import 'package:flutter_base/src/core/notifications/reminder_planner.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 13, 10);

Task task(
  String id, {
  DateTime? due,
  int? time,
  int? offset,
  bool done = false,
  DateTime? snoozed,
}) => Task(
  id: id,
  title: id,
  dueDate: due,
  dueTime: time,
  priority: 0,
  isDone: done,
  remindOffset: offset,
  snoozedUntil: snoozed,
  sortOrder: 0,
  createdAt: now,
  updatedAt: now,
);

void main() {
  test('fires at due time minus offset', () {
    final t = task('a', due: DateTime(2026, 11, 13), time: 17 * 60, offset: 15);
    expect(ReminderPlanner.fireTimeOf(t, now), DateTime(2026, 11, 13, 16, 45));
  });

  test('all-day tasks fire at 9:00, a day-before offset crosses midnight', () {
    final t = task('a', due: DateTime(2026, 11, 14), offset: 1440);
    final early = DateTime(2026, 11, 13, 8);
    expect(ReminderPlanner.fireTimeOf(t, early), DateTime(2026, 11, 13, 9));
    // 9:00 today already passed at 10:00 → nothing to schedule
    expect(ReminderPlanner.fireTimeOf(t, now), isNull);
  });

  test('past, done and reminder-less tasks are skipped', () {
    expect(
      ReminderPlanner.fireTimeOf(
        task('a', due: DateTime(2026, 11, 13), time: 9 * 60, offset: 0),
        now,
      ),
      isNull,
    );
    expect(
      ReminderPlanner.fireTimeOf(
        task('b', due: DateTime(2026, 11, 14), offset: 0, done: true),
        now,
      ),
      isNull,
    );
    expect(
      ReminderPlanner.fireTimeOf(task('c', due: DateTime(2026, 11, 14)), now),
      isNull,
    );
  });

  test('snooze overrides the computed time', () {
    final snoozed = DateTime(2026, 11, 13, 11);
    final t = task(
      'a',
      due: DateTime(2026, 11, 13),
      time: 9 * 60,
      offset: 0,
      snoozed: snoozed,
    );
    expect(ReminderPlanner.fireTimeOf(t, now), snoozed);
  });

  test('keeps only the nearest 60 (iOS cap 64)', () {
    final tasks = [
      for (var i = 0; i < 100; i++)
        task('t$i', due: DateTime(2026, 11, 14 + i), offset: 0),
    ];
    final plan = ReminderPlanner.plan(tasks, now);
    expect(plan, hasLength(60));
    expect(plan.first.task.id, 't0');
    expect(plan.last.task.id, 't59');
  });

  test('notification ids are stable and 31-bit', () {
    final a = ReminderPlanner.notificationIdOf(
      '8f14e45f-ceea-4675-a6b6-8b1c2b1c',
    );
    expect(
      a,
      ReminderPlanner.notificationIdOf('8f14e45f-ceea-4675-a6b6-8b1c2b1c'),
    );
    expect(a, lessThan(1 << 31));
    expect(a, isNot(ReminderPlanner.notificationIdOf('other')));
  });
}
