import 'lunar_calendar.dart';

/// Lunar festivals shown in the calendar when the lunar calendar is on.
/// Fixed lunar dates; never in a leap month.
enum LunarFestival {
  tet(1, 1),
  lantern(15, 1),
  hungKings(10, 3),
  buddha(15, 4),
  doanNgo(5, 5),
  vuLan(15, 7),
  midAutumn(15, 8),
  kitchenGods(23, 12);

  const LunarFestival(this.day, this.month);

  final int day;
  final int month;

  static LunarFestival? of(LunarDate date) {
    if (date.leap) {
      return null;
    }
    for (final f in values) {
      if (f.day == date.day && f.month == date.month) {
        return f;
      }
    }
    return null;
  }
}
