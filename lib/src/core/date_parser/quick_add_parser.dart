import '../date/dates.dart';
import '../recurrence/recurrence.dart';

/// Result of parsing a quick-add line such as "Nộp báo cáo thứ 6 9h !!".
class QuickAddResult {
  const QuickAddResult({
    required this.title,
    this.date,
    this.time,
    this.recurrence,
    this.priority = 0,
    this.spans = const [],
  });

  /// Input with the recognised date/time/priority words removed
  final String title;
  final DateTime? date;

  /// Minutes after midnight
  final int? time;
  final Recurrence? recurrence;
  final int priority;

  /// Ranges of the ORIGINAL input that were recognised (for highlighting)
  final List<(int, int)> spans;

  bool get hasSchedule => date != null || recurrence != null;

  bool get isEmpty => !hasSchedule && time == null && priority == 0;
}

/// Natural-language quick add for Vietnamese and English.
///
/// Matching runs on a lowercased, diacritic-free copy of the input ("thứ 6" ≡
/// "thu 6"), then maps matches back to the original text. Words that are
/// ambiguous in Vietnamese ("mai" is also a name, "một" loses its accent to
/// "mot") are guarded against the original spelling.
class QuickAddParser {
  QuickAddParser({this.dayFirst = true});

  /// `20/11` = 20 Nov when true (VN, UK…), 11 Nov… when false (US)
  final bool dayFirst;

  QuickAddResult parse(String input, DateTime now) {
    final norm = _Normalized(input);
    final ctx = _Ctx(Dates.dateOnly(now), now, input);
    final consumed = <(int, int)>[];

    for (final rule in _rules) {
      for (final m in rule.re.allMatches(norm.text)) {
        if (consumed.any((c) => m.start < c.$2 && c.$1 < m.end)) {
          continue;
        }
        final original = input.substring(
          norm.originalIndex(m.start),
          norm.originalIndex(m.end),
        );
        if (rule.apply(m, ctx, original, _isMidSentence(input, norm, m))) {
          consumed.add((m.start, m.end));
        }
      }
    }

    // Absorb a connector right before a match: "vào thứ 6", "at 5pm"
    final extended = [
      for (final span in consumed) _withConnector(norm.text, span),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final spans = [
      for (final s in extended)
        (norm.originalIndex(s.$1), norm.originalIndex(s.$2)),
    ];

    var title = input;
    for (final s in spans.reversed) {
      title = title.replaceRange(s.$1, s.$2, ' ');
    }
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceAll(RegExp(r'^[,;\-–]+\s*|\s*[,;\-–]+$'), '').trim();
    if (title.isEmpty) {
      title = input.trim();
    }

    return ctx.build(title, spans);
  }

  bool _isMidSentence(String input, _Normalized norm, Match m) {
    final start = norm.originalIndex(m.start);
    if (start == 0) {
      return false;
    }
    final first = input[start];
    final isUpper = first != first.toLowerCase();
    if (!isUpper) {
      return false;
    }
    final before = input.substring(0, start).trimRight();
    return before.isNotEmpty && !RegExp(r'[.!?:]$').hasMatch(before);
  }

  static final _connector = RegExp(
    r'(?:^|\s)(on|at|by|due|vao|luc|truoc|han|tu|ngay|starting|bat dau)\s+$',
  );

  (int, int) _withConnector(String text, (int, int) span) {
    final before = text.substring(0, span.$1);
    final m = _connector.firstMatch(before);
    if (m == null) {
      return span;
    }
    return (m.start + (m.group(0)!.startsWith(RegExp(r'\s')) ? 1 : 0), span.$2);
  }

  // ------------------------------------------------------------------ rules

  late final List<_Rule> _rules = [
    // ---- priority
    _Rule(r'!{1,3}', (m, c, o, mid) => c.setPriority(m.group(0)!.length)),

    // ---- recurrence (before dates: "every monday" must not become a date)
    _Rule(r'every\s*day|daily|hang\s+ngay|moi\s+ngay', (m, c, o, mid) {
      return c.setRecurrence(Recurrence.daily());
    }),
    _Rule(
      r'every\s+(?:week|work)\s*days?|weekdays|ngay\s+thuong|'
      r'(?:moi|cac)\s+ngay\s+(?:lam\s+viec|trong\s+tuan)|ngay\s+lam\s+viec',
      (m, c, o, mid) => c.setRecurrence(Recurrence.weekdaysOnly()),
    ),
    _Rule(
      r'every\s+(?:last\s+day(?:\s+of\s+(?:the\s+)?month)?|end\s+of\s+(?:the\s+)?month)|'
      r'(?:ngay\s+)?cuoi\s+(?:moi|hang)\s+thang|hang\s+thang\s+ngay\s+cuoi(?:\s+thang)?',
      (m, c, o, mid) => c.setRecurrence(Recurrence.monthly(-1)),
    ),
    _Rule(r'every\s+(\d{1,3}|other)\s+(day|week|month|year)s?', (m, c, o, mid) {
      final n = m.group(1) == 'other' ? 2 : int.parse(m.group(1)!);
      return c.setUnitRecurrence(m.group(2)!, n);
    }),
    _Rule(r'moi\s+(\d{1,3})\s+(ngay|tuan|thang|nam)', (m, c, o, mid) {
      return c.setUnitRecurrence(_viUnit[m.group(2)]!, int.parse(m.group(1)!));
    }),
    // "mỗi rằm", "hằng tháng ngày rằm", "mùng 1 hằng tháng" (lunar)
    _Rule(r'(?:moi|hang)\s+(?:thang\s+)?(?:vao\s+)?(?:ngay\s+)?'
        r'(?:(ram)|(?:mung|mong)\s*(\d{1,2}))', (m, c, o, mid) {
      final day = m.group(1) != null ? 15 : int.parse(m.group(2)!);
      if (day < 1 || day > 10 && m.group(1) == null) {
        return false;
      }
      return c.setRecurrence(Recurrence.lunarMonthly(day));
    }),
    _Rule(r'(?:hang\s+thang\s+(?:vao\s+)?ngay\s+(\d{1,2}))|'
        r'(?:ngay\s+(\d{1,2})\s+(?:hang|moi)\s+thang)|'
        r'(?:every\s+month\s+on\s+(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?)', (
      m,
      c,
      o,
      mid,
    ) {
      final day = int.parse(m.group(1) ?? m.group(2) ?? m.group(3)!);
      if (day < 1 || day > 31) {
        return false;
      }
      return c.setRecurrence(Recurrence.monthly(day));
    }),
    _Rule(
      'every\\s+($_enDay(?:\\s*(?:,|and|&)\\s*$_enDay)*)',
      (m, c, o, mid) =>
          c.setRecurrence(Recurrence.weekly(_enDays(m.group(1)!))),
    ),
    _Rule(
      '(?:moi|hang)\\s+($_viDay(?:\\s*(?:,|va|&)\\s*$_viDay)*)',
      (m, c, o, mid) =>
          c.setRecurrence(Recurrence.weekly(_viDays(m.group(1)!))),
    ),
    _Rule(
      '($_viDay(?:\\s*(?:,|va|&)\\s*$_viDay)*)\\s+(?:hang|moi)\\s+tuan',
      (m, c, o, mid) =>
          c.setRecurrence(Recurrence.weekly(_viDays(m.group(1)!))),
    ),
    _Rule(r'every\s+week|weekly|hang\s+tuan|moi\s+tuan', (m, c, o, mid) {
      return c.setUnitRecurrence('week', 1);
    }),
    _Rule(r'every\s+month|monthly|hang\s+thang|moi\s+thang', (m, c, o, mid) {
      return c.setUnitRecurrence('month', 1);
    }),
    _Rule(
      r'every\s+year|yearly|annually|hang\s+nam|moi\s+nam',
      (m, c, o, mid) => c.setUnitRecurrence('year', 1),
    ),

    // ---- lunar dates (before solar dates and times: "15/7 âm" isn't 15 July
    // and "7 âm" isn't 7 am)
    _Rule(r'(\d{1,2})/(\d{1,2})\s*(?:am\s+lich|am|al|lunar)', (m, c, o, mid) {
      final lower = o.toLowerCase();
      if (!lower.contains('âm') &&
          !lower.endsWith('al') &&
          !lower.contains('lunar')) {
        return false;
      }
      return c.setLunarDate(int.parse(m.group(1)!), int.parse(m.group(2)!));
    }),
    _Rule('ram(?:\\s+thang\\s+($_lunarMonth))?', (m, c, o, mid) {
      // "RAM" (memory) isn't "rằm"
      if (!o.toLowerCase().startsWith('rằm')) {
        return false;
      }
      return c.setLunarDate(15, _lunarMonthOf(m.group(1)));
    }),
    _Rule(r'(?:mung|mong)\s*(\d{1,2})'
        '(?:\\s+(tet)|\\s+thang\\s+($_lunarMonth))?', (m, c, o, mid) {
      final day = int.parse(m.group(1)!);
      if (day < 1 || day > 10) {
        return false;
      }
      final month = m.group(2) != null ? 1 : _lunarMonthOf(m.group(3));
      return c.setLunarDate(day, month);
    }),

    // ---- part of day + date ("tối nay", "sáng mai", "tonight")
    _Rule(r'tonight|toi\s+nay', (m, c, o, mid) {
      if (o.toLowerCase().startsWith('tôi')) {
        return false;
      }
      return c.setDate(c.today, defaultTime: 20 * 60);
    }),
    _Rule(r'(sang|trua|chieu|toi)\s+nay', (m, c, o, mid) {
      if (o.toLowerCase().startsWith('tôi')) {
        return false;
      }
      return c.setDate(c.today, defaultTime: _partOfDay[m.group(1)]);
    }),
    _Rule(
      '(sang|trua|chieu|toi)(?=\\s+(?:ngay\\s+mai|mai|$_viDay|ngay\\s+\\d))',
      (m, c, o, mid) {
        if (o.toLowerCase().startsWith('tôi') || c.defaultTime != null) {
          return false;
        }
        c.defaultTime = _partOfDay[m.group(1)];
        return true;
      },
    ),

    // ---- weekdays
    _Rule('(next|this|on|by)?\\s*($_enDay)', (m, c, o, mid) {
      final word = m.group(2)!;
      final prefix = m.group(1);
      // "sat", "sun", "wed" are also plain words → abbreviations need a prefix
      if (prefix == null && !_enFullDay.hasMatch(word)) {
        return false;
      }
      final day = _enDays(word).first;
      return c.setDate(
        prefix == 'next'
            ? Dates.addDays(Dates.startOfWeek(c.today), 7 + day - 1)
            : _nextWeekday(c.today, day),
      );
    }),
    _Rule('($_viDay)(\\s+tuan\\s+(?:sau|toi|nay))?', (m, c, o, mid) {
      final day = _viDays(m.group(1)!).first;
      final week = m.group(2)?.trim();
      final nextWeek = week != null && !week.endsWith('nay');
      return c.setDate(
        nextWeek
            ? Dates.addDays(Dates.startOfWeek(c.today), 7 + day - 1)
            : _nextWeekday(c.today, day),
      );
    }),

    // ---- relative dates
    _Rule(r'day\s+after\s+tomorrow|ngay\s+(?:kia|mot)', (m, c, o, mid) {
      return c.setDate(Dates.addDays(c.today, 2));
    }),
    _Rule(r'mot', (m, c, o, mid) {
      // Only "mốt" — not "một" (one)
      if (o.toLowerCase() != 'mốt' || mid) {
        return false;
      }
      return c.setDate(Dates.addDays(c.today, 2));
    }),
    _Rule(r'today|hom\s*nay', (m, c, o, mid) => c.setDate(c.today)),
    _Rule(r'tomorrow|tmrw?|ngay\s+mai', (m, c, o, mid) {
      return c.setDate(Dates.addDays(c.today, 1));
    }),
    _Rule(r'mai', (m, c, o, mid) {
      // "Gọi chị Mai" is a name, "mái" / "mãi" are other words
      if (o.toLowerCase() != 'mai' || mid) {
        return false;
      }
      return c.setDate(Dates.addDays(c.today, 1));
    }),
    _Rule(r'next\s+week|tuan\s+(?:sau|toi)', (m, c, o, mid) {
      return c.setDate(Dates.addDays(Dates.startOfWeek(c.today), 7));
    }),
    _Rule(r'next\s+month|thang\s+(?:sau|toi)', (m, c, o, mid) {
      return c.setDate(DateTime(c.today.year, c.today.month + 1));
    }),
    _Rule(
      r'(?:end\s+of\s+(?:the\s+)?month|cuoi\s+thang)',
      (m, c, o, mid) => c.setDate(
        DateTime(
          c.today.year,
          c.today.month,
          Dates.daysInMonth(c.today.year, c.today.month),
        ),
      ),
    ),
    _Rule(r'(?:this\s+)?weekend|cuoi\s+tuan', (m, c, o, mid) {
      return c.setDate(_nextWeekday(c.today, DateTime.saturday));
    }),
    _Rule(r'in\s+(\d{1,3})\s+(day|week|month)s?|'
        r'(?:sau\s+(\d{1,3})\s+(ngay|tuan|thang))|'
        r'(?:(\d{1,3})\s+(ngay|tuan|thang)\s+(?:nua|toi))', (m, c, o, mid) {
      final n = int.parse(m.group(1) ?? m.group(3) ?? m.group(5)!);
      final rawUnit = m.group(2) ?? m.group(4) ?? m.group(6)!;
      final unit = _viUnit[rawUnit] ?? rawUnit;
      final t = c.today;
      final date = switch (unit) {
        'day' => Dates.addDays(t, n),
        'week' => Dates.addDays(t, 7 * n),
        _ => DateTime(
          t.year,
          t.month + n,
          t.day.clamp(1, Dates.daysInMonth(t.year, t.month + n)),
        ),
      };
      return c.setDate(date);
    }),

    // ---- explicit dates
    // "20/11", "20/11/26"; dots/dashes only with a 4-digit year so "1-2 slides"
    // stays text
    _Rule(
      r'(\d{1,2})/(\d{1,2})(?:/(\d{2}|\d{4}))?|(\d{1,2})[.\-](\d{1,2})[.\-](\d{4})',
      (m, c, o, mid) {
        final a = int.parse(m.group(1) ?? m.group(4)!);
        final b = int.parse(m.group(2) ?? m.group(5)!);
        final year = m.group(3) ?? m.group(6);
        return c.setDayMonth(
          dayFirst ? a : b,
          dayFirst ? b : a,
          year == null ? null : _fullYear(int.parse(year)),
        );
      },
    ),
    _Rule(
      'ngay\\s+(\\d{1,2})(?:\\s+thang\\s+(\\d{1,2})(?:\\s+nam\\s+(\\d{4}))?)?',
      (m, c, o, mid) {
        final day = int.parse(m.group(1)!);
        final month = m.group(2);
        if (month == null) {
          return c.setDayOfMonth(day);
        }
        final year = m.group(3);
        return c.setDayMonth(
          day,
          int.parse(month),
          year == null ? null : int.parse(year),
        );
      },
    ),
    _Rule(
      '($_enMonth)\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?|'
      '(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?($_enMonth)(?:,?\\s+(\\d{4}))?',
      (m, c, o, mid) {
        final month = _monthOf(m.group(1) ?? m.group(5)!);
        final day = int.parse(m.group(2) ?? m.group(4)!);
        final year = m.group(3) ?? m.group(6);
        return c.setDayMonth(day, month, year == null ? null : int.parse(year));
      },
    ),

    // ---- times
    _Rule(r'noon|midday|giua\s+trua', (m, c, o, mid) => c.setTime(12, 0)),
    _Rule(r'midnight|nua\s+dem', (m, c, o, mid) => c.setTime(23, 59)),
    _Rule(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)', (m, c, o, mid) {
      var hour = int.parse(m.group(1)!);
      final minute = int.parse(m.group(2) ?? '0');
      if (hour < 1 || hour > 12) {
        return false;
      }
      final pm = m.group(3)!.startsWith('p');
      hour = hour % 12 + (pm ? 12 : 0);
      return c.setTime(hour, minute);
    }),
    _Rule(
      r'(?:luc\s+)?(\d{1,2})\s*(?:h|g|gio)\s*(?:(\d{1,2})\s*(?:p|phut)?|(ruoi|kem\s+15|kem\s+muoi\s+lam))?'
      r'(?:\s+(sang|trua|chieu|toi|dem))?',
      (m, c, o, mid) {
        if (o.toLowerCase().contains('tôi')) {
          return false;
        }
        var hour = int.parse(m.group(1)!);
        var minute = int.parse(m.group(2) ?? '0');
        final extra = m.group(3);
        if (extra == 'ruoi') {
          minute = 30;
        } else if (extra != null) {
          hour -= 1;
          minute = 45;
        }
        hour = _applyPartOfDay(hour, m.group(4));
        return c.setTime(hour, minute);
      },
    ),
    _Rule(r'(?:at\s+|luc\s+)?(\d{1,2}):(\d{2})', (m, c, o, mid) {
      return c.setTime(int.parse(m.group(1)!), int.parse(m.group(2)!));
    }),
    _Rule(r'luc\s+(\d{1,2})(?:\s+(sang|trua|chieu|toi|dem))?', (m, c, o, mid) {
      final hour = _applyPartOfDay(int.parse(m.group(1)!), m.group(2));
      return c.setTime(hour, 0);
    }),
  ];

  static int _applyPartOfDay(int hour, String? part) {
    switch (part) {
      case 'trua':
        return hour <= 2 ? hour + 12 : hour;
      case 'chieu':
        return hour < 12 ? hour + 12 : hour;
      case 'toi':
        return hour < 12 ? hour + 12 : hour;
      case 'dem':
        // "12h đêm" = midnight, "2h đêm" = 2am, "11h đêm" = 23h
        if (hour == 12) {
          return 0;
        }
        return hour >= 8 && hour < 12 ? hour + 12 : hour;
      default:
        return hour;
    }
  }

  static int _fullYear(int y) => y < 100 ? 2000 + y : y;

  /// "giêng" = 1st lunar month, "chạp" = 12th
  static const _lunarMonth = r'gieng|chap|\d{1,2}';

  static int? _lunarMonthOf(String? word) => switch (word) {
    null => null,
    'gieng' => 1,
    'chap' => 12,
    _ => int.tryParse(word),
  };

  static DateTime _nextWeekday(DateTime today, int weekday) {
    final diff = (weekday - today.weekday + 7) % 7;
    return Dates.addDays(today, diff);
  }

  // ---- vocabulary

  static const _enDay =
      r'(?:mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:r(?:s(?:day)?)?)?'
      r'|fri(?:day)?|sat(?:urday)?|sun(?:day)?)';
  static final _enFullDay = RegExp(
    r'^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)$',
  );
  static const _viDay =
      r'(?:(?:thu|t)\s*(?:[2-7]|hai|ba|tu|nam|sau|bay)|chu\s*nhat|cn)';
  static const _enMonth =
      r'(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?'
      r'|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';

  static const _viUnit = {
    'ngay': 'day',
    'tuan': 'week',
    'thang': 'month',
    'nam': 'year',
  };

  static const _partOfDay = {
    'sang': 9 * 60,
    'trua': 12 * 60,
    'chieu': 15 * 60,
    'toi': 20 * 60,
  };

  static Set<int> _enDays(String text) {
    final result = <int>{};
    for (final m in RegExp(_enDay).allMatches(text)) {
      final w = m.group(0)!;
      result.add(switch (w.substring(0, 2)) {
        'mo' => 1,
        'tu' => 2,
        'we' => 3,
        'th' => 4,
        'fr' => 5,
        'sa' => 6,
        _ => 7,
      });
    }
    return result;
  }

  static Set<int> _viDays(String text) {
    final result = <int>{};
    for (final m in RegExp(_viDay).allMatches(text)) {
      final w = m.group(0)!.replaceAll(RegExp(r'\s'), '');
      if (w.startsWith('chu') || w == 'cn') {
        result.add(7);
        continue;
      }
      final key = w.replaceFirst(RegExp('^(thu|t)'), '');
      final number = int.tryParse(key);
      result.add(
        number != null
            ? number - 1
            : const {
                'hai': 1,
                'ba': 2,
                'tu': 3,
                'nam': 4,
                'sau': 5,
                'bay': 6,
              }[key]!,
      );
    }
    return result;
  }

  static int _monthOf(String word) {
    const names = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    return names.indexOf(word.substring(0, 3)) + 1;
  }
}

typedef _Apply =
    bool Function(Match m, _Ctx c, String original, bool midSentence);

class _Rule {
  _Rule(String pattern, this.apply)
    : re = RegExp(
        '(?<![\\p{L}\\p{N}])(?:$pattern)(?![\\p{L}\\p{N}])',
        unicode: true,
      );

  final RegExp re;
  final _Apply apply;
}

class _Ctx {
  _Ctx(this.today, this.now, this.input);

  final DateTime today;
  final DateTime now;

  /// The whole original text ("giỗ" makes a lunar date yearly)
  final String input;

  /// Set by lunar dates ("rằm", "mùng 1", "10/3 âm"), so "hằng tháng" /
  /// "hằng năm" repeat by the lunar calendar
  int? lunarDay;
  int? lunarMonth;
  DateTime? date;
  int? time;
  int? defaultTime;
  Recurrence? recurrence;
  String? pendingUnit;
  int pendingInterval = 1;
  int priority = 0;

  bool setPriority(int value) {
    if (priority != 0) {
      return false;
    }
    priority = value;
    return true;
  }

  bool setRecurrence(Recurrence value) {
    if (recurrence != null || pendingUnit != null) {
      return false;
    }
    recurrence = value;
    return true;
  }

  /// Unit recurrences ("every 2 weeks") are anchored on the parsed date later
  bool setUnitRecurrence(String unit, int interval) {
    if (recurrence != null || pendingUnit != null) {
      return false;
    }
    pendingUnit = unit;
    pendingInterval = interval;
    return true;
  }

  bool setDate(DateTime value, {int? defaultTime}) {
    if (date != null) {
      return false;
    }
    date = value;
    if (defaultTime != null) {
      this.defaultTime ??= defaultTime;
    }
    return true;
  }

  bool setTime(int hour, int minute) {
    if (time != null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return false;
    }
    time = hour * 60 + minute;
    return true;
  }

  bool setDayMonth(int day, int month, int? year) {
    if (month < 1 || month > 12 || day < 1) {
      return false;
    }
    var y = year ?? today.year;
    if (day > Dates.daysInMonth(y, month)) {
      return false;
    }
    var candidate = DateTime(y, month, day);
    if (year == null && candidate.isBefore(today)) {
      y += 1;
      if (day > Dates.daysInMonth(y, month)) {
        return false;
      }
      candidate = DateTime(y, month, day);
    }
    return setDate(candidate);
  }

  /// Next lunar [day] (of lunar [month], or of any month) on or after today
  bool setLunarDate(int day, int? month) {
    if (date != null || day < 1 || day > 30) {
      return false;
    }
    if (month != null && (month < 1 || month > 12)) {
      return false;
    }
    lunarDay = day;
    lunarMonth = month;
    return setDate(
      (month == null
              ? Recurrence.lunarMonthly(day)
              : Recurrence.lunarYearly(month, day))
          .firstOnOrAfter(today),
    );
  }

  bool setDayOfMonth(int day) {
    if (day < 1 || day > 31) {
      return false;
    }
    var year = today.year;
    var month = today.month;
    if (day < today.day) {
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
    }
    final clamped = day.clamp(1, Dates.daysInMonth(year, month));
    return setDate(DateTime(year, month, clamped));
  }

  QuickAddResult build(String title, List<(int, int)> spans) {
    var rec = recurrence;
    var due = date;
    final unit = pendingUnit;
    final lDay = lunarDay;
    final lMonth = lunarMonth;
    if (unit != null && lDay != null && (unit == 'month' || lMonth != null)) {
      // "rằm hằng tháng", "15/7 âm hằng năm"
      rec = unit == 'month'
          ? Recurrence.lunarMonthly(lDay, interval: pendingInterval)
          : Recurrence.lunarYearly(lMonth!, lDay, interval: pendingInterval);
    } else if (rec == null &&
        unit == null &&
        lDay != null &&
        lMonth != null &&
        input.toLowerCase().contains('giỗ')) {
      // A death anniversary comes back every year
      rec = Recurrence.lunarYearly(lMonth, lDay);
    } else if (unit != null) {
      final anchor = due ?? today;
      rec = switch (unit) {
        'day' => Recurrence.daily(interval: pendingInterval),
        'week' => Recurrence.weekly({
          anchor.weekday,
        }, interval: pendingInterval),
        'month' => Recurrence.monthly(anchor.day, interval: pendingInterval),
        _ => Recurrence.yearly(
          anchor.month,
          anchor.day,
          interval: pendingInterval,
        ),
      };
    }
    if (rec != null) {
      due = rec.firstOnOrAfter(due ?? today);
    }
    final t = time ?? defaultTime;
    if (due == null && time != null) {
      // "9pm" alone → today if still ahead, otherwise tomorrow
      final todayAt = Dates.atMinutes(today, time!);
      due = todayAt.isAfter(now) ? today : Dates.addDays(today, 1);
    }
    return QuickAddResult(
      title: title,
      date: due,
      time: due == null ? null : t,
      recurrence: rec,
      priority: priority,
      spans: spans,
    );
  }
}

/// Lowercased, diacritic-free view of a string with an index map back to it
class _Normalized {
  _Normalized(String input) {
    final buffer = StringBuffer();
    final map = <int>[];
    for (var i = 0; i < input.length; i++) {
      final unit = input.codeUnitAt(i);
      // Combining diacritics (NFD input) are dropped
      if (unit >= 0x0300 && unit <= 0x036F) {
        continue;
      }
      var ch = String.fromCharCode(unit);
      final lower = ch.toLowerCase();
      if (lower.length == 1) {
        ch = lower;
      }
      ch = _fold[ch] ?? ch;
      buffer.write(ch);
      map.add(i);
    }
    text = buffer.toString();
    _map = map..add(input.length);
  }

  late final String text;
  late final List<int> _map;

  int originalIndex(int normalizedIndex) => _map[normalizedIndex];

  static final Map<String, String> _fold = () {
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    return {
      for (final entry in groups.entries)
        for (final ch in entry.value.split('')) ch: entry.key,
    };
  }();
}
