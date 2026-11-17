import 'package:flutter_base/src/core/planner/timeline_layout.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime(2026, 11, 17);

Task _task(String id, int? time, {int? estimate, int priority = 0}) => Task(
  id: id,
  title: id,
  dueDate: _at,
  dueTime: time,
  priority: priority,
  isDone: false,
  reminders: '',
  alarm: false,
  estimateMinutes: estimate,
  sortOrder: 0,
  createdAt: _at,
  updatedAt: _at,
);

void main() {
  Map<String, TimelineBlock> layout(List<Task> tasks) => {
    for (final b in TimelineLayout.layout(tasks)) b.task.id: b,
  };

  test('untimed tasks have no block; blocks come in time order', () {
    final blocks = TimelineLayout.layout([
      _task('late', 15 * 60),
      _task('none', null),
      _task('early', 8 * 60),
    ]);
    expect(blocks.map((b) => b.task.id), ['early', 'late']);
    expect(blocks.every((b) => b.columns == 1 && b.column == 0), isTrue);
  });

  test('length follows the estimate, never under 30 minutes', () {
    final b = layout([
      _task('quick', 9 * 60, estimate: 5),
      _task('plain', 11 * 60),
      _task('long', 13 * 60, estimate: 90),
    ]);
    expect(b['quick']!.minutes, 30);
    expect(b['plain']!.minutes, 30);
    expect(b['long']!.minutes, 90);
    expect(b['long']!.end, 14 * 60 + 30);
  });

  test('overlapping tasks sit side by side, and only they do', () {
    final b = layout([
      _task('a', 9 * 60, estimate: 60),
      _task('b', 9 * 60 + 15),
      _task('c', 9 * 60 + 45),
      _task('alone', 12 * 60),
    ]);
    // a 9:00–10:00 overlaps b 9:15–9:45 and c 9:45–10:15; c fits under b
    expect((b['a']!.column, b['a']!.columns), (0, 2));
    expect((b['b']!.column, b['b']!.columns), (1, 2));
    expect((b['c']!.column, b['c']!.columns), (1, 2));
    expect((b['alone']!.column, b['alone']!.columns), (0, 1));
  });

  test('back-to-back tasks do not count as overlapping', () {
    final b = layout([_task('a', 9 * 60), _task('b', 9 * 60 + 30)]);
    expect(b['a']!.columns, 1);
    expect(b['b']!.columns, 1);
  });

  test('same start: higher priority first; three wide', () {
    final b = layout([
      _task('low', 9 * 60),
      _task('high', 9 * 60, priority: 3),
      _task('mid', 9 * 60, priority: 2),
    ]);
    expect([b['high']!.column, b['mid']!.column, b['low']!.column], [0, 1, 2]);
    expect(b['low']!.columns, 3);
  });

  test('a late task stops at midnight but stays readable', () {
    final b = layout([
      _task('late', 23 * 60, estimate: 120),
      _task('last', 23 * 60 + 50),
    ]);
    expect(b['late']!.end, 24 * 60);
    expect(b['last']!.minutes, 30);
  });

  test('drag positions snap to quarter hours inside the day', () {
    expect(TimelineLayout.snapMinutes(9 * 60 + 7), 9 * 60);
    expect(TimelineLayout.snapMinutes(9 * 60 + 8), 9 * 60 + 15);
    expect(TimelineLayout.snapMinutes(-40), 0);
    expect(TimelineLayout.snapMinutes(24 * 60 + 30), 23 * 60 + 45);
    // 72 px per hour: 108 px down is 1:30
    expect(TimelineLayout.minutesAt(108, 72), 90);
    expect(TimelineLayout.minutesAt(100, 72), 90);
  });
}
