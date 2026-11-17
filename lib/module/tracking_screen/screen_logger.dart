import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticLogger {
  AnalyticLogger._();

  static final AnalyticLogger instance = AnalyticLogger._();

  /// Analytics must never break a screen: without Firebase (tests, a
  /// failed init) this does nothing.
  Future<void> logScreen(String name) async {
    try {
      await FirebaseAnalytics.instance.logScreenView(
        screenName: name,
        screenClass: name,
      );
    } on Object {
      // No Firebase app, or the platform refused: skip
    }
  }
}
