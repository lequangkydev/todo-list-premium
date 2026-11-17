import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Vietnamese lunisolar calendar (âm lịch), computed for UTC+7.
///
/// Port of Hồ Ngọc Đức's well-known algorithm ("Computing the Vietnamese
/// lunar calendar"): months start on the day of the new moon in Vietnam's
/// time zone, the 11th month always contains the winter solstice, and a leap
/// month is the first month without a major solar term. Because the time
/// zone is UTC+7, a few dates differ from the Chinese calendar (UTC+8), e.g.
/// Tết 1985 and 2007.
///
/// Valid roughly 1800–2199; tested 1900–2100.
@immutable
class LunarDate {
  const LunarDate(this.day, this.month, this.year, {this.leap = false});

  final int day;
  final int month;
  final int year;

  /// The repeated (nhuận) month of a leap year
  final bool leap;

  static LunarDate fromSolar(DateTime date) =>
      LunarCalendar.toLunar(date.day, date.month, date.year);

  /// The solar date, or null when this lunar date doesn't exist (a leap
  /// month that year doesn't have, or day 30 of a 29-day month)
  DateTime? toSolar() => LunarCalendar.toSolar(this);

  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      other.day == day &&
      other.month == month &&
      other.year == year &&
      other.leap == leap;

  @override
  int get hashCode => Object.hash(day, month, year, leap);

  @override
  String toString() => '$day/$month${leap ? 'L' : ''}/$year';
}

class LunarCalendar {
  LunarCalendar._();

  static const _can = [
    'Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', //
    'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý',
  ];
  static const _chi = [
    'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ', //
    'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi',
  ];

  /// The lunar year's name in the sexagenary cycle, e.g. 2026 → "Bính Ngọ"
  /// (Vietnamese names; used when the app is in Vietnamese)
  static String canChiYear(int lunarYear) =>
      '${_can[(lunarYear + 6) % 10]} ${_chi[(lunarYear + 8) % 12]}';

  static const double timeZone = 7;

  static int _floor(double x) => x.floor();

  /// Julian day number of a Gregorian (or, before 1582, Julian) date
  static int jdFromDate(int dd, int mm, int yy) {
    final a = _floor((14 - mm) / 12);
    final y = yy + 4800 - a;
    final m = mm + 12 * a - 3;
    var jd =
        dd +
        _floor((153 * m + 2) / 5) +
        365 * y +
        _floor(y / 4) -
        _floor(y / 100) +
        _floor(y / 400) -
        32045;
    if (jd < 2299161) {
      jd = dd + _floor((153 * m + 2) / 5) + 365 * y + _floor(y / 4) - 32083;
    }
    return jd;
  }

  static DateTime dateFromJd(int jd) {
    int b;
    int c;
    if (jd > 2299160) {
      final a = jd + 32044;
      b = _floor((4 * a + 3) / 146097);
      c = a - _floor((b * 146097) / 4);
    } else {
      b = 0;
      c = jd + 32082;
    }
    final d = _floor((4 * c + 3) / 1461);
    final e = c - _floor((1461 * d) / 4);
    final m = _floor((5 * e + 2) / 153);
    final day = e - _floor((153 * m + 2) / 5) + 1;
    final month = m + 3 - 12 * _floor(m / 10);
    final year = b * 100 + d - 4800 + _floor(m / 10);
    return DateTime(year, month, day);
  }

  static int jdOf(DateTime date) => jdFromDate(date.day, date.month, date.year);

  /// Julian day (fractional, UT) of the k-th new moon after 1900-01-01
  static double _newMoon(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    const dr = math.pi / 180;
    var jd1 =
        2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c1 =
        (0.1734 - 0.000393 * t) * math.sin(m * dr) +
        0.0021 * math.sin(2 * dr * m);
    c1 = c1 - 0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(dr * 2 * mpr);
    c1 = c1 - 0.0004 * math.sin(dr * 3 * mpr);
    c1 = c1 + 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr));
    c1 =
        c1 -
        0.0074 * math.sin(dr * (m - mpr)) +
        0.0004 * math.sin(dr * (2 * f + m));
    c1 =
        c1 -
        0.0004 * math.sin(dr * (2 * f - m)) -
        0.0006 * math.sin(dr * (2 * f + mpr));
    c1 =
        c1 +
        0.0010 * math.sin(dr * (2 * f - mpr)) +
        0.0005 * math.sin(dr * (2 * mpr + m));
    final double deltaT;
    if (t < -11) {
      deltaT =
          0.001 +
          0.000839 * t +
          0.0002261 * t2 -
          0.00000845 * t3 -
          0.000000081 * t * t3;
    } else {
      deltaT = -0.000278 + 0.000265 * t + 0.000262 * t2;
    }
    return jd1 + c1 - deltaT;
  }

  /// Sun's ecliptic longitude (radians, 0..2π) at Julian day [jdn] (UT)
  static double _sunLongitude(double jdn) {
    final t = (jdn - 2451545.0) / 36525;
    final t2 = t * t;
    const dr = math.pi / 180;
    final m =
        357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
    dl =
        dl +
        (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) +
        0.000290 * math.sin(dr * 3 * m);
    var l = (l0 + dl) * dr;
    l = l - math.pi * 2 * _floor(l / (math.pi * 2));
    return l;
  }

  /// Major solar term (0..11) at local midnight of day [dayNumber]
  static int _solarTerm(int dayNumber) =>
      _floor(_sunLongitude(dayNumber - 0.5 - timeZone / 24) / math.pi * 6);

  /// Local day of the k-th new moon — the first day of a lunar month
  static int newMoonDay(int k) => _floor(_newMoon(k) + 0.5 + timeZone / 24);

  /// Index k of the lunar month containing [jd]
  static int monthIndexOf(int jd) {
    var k = _floor((jd - 2415021.076998695) / 29.530588853);
    if (newMoonDay(k + 1) <= jd) {
      k += 1;
    }
    if (newMoonDay(k) > jd) {
      k -= 1;
    }
    return k;
  }

  /// Length (29 or 30) of the lunar month with index [k]
  static int monthLength(int k) => newMoonDay(k + 1) - newMoonDay(k);

  /// First day of the 11th lunar month (the one with the winter solstice)
  /// of solar year [yy]
  static int _lunarMonth11(int yy) {
    final off = jdFromDate(31, 12, yy) - 2415021;
    final k = _floor(off / 29.530588853);
    var nm = newMoonDay(k);
    if (_solarTerm(nm) >= 9) {
      nm = newMoonDay(k - 1);
    }
    return nm;
  }

  /// How many months after month 11 the leap month comes
  static int _leapMonthOffset(int a11) {
    final k = _floor((a11 - 2415021.076998695) / 29.530588853 + 0.5);
    var last = 0;
    var i = 1;
    var arc = _solarTerm(newMoonDay(k + i));
    do {
      last = arc;
      i++;
      arc = _solarTerm(newMoonDay(k + i));
    } while (arc != last && i < 14);
    return i - 1;
  }

  static LunarDate toLunar(int dd, int mm, int yy) {
    final dayNumber = jdFromDate(dd, mm, yy);
    // The original estimates k and checks one side only; once in a while
    // (e.g. 7 May 2054) the estimate is a month late and gives "day 0"
    final monthStart = newMoonDay(monthIndexOf(dayNumber));
    var a11 = _lunarMonth11(yy);
    var b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = yy;
      a11 = _lunarMonth11(yy - 1);
    } else {
      lunarYear = yy + 1;
      b11 = _lunarMonth11(yy + 1);
    }
    final lunarDay = dayNumber - monthStart + 1;
    final diff = _floor((monthStart - a11) / 29);
    var leap = false;
    var lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      final leapMonthDiff = _leapMonthOffset(a11);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) {
          leap = true;
        }
      }
    }
    if (lunarMonth > 12) {
      lunarMonth -= 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
      lunarYear -= 1;
    }
    return LunarDate(lunarDay, lunarMonth, lunarYear, leap: leap);
  }

  /// Index k of the first day of lunar month [month] (leap or not) of
  /// [year], or null when that month doesn't exist
  static int? monthIndex(int month, int year, {bool leap = false}) {
    int a11;
    int b11;
    if (month < 11) {
      a11 = _lunarMonth11(year - 1);
      b11 = _lunarMonth11(year);
    } else {
      a11 = _lunarMonth11(year);
      b11 = _lunarMonth11(year + 1);
    }
    final k = _floor(0.5 + (a11 - 2415021.076998695) / 29.530588853);
    var off = month - 11;
    if (off < 0) {
      off += 12;
    }
    if (b11 - a11 > 365) {
      final leapOff = _leapMonthOffset(a11);
      var leapMonth = leapOff - 2;
      if (leapMonth < 0) {
        leapMonth += 12;
      }
      if (leap && month != leapMonth) {
        return null;
      }
      if (leap || off >= leapOff) {
        off += 1;
      }
    } else if (leap) {
      return null;
    }
    return k + off;
  }

  static DateTime? toSolar(LunarDate date) {
    if (date.month < 1 || date.month > 12 || date.day < 1) {
      return null;
    }
    final k = monthIndex(date.month, date.year, leap: date.leap);
    if (k == null || date.day > monthLength(k)) {
      return null;
    }
    return dateFromJd(newMoonDay(k) + date.day - 1);
  }

  /// [day] of the lunar month with index [k], clamped to its last day
  /// (a 30th in a 29-day month lands on the 29th)
  static DateTime dayInMonth(int k, int day) {
    final clamped = day.clamp(1, monthLength(k));
    return dateFromJd(newMoonDay(k) + clamped - 1);
  }
}
