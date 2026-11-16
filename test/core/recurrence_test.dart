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
}
