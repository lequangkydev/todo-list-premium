import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Morning summary preferences. Kept in SharedPreferences (not a hydrated
/// cubit) so the background isolate that handles notification actions and
/// widget taps plans with the same values.
typedef DigestSetting = ({bool on, int minutes});

@lazySingleton
class ReminderSettings {
  static const _onKey = 'digest_on';
  static const _minutesKey = 'digest_minutes';
  static const defaultMinutes = 8 * 60;
  static const _eveningOnKey = 'evening_on';
  static const _eveningMinutesKey = 'evening_minutes';
  static const defaultEveningMinutes = 20 * 60 + 30;
  static const _weeklyKey = 'weekly_on';

  final digest = ValueNotifier<DigestSetting>((
    on: true,
    minutes: defaultMinutes,
  ));

  /// The evening look at tomorrow
  final evening = ValueNotifier<DigestSetting>((
    on: true,
    minutes: defaultEveningMinutes,
  ));

  /// The Sunday recap
  final weekly = ValueNotifier<bool>(true);

  Future<void> load() async {
    digest.value = await read();
    evening.value = await readEvening();
    weekly.value = await readWeekly();
  }

  static Future<DigestSetting> readEvening() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      on: prefs.getBool(_eveningOnKey) ?? true,
      minutes: prefs.getInt(_eveningMinutesKey) ?? defaultEveningMinutes,
    );
  }

  static Future<bool> readWeekly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_weeklyKey) ?? true;
  }

  Future<void> setEvening({bool? on, int? minutes}) async {
    final next = (
      on: on ?? evening.value.on,
      minutes: minutes ?? evening.value.minutes,
    );
    evening.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eveningOnKey, next.on);
    await prefs.setInt(_eveningMinutesKey, next.minutes);
  }

  Future<void> setWeekly({required bool on}) async {
    weekly.value = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weeklyKey, on);
  }

  static Future<DigestSetting> read() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      on: prefs.getBool(_onKey) ?? true,
      minutes: prefs.getInt(_minutesKey) ?? defaultMinutes,
    );
  }

  /// Minutes after midnight of the morning summary, or null when it's off
  static Future<int?> digestMinutes() async {
    final setting = await read();
    return setting.on ? setting.minutes : null;
  }

  Future<void> setDigest({bool? on, int? minutes}) async {
    final next = (
      on: on ?? digest.value.on,
      minutes: minutes ?? digest.value.minutes,
    );
    digest.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onKey, next.on);
    await prefs.setInt(_minutesKey, next.minutes);
  }
}
