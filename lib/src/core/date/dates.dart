/// Calendar-day helpers that never go through UTC, so DST transitions can't
/// shift a date by one (adding `Duration(days: 1)` can).
class Dates {
  Dates._();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime today([DateTime? now]) => dateOnly(now ?? DateTime.now());

  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  static int daysBetween(DateTime from, DateTime to) {
    // Compare at UTC noon to stay immune to DST
    final a = DateTime.utc(from.year, from.month, from.day, 12);
    final b = DateTime.utc(to.year, to.month, to.day, 12);
    return b.difference(a).inHours ~/ 24;
  }

  /// Monday of the week containing [d]
  static DateTime startOfWeek(DateTime d) =>
      addDays(dateOnly(d), -(d.weekday - DateTime.monday));

  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Combines a date with minutes-after-midnight
  static DateTime atMinutes(DateTime date, int minutes) =>
      DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
}
