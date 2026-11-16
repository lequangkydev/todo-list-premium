import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/date/dates.dart';
import '../../core/recurrence/recurrence.dart';
import '../../data/local/database/app_database.dart';
import '../../gen/l18n/app_localizations.dart';

/// Human labels for dates, times, repeats and reminders
class TaskFormat {
  TaskFormat._();

  static String _locale(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag();

  /// "Today", "Tomorrow", "Monday", "20 Nov", "20 Nov 2027"
  static String day(BuildContext context, DateTime date, DateTime today) {
    final l10n = AppLocalizations.of(context);
    final diff = Dates.daysBetween(today, date);
    final locale = _locale(context);
    if (diff == 0) {
      return l10n.today;
    }
    if (diff == 1) {
      return l10n.tomorrow;
    }
    if (diff == -1) {
      return l10n.yesterday;
    }
    if (diff > 1 && diff < 7) {
      return toBeginningOfSentenceCase(DateFormat.EEEE(locale).format(date));
    }
    if (date.year == today.year) {
      return DateFormat.MMMd(locale).format(date);
    }
    return DateFormat.yMMMd(locale).format(date);
  }

  /// Compact header date, e.g. "Sat, 14 Nov"
  static String shortDay(BuildContext context, DateTime date) {
    return toBeginningOfSentenceCase(
      DateFormat.MMMEd(_locale(context)).format(date),
    );
  }

  /// Long header, e.g. "Saturday, 14 Nov"
  static String longDay(BuildContext context, DateTime date) {
    return toBeginningOfSentenceCase(
      DateFormat.MMMMEEEEd(_locale(context)).format(date),
    );
  }

  static String time(BuildContext context, int minutes) {
    final media = MediaQuery.maybeOf(context);
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      alwaysUse24HourFormat: media?.alwaysUse24HourFormat ?? false,
    );
  }

  /// "Tomorrow 17:00" / "Today"
  static String due(BuildContext context, Task task, DateTime today) {
    final date = task.dueDate;
    if (date == null) {
      return '';
    }
    final label = day(context, date, today);
    final t = task.dueTime;
    return t == null ? label : '$label ${time(context, t)}';
  }

  static String recurrence(BuildContext context, Recurrence r) {
    final l10n = AppLocalizations.of(context);
    final locale = _locale(context);
    switch (r.frequency) {
      case Frequency.daily:
        return r.interval == 1
            ? l10n.repeatDaily
            : l10n.repeatEveryNDays(r.interval);
      case Frequency.weekly:
        if (r.isWeekdaysOnly) {
          return l10n.repeatWeekdays;
        }
        final days = (r.weekdays.toList()..sort())
            .map(
              // 2024-01-01 was a Monday
              (d) => DateFormat.E(locale).format(DateTime(2024, 1, d)),
            )
            .join(', ');
        return r.interval == 1
            ? l10n.repeatWeeklyOn(days)
            : l10n.repeatEveryNWeeksOn(r.interval, days);
      case Frequency.monthly:
        if (r.isLastDayOfMonth) {
          return l10n.repeatLastDayOfMonth;
        }
        final dayOfMonth = r.monthDay ?? 1;
        return r.interval == 1
            ? l10n.repeatMonthlyOnDay(dayOfMonth)
            : l10n.repeatEveryNMonthsOnDay(r.interval, dayOfMonth);
      case Frequency.yearly:
        final date = DateTime(2024, r.month ?? 1, r.monthDay ?? 1);
        return l10n.repeatYearlyOn(DateFormat.MMMd(locale).format(date));
    }
  }

  static String reminder(AppLocalizations l10n, int offset) {
    if (offset == 0) {
      return l10n.reminderAtTime;
    }
    if (offset % 1440 == 0) {
      return l10n.reminderDaysBefore(offset ~/ 1440);
    }
    if (offset % 60 == 0) {
      return l10n.reminderHoursBefore(offset ~/ 60);
    }
    return l10n.reminderMinutesBefore(offset);
  }

  static String priority(AppLocalizations l10n, int priority) =>
      switch (priority) {
        1 => l10n.priorityLow,
        2 => l10n.priorityMedium,
        3 => l10n.priorityHigh,
        _ => l10n.priorityNone,
      };
}
