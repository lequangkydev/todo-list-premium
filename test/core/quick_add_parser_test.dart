import 'package:flutter_base/src/core/date_parser/quick_add_parser.dart';
import 'package:flutter_base/src/core/lunar/lunar_calendar.dart';
import 'package:flutter_base/src/core/recurrence/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

// Friday 13 Nov 2026, 10:00
final now = DateTime(2026, 11, 13, 10);
final parser = QuickAddParser();

QuickAddResult p(String input, {bool dayFirst = true}) =>
    QuickAddParser(dayFirst: dayFirst).parse(input, now);

int hm(int h, [int m = 0]) => h * 60 + m;

void main() {
  group('Vietnamese', () {
    test('mai 9h', () {
      final r = p('Họp nhóm mai 9h');
      expect(r.title, 'Họp nhóm');
      expect(r.date, DateTime(2026, 11, 14));
      expect(r.time, hm(9));
    });

    test('thứ 6 / thu 6 without accents', () {
      expect(p('Nộp báo cáo thứ 6').date, DateTime(2026, 11, 13));
      expect(p('Nop bao cao thu 6').date, DateTime(2026, 11, 13));
      expect(p('Nộp báo cáo thứ 6').title, 'Nộp báo cáo');
    });

    test('thứ 2 tuần sau', () {
      final r = p('Gửi hợp đồng thứ 2 tuần sau');
      expect(r.date, DateTime(2026, 11, 16));
      expect(r.title, 'Gửi hợp đồng');
    });

    test('thứ hai and chủ nhật words', () {
      expect(p('Đi chợ thứ hai').date, DateTime(2026, 11, 16));
      expect(p('Dọn nhà chủ nhật').date, DateTime(2026, 11, 15));
      expect(p('Dọn nhà CN').date, DateTime(2026, 11, 15));
    });

    test('9h tối and 7h30 sáng', () {
      expect(p('Gọi mẹ 9h tối').time, hm(21));
      expect(p('Chạy bộ 7h30 sáng').time, hm(7, 30));
      expect(p('Ăn trưa 1h trưa').time, hm(13));
      expect(p('Họp 3 giờ rưỡi chiều').time, hm(15, 30));
    });

    test('time only goes to today or tomorrow', () {
      expect(p('Uống thuốc 9h tối').date, DateTime(2026, 11, 13));
      expect(p('Uống thuốc 8h').date, DateTime(2026, 11, 14));
    });

    test('tối nay / sáng mai default times', () {
      final tonight = p('Xem phim tối nay');
      expect(tonight.date, DateTime(2026, 11, 13));
      expect(tonight.time, hm(20));
      final morning = p('Chạy bộ sáng mai');
      expect(morning.date, DateTime(2026, 11, 14));
      expect(morning.time, hm(9));
      expect(morning.title, 'Chạy bộ');
    });

    test('explicit time beats part-of-day default', () {
      final r = p('Họp sáng mai 8h');
      expect(r.time, hm(8));
    });

    test('ngày kia / mốt / hôm nay', () {
      expect(p('Đi khám ngày kia').date, DateTime(2026, 11, 15));
      expect(p('Đi khám mốt').date, DateTime(2026, 11, 15));
      expect(p('Đi khám hôm nay').date, DateTime(2026, 11, 13));
    });

    test('dates: 20/11, ngày 25, ngày 3 tháng 1', () {
      expect(p('Sinh nhật 20/11').date, DateTime(2026, 11, 20));
      expect(p('Trả tiền nhà ngày 25').date, DateTime(2026, 11, 25));
      expect(p('Trả tiền nhà ngày 5').date, DateTime(2026, 12, 5));
      expect(p('Gia hạn ngày 3 tháng 1').date, DateTime(2027, 1, 3));
      expect(p('Hạn chót 1/11').date, DateTime(2027, 11, 1));
    });

    test('recurrence', () {
      expect(p('Tưới cây hàng ngày').recurrence, Recurrence.daily());
      final weekly = p('Đổ rác thứ 3 hàng tuần');
      expect(weekly.recurrence, Recurrence.weekly({DateTime.tuesday}));
      expect(weekly.date, DateTime(2026, 11, 17));
      expect(weekly.title, 'Đổ rác');
      expect(
        p('Tập gym mỗi thứ 2, thứ 4').recurrence,
        Recurrence.weekly({1, 3}),
      );
      expect(p('Báo cáo ngày thường').recurrence, Recurrence.weekdaysOnly());
      final eom = p('Chốt sổ cuối mỗi tháng');
      expect(eom.recurrence, Recurrence.monthly(-1));
      expect(eom.date, DateTime(2026, 11, 30));
      expect(
        p('Đóng tiền điện ngày 10 hàng tháng').recurrence,
        Recurrence.monthly(10),
      );
      expect(
        p('Dọn tủ lạnh mỗi 2 tuần').recurrence,
        Recurrence.weekly({DateTime.friday}, interval: 2),
      );
    });

    test('ambiguous words are left alone', () {
      // "Mai" is a name here; "một" (one) is not "mốt"
      final name = p('Gọi chị Mai');
      expect(name.date, isNull);
      expect(name.title, 'Gọi chị Mai');
      expect(p('Mua một cái bánh').date, isNull);
      expect(p('Tôi nay bận').time, isNull);
      expect(p('Chuẩn bị 1-2 slide').date, isNull);
      expect(p('Mua 2 gói mì').time, isNull);
    });

    test('connector words are removed with the date', () {
      expect(p('Nộp đơn vào thứ 6').title, 'Nộp đơn');
      expect(p('Họp lúc 3h chiều').title, 'Họp');
    });
  });

  group('English', () {
    test('tomorrow 5pm', () {
      final r = p('Call mom tomorrow 5pm');
      expect(r.title, 'Call mom');
      expect(r.date, DateTime(2026, 11, 14));
      expect(r.time, hm(17));
    });

    test('next friday / on monday', () {
      expect(p('Ship it next friday').date, DateTime(2026, 11, 20));
      expect(p('Dentist on monday').date, DateTime(2026, 11, 16));
      expect(p('Dentist on mon at 9:30').time, hm(9, 30));
    });

    test('abbreviated weekdays need a prefix', () {
      expect(p('Buy sun cream').date, isNull);
      expect(p('Buy sun cream').title, 'Buy sun cream');
    });

    test('every monday', () {
      final r = p('Team sync every monday 10am');
      expect(r.recurrence, Recurrence.weekly({DateTime.monday}));
      expect(r.date, DateTime(2026, 11, 16));
      expect(r.time, hm(10));
      expect(r.title, 'Team sync');
    });

    test('every weekday / every other week / last day', () {
      expect(p('Standup every weekday').recurrence, Recurrence.weekdaysOnly());
      expect(
        p('Payroll every 2 weeks').recurrence,
        Recurrence.weekly({DateTime.friday}, interval: 2),
      );
      expect(
        p('Rent every last day of the month').recurrence,
        Recurrence.monthly(-1),
      );
      expect(p('Water plants daily').recurrence, Recurrence.daily());
    });

    test('month names and in N days', () {
      expect(p('Tax return apr 15').date, DateTime(2027, 4, 15));
      expect(p('Party 20th december').date, DateTime(2026, 12, 20));
      expect(p('Follow up in 3 days').date, DateTime(2026, 11, 16));
      expect(p('Follow up in 2 weeks').date, DateTime(2026, 11, 27));
    });

    test('US month-first numeric dates', () {
      expect(p('Meeting 11/20', dayFirst: false).date, DateTime(2026, 11, 20));
    });

    test('tonight / noon', () {
      final r = p('Read a book tonight');
      expect(r.date, DateTime(2026, 11, 13));
      expect(r.time, hm(20));
      expect(p('Lunch tomorrow noon').time, hm(12));
    });
  });

  group('priority', () {
    test('! marks', () {
      expect(p('Pay bills !!!').priority, 3);
      expect(p('Pay bills !!').priority, 2);
      expect(p('Pay bills !!').title, 'Pay bills');
      expect(p('Done!').priority, 0);
    });
  });

  test('plain text stays plain', () {
    final r = p('Buy milk');
    expect(r.isEmpty, isTrue);
    expect(r.title, 'Buy milk');
  });

  test('only a date keeps the input as title', () {
    expect(p('mai').title, 'mai');
  });

  group('lunar (âm lịch)', () {
    final today = DateTime(2026, 11, 13);
    DateTime lunar(int d, int m, int y) => LunarDate(d, m, y).toSolar()!;

    test('rằm and mùng N: the next one', () {
      final r = p('Cúng rằm');
      expect(r.title, 'Cúng');
      expect(r.date, Recurrence.lunarMonthly(15).firstOnOrAfter(today));
      expect(LunarDate.fromSolar(r.date!).day, 15);
      expect(p('Đi chùa mùng 1').date!.isAfter(today), isTrue);
      expect(LunarDate.fromSolar(p('Đi chùa mùng 1').date!).day, 1);
    });

    test('a lunar day of a named month', () {
      // Trung thu 2026 has passed by 13 Nov 2026
      final r = p('Mua bánh trung thu trước rằm tháng 8');
      expect(r.title, 'Mua bánh trung thu');
      expect(r.date, lunar(15, 8, 2027));
      expect(p('Về quê mùng 2 Tết').date, lunar(2, 1, 2027));
      expect(p('Họp lớp rằm tháng giêng').date, lunar(15, 1, 2027));
      expect(p('Tất niên 23/12 âm').date, lunar(23, 12, 2026));
      expect(p('Tất niên 23/12 AL').date, lunar(23, 12, 2026));
    });

    test('giỗ repeats every lunar year', () {
      final r = p('Giỗ ông 10/3 âm lịch');
      expect(r.title, 'Giỗ ông');
      expect(r.recurrence, Recurrence.lunarYearly(3, 10));
      expect(r.date, lunar(10, 3, 2027));
    });

    test('hằng tháng / hằng năm with a lunar date', () {
      final monthly = p('Thắp hương mùng 1 hằng tháng');
      expect(monthly.title, 'Thắp hương');
      expect(monthly.recurrence, Recurrence.lunarMonthly(1));
      expect(p('Ăn chay mỗi rằm').recurrence, Recurrence.lunarMonthly(15));
      expect(
        p('Ăn chay rằm hằng tháng').recurrence,
        Recurrence.lunarMonthly(15),
      );
      expect(
        p('Cúng cô hồn 15/7 âm hằng năm').recurrence,
        Recurrence.lunarYearly(7, 15),
      );
    });

    test('look-alikes stay text', () {
      expect(p('Nâng cấp RAM').hasSchedule, isFalse);
      expect(p('Nâng cấp RAM').title, 'Nâng cấp RAM');
      // A solar date is still solar
      expect(p('Nộp hồ sơ 15/7').date, DateTime(2027, 7, 15));
      expect(p('Họp 9 am').time, 9 * 60);
    });
  });
}
