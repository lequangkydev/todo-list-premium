import 'package:flutter_base/src/core/notifications/reminder_health.dart';
import 'package:flutter_base/src/core/notifications/reminder_planner.dart';
import 'package:flutter_base/src/core/notifications/reminder_service.dart';
import 'package:flutter_base/src/core/notifications/snooze.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/local/database/converters.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 13, 10);

Task task(
  String id, {
  DateTime? due,
  int? time,
  List<int> reminders = const [],
  bool done = false,
  DateTime? snoozed,
  String? parent,
}) => Task(
  id: id,
  title: id,
  parentId: parent,
  dueDate: due,
  dueTime: time,
  priority: 0,
  isDone: done,
  reminders: reminders,
  alarm: false,
  snoozedUntil: snoozed,
  sortOrder: 0,
  createdAt: now,
  updatedAt: now,
);

void main() {
  group('fire times', () {
    test('due time minus each offset', () {
      final t = task(
        'a',
        due: DateTime(2026, 11, 13),
        time: 17 * 60,
        reminders: [0, 15, 60],
      );
      expect(ReminderPlanner.fireTimesOf(t, now), [
        (0, DateTime(2026, 11, 13, 17)),
        (15, DateTime(2026, 11, 13, 16, 45)),
        (60, DateTime(2026, 11, 13, 16)),
      ]);
    });

    test('all-day tasks count from 9:00, a day before crosses midnight', () {
      final t = task('a', due: DateTime(2026, 11, 14), reminders: [1440]);
      expect(
        ReminderPlanner.fireTimeOf(t, 1440, DateTime(2026, 11, 13, 8)),
        DateTime(2026, 11, 13, 9),
      );
      // 9:00 today already passed at 10:00 → nothing to schedule
      expect(ReminderPlanner.fireTimeOf(t, 1440, now), isNull);
    });

    test('past offsets drop out, future ones stay', () {
      final t = task(
        'a',
        due: DateTime(2026, 11, 13),
        time: 11 * 60,
        reminders: [0, 120],
      );
      // 9:00 has passed, 11:00 hasn't
      expect(ReminderPlanner.fireTimesOf(t, now), [
        (0, DateTime(2026, 11, 13, 11)),
      ]);
    });

    test('done, deleted and dateless tasks never ring', () {
      expect(
        ReminderPlanner.fireTimesOf(
          task('b', due: DateTime(2026, 11, 14), reminders: [0], done: true),
          now,
        ),
        isEmpty,
      );
      expect(
        ReminderPlanner.fireTimesOf(task('c', reminders: [0]), now),
        isEmpty,
      );
    });
  });

  group('plan', () {
    test('several reminders on one task get distinct ids', () {
      final t = task(
        'a',
        due: DateTime(2026, 11, 14),
        time: 9 * 60,
        reminders: [0, 5, 15, 60, 1440],
      );
      final plan = ReminderPlanner.plan([t], DateTime(2026, 11, 13, 8));
      expect(plan.reminders, hasLength(5));
      expect(plan.ids, hasLength(5));
      expect(plan.reminders.first.fireAt, DateTime(2026, 11, 13, 9));
    });

    test('a snooze rings on top of the regular reminders, once per minute', () {
      final t = task(
        'a',
        due: DateTime(2026, 11, 13),
        time: 11 * 60,
        reminders: [0, 30],
        snoozed: DateTime(2026, 11, 13, 11),
      );
      final plan = ReminderPlanner.plan([t], now);
      // 10:30 regular, 11:00 snooze (the 11:00 regular one is the same
      // moment, so it rings once)
      expect(plan.reminders.map((r) => (r.fireAt.hour, r.fireAt.minute)), [
        (10, 30),
        (11, 0),
      ]);
      expect(plan.reminders.last.snoozed, isTrue);
    });

    test('a past snooze is ignored', () {
      final t = task(
        'a',
        due: DateTime(2026, 11, 14),
        reminders: [0],
        snoozed: DateTime(2026, 11, 13, 9),
      );
      final plan = ReminderPlanner.plan([t], now);
      expect(plan.reminders.single.snoozed, isFalse);
    });

    test('keeps only the nearest 60 (iOS cap 64), digests included', () {
      final tasks = [
        for (var i = 0; i < 40; i++)
          task(
            't$i',
            due: DateTime(2026, 11, 14 + i),
            time: 12 * 60,
            reminders: [0, 60],
          ),
      ];
      final plan = ReminderPlanner.plan(tasks, now, digestMinutes: 8 * 60);
      expect(plan.reminders.length + plan.digests.length, 60);
      expect(plan.ids, hasLength(60));
      // Nearest first: all 6 digests fit (14th–19th; today's 8:00 has passed)
      expect(plan.digests, hasLength(6));
      expect(plan.reminders.first.task.id, 't0');
    });

    test('colliding ids are moved apart deterministically', () {
      // Same task twice would hash identically: the planner must still
      // hand out unique ids
      final a = task('x', due: DateTime(2026, 11, 14), reminders: [0]);
      final plan = ReminderPlanner.plan([a, a], now);
      expect(plan.reminders, hasLength(2));
      expect(plan.ids, hasLength(2));
      expect(ReminderPlanner.plan([a, a], now).ids, plan.ids);
    });

    test('ids are stable and 31-bit', () {
      final a = ReminderPlanner.notificationIdOf('8f14e45f-ceea:0');
      expect(a, ReminderPlanner.notificationIdOf('8f14e45f-ceea:0'));
      expect(a, lessThan(1 << 31));
      expect(a, isNot(ReminderPlanner.notificationIdOf('8f14e45f-ceea:5')));
    });
  });

  group('morning summary', () {
    test('one per day with something due, counting overdue', () {
      final tasks = [
        task('late', due: DateTime(2026, 11, 12)),
        task('today', due: DateTime(2026, 11, 13), time: 15 * 60),
        task('fri', due: DateTime(2026, 11, 14), time: 9 * 60),
        task('fri-early', due: DateTime(2026, 11, 14), time: 7 * 60),
        task('done', due: DateTime(2026, 11, 15), done: true),
        task('sub', due: DateTime(2026, 11, 16), parent: 'fri'),
      ];
      final plan = ReminderPlanner.plan(
        tasks,
        DateTime(2026, 11, 13, 7),
        digestMinutes: 8 * 60,
      );
      final byDay = {for (final d in plan.digests) d.day.day: d};
      // Today 8:00 is still ahead at 7:00
      expect(byDay[13]!.due.map((t) => t.id), ['today']);
      expect(byDay[13]!.overdue.map((t) => t.id), ['late']);
      // Ordered by time; yesterday's open task is overdue on every later day
      expect(byDay[14]!.due.map((t) => t.id), ['fri-early', 'fri']);
      expect(byDay[14]!.count, 4);
      expect(byDay[14]!.fireAt, DateTime(2026, 11, 14, 8));
      // Days with nothing due still carry the overdue ones; subtasks and
      // done tasks don't count
      expect(byDay[16]!.due, isEmpty);
      expect(byDay[16]!.overdue, hasLength(4));
      expect(plan.digests, hasLength(ReminderPlanner.digestDays));
    });

    test('no tasks, no summary; off means none', () {
      expect(
        ReminderPlanner.plan([], now, digestMinutes: 8 * 60).digests,
        isEmpty,
      );
      final t = task('a', due: DateTime(2026, 11, 14));
      expect(ReminderPlanner.plan([t], now).digests, isEmpty);
    });
  });

  group('snooze', () {
    final at = DateTime(2026, 11, 13, 14, 20, 35);
    const morning = (on: true, minutes: 7 * 60 + 30);
    const off = (on: false, minutes: 7 * 60 + 30);

    test('each choice', () {
      expect(
        snoozeTime(SnoozeOption.tenMinutes, at, morning),
        DateTime(2026, 11, 13, 14, 30),
      );
      expect(
        snoozeTime(SnoozeOption.oneHour, at, morning),
        DateTime(2026, 11, 13, 15, 20),
      );
      expect(
        snoozeTime(SnoozeOption.tonight, at, morning),
        DateTime(2026, 11, 13, 19),
      );
      // Tomorrow morning follows the morning summary when it's on…
      expect(
        snoozeTime(SnoozeOption.tomorrowMorning, at, morning),
        DateTime(2026, 11, 14, 7, 30),
      );
      // …and 8:00 otherwise
      expect(
        snoozeTime(SnoozeOption.tomorrowMorning, at, off),
        DateTime(2026, 11, 14, 8),
      );
    });

    test('"tonight" is offered until an hour before it', () {
      expect(
        SnoozeOption.availableAt(DateTime(2026, 11, 13, 17, 59)),
        contains(SnoozeOption.tonight),
      );
      expect(
        SnoozeOption.availableAt(DateTime(2026, 11, 13, 18)),
        isNot(contains(SnoozeOption.tonight)),
      );
    });

    test('a choice already past rings in an hour', () {
      // "Tonight" tapped on a notification seen at 21:00
      expect(
        snoozeTime(SnoozeOption.tonight, DateTime(2026, 11, 13, 21), morning),
        DateTime(2026, 11, 13, 22),
      );
    });

    test('notification actions map back, including the old one', () {
      for (final option in SnoozeOption.values) {
        expect(SnoozeOption.ofAction(option.actionId), option);
      }
      expect(SnoozeOption.ofAction('snooze'), SnoozeOption.oneHour);
      expect(SnoozeOption.ofAction('done'), isNull);
    });
  });

  test('reminder lists are stored sorted and without duplicates', () {
    const c = ReminderOffsetsConverter();
    expect(c.toSql([60, 0, 60, 15]), '0,15,60');
    expect(c.fromSql('60,0,x,15'), [0, 15, 60]);
    expect(c.fromSql(''), isEmpty);
  });

  test('phone makers', () {
    expect(Oem.of('xiaomi', 'redmi'), Oem.xiaomi);
    expect(Oem.of('xiaomi', 'poco'), Oem.xiaomi);
    expect(Oem.of('huawei', 'honor'), Oem.honor);
    expect(Oem.of('oneplus', 'oneplus'), Oem.oneplus);
    expect(Oem.of('oppo', 'realme'), Oem.realme);
    expect(Oem.of('vivo', 'iqoo'), Oem.vivo);
    expect(Oem.of('samsung', 'samsung'), Oem.samsung);
    expect(Oem.of('google', 'google'), Oem.other);
    expect(Oem.of('google', 'google').autostart, isFalse);
    expect(Oem.xiaomi.guideUrl.toString(), 'https://dontkillmyapp.com/xiaomi');
  });
}
