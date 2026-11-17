import '../date/dates.dart';

/// "Remind me again" choices, on notifications and in the app
enum SnoozeOption {
  tenMinutes('snooze10'),
  oneHour('snooze60'),
  tonight('snoozeTonight'),
  tomorrowMorning('snoozeMorning');

  const SnoozeOption(this.actionId);

  /// Notification action id
  final String actionId;

  /// "Tonight" means this time
  static const tonightMinutes = 19 * 60;

  /// Default "tomorrow morning"; the morning summary time when it is on
  static const morningMinutes = 8 * 60;

  /// When the reminder comes back if chosen at [now]
  DateTime until(DateTime now, {int morning = morningMinutes}) {
    final minute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return switch (this) {
      tenMinutes => minute.add(const Duration(minutes: 10)),
      oneHour => minute.add(const Duration(hours: 1)),
      tonight => Dates.atMinutes(Dates.dateOnly(now), tonightMinutes),
      tomorrowMorning => Dates.atMinutes(
        Dates.addDays(Dates.dateOnly(now), 1),
        morning,
      ),
    };
  }

  /// The choices that make sense at [now]: "tonight" only until an hour
  /// before it (after that, "1 hour" says the same)
  static List<SnoozeOption> availableAt(DateTime now) => [
    tenMinutes,
    oneHour,
    if (now.hour * 60 + now.minute < tonightMinutes - 60) tonight,
    tomorrowMorning,
  ];

  static SnoozeOption? ofAction(String? actionId) {
    for (final option in values) {
      if (option.actionId == actionId) {
        return option;
      }
    }
    // "Snooze 1 hour" on notifications posted before there were choices
    return actionId == 'snooze' ? oneHour : null;
  }
}
