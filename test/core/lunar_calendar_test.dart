import 'package:flutter_base/src/core/lunar/lunar_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tết (1/1 âm lịch), Vietnam time zone', () {
    const tet = {
      1968: (1, 29), // Mậu Thân — a day before China's
      1985: (1, 21), // a month before China's (20 Feb)
      2000: (2, 5),
      2001: (1, 24),
      2002: (2, 12),
      2003: (2, 1),
      2004: (1, 22),
      2005: (2, 9),
      2006: (1, 29),
      2007: (2, 17), // China: 18 Feb
      2008: (2, 7),
      2009: (1, 26),
      2010: (2, 14),
      2011: (2, 3),
      2012: (1, 23),
      2013: (2, 10),
      2014: (1, 31),
      2015: (2, 19),
      2016: (2, 8),
      2017: (1, 28),
      2018: (2, 16),
      2019: (2, 5),
      2020: (1, 25),
      2021: (2, 12),
      2022: (2, 1),
      2023: (1, 22),
      2024: (2, 10),
      2025: (1, 29),
      2026: (2, 17),
      2027: (2, 6),
      2028: (1, 26),
      2029: (2, 13),
      2030: (2, 2), // China: 3 Feb (new moon ~23:00 in Vietnam)
    };
    for (final MapEntry(key: year, value: (month, day)) in tet.entries) {
      test('$year', () {
        final solar = DateTime(year, month, day);
        expect(LunarDate.fromSolar(solar), LunarDate(1, 1, year));
        expect(LunarDate(1, 1, year).toSolar(), solar);
        // The day before is the last day of the previous lunar year
        final eve = LunarDate.fromSolar(
          solar.subtract(const Duration(days: 1)),
        );
        expect((eve.month, eve.year), (12, year - 1));
      });
    }
  });

  group('leap months', () {
    test('2020: leap 4th month from 23 May', () {
      expect(
        LunarDate.fromSolar(DateTime(2020, 5, 23)),
        const LunarDate(1, 4, 2020, leap: true),
      );
      expect(
        const LunarDate(1, 4, 2020, leap: true).toSolar(),
        DateTime(2020, 5, 23),
      );
      expect(const LunarDate(1, 4, 2020).toSolar(), DateTime(2020, 4, 23));
    });

    test('2023: leap 2nd month from 22 Mar', () {
      expect(
        LunarDate.fromSolar(DateTime(2023, 3, 22)),
        const LunarDate(1, 2, 2023, leap: true),
      );
    });

    test('2025: leap 6th month from 25 Jul', () {
      expect(
        LunarDate.fromSolar(DateTime(2025, 7, 25)),
        const LunarDate(1, 6, 2025, leap: true),
      );
    });

    test('no leap month that year → null', () {
      expect(const LunarDate(1, 4, 2024, leap: true).toSolar(), isNull);
      expect(const LunarDate(1, 5, 2020, leap: true).toSolar(), isNull);
    });
  });

  group('festivals 2024', () {
    test('known dates', () {
      expect(const LunarDate(15, 1, 2024).toSolar(), DateTime(2024, 2, 24));
      expect(const LunarDate(10, 3, 2024).toSolar(), DateTime(2024, 4, 18));
      expect(const LunarDate(15, 7, 2024).toSolar(), DateTime(2024, 8, 18));
      expect(const LunarDate(15, 8, 2024).toSolar(), DateTime(2024, 9, 17));
      expect(const LunarDate(23, 12, 2024).toSolar(), DateTime(2025, 1, 22));
    });
  });

  test('day 30 of a 29-day month does not exist', () {
    // Find a 29-day month and ask for its 30th
    var k = LunarCalendar.monthIndexOf(LunarCalendar.jdOf(DateTime(2026)));
    while (LunarCalendar.monthLength(k) != 29) {
      k++;
    }
    final first = LunarDate.fromSolar(LunarCalendar.dayInMonth(k, 1));
    final thirtieth = LunarDate(30, first.month, first.year, leap: first.leap);
    expect(thirtieth.toSolar(), isNull);
    // Clamping lands on the 29th
    expect(LunarDate.fromSolar(LunarCalendar.dayInMonth(k, 30)).day, 29);
  });

  test('every day 1900–2100 round-trips and days run in sequence', () {
    var date = DateTime(1900);
    final end = DateTime(2100, 12, 31);
    var previous = LunarDate.fromSolar(DateTime(1899, 12, 31));
    var checked = 0;
    while (!date.isAfter(end)) {
      final lunar = LunarDate.fromSolar(date);
      expect(lunar.toSolar(), date, reason: '$date → $lunar');
      expect(lunar.day, inInclusiveRange(1, 30));
      expect(lunar.month, inInclusiveRange(1, 12));
      if (lunar.day != 1) {
        expect(lunar.day, previous.day + 1, reason: '$date');
      } else {
        expect(previous.day, inInclusiveRange(29, 30), reason: '$date');
      }
      previous = lunar;
      date = DateTime(date.year, date.month, date.day + 1);
      checked++;
    }
    expect(checked, greaterThan(73000));
  });

  test('month index and length agree with conversions', () {
    final jd = LunarCalendar.jdOf(DateTime(2026, 11, 13));
    final k = LunarCalendar.monthIndexOf(jd);
    expect(LunarCalendar.newMoonDay(k), lessThanOrEqualTo(jd));
    expect(LunarCalendar.newMoonDay(k + 1), greaterThan(jd));
    expect(LunarCalendar.monthLength(k), inInclusiveRange(29, 30));
  });
}
