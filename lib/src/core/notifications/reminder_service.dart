import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
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
import '../focus/focus_service.dart';
import '../widgets/launch_links.dart';
import '../widgets/widget_sync.dart';
import 'reminder_planner.dart';
import 'reminder_settings.dart';
import 'snooze.dart';

const _channelId = 'task_reminders';
const _alarmChannelId = 'task_alarms';
const _digestChannelId = 'daily_digest';

/// iOS action sets: with "Tonight" while it is still ahead, without after
const _categoryId = 'task';
const _lateCategoryId = 'task_late';

const _actionDone = 'done';

/// Android shows three buttons at most: the rest of the choices in the app
const _actionSnoozeMore = 'snoozeMore';
const _localeKey = 'reminder_locale';
const _askedExactKey = 'asked_exact_alarm';

/// The "send a test" notification: never cancelled by a re-plan
final testNotificationId = ReminderPlanner.notificationIdOf('test');

/// Android FLAG_INSISTENT: the alarm sound repeats until the user acts
const _flagInsistent = 4;

/// Keeps pending notifications in sync with the tasks.
///
/// Every change to a task (and every app resume, time-zone change, settings
/// change or permission change) recomputes the nearest
/// [ReminderPlanner.maxPending] notifications — reminders, snoozes and
/// morning summaries — cancels stale ones and (re)schedules the rest under
/// stable ids.
@lazySingleton
class ReminderService with WidgetsBindingObserver {
  ReminderService(this._repo, this._language, this._settings);

  final TaskRepository _repo;
  final LanguageCubit _language;
  final ReminderSettings _settings;
  final _plugin = FlutterLocalNotificationsPlugin();

  StreamSubscription<Object>? _tasksSub;
  StreamSubscription<Object>? _languageSub;
  List<Task>? _latest;
  Timer? _debounce;
  Future<void> _syncing = Future.value();

  Future<void> start() async {
    if (_tasksSub != null) {
      return;
    }
    await _settings.load();
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
    _tasksSub = _repo.watchForNotifications().listen((tasks) {
      _latest = tasks;
      _scheduleSync();
    });
    _languageSub = _language.stream.listen((_) => _scheduleSync());
    _settings.digest.addListener(_scheduleSync);
  }

  AppLocalizations get _l10n => lookupAppLocalizations(_language.state.locale);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Time zone, day or exact-alarm permission may have changed meanwhile
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
        final digest = _settings.digest.value;
        await syncReminders(
          _plugin,
          tasks,
          _l10n,
          code,
          digestMinutes: digest.on ? digest.minutes : null,
        );
      });
    });
  }

  Future<void> _onForegroundResponse(NotificationResponse response) async {
    final payload = _payloadOf(response.payload);
    switch (payload['open']) {
      case 'today':
        LaunchLinks.instance.open(LaunchLinks.today);
        return;
      case 'focus':
        LaunchLinks.instance.open(LaunchLinks.focus);
        return;
    }
    final taskId = payload['task'] as String?;
    if (taskId == null) {
      return;
    }
    final snooze = SnoozeOption.ofAction(response.actionId);
    if (response.actionId == _actionDone) {
      final task = await _repo.getTask(taskId);
      if (task != null && !task.isDone) {
        await _repo.complete(task);
      }
    } else if (snooze != null) {
      await snoozeTask(taskId, snooze);
    } else if (response.actionId == _actionSnoozeMore) {
      LaunchLinks.instance.open(LaunchLinks.snooze(taskId));
    } else if (payload['alarm'] == true) {
      LaunchLinks.instance.open(LaunchLinks.alarm(taskId));
    } else {
      LaunchLinks.instance.open(LaunchLinks.task(taskId));
    }
  }

  /// Rings the task again later; returns when
  Future<DateTime> snoozeTask(String taskId, SnoozeOption option) async {
    final until = snoozeTime(option, DateTime.now(), _settings.digest.value);
    await _repo.snoozeUntil(taskId, until);
    return until;
  }

  /// Schedules a notification a few seconds from now through the same path
  /// as real reminders, so the user can lock the phone and see it arrive.
  /// Returns whether it was scheduled.
  Future<bool> sendTest() async {
    final l10n = _l10n;
    try {
      await _scheduleTest(l10n, exact: await exactAlarmsAllowed());
      return true;
    } on Exception catch (e) {
      logger.e(e);
      return false;
    }
  }

  Future<void> _scheduleTest(
    AppLocalizations l10n, {
    required bool exact,
  }) async {
    await _plugin.zonedSchedule(
      id: testNotificationId,
      scheduledDate: tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 5)),
      title: l10n.testNotificationTitle,
      body: l10n.testNotificationBody,
      payload: jsonEncode({'test': true}),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.reminderChannelName,
          channelDescription: l10n.reminderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: Palette.primary,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Takes the task's notifications that are on screen away (an alarm-style
  /// one keeps ringing until then). Scheduled ones stay.
  Future<void> dismissShown(Task task) async {
    try {
      final ids = ReminderPlanner.notificationIdsOf(task).toSet();
      for (final shown in await _plugin.getActiveNotifications()) {
        final id = shown.id;
        if (id != null && ids.contains(id)) {
          await _plugin.cancel(id: id);
        }
      }
    } on Exception catch (e) {
      logger.e(e);
    }
  }

  Future<int> pendingCount() async {
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } on Exception catch (e) {
      logger.e(e);
      return 0;
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

  /// Android 14+: opens the "full-screen notifications" setting
  Future<void> requestFullScreen() async {
    await _android?.requestFullScreenIntentPermission();
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

  /// Permission is off and asking again won't show a prompt: only the
  /// system settings page can turn it back on
  Future<void> openNotificationSettings() =>
      _plugin.openAppNotificationSettings();

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
    _settings.digest.removeListener(_scheduleSync);
    await _tasksSub?.cancel();
    await _languageSub?.cancel();
    _debounce?.cancel();
  }
}

/// When [option] chosen at [now] rings again. "Tomorrow morning" follows the
/// morning summary time when that is on; a choice already past (tapping
/// "Tonight" late at night) rings in an hour instead.
DateTime snoozeTime(SnoozeOption option, DateTime now, DigestSetting digest) {
  final until = option.until(
    now,
    morning: digest.on ? digest.minutes : SnoozeOption.morningMinutes,
  );
  return until.isAfter(now) ? until : SnoozeOption.oneHour.until(now);
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
  List<DarwinNotificationAction> actions({required bool tonight}) => [
    DarwinNotificationAction.plain(_actionDone, l10n.actionDone),
    for (final option in SnoozeOption.values)
      if (option != SnoozeOption.tonight || tonight)
        DarwinNotificationAction.plain(
          option.actionId,
          snoozeLabel(l10n, option),
        ),
  ];
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
            actions: actions(tonight: true),
          ),
          DarwinNotificationCategory(
            _lateCategoryId,
            actions: actions(tonight: false),
          ),
        ],
      ),
    ),
    onDidReceiveNotificationResponse: onResponse,
    onDidReceiveBackgroundNotificationResponse:
        onNotificationActionInBackground,
  );
}

/// Short label for a snooze choice (notification buttons, snooze sheet)
String snoozeLabel(AppLocalizations l10n, SnoozeOption option) =>
    switch (option) {
      SnoozeOption.tenMinutes => l10n.snoozeTenMinutes,
      SnoozeOption.oneHour => l10n.snoozeOneHour,
      SnoozeOption.tonight => l10n.snoozeTonight,
      SnoozeOption.tomorrowMorning => l10n.snoozeTomorrowMorning,
    };

Map<String, Object?> _payloadOf(String? payload) {
  if (payload == null) {
    return const {};
  }
  try {
    final data = jsonDecode(payload);
    return data is Map<String, Object?> ? data : const {};
  } on FormatException {
    return const {};
  }
}

Future<void> syncReminders(
  FlutterLocalNotificationsPlugin plugin,
  List<Task> tasks,
  AppLocalizations l10n,
  String localeCode, {
  int? digestMinutes,
}) async {
  try {
    final now = DateTime.now();
    final plan = ReminderPlanner.plan(tasks, now, digestMinutes: digestMinutes);
    final desired = {...plan.ids, testNotificationId, ...focusNotificationIds};
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
    // Without the exact-alarm permission Android may delay by minutes
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final reminder in plan.reminders) {
      final task = reminder.task;
      await plugin.zonedSchedule(
        id: reminder.notificationId,
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.local),
        title: task.title,
        body: _bodyOf(task, l10n, localeCode, now),
        payload: jsonEncode({'task': task.id, if (task.alarm) 'alarm': true}),
        notificationDetails: _taskDetails(task, l10n, reminder.fireAt),
        androidScheduleMode: mode,
      );
    }
    for (final digest in plan.digests) {
      final body = _digestBody(digest, l10n, localeCode);
      await plugin.zonedSchedule(
        id: digest.notificationId,
        scheduledDate: tz.TZDateTime.from(digest.fireAt, tz.local),
        title: l10n.digestTitle(digest.count),
        body: body,
        payload: jsonEncode({'open': 'today'}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _digestChannelId,
            l10n.morningSummary,
            channelDescription: l10n.digestChannelDescription,
            color: Palette.primary,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: mode,
      );
    }
  } on Exception catch (e) {
    logger.e(e);
  }
}

NotificationDetails _taskDetails(
  Task task,
  AppLocalizations l10n,
  DateTime fireAt,
) {
  final android = [
    AndroidNotificationAction(_actionDone, l10n.actionDone),
    AndroidNotificationAction(
      SnoozeOption.tenMinutes.actionId,
      l10n.snoozeTenMinutes,
    ),
    AndroidNotificationAction(
      _actionSnoozeMore,
      l10n.snoozeMore,
      showsUserInterface: true,
    ),
  ];
  final category =
      SnoozeOption.availableAt(fireAt).contains(SnoozeOption.tonight)
      ? _categoryId
      : _lateCategoryId;
  if (task.alarm) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _alarmChannelId,
        l10n.alarmChannelName,
        channelDescription: l10n.alarmChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        color: Palette.primary,
        category: AndroidNotificationCategory.alarm,
        // The phone's alarm ringtone, on the alarm volume
        sound: const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert',
        ),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        additionalFlags: Int32List.fromList([_flagInsistent]),
        actions: android,
      ),
      // Breaks through Focus; needs the Time Sensitive capability
      iOS: DarwinNotificationDetails(
        categoryIdentifier: category,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }
  return NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      l10n.reminderChannelName,
      channelDescription: l10n.reminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      color: Palette.primary,
      category: AndroidNotificationCategory.reminder,
      actions: android,
    ),
    iOS: DarwinNotificationDetails(categoryIdentifier: category),
  );
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

/// "9:00 Standup · Pay rent · +2 more · 1 overdue", one per line
String _digestBody(PlannedDigest digest, AppLocalizations l10n, String code) {
  const shown = 4;
  final time = DateFormat.jm(code);
  final lines = [
    for (final t in digest.due.take(shown))
      if (t.dueTime case final minutes?)
        '${time.format(Dates.atMinutes(digest.day, minutes))}  ${t.title}'
      else
        t.title,
    if (digest.due.length > shown) l10n.digestMore(digest.due.length - shown),
    if (digest.overdue.isNotEmpty) l10n.digestOverdue(digest.overdue.length),
  ];
  return lines.join('\n');
}

/// Done / snooze tapped while the app is in the background or closed
@pragma('vm:entry-point')
Future<void> onNotificationActionInBackground(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final taskId = _payloadOf(response.payload)['task'] as String?;
  if (taskId == null) {
    return;
  }
  final db = AppDatabase();
  try {
    final repo = TaskRepository(db);
    final snooze = SnoozeOption.ofAction(response.actionId);
    if (response.actionId == _actionDone) {
      final task = await repo.getTask(taskId);
      if (task != null && !task.isDone) {
        await repo.complete(task);
      }
    } else if (snooze != null) {
      final digest = await ReminderSettings.read();
      await repo.snoozeUntil(
        taskId,
        snoozeTime(snooze, DateTime.now(), digest),
      );
    }
    final code = await resyncRemindersInBackground(repo);
    // Done from a notification: the home-screen widget should know too
    await configureWidgetStorage();
    await pushWidgetSnapshot(repo, locale: localeForCode(code));
  } on Exception catch (e) {
    logger.e(e);
  } finally {
    await db.close();
  }
}

/// Re-plans pending notifications from a background isolate (notification
/// actions, widget taps, time-zone changes) in the language the app last
/// used. Returns that language code.
Future<String> resyncRemindersInBackground(TaskRepository repo) async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_localeKey) ?? Language.english.languageCode;
  await initializeDateFormatting(code);
  final l10n = lookupAppLocalizations(Locale(code));
  final plugin = FlutterLocalNotificationsPlugin();
  await _initPlugin(plugin, l10n);
  final tasks = await repo.watchForNotifications().first;
  await syncReminders(
    plugin,
    tasks,
    l10n,
    code,
    digestMinutes: await ReminderSettings.digestMinutes(),
  );
  return code;
}
