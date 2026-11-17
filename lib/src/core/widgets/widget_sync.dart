import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../data/local/database/app_database.dart';
import '../../data/local/database/converters.dart';
import '../../data/repositories/task_repository.dart';
import '../../gen/l18n/app_localizations.dart';
import '../../shared/cubit/language_cubit.dart';
import '../../shared/enum/language.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/logger_utils.dart';
import '../date/dates.dart';
import '../notifications/reminder_planner.dart';
import '../notifications/reminder_service.dart';

/// Names the native widgets are registered under
const _iOSWidget = 'TodayWidget';
const _androidWidget = 'com.vtn.todolist.widget.TodayWidgetReceiver';

/// Shared storage between the app and its widgets on iOS (one per flavor,
/// matching the entitlements)
String widgetAppGroupId() => appFlavor == 'dev'
    ? 'group.com.vtn.todolist.dev'
    : 'group.com.vtn.todolist';

Future<void> configureWidgetStorage() async {
  if (Platform.isIOS) {
    await HomeWidget.setAppGroupId(widgetAppGroupId());
  }
}

/// What the home-screen widgets show, as JSON. The native widgets only
/// render it (and, when a task is ticked there, update it optimistically),
/// so every word is already translated here.
class WidgetSnapshot {
  WidgetSnapshot._();

  static const key = 'today_snapshot';

  /// Task ids ticked on an iOS widget, applied when the app next runs
  static const pendingKey = 'pending_done';

  static const maxItems = 12;

  static Map<String, Object?> build({
    required List<Task> due,
    required int done,
    required DateTime today,
    required AppLocalizations l10n,
    required String locale,
  }) {
    final time = DateFormat.jm(locale);
    final todays = [
      for (final t in due)
        if (Dates.isSameDay(t.dueDate!, today)) t,
    ];
    final overdue = [
      for (final t in due)
        if (t.dueDate!.isBefore(today)) t,
    ];
    final open = todays.length + overdue.length;
    return {
      'v': 1,
      'date': const LocalDateConverter().toSql(today),
      'open': open,
      'done': done,
      'rtl': Bidi.isRtlLanguage(locale),
      'items': [
        for (final t in [...todays, ...overdue].take(maxItems))
          {
            'id': t.id,
            'title': t.title,
            'time': t.dueTime == null || t.dueDate!.isBefore(today)
                ? null
                : time.format(Dates.atMinutes(today, t.dueTime!)),
            'p': t.priority,
            'late': t.dueDate!.isBefore(today),
            // Ticking it on the iOS widget cancels these
            'nids': ReminderPlanner.notificationIdsOf(t),
          },
      ],
      'l': {
        'title': l10n.today,
        'date': DateFormat.MMMEd(locale).format(today),
        'empty': l10n.todayEmptyTitle,
        'allDone': l10n.allDoneTitle,
        'add': l10n.addTask,
        'late': l10n.stillOpen,
        'check': l10n.actionDone,
        // Ticking on the widget lowers "left" and raises "done" before the
        // app can re-translate, so every count it can reach is ready
        'left': {
          for (var n = 0; n <= open; n++) '$n': l10n.summaryRemaining(n),
        },
        'done': {
          for (var n = done; n <= done + open; n++) '$n': l10n.doneToday(n),
        },
      },
    };
  }

  static Future<void> save(Map<String, Object?> snapshot) async {
    await HomeWidget.saveWidgetData<String>(key, jsonEncode(snapshot));
    await HomeWidget.updateWidget(
      iOSName: _iOSWidget,
      qualifiedAndroidName: _androidWidget,
    );
  }
}

/// Rebuilds the widget snapshot from the database, from any isolate
Future<void> pushWidgetSnapshot(
  TaskRepository repo, {
  required Locale locale,
  DateTime? now,
}) async {
  final today = Dates.today(now);
  final tag = locale.toLanguageTag();
  await initializeDateFormatting(tag);
  final snapshot = WidgetSnapshot.build(
    due: await repo.watchDueBy(today).first,
    done: await repo.watchDoneOn(today).first,
    today: today,
    l10n: lookupAppLocalizations(locale),
    locale: tag,
  );
  await WidgetSnapshot.save(snapshot);
}

/// Keeps the home-screen widgets in step with today's tasks, and applies
/// ticks made on an iOS widget while the app was closed.
@lazySingleton
class WidgetSync with WidgetsBindingObserver {
  WidgetSync(this._repo, this._language, this._clock);

  final TaskRepository _repo;
  final LanguageCubit _language;
  final DayClock _clock;

  StreamSubscription<Object>? _dueSub;
  StreamSubscription<Object>? _doneSub;
  StreamSubscription<Object?>? _languageSub;
  Timer? _debounce;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      await configureWidgetStorage();
      await HomeWidget.registerInteractivityCallback(widgetInteraction);
    } on Exception catch (e) {
      logger.e(e);
    }
    WidgetsBinding.instance.addObserver(this);
    _clock.addListener(_watch);
    _watch();
    _languageSub = _language.stream.listen((_) => _schedule());
    await applyPending();
  }

  void _watch() {
    _dueSub?.cancel();
    _doneSub?.cancel();
    final today = _clock.value;
    _dueSub = _repo.watchDueBy(today).listen((_) => _schedule());
    _doneSub = _repo.watchDoneOn(today).listen((_) => _schedule());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(applyPending());
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        await pushWidgetSnapshot(
          _repo,
          locale: _language.state.locale,
          now: _clock.value,
        );
      } on Exception catch (e) {
        logger.e(e);
      }
    });
  }

  /// Completes the tasks ticked on an iOS widget since the app last ran
  Future<void> applyPending() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>(
        WidgetSnapshot.pendingKey,
      );
      if (raw == null || raw.isEmpty) {
        return;
      }
      await HomeWidget.saveWidgetData<String>(WidgetSnapshot.pendingKey, null);
      for (final id in (jsonDecode(raw) as List).cast<String>()) {
        final task = await _repo.getTask(id);
        if (task != null && !task.isDone && task.deletedAt == null) {
          await _repo.complete(task);
        }
      }
    } on Exception catch (e) {
      logger.e(e);
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _clock.removeListener(_watch);
    _debounce?.cancel();
    await _dueSub?.cancel();
    await _doneSub?.cancel();
    await _languageSub?.cancel();
  }
}

/// Runs in a background isolate, while the app may be closed:
/// - `todolist://complete?id=…` — a task ticked on an Android widget
/// - `todolist://resync` — time zone or clock changed, phone rebooted, app
///   updated (Android `TimeChangeReceiver`): re-plan reminders, and the
///   widget's "today" may have moved too
@pragma('vm:entry-point')
Future<void> widgetInteraction(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final id = uri?.queryParameters['id'];
  final complete = uri?.host == 'complete' && id != null;
  if (!complete && uri?.host != 'resync') {
    return;
  }
  final db = AppDatabase();
  try {
    final repo = TaskRepository(db);
    if (complete) {
      final task = await repo.getTask(id);
      if (task != null && !task.isDone) {
        await repo.complete(task);
      }
    }
    final code = await resyncRemindersInBackground(repo);
    await configureWidgetStorage();
    await pushWidgetSnapshot(repo, locale: _localeOf(code));
  } on Exception catch (e) {
    logger.e(e);
  } finally {
    await db.close();
  }
}

Locale _localeOf(String code) => Language.values
    .firstWhere((l) => l.languageCode == code, orElse: () => Language.english)
    .locale;

/// For callers outside this file (notification actions)
Locale localeForCode(String code) => _localeOf(code);
