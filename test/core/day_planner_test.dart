import 'package:flutter_base/src/core/ai/day_planner.dart';
import 'package:flutter_base/src/core/ai/weekly_recap.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 11, 13);

var _id = 0;

Task t(
  String title, {
  DateTime? due,
  int? time,
  int priority = 0,
  int? estimate,
  bool done = false,
  DateTime? doneAt,
  String? list,
}) => Task(
  id: 't${_id++}',
  title: title,
  listId: list,
  dueDate: due ?? today,
  dueTime: time,
  priority: priority,
  estimateMinutes: estimate,
  isDone: done,
  doneAt: doneAt,
  sortOrder: _id.toDouble(),
  createdAt: today,
  updatedAt: today,
);

int hm(int h, [int m = 0]) => h * 60 + m;

DayPlan plan(List<Task> tasks, {DateTime? now}) => DayPlanner.plan(
  tasks: tasks,
  now: now ?? DateTime(2026, 11, 13, 9, 7),
  estimateOf: (task) => task.estimateMinutes,
);

void main() {
  group('DayPlanner', () {
    test('starts at the next quarter hour, most important first', () {
      final low = t('Low', estimate: 30);
      final high = t('High', priority: 3, estimate: 60);
      final p = plan([low, high]);
      expect(p.items.map((i) => (i.task.title, i.start)), [
        ('High', hm(9, 15)),
        ('Low', hm(10, 15)),
      ]);
    });

    test('works around tasks that already have a time', () {
      final meeting = t('Meeting', time: hm(10), estimate: 60);
      final a = t('A', estimate: 30);
      final b = t('B', estimate: 45);
      final p = plan([meeting, a, b]);
      expect(p.items.map((i) => (i.task.title, i.start, i.fixed)), [
        ('A', hm(9, 15), false),
        ('Meeting', hm(10), true),
        // 45 min doesn't fit 9:45–10:00, so after the meeting
        ('B', hm(11), false),
      ]);
      expect(p.placed.map((i) => i.task.title), ['A', 'B']);
    });

    test('overdue tasks are planned too, oldest first among equals', () {
      final old = t('Old', due: DateTime(2026, 11, 10));
      final newer = t('Newer', due: DateTime(2026, 11, 12));
      final p = plan([newer, old]);
      expect(p.placed.map((i) => i.task.title), ['Old', 'Newer']);
    });

    test('unknown durations count as 30 minutes', () {
      final p = plan([t('A'), t('B')]);
      expect(p.items.map((i) => i.start), [hm(9, 15), hm(9, 45)]);
    });

    test('what does not fit before 22:00 waits', () {
      final p = plan([
        t('Long', estimate: 120),
        t('Short', estimate: 30),
      ], now: DateTime(2026, 11, 13, 20, 50));
      expect(p.placed.map((i) => i.task.title), ['Short']);
      expect(p.later.map((t) => t.title), ['Long']);
    });

    test('never before 6:00, ignores future and done tasks', () {
      final p = plan([
        t('Early'),
        t('Tomorrow', due: DateTime(2026, 11, 14)),
        t('Done', done: true),
      ], now: DateTime(2026, 11, 13, 4, 30));
      expect(p.items.map((i) => (i.task.title, i.start)), [('Early', hm(6))]);
    });
  });

  group('WeeklyRecap', () {
    DateTime on(int day, [int hour = 10]) => DateTime(2026, 11, day, hour);

    test('counts the last 7 days, finds a clear best day and list', () {
      final r = WeeklyRecap.of([
        t('a', done: true, doneAt: on(13), list: 'work'),
        t('b', done: true, doneAt: on(11), list: 'work'),
        t('c', done: true, doneAt: on(11), list: 'work'),
        t('d', done: true, doneAt: on(11)),
        t('e', done: true, doneAt: on(7)), // first day of the window
        t('f', done: true, doneAt: on(6)), // too old
      ], today);
      expect(r.done, 5);
      expect(r.bestDay, DateTime(2026, 11, 11));
      expect(r.topListId, 'work');
    });

    test('no best day on a tie, no top list when nothing stands out', () {
      final r = WeeklyRecap.of([
        t('a', done: true, doneAt: on(12), list: 'a'),
        t('b', done: true, doneAt: on(12), list: 'b'),
        t('c', done: true, doneAt: on(13), list: 'c'),
        t('d', done: true, doneAt: on(13)),
      ], today);
      expect(r.done, 4);
      expect(r.bestDay, isNull);
      expect(r.topListId, isNull);
    });

    test('empty week', () {
      final r = WeeklyRecap.of(const [], today);
      expect(r.done, 0);
      expect(r.bestDay, isNull);
    });
  });
}
