import 'package:intl/intl.dart';

import '../../data/local/database/converters.dart';
import '../../gen/l18n/app_localizations.dart';
import '../../shared/helpers/task_format.dart';
import '../date/dates.dart';
import '../lunar/festivals.dart';
import '../lunar/lunar_calendar.dart';

/// What the lunar-calendar widget shows, written by the app as JSON.
///
/// The widget can't compute the lunar calendar itself, and must change at
/// midnight without the app running — so the app writes a table of the
/// coming [days], every label already translated, and the widget looks up
/// today's row. Opening the app (or any background re-plan) extends it.
class LunarWidgetSnapshot {
  LunarWidgetSnapshot._();

  static const key = 'lunar_snapshot';

  /// About four months ahead
  static const days = 120;

  static Map<String, Object?> build({
    required DateTime today,
    required AppLocalizations l10n,
    required String locale,
    int days = days,
  }) {
    final weekday = DateFormat.EEEE(locale);
    final month = DateFormat.yMMMM(locale);
    // The year's name (Bính Ngọ…) only reads naturally in Vietnamese
    final vietnamese = locale.startsWith('vi');
    const date = LocalDateConverter();
    final start = Dates.dateOnly(today);
    return {
      'v': 1,
      'title': l10n.lunarCalendar,
      'days': {
        for (var i = 0; i < days; i++)
          date.toSql(Dates.addDays(start, i)): _day(
            Dates.addDays(start, i),
            l10n,
            weekday,
            month,
            vietnamese: vietnamese,
          ),
      },
    };
  }

  static Map<String, Object?> _day(
    DateTime day,
    AppLocalizations l10n,
    DateFormat weekday,
    DateFormat month, {
    required bool vietnamese,
  }) {
    final lunar = LunarDate.fromSolar(day);
    final festival = LunarFestival.of(lunar);
    return {
      'd': day.day,
      'w': toBeginningOfSentenceCase(weekday.format(day)),
      'm': toBeginningOfSentenceCase(month.format(day)),
      'l': TaskFormat.lunar(l10n, day),
      'f': ?(festival == null ? null : TaskFormat.festival(l10n, festival)),
      if (vietnamese) 'y': 'Năm ${LunarCalendar.canChiYear(lunar.year)}',
    };
  }
}
