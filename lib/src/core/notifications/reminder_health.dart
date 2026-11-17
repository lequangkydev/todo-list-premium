import 'dart:io';

import 'package:flutter/services.dart';

import '../../shared/helpers/logger_utils.dart';

/// Phone makers whose battery savers are known to kill or delay reminders
/// (see dontkillmyapp.com), and what to do about each.
enum Oem {
  xiaomi('xiaomi', autostart: true, lockInRecents: true),
  huawei('huawei', autostart: true, lockInRecents: true),
  honor('huawei', autostart: true, lockInRecents: true),
  oppo('oppo', autostart: true, lockInRecents: true),
  realme('realme', autostart: true, lockInRecents: true),
  oneplus('oneplus', autostart: true, lockInRecents: true),
  vivo('vivo', autostart: true, lockInRecents: true),
  samsung('samsung', autostart: true),
  asus('asus', autostart: true),
  other('');

  const Oem(this.guide, {this.autostart = false, this.lockInRecents = false});

  /// Page on dontkillmyapp.com with illustrated steps
  final String guide;

  /// How the maker writes its name
  String get displayName => switch (this) {
    xiaomi => 'Xiaomi',
    huawei => 'HUAWEI',
    honor => 'HONOR',
    oppo => 'OPPO',
    realme => 'realme',
    oneplus => 'OnePlus',
    vivo => 'vivo',
    samsung => 'Samsung',
    asus => 'ASUS',
    other => '',
  };

  /// Has an "auto-start" / background-activity page to allow the app on
  final bool autostart;

  /// Clears apps swiped from recents unless they are locked there
  final bool lockInRecents;

  Uri get guideUrl => Uri.parse('https://dontkillmyapp.com/$guide');

  static Oem of(String manufacturer, [String brand = '']) {
    final names = '${manufacturer.toLowerCase()} ${brand.toLowerCase()}';
    bool has(List<String> keys) => keys.any(names.contains);
    if (has(['xiaomi', 'redmi', 'poco'])) {
      return xiaomi;
    }
    if (has(['honor'])) {
      return honor;
    }
    if (has(['huawei'])) {
      return huawei;
    }
    if (has(['oneplus'])) {
      return oneplus;
    }
    if (has(['realme'])) {
      return realme;
    }
    if (has(['oppo'])) {
      return oppo;
    }
    if (has(['vivo', 'iqoo'])) {
      return vivo;
    }
    if (has(['samsung'])) {
      return samsung;
    }
    if (has(['asus'])) {
      return asus;
    }
    return other;
  }
}

/// What can stop reminders from arriving on this phone
class DeviceReminderInfo {
  const DeviceReminderInfo({
    required this.oem,
    required this.brandName,
    required this.batteryOptimized,
    required this.fullScreenAllowed,
  });

  /// iOS, or the platform channel failed: nothing Android-specific to fix
  static const none = DeviceReminderInfo(
    oem: Oem.other,
    brandName: '',
    batteryOptimized: false,
    fullScreenAllowed: true,
  );

  final Oem oem;

  /// As the phone calls itself, for "On your Xiaomi…"
  final String brandName;

  /// The system may defer the app's alarms to save battery
  final bool batteryOptimized;

  /// Android 14+: alarm-style reminders may open full screen
  final bool fullScreenAllowed;
}

/// Android settings that decide whether reminders arrive on time
class ReminderHealth {
  ReminderHealth._();

  static const _channel = MethodChannel('todolist/reminders');

  static Future<DeviceReminderInfo> read() async {
    if (!Platform.isAndroid) {
      return DeviceReminderInfo.none;
    }
    try {
      final info = await _channel.invokeMapMethod<String, Object?>('info');
      if (info == null) {
        return DeviceReminderInfo.none;
      }
      final manufacturer = info['manufacturer'] as String? ?? '';
      final brand = info['brand'] as String? ?? '';
      final oem = Oem.of(manufacturer, brand);
      return DeviceReminderInfo(
        oem: oem,
        brandName: oem == Oem.other
            ? _title(brand.isEmpty ? manufacturer : brand)
            : oem.displayName,
        batteryOptimized: info['batteryOptimized'] as bool? ?? false,
        fullScreenAllowed: info['fullScreenAllowed'] as bool? ?? true,
      );
    } on PlatformException catch (e) {
      logger.e(e);
      return DeviceReminderInfo.none;
    } on MissingPluginException {
      return DeviceReminderInfo.none;
    }
  }

  static Future<void> openBatterySettings() => _call('openBatterySettings');

  static Future<void> openAutostart() => _call('openAutostart');

  /// Closes the over-the-lock-screen state an alarm reminder opened with
  static Future<void> releaseLockScreen() => _call('releaseLockScreen');

  static Future<void> _call(String method) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<Object?>(method);
    } on PlatformException catch (e) {
      logger.e(e);
    } on MissingPluginException {
      // Tests, or an engine without the channel (background isolate)
    }
  }

  static String _title(String name) =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}
