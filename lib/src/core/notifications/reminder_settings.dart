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

  final digest = ValueNotifier<DigestSetting>((
    on: true,
    minutes: defaultMinutes,
  ));

  Future<void> load() async {
    digest.value = await read();
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
