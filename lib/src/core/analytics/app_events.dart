/// Where product events go. Null (the default) drops them: tests and the
/// background isolates that handle notifications and widgets never set it,
/// so logging from shared code is always safe.
typedef EventSink = void Function(String name, Map<String, Object> params);

/// The few events that say whether people get value from the app: do they
/// add a first task, set reminders, come back to finish things, add the
/// widget. No task text, titles or ids are ever sent — only counts and
/// yes/no flags (as 0/1; analytics values are strings or numbers).
class AppEvents {
  AppEvents._();

  static EventSink? sink;

  static void log(String name, [Map<String, Object> params = const {}]) {
    try {
      sink?.call(name, params);
    } on Object {
      // Analytics must never break the app
    }
  }

  static int _flag(bool value) => value ? 1 : 0;

  // ------------------------------------------------------------------ tasks

  static void taskCreated({
    required bool hasDate,
    required bool hasTime,
    required int reminders,
    required bool recurring,
    required bool subtask,
  }) => log('task_created', {
    'has_date': _flag(hasDate),
    'has_time': _flag(hasTime),
    'reminders': reminders,
    'recurring': _flag(recurring),
    'subtask': _flag(subtask),
  });

  static void taskCompleted({required bool recurring, required bool subtask}) =>
      log('task_completed', {
        'recurring': _flag(recurring),
        'subtask': _flag(subtask),
      });

  static void brainDumpSaved(int count) =>
      log('brain_dump_saved', {'count': count});

  static void dayPlanned(int count) => log('day_planned', {'count': count});

  // -------------------------------------------------------------- reminders

  static void reminderSet({required int count, required bool alarm}) =>
      log('reminder_set', {'count': count, 'alarm': _flag(alarm)});

  /// [minutes] until it rings again
  static void reminderSnoozed(int minutes) =>
      log('reminder_snoozed', {'minutes': minutes});

  static void notificationPermission({required bool granted}) =>
      log('notification_permission', {'granted': _flag(granted)});

  // ------------------------------------------------------------- activation

  /// The first task this install ever created
  static void firstTask() => log('first_task_created');

  /// A getting-started step was finished: `task`, `notifications`, `widget`
  static void setupStep(String step) => log('setup_step', {'step': step});

  static void setupDone() => log('setup_done');

  static void setupDismissed(int stepsDone) =>
      log('setup_dismissed', {'steps_done': stepsDone});

  static void widgetPinRequested() => log('widget_pin_requested');

  /// Home-screen widgets present when the app starts
  static void widgetsInstalled(int count) =>
      log('widgets_installed', {'count': count});

  // ------------------------------------------------------- backup and focus

  static void backupCreated({required bool toFolder}) =>
      log('backup_created', {'to_folder': _flag(toFolder)});

  static void backupRestored({required bool replace, required int tasks}) =>
      log('backup_restored', {'replace': _flag(replace), 'tasks': tasks});

  static void focusStarted({required bool withTask, required int minutes}) =>
      log('focus_started', {'with_task': _flag(withTask), 'minutes': minutes});

  static void focusRecorded({required int minutes, required bool completed}) =>
      log('focus_recorded', {
        'minutes': minutes,
        'completed': _flag(completed),
      });
}
