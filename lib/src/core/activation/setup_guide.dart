import 'dart:async';
import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:injectable/injectable.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/task_repository.dart';
import '../../shared/helpers/logger_utils.dart';
import '../analytics/app_events.dart';
import '../notifications/reminder_service.dart';

/// The three things that make the app worth coming back to
enum SetupStep { task, notifications, widget }

/// Which getting-started steps are done
@immutable
class SetupState {
  const SetupState({
    this.hasTask = false,
    this.notificationsOn = false,
    this.hasWidget = false,
    this.hidden = true,
  });

  final bool hasTask;
  final bool notificationsOn;
  final bool hasWidget;

  /// Dismissed by the user, finished, or not loaded yet
  final bool hidden;

  bool isDone(SetupStep step) => switch (step) {
    SetupStep.task => hasTask,
    SetupStep.notifications => notificationsOn,
    SetupStep.widget => hasWidget,
  };

  int get doneCount => SetupStep.values.where(isDone).length;

  bool get allDone => doneCount == SetupStep.values.length;

  /// Show the card: something is left to do and the user hasn't hidden it
  bool get visible => !hidden && !allDone;

  SetupState copyWith({
    bool? hasTask,
    bool? notificationsOn,
    bool? hasWidget,
    bool? hidden,
  }) => SetupState(
    hasTask: hasTask ?? this.hasTask,
    notificationsOn: notificationsOn ?? this.notificationsOn,
    hasWidget: hasWidget ?? this.hasWidget,
    hidden: hidden ?? this.hidden,
  );

  @override
  bool operator ==(Object other) =>
      other is SetupState &&
      other.hasTask == hasTask &&
      other.notificationsOn == notificationsOn &&
      other.hasWidget == hasWidget &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(hasTask, notificationsOn, hasWidget, hidden);
}

/// Getting started, on the Today tab: add a first task, turn notifications
/// on (reminders and the morning summary need them), put the widget on the
/// home screen. Each step ticks itself off; the card goes away for good
/// once all are done or the user hides it.
@lazySingleton
class SetupGuide with WidgetsBindingObserver {
  SetupGuide(this._tasks, this._reminders);

  final TaskRepository _tasks;
  final ReminderService _reminders;

  static const _hiddenKey = 'setup_hidden';
  static const _firstTaskKey = 'setup_first_task';
  static const _stepsKey = 'setup_steps_logged';

  /// Android class of the Today widget, for the "add widget" dialog
  static const todayWidget = 'com.vtn.todolist.widget.TodayWidgetReceiver';

  final state = ValueNotifier<SetupState>(const SetupState());

  StreamSubscription<bool>? _sub;
  Future<void> _queue = Future.value();
  bool _started = false;

  /// Replaceable in tests, where neither plugin has a platform
  @visibleForTesting
  Future<bool> Function() notificationsEnabled = _unset;

  @visibleForTesting
  Future<int> Function() installedWidgets = _countWidgets;

  static Future<bool> _unset() async => false;

  static Future<int> _countWidgets() async {
    try {
      return (await HomeWidget.getInstalledWidgets()).length;
    } on Exception catch (e) {
      logger.e(e);
      return 0;
    }
  }

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    if (notificationsEnabled == _unset) {
      notificationsEnabled = _reminders.notificationsEnabled;
    }
    final prefs = await SharedPreferences.getInstance();
    state.value = state.value.copyWith(
      hidden: prefs.getBool(_hiddenKey) ?? false,
    );
    WidgetsBinding.instance.addObserver(this);
    _sub = _tasks.watchHasAnyTask().listen((has) {
      unawaited(_update((s) => s.copyWith(hasTask: has)));
    });
    final widgets = await installedWidgets();
    AppEvents.widgetsInstalled(widgets);
    await refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the permission dialog, settings, or the home screen
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  /// Re-reads what only the system knows: permission and widgets
  Future<void> refresh() async {
    final on = await notificationsEnabled();
    final widgets = await installedWidgets();
    await _update(
      (s) => s.copyWith(notificationsOn: on, hasWidget: widgets > 0),
    );
  }

  /// Changes are applied one after another, each to the latest state, so
  /// a task arriving while the permission is being read isn't lost
  Future<void> _update(SetupState Function(SetupState) change) =>
      _queue = _queue.then((_) => _apply(change(state.value)));

  Future<void> _apply(SetupState next) async {
    final prefs = await SharedPreferences.getInstance();
    if (next.hasTask && !(prefs.getBool(_firstTaskKey) ?? false)) {
      await prefs.setBool(_firstTaskKey, true);
      AppEvents.firstTask();
    }
    // Each step is reported once, the first time it is seen done
    final logged = prefs.getStringList(_stepsKey) ?? const [];
    final newlyDone = [
      for (final step in SetupStep.values)
        if (next.isDone(step) && !logged.contains(step.name)) step.name,
    ];
    if (newlyDone.isNotEmpty) {
      await prefs.setStringList(_stepsKey, [...logged, ...newlyDone]);
      newlyDone.forEach(AppEvents.setupStep);
    }
    var result = next;
    if (next.allDone && !next.hidden) {
      // Finished: don't come back if the widget is removed later
      await prefs.setBool(_hiddenKey, true);
      AppEvents.setupDone();
      result = next.copyWith(hidden: true);
    }
    state.value = result;
  }

  Future<void> dismiss() async {
    AppEvents.setupDismissed(state.value.doneCount);
    state.value = state.value.copyWith(hidden: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hiddenKey, true);
  }

  /// Asks for notifications; when the system won't ask again, opens its
  /// settings page instead
  Future<void> turnOnNotifications() async {
    await _reminders.requestNotifications();
    if (!await _reminders.notificationsEnabled()) {
      await _reminders.openNotificationSettings();
    }
    await refresh();
  }

  /// Android launchers that support it show their own "add widget" dialog.
  /// Returns false when the user has to add it by hand (iOS, other
  /// launchers) — show them how.
  Future<bool> requestWidget() async {
    AppEvents.widgetPinRequested();
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() ?? false) {
        await HomeWidget.requestPinWidget(qualifiedAndroidName: todayWidget);
        return true;
      }
    } on Exception catch (e) {
      logger.e(e);
    }
    return false;
  }

  @disposeMethod
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _sub?.cancel();
  }
}
