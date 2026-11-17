import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/local/database/app_database.dart';

/// A timed task as a block on the day timeline
@immutable
class TimelineBlock {
  const TimelineBlock({
    required this.task,
    required this.start,
    required this.minutes,
    required this.column,
    required this.columns,
  });

  final Task task;

  /// Minutes after midnight
  final int start;

  /// Length drawn (at least [TimelineLayout.minBlockMinutes])
  final int minutes;

  /// Position among the blocks it overlaps: [column] of [columns]
  final int column;
  final int columns;

  int get end => start + minutes;
}

/// Places a day's timed tasks on a vertical timeline: each as long as its
/// estimate, and tasks that overlap side by side.
class TimelineLayout {
  TimelineLayout._();

  /// Times snap to this when dragging
  static const snap = 15;

  /// Length of a task with no estimate
  static const defaultMinutes = 30;

  /// Shorter tasks are still drawn this long, so they stay readable and
  /// easy to touch
  static const minBlockMinutes = 30;

  static const _dayMinutes = 24 * 60;

  static List<TimelineBlock> layout(
    Iterable<Task> tasks, {
    int? Function(Task task)? estimateOf,
  }) {
    final timed =
        [
          for (final t in tasks)
            if (t.dueTime != null) t,
        ]..sort((a, b) {
          final byTime = a.dueTime!.compareTo(b.dueTime!);
          if (byTime != 0) {
            return byTime;
          }
          final byPriority = b.priority.compareTo(a.priority);
          return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
        });

    int lengthOf(Task t) {
      final estimate = estimateOf?.call(t) ?? t.estimateMinutes;
      final length = math.max(estimate ?? defaultMinutes, minBlockMinutes);
      // Not past midnight, but never shorter than a readable block
      final room = math.max(_dayMinutes - t.dueTime!, minBlockMinutes);
      return math.min(length, room);
    }

    final blocks = <TimelineBlock>[];
    // A cluster is a run of tasks chained together by overlaps; all of its
    // blocks share one column count
    var cluster = <({Task task, int start, int minutes, int column})>[];
    var clusterEnd = 0;
    final columnEnds = <int>[];

    void flush() {
      for (final item in cluster) {
        blocks.add(
          TimelineBlock(
            task: item.task,
            start: item.start,
            minutes: item.minutes,
            column: item.column,
            columns: columnEnds.length,
          ),
        );
      }
      cluster = [];
      columnEnds.clear();
    }

    for (final task in timed) {
      final start = task.dueTime!;
      final minutes = lengthOf(task);
      if (cluster.isNotEmpty && start >= clusterEnd) {
        flush();
      }
      // First column that is free again by this start
      var column = columnEnds.indexWhere((end) => end <= start);
      if (column == -1) {
        column = columnEnds.length;
        columnEnds.add(start + minutes);
      } else {
        columnEnds[column] = start + minutes;
      }
      cluster.add((task: task, start: start, minutes: minutes, column: column));
      clusterEnd = cluster.length == 1
          ? start + minutes
          : math.max(clusterEnd, start + minutes);
    }
    flush();
    return blocks;
  }

  /// Nearest [snap] step, kept inside the day
  static int snapMinutes(num minutes) {
    final snapped = (minutes / snap).round() * snap;
    return snapped.clamp(0, _dayMinutes - snap);
  }

  /// The time at [dy] pixels down a timeline whose hours are [hourHeight]
  /// tall, snapped
  static int minutesAt(double dy, double hourHeight) =>
      snapMinutes(dy / hourHeight * 60);
}
