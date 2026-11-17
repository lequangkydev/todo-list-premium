import 'package:flutter/services.dart';

import '../../config/di/di.dart';
import '../cubit/haptics_cubit.dart';

/// The app's only entry point for haptics, so the Settings switch covers
/// every one of them. Keep it subtle: one light tap per meaningful moment.
class AppHaptics {
  AppHaptics._();

  static bool get _on => getIt<HapticsCubit>().state;

  /// Picking something up, a segment or chip changing
  static Future<void> selection() async {
    if (_on) {
      await HapticFeedback.selectionClick();
    }
  }

  /// A task completed, a swipe crossing its threshold
  static Future<void> light() async {
    if (_on) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Rare, bigger moments — everything done for today
  static Future<void> medium() async {
    if (_on) {
      await HapticFeedback.mediumImpact();
    }
  }
}
