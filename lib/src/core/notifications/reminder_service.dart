import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../config/theme/palette.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../gen/l18n/app_localizations.dart';
import '../../shared/cubit/language_cubit.dart';
import '../../shared/enum/language.dart';
import '../../shared/helpers/logger_utils.dart';
import '../date/dates.dart';
import 'reminder_planner.dart';

const _channelId = 'task_reminders';
const _categoryId = 'task';
const _actionDone = 'done';
const _actionSnooze = 'snooze';
const _localeKey = 'reminder_locale';
const _askedExactKey = 'asked_exact_alarm';
const snoozeDuration = Duration(hours: 1);

/// Keeps pending notifications in sync with the tasks.
///
/// Every change to a task with a reminder (and every app resume, time-zone
/// change or permission change) recomputes the nearest
/// [ReminderPlanner.maxPending] reminders, cancels stale ones and
/// (re)schedules the rest under stable ids.
@lazySingleton
class ReminderService with WidgetsBindingObserver {
  ReminderService(this._repo, this._language);

  final TaskRepository _repo;
  final LanguageCubit _language;
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Task id the user opened from a notification (Home shows its editor)
  final openTaskRequest = ValueNotifier<String?>(null);

  StreamSubscription<Object>? _tasksSub;
  StreamSubscription<Object>? _languageSub;
  List<Task>? _latest;
  Timer? _debounce;
  Future<void> _syncing = Future.value();

  Future<void> start() async {
    if (_tasksSub != null) {
      return;
    }
    try {
      await _initPlugin(_plugin, _l10n, onResponse: _onForegroundResponse);
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        await _onForegroundResponse(response);
      }
    } on Exception catch (e) {
      logger.e(e);
    }
    WidgetsBinding.instance.addObserver(this);
    _tasksSub = _repo.watchWithReminders().listen((tasks) {
      _latest = tasks;
      _scheduleSync();
    });
    _languageSub = _language.stream.listen((_) => _scheduleSync());
  }

  AppLocalizations get _l10n => lookupAppLocalizations(_language.state.locale);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Time zone or exact-alarm permission may have changed meanwhile
      unawaited(_refreshTimeZone().then((_) => _scheduleSync()));
    }
  }

  void _scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final tasks = _latest;
      if (tasks == null) {
        return;
      }
      _syncing = _syncing.then((_) async {
        final code = _language.state.locale.languageCode;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_localeKey, code);
        await syncReminders(_plugin, tasks, _l10n, code);
      });
    });
  }

  Future<void> _onForegroundResponse(NotificationResponse response) async {
    final taskId = _taskIdOf(response.payload);
    if (taskId == null) {
      return;
    }
    switch (response.actionId) {
      case _actionDone:
        final task = await _repo.getTask(taskId);
        if (task != null && !task.isDone) {
          await _repo.complete(task);
        }
      case _actionSnooze:
        await _repo.snooze(taskId, snoozeDuration);
      default:
        openTaskRequest.value = taskId;
    }
  }

  // ------------------------------------------------------------ permissions

  Future<bool> notificationsEnabled() async {
    if (Platform.isAndroid) {
      return await _android?.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final options = await ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  /// Android 12+: exact alarms are opt-in (denied by default on 14+).
  /// Without them reminders may arrive a few minutes late.
  Future<bool> exactAlarmsAllowed() async {
    if (!Platform.isAndroid) {
      return true;
    }
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  Future<void> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
    _scheduleSync();
  }

  Future<void> requestNotifications() async {
    if (Platform.isAndroid) {
      await _android?.requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    _scheduleSync();
  }

  /// Called when the user sets a reminder: asks for notifications, then (once,
  /// on Android) explains and offers exact alarms.
  Future<void> ensurePermission(BuildContext context) async {
    if (!await notificationsEnabled()) {
      await requestNotifications();
    }
    if (!Platform.isAndroid || await exactAlarmsAllowed()) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedExactKey) ?? false) {
      return;
    }
    await prefs.setBool(_askedExactKey, true);
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.alarm_rounded),
        title: Text(l10n.exactAlarmTitle),
        content: Text(l10n.exactAlarmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.allowExactAlarms),
          ),
        ],
      ),
    );
    if (allow ?? false) {
      await requestExactAlarms();
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @disposeMethod
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _tasksSub?.cancel();
    await _languageSub?.cancel();
    _debounce?.cancel();
  }
}

// ------------------------------------------------------------------ shared
// Used by both the app and the background isolate that handles notification
// actions while the app is closed.

Future<void> _refreshTimeZone() async {
  try {
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
  } on Exception catch (e) {
    // Fall back to UTC: reminders may be off by the UTC offset
    logger.e(e);
  }
}

Future<void> _initPlugin(
  FlutterLocalNotificationsPlugin plugin,
  AppLocalizations l10n, {
  DidReceiveNotificationResponseCallback? onResponse,
}) async {
  tz_data.initializeTimeZones();
  await _refreshTimeZone();
  await plugin.initialize(
    settings: InitializationSettings(
      android: const AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        // Asked when the user first sets a reminder, not at launch
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            _categoryId,
            actions: [
              DarwinNotificationAction.plain(_actionDone, l10n.actionDone),
              DarwinNotificationAction.plain(_actionSnooze, l10n.actionSnooze),
            ],
          ),
        ],
      ),
    ),
    onDidReceiveNotificationResponse: onResponse,
    onDidReceiveBackgroundNotificationResponse:
        onNotificationActionInBackground,
  );
}

String? _taskIdOf(String? payload) {
  if (payload == null) {
    return null;
  }
  try {
    final data = jsonDecode(payload);
    return data is Map ? data['task'] as String? : null;
  } on FormatException {
    return null;
  }
}

Future<void> syncReminders(
  FlutterLocalNotificationsPlugin plugin,
  List<Task> tasks,
  AppLocalizations l10n,
  String localeCode,
) async {
  try {
    final now = DateTime.now();
    final planned = ReminderPlanner.plan(tasks, now);
    final desired = {for (final p in planned) p.notificationId};
    for (final pending in await plugin.pendingNotificationRequests()) {
      if (!desired.contains(pending.id)) {
        await plugin.cancel(id: pending.id);
      }
    }
    final exact = Platform.isAndroid
        ? await plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.canScheduleExactNotifications() ??
              false
        : true;
    for (final reminder in planned) {
      final task = reminder.task;
      await plugin.zonedSchedule(
        id: reminder.notificationId,
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.local),
        title: task.title,
        body: _bodyOf(task, l10n, localeCode, now),
        payload: jsonEncode({'task': task.id}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            l10n.reminderChannelName,
            channelDescription: l10n.reminderChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: Palette.primary,
            category: AndroidNotificationCategory.reminder,
            actions: [
              AndroidNotificationAction(_actionDone, l10n.actionDone),
              AndroidNotificationAction(_actionSnooze, l10n.actionSnooze),
            ],
          ),
          iOS: const DarwinNotificationDetails(categoryIdentifier: _categoryId),
        ),
        // Without the exact-alarm permission Android may delay by minutes
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  } on Exception catch (e) {
    logger.e(e);
  }
}

String _bodyOf(
  Task task,
  AppLocalizations l10n,
  String localeCode,
  DateTime now,
) {
  final note = task.note;
  if (note != null) {
    return note;
  }
  final due = task.dueDate!;
  final diff = Dates.daysBetween(Dates.dateOnly(now), due);
  final day = switch (diff) {
    0 => l10n.today,
    1 => l10n.tomorrow,
    _ => DateFormat.MMMEd(localeCode).format(due),
  };
  final time = task.dueTime;
  if (time == null) {
    return l10n.reminderDue(day);
  }
  final at = DateFormat.jm(localeCode).format(Dates.atMinutes(due, time));
  return l10n.reminderDue('$day $at');
}

/// Done / Snooze tapped while the app is in the background or closed
@pragma('vm:entry-point')
Future<void> onNotificationActionInBackground(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final taskId = _taskIdOf(response.payload);
  if (taskId == null) {
    return;
  }
  final db = AppDatabase();
  try {
    final repo = TaskRepository(db);
    if (response.actionId == _actionDone) {
      final task = await repo.getTask(taskId);
      if (task != null && !task.isDone) {
        await repo.complete(task);
      }
    } else if (response.actionId == _actionSnooze) {
      await repo.snooze(taskId, snoozeDuration);
    }
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey) ?? Language.english.languageCode;
    await initializeDateFormatting(code);
    final l10n = lookupAppLocalizations(Locale(code));
    final plugin = FlutterLocalNotificationsPlugin();
    await _initPlugin(plugin, l10n);
    final tasks = await repo.watchWithReminders().first;
    await syncReminders(plugin, tasks, l10n, code);
  } on Exception catch (e) {
    logger.e(e);
  } finally {
    await db.close();
  }
}
