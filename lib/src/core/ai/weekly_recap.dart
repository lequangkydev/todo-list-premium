import 'package:flutter/foundation.dart';

import '../../data/local/database/app_database.dart';
import '../date/dates.dart';

/// The last seven days at a glance, for a calm one-paragraph summary.
/// Nothing here is a score: no streaks, no comparisons with other weeks.
@immutable
class WeeklyRecap {
  const WeeklyRecap({required this.done, this.bestDay, this.topListId});

  /// Top-level tasks completed in the last 7 days (today included)
  final int done;

  /// The day with clearly the most completions, if there is one
  final DateTime? bestDay;

  /// The list that most of the week's work came from, if one stands out
  final String? topListId;

  static WeeklyRecap of(Iterable<Task> completed, DateTime today) {
    final from = Dates.addDays(Dates.dateOnly(today), -6);
    final perDay = <DateTime, int>{};
    final perList = <String, int>{};
    var done = 0;
    for (final task in completed) {
      final at = task.doneAt;
      if (!task.isDone || at == null || task.parentId != null) {
        continue;
      }
      final day = Dates.dateOnly(at);
      if (day.isBefore(from) || day.isAfter(today)) {
        continue;
      }
      done++;
      perDay[day] = (perDay[day] ?? 0) + 1;
      final list = task.listId;
      if (list != null) {
        perList[list] = (perList[list] ?? 0) + 1;
      }
    }
    return WeeklyRecap(
      done: done,
      bestDay: _clearWinner(perDay, min: 2),
      topListId: _top(perList, done),
    );
  }

  /// Key with the highest count, only if no other key ties it
  static DateTime? _clearWinner(Map<DateTime, int> counts, {required int min}) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty || sorted.first.value < min) {
      return null;
    }
    if (sorted.length > 1 && sorted[1].value == sorted.first.value) {
      return null;
    }
    return sorted.first.key;
  }

  static String? _top(Map<String, int> counts, int total) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) {
      return null;
    }
    final best = sorted.first;
    final unique = sorted.length == 1 || sorted[1].value < best.value;
    return unique && best.value >= 2 && best.value * 5 >= total * 2
        ? best.key
        : null;
  }
}
