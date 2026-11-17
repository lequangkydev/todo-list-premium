import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../config/theme/palette.dart';
import '../../data/repositories/focus_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../gen/l18n/app_localizations.dart';
import '../../shared/cubit/language_cubit.dart';
import '../../shared/enum/language.dart';
import '../../shared/helpers/logger_utils.dart';
import '../analytics/app_events.dart';
import '../notifications/reminder_planner.dart';
import 'focus_timer.dart';

typedef FocusSettings = ({int focus, int rest});

/// Notification ids the focus timer owns; re-planning reminders leaves
/// them alone
final focusNotificationIds = {_ongoingId, _endId};
final _ongoingId = ReminderPlanner.notificationIdOf('focus:ongoing');
final _endId = ReminderPlanner.notificationIdOf('focus:end');

const _channelTimer = 'focus_timer';
const _channelDone = 'focus_done';

/// Runs the focus timer: keeps its state across app restarts, records
/// finished blocks, and tells the user when a block or break is over —
/// with a countdown notification while it runs on Android.
@lazySingleton
class FocusService with WidgetsBindingObserver {
  FocusService(this._repo, this._tasks, this._language);

  final FocusRepository _repo;
  final TaskRepository _tasks;
  final LanguageCubit _language;
  final _plugin = FlutterLocalNotificationsPlugin();

  static const focusChoices = [15, 20, 25, 30, 45, 50, 60, 90];
  static const restChoices = [3, 5, 10, 15, 20];
  static const _stateKey = 'focus_state';
  static const _focusKey = 'focus_minutes';
  static const _restKey = 'rest_minutes';

  final state = ValueNotifier<FocusState>(FocusState.idle);
  final settings = ValueNotifier<FocusSettings>((focus: 25, rest: 5));

  /// Title of the task being focused on, for the screen and notification
  final taskTitle = ValueNotifier<String?>(null);

  Timer? _endTimer;
  bool _started = false;

  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// Off in tests, where the notification plugin has no platform
  @visibleForTesting
  bool notifications = true;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    final prefs = await SharedPreferences.getInstance();
    settings.value = (
      focus: prefs.getInt(_focusKey) ?? 25,
      rest: prefs.getInt(_restKey) ?? 5,
    );
    final saved = prefs.getString(_stateKey);
    var restored = FocusState.idle;
    if (saved != null) {
      try {
        restored = FocusState.fromJson(
          jsonDecode(saved) as Map<String, Object?>,
        );
      } on FormatException {
        restored = FocusState.idle;
      }
    }
    WidgetsBinding.instance.addObserver(this);
    // A block may have finished while the app was closed
    await _apply(FocusTimer.tick(restored, clock()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_tick());
    }
  }

  Future<void> startFocus({String? taskId, int? minutes}) {
    final length = minutes ?? settings.value.focus;
    AppEvents.focusStarted(withTask: taskId != null, minutes: length);
    return _apply((
      state: FocusTimer.start(clock(), minutes: length, taskId: taskId),
      record: null,
    ));
  }

  Future<void> pause() =>
      _apply((state: FocusTimer.pause(state.value, clock()), record: null));

  Future<void> resume() =>
      _apply((state: FocusTimer.resume(state.value, clock()), record: null));

  Future<void> startBreak() => _apply((
    state: FocusTimer.startBreak(clock(), minutes: settings.value.rest),
    record: null,
  ));

  /// Another focus block for the same task
  Future<void> focusAgain() => startFocus(taskId: state.value.taskId);

  Future<void> stop() => _apply(FocusTimer.stop(state.value, clock()));

  Future<void> setSettings({int? focus, int? rest}) async {
    settings.value = (
      focus: focus ?? settings.value.focus,
      rest: rest ?? settings.value.rest,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_focusKey, settings.value.focus);
    await prefs.setInt(_restKey, settings.value.rest);
  }

  Future<void> _tick() => _apply(FocusTimer.tick(state.value, clock()));

  Future<void> _apply(FocusStep step) async {
    final changed = step.state != state.value;
    state.value = step.state;
    final record = step.record;
    if (record != null) {
      await _repo.add(record);
      AppEvents.focusRecorded(
        minutes: record.focusMinutes,
        completed: record.completed,
      );
    }
    await _loadTitle(step.state.taskId);
    _endTimer?.cancel();
    final ends = step.state.endsAt;
    if (step.state.running && ends != null) {
      _endTimer = Timer(ends.difference(clock()), () => unawaited(_tick()));
    }
    if (changed) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_stateKey, jsonEncode(step.state.toJson()));
    }
    await _updateNotifications(step.state);
  }

  Future<void> _loadTitle(String? taskId) async {
    if (taskId == null) {
      taskTitle.value = null;
      return;
    }
    taskTitle.value = (await _tasks.getTask(taskId))?.title;
  }

  // ---------------------------------------------------------- notifications

  AppLocalizations get _l10n => lookupAppLocalizations(_language.state.locale);

  Future<void> _updateNotifications(FocusState s) async {
    if (!notifications) {
      return;
    }
    try {
      final l10n = _l10n;
      if (Platform.isAndroid) {
        await _ongoing(s, l10n);
      }
      await _plugin.cancel(id: _endId);
      final ends = s.endsAt;
      if (s.running && ends != null) {
        await _plugin.zonedSchedule(
          id: _endId,
          scheduledDate: tz.TZDateTime.from(ends, tz.local),
          title: s.phase == FocusPhase.rest
              ? l10n.focusRestOverTitle
              : l10n.focusOverTitle,
          body: s.phase == FocusPhase.rest
              ? l10n.focusRestOverBody
              : (taskTitle.value ?? l10n.focusOverBody),
          payload: jsonEncode({'open': 'focus'}),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channelDone,
              l10n.focusOverTitle,
              importance: Importance.high,
              priority: Priority.high,
              color: Palette.primary,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    } on Exception catch (e) {
      // No notification plugin (tests) or permission: the screen still works
      logger.e(e);
    }
  }

  /// Android: a quiet notification counting down while the timer runs
  Future<void> _ongoing(FocusState s, AppLocalizations l10n) async {
    if (!s.running && s.phase != FocusPhase.paused) {
      await _plugin.cancel(id: _ongoingId);
      return;
    }
    final ends = s.endsAt;
    final title = switch (s.phase) {
      FocusPhase.rest => l10n.focusResting,
      FocusPhase.paused => l10n.focusPaused,
      _ => l10n.focusFocusing,
    };
    await _plugin.show(
      id: _ongoingId,
      title: title,
      body: taskTitle.value,
      payload: jsonEncode({'open': 'focus'}),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelTimer,
          l10n.focus,
          importance: Importance.low,
          priority: Priority.low,
          color: Palette.primary,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          silent: true,
          showWhen: ends != null,
          when: ends?.millisecondsSinceEpoch,
          usesChronometer: ends != null,
          chronometerCountDown: ends != null,
          category: AndroidNotificationCategory.progress,
        ),
      ),
    );
  }

  @disposeMethod
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _endTimer?.cancel();
  }
}
