import 'package:flutter/foundation.dart';

import '../date/dates.dart';

enum Frequency { daily, weekly, monthly, yearly }

/// A small, predictable subset of RFC 5545 RRULE:
///
/// `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY`, `INTERVAL=n`, `BYDAY=MO,TU,..` (weekly),
/// `BYMONTHDAY=d|-1` (monthly/yearly; -1 = last day), `BYMONTH=m` (yearly).
///
/// Unlike RFC 5545, a month without the requested day is NOT skipped: "every
/// month on the 31st" lands on Feb 28/29, and "every year on Feb 29" on Feb 28
/// in non-leap years. That is what people expect from a to-do app.
@immutable
class Recurrence {
  const Recurrence({
    required this.frequency,
    this.interval = 1,
    this.weekdays = const {},
    this.monthDay,
    this.month,
  }) : assert(interval >= 1);

  factory Recurrence.daily({int interval = 1}) =>
      Recurrence(frequency: Frequency.daily, interval: interval);

  /// [weekdays] use [DateTime.monday]..[DateTime.sunday]
  factory Recurrence.weekly(Set<int> weekdays, {int interval = 1}) =>
      Recurrence(
        frequency: Frequency.weekly,
        interval: interval,
        weekdays: weekdays,
      );

  factory Recurrence.weekdaysOnly() => Recurrence.weekly(const {1, 2, 3, 4, 5});

  /// [day] 1..31, or -1 for the last day of the month
  factory Recurrence.monthly(int day, {int interval = 1}) => Recurrence(
    frequency: Frequency.monthly,
    interval: interval,
    monthDay: day,
  );

  factory Recurrence.yearly(int month, int day, {int interval = 1}) =>
      Recurrence(
        frequency: Frequency.yearly,
        interval: interval,
        month: month,
        monthDay: day,
      );

  final Frequency frequency;
  final int interval;
  final Set<int> weekdays;
  final int? monthDay;
  final int? month;

  bool get isWeekdaysOnly =>
      frequency == Frequency.weekly &&
      interval == 1 &&
      weekdays.length == 5 &&
      weekdays.containsAll(const [1, 2, 3, 4, 5]);

  bool get isLastDayOfMonth => frequency == Frequency.monthly && monthDay == -1;

  static const _dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  /// Returns null for anything outside the supported subset.
  static Recurrence? tryParse(String? rule) {
    if (rule == null || rule.trim().isEmpty) {
      return null;
    }
    final parts = <String, String>{};
    for (final part in rule.toUpperCase().split(';')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        parts[kv[0].trim()] = kv[1].trim();
      }
    }
    final frequency = switch (parts['FREQ']) {
      'DAILY' => Frequency.daily,
      'WEEKLY' => Frequency.weekly,
      'MONTHLY' => Frequency.monthly,
      'YEARLY' => Frequency.yearly,
      _ => null,
    };
    if (frequency == null) {
      return null;
    }
    final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
    final weekdays = <int>{};
    for (final code in (parts['BYDAY'] ?? '').split(',')) {
      final index = _dayCodes.indexOf(code.trim());
      if (index >= 0) {
        weekdays.add(index + 1);
      }
    }
    final monthDay = int.tryParse(parts['BYMONTHDAY'] ?? '');
    final month = int.tryParse(parts['BYMONTH'] ?? '');
    if (monthDay != null && (monthDay == 0 || monthDay < -1 || monthDay > 31)) {
      return null;
    }
    if (month != null && (month < 1 || month > 12)) {
      return null;
    }
    return Recurrence(
      frequency: frequency,
      interval: interval < 1 ? 1 : interval,
      weekdays: weekdays,
      monthDay: monthDay,
      month: month,
    );
  }

  String toRule() {
    final buffer = StringBuffer('FREQ=${frequency.name.toUpperCase()}');
    if (interval > 1) {
      buffer.write(';INTERVAL=$interval');
    }
    if (weekdays.isNotEmpty) {
      final sorted = weekdays.toList()..sort();
      buffer.write(';BYDAY=${sorted.map((d) => _dayCodes[d - 1]).join(',')}');
    }
    if (month != null) {
      buffer.write(';BYMONTH=$month');
    }
    if (monthDay != null) {
      buffer.write(';BYMONTHDAY=$monthDay');
    }
    return buffer.toString();
  }

  /// First occurrence strictly after [date] (date-only).
  DateTime nextAfter(DateTime date) {
    final from = Dates.dateOnly(date);
    switch (frequency) {
      case Frequency.daily:
        return Dates.addDays(from, interval);
      case Frequency.weekly:
        if (weekdays.isEmpty) {
          return Dates.addDays(from, 7 * interval);
        }
        final anchorWeek = Dates.startOfWeek(from);
        // Bounded: at most `interval` weeks + 1 week of candidates
        for (var i = 1; i <= 7 * (interval + 1); i++) {
          final candidate = Dates.addDays(from, i);
          final weeks =
              Dates.daysBetween(anchorWeek, Dates.startOfWeek(candidate)) ~/ 7;
          if (weeks % interval == 0 && weekdays.contains(candidate.weekday)) {
            return candidate;
          }
        }
        return Dates.addDays(from, 7 * interval);
      case Frequency.monthly:
        final day = monthDay ?? from.day;
        final target = DateTime(from.year, from.month + interval);
        return DateTime(
          target.year,
          target.month,
          _clampDay(target.year, target.month, day),
        );
      case Frequency.yearly:
        final m = month ?? from.month;
        final day = monthDay ?? from.day;
        final year = from.year + interval;
        return DateTime(year, m, _clampDay(year, m, day));
    }
  }

  /// Next due date when a task due on [due] is completed on [today]: skips
  /// occurrences that are already in the past so an overdue daily task
  /// doesn't pile up.
  DateTime nextDueAfterCompletion(DateTime due, DateTime today) {
    final todayDate = Dates.dateOnly(today);
    var next = nextAfter(due);
    var guard = 0;
    while (!next.isAfter(todayDate) && guard++ < 5000) {
      next = nextAfter(next);
    }
    return next;
  }

  /// Snaps a freshly chosen start date onto the rule, e.g. "every Monday"
  /// created on a Wednesday starts next Monday.
  DateTime firstOnOrAfter(DateTime date) {
    final from = Dates.dateOnly(date);
    if (matches(from)) {
      return from;
    }
    // Monthly/yearly: the occurrence later in the current period comes first
    if (frequency == Frequency.monthly && monthDay != null) {
      final candidate = DateTime(
        from.year,
        from.month,
        _clampDay(from.year, from.month, monthDay!),
      );
      if (candidate.isAfter(from)) {
        return candidate;
      }
    }
    if (frequency == Frequency.yearly) {
      final m = month ?? from.month;
      final candidate = DateTime(
        from.year,
        m,
        _clampDay(from.year, m, monthDay ?? from.day),
      );
      if (candidate.isAfter(from)) {
        return candidate;
      }
    }
    return nextAfter(from);
  }

  bool matches(DateTime date) {
    final d = Dates.dateOnly(date);
    switch (frequency) {
      case Frequency.daily:
        return true;
      case Frequency.weekly:
        return weekdays.isEmpty || weekdays.contains(d.weekday);
      case Frequency.monthly:
        final day = monthDay;
        return day == null || d.day == _clampDay(d.year, d.month, day);
      case Frequency.yearly:
        final m = month;
        final day = monthDay;
        return (m == null || d.month == m) &&
            (day == null || d.day == _clampDay(d.year, d.month, day));
    }
  }

  static int _clampDay(int year, int month, int day) {
    final last = Dates.daysInMonth(year, month);
    if (day == -1 || day > last) {
      return last;
    }
    return day;
  }

  @override
  bool operator ==(Object other) =>
      other is Recurrence && other.toRule() == toRule();

  @override
  int get hashCode => toRule().hashCode;

  @override
  String toString() => toRule();
}
