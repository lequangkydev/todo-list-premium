import 'package:flutter_base/src/core/lunar/lunar_calendar.dart';
import 'package:flutter_base/src/core/recurrence/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parse / serialize', () {
    test('round-trips supported rules', () {
      for (final rule in [
        'FREQ=DAILY',
        'FREQ=DAILY;INTERVAL=3',
        'FREQ=WEEKLY;BYDAY=MO,WE',
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU',
        'FREQ=MONTHLY;BYMONTHDAY=-1',
        'FREQ=MONTHLY;BYMONTHDAY=15',
        'FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29',
      ]) {
        expect(Recurrence.tryParse(rule)!.toRule(), rule);
      }
    });

    test('rejects unsupported / invalid rules', () {
      expect(Recurrence.tryParse(null), isNull);
      expect(Recurrence.tryParse(''), isNull);
      expect(Recurrence.tryParse('FREQ=HOURLY'), isNull);
      expect(Recurrence.tryParse('FREQ=MONTHLY;BYMONTHDAY=40'), isNull);
    });
  });

  group('nextAfter', () {
    test('daily with interval', () {
      expect(
        Recurrence.daily(interval: 2).nextAfter(DateTime(2026, 2, 27)),
        DateTime(2026, 3, 1),
      );
    });

    test('weekly on several days', () {
      final r = Recurrence.weekly({DateTime.monday, DateTime.wednesday});
      // Mon 16 Nov 2026 → Wed 18 → Mon 23
      expect(r.nextAfter(DateTime(2026, 11, 16)), DateTime(2026, 11, 18));
      expect(r.nextAfter(DateTime(2026, 11, 18)), DateTime(2026, 11, 23));
    });

    test('every other Tuesday', () {
      final r = Recurrence.weekly({DateTime.tuesday}, interval: 2);
      expect(r.nextAfter(DateTime(2026, 11, 17)), DateTime(2026, 12, 1));
    });

    test('weekdays skip the weekend', () {
      final r = Recurrence.weekdaysOnly();
      expect(r.nextAfter(DateTime(2026, 11, 13)), DateTime(2026, 11, 16));
    });

    test('monthly on the 31st clamps and comes back', () {
      final r = Recurrence.monthly(31);
      final feb = r.nextAfter(DateTime(2026, 1, 31));
      expect(feb, DateTime(2026, 2, 28));
      expect(r.nextAfter(feb), DateTime(2026, 3, 31));
      expect(r.nextAfter(DateTime(2026, 3, 31)), DateTime(2026, 4, 30));
    });

    test('last day of month', () {
      final r = Recurrence.monthly(-1);
      expect(r.nextAfter(DateTime(2027, 1, 31)), DateTime(2027, 2, 28));
      expect(r.nextAfter(DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
      expect(r.nextAfter(DateTime(2026, 12, 31)), DateTime(2027, 1, 31));
    });

    test('yearly on Feb 29', () {
      final r = Recurrence.yearly(2, 29);
      expect(r.nextAfter(DateTime(2028, 2, 29)), DateTime(2029, 2, 28));
      expect(r.nextAfter(DateTime(2031, 2, 28)), DateTime(2032, 2, 29));
    });

    test('daily across a DST change keeps calendar days', () {
      // Dates are built from Y/M/D, so DST never shifts the day
      final r = Recurrence.daily();
      expect(r.nextAfter(DateTime(2026, 3, 28)), DateTime(2026, 3, 29));
      expect(r.nextAfter(DateTime(2026, 3, 29)), DateTime(2026, 3, 30));
      expect(r.nextAfter(DateTime(2026, 10, 25)), DateTime(2026, 10, 26));
    });
  });

  group('completion', () {
    test('overdue daily task jumps past today', () {
      final r = Recurrence.daily();
      expect(
        r.nextDueAfterCompletion(
          DateTime(2026, 11, 10),
          DateTime(2026, 11, 13),
        ),
        DateTime(2026, 11, 14),
      );
    });

    test('completing early keeps the schedule', () {
      final r = Recurrence.weekly({DateTime.friday});
      expect(
        r.nextDueAfterCompletion(
          DateTime(2026, 11, 20),
          DateTime(2026, 11, 13),
        ),
        DateTime(2026, 11, 27),
      );
    });

    test('first occurrence snaps onto the rule', () {
      final r = Recurrence.weekly({DateTime.monday});
      expect(r.firstOnOrAfter(DateTime(2026, 11, 13)), DateTime(2026, 11, 16));
      expect(r.firstOnOrAfter(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
    });
  });

  group('lunar (âm lịch)', () {
    DateTime lunar(int day, int month, int year, {bool leap = false}) =>
        LunarDate(day, month, year, leap: leap).toSolar()!;

    test('round-trips and rejects nonsense', () {
      const rule = 'FREQ=YEARLY;BYMONTH=7;BYMONTHDAY=15;X-CAL=LUNAR';
      expect(Recurrence.tryParse(rule)?.toRule(), rule);
      expect(Recurrence.tryParse(rule), Recurrence.lunarYearly(7, 15));
      expect(
        Recurrence.lunarMonthly(15).toRule(),
        'FREQ=MONTHLY;BYMONTHDAY=15;X-CAL=LUNAR',
      );
      expect(Recurrence.tryParse('FREQ=DAILY;X-CAL=LUNAR'), isNull);
      expect(Recurrence.tryParse('FREQ=MONTHLY;X-CAL=LUNAR'), isNull);
      expect(
        Recurrence.tryParse('FREQ=YEARLY;BYMONTHDAY=15;X-CAL=LUNAR'),
        isNull,
      );
    });

    test('Vu Lan every year', () {
      final r = Recurrence.lunarYearly(7, 15);
      expect(r.firstOnOrAfter(DateTime(2024, 8)), DateTime(2024, 8, 18));
      expect(r.matches(DateTime(2024, 8, 18)), isTrue);
      expect(r.nextAfter(DateTime(2024, 8, 18)), lunar(15, 7, 2025));
      // Completed late: no pile-up of past years
      expect(
        r.nextDueAfterCompletion(DateTime(2024, 8, 18), DateTime(2025, 10)),
        lunar(15, 7, 2026),
      );
    });

    test('rằm every lunar month, leap month included', () {
      final r = Recurrence.lunarMonthly(15);
      final sixth = lunar(15, 6, 2025);
      final leapSixth = lunar(15, 6, 2025, leap: true);
      expect(r.nextAfter(sixth), leapSixth);
      expect(r.nextAfter(leapSixth), lunar(15, 7, 2025));
      expect(r.firstOnOrAfter(sixth), sixth);
      expect(r.firstOnOrAfter(sixth.add(const Duration(days: 1))), leapSixth);
    });

    test('a giỗ is never in the leap month', () {
      final r = Recurrence.lunarYearly(6, 15);
      final after = lunar(15, 6, 2025).add(const Duration(days: 1));
      expect(r.firstOnOrAfter(after), lunar(15, 6, 2026));
      expect(r.matches(lunar(15, 6, 2025, leap: true)), isFalse);
    });

    test('the 30th of a 29-day month lands on the 29th', () {
      final r = Recurrence.lunarMonthly(30);
      var day = DateTime(2026);
      for (var i = 0; i < 12; i++) {
        day = r.nextAfter(day);
        final l = LunarDate.fromSolar(day);
        expect(l.day, inInclusiveRange(29, 30));
        // It's the last day of its month
        expect(LunarDate.fromSolar(day.add(const Duration(days: 1))).day, 1);
      }
    });
  });
}
