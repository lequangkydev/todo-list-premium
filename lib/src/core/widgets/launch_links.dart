import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../shared/helpers/logger_utils.dart';

/// Links into the app from outside it: home-screen widgets, the Android
/// Quick Settings tile and app-icon shortcuts. Home consumes [pending] once
/// it is on screen, so links that arrive during splash/onboarding wait.
///
/// - `todolist://quickadd` — open the quick-add sheet
/// - `todolist://task?id=…` — open that task
/// - `todolist://today` — show the Today tab
/// - `todolist://alarm?id=…` — an alarm-style reminder rang: full screen
/// - `todolist://snooze?id=…` — "Snooze…" on a notification: pick when
/// - `todolist://focus` — the focus timer
class LaunchLinks {
  LaunchLinks._();

  static final LaunchLinks instance = LaunchLinks._();

  static const scheme = 'todolist';
  static final quickAdd = Uri.parse('$scheme://quickadd');
  static final today = Uri.parse('$scheme://today');
  static final focus = Uri.parse('$scheme://focus');

  static Uri task(String id) => Uri.parse('$scheme://task?id=$id');

  static Uri alarm(String id) => Uri.parse('$scheme://alarm?id=$id');

  static Uri snooze(String id) => Uri.parse('$scheme://snooze?id=$id');

  final pending = ValueNotifier<Uri?>(null);
  StreamSubscription<Uri?>? _sub;

  void open(Uri uri) {
    if (uri.scheme == scheme) {
      pending.value = uri;
    }
  }

  /// Takes the pending link, so it's handled once
  Uri? take() {
    final uri = pending.value;
    pending.value = null;
    return uri;
  }

  Future<void> start() async {
    if (_sub != null) {
      return;
    }
    try {
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initial != null) {
        open(initial);
      }
      _sub = HomeWidget.widgetClicked.listen((uri) {
        if (uri != null) {
          open(uri);
        }
      });
    } on Exception catch (e) {
      logger.e(e);
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
