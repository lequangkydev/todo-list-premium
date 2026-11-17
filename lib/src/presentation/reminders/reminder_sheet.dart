import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/notifications/reminder_health.dart';
import '../../core/notifications/reminder_service.dart';
import '../../data/local/database/app_database.dart';
import '../../data/local/database/converters.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_format.dart';
import 'reminder_nudge.dart';

/// Picks any number of reminders for a task, and whether they ring like an
/// alarm. Every change is saved at once, like the rest of the editor.
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({super.key, required this.task});

  final Task task;

  /// Offsets offered for a task with a time
  static const timed = [0, 5, 10, 15, 30, 60, 120, 1440];

  /// Offsets offered for an all-day task (relative to 9:00 on the day)
  static const allDay = [0, 1440, 2880, 10080];

  static Future<void> show(BuildContext context, Task task) async {
    final hadReminders = task.reminders.isNotEmpty;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AppMotion.sheet(context),
      builder: (_) => ReminderSheet(task: task),
    );
    final saved = await getIt<TaskRepository>().getTask(task.id);
    // The first reminder on a task is when to ask for what reminders need
    if (!hadReminders &&
        (saved?.reminders.isNotEmpty ?? false) &&
        context.mounted) {
      await afterReminderSet(context);
    }
  }

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  final _repo = getIt<TaskRepository>();
  late List<int> _offsets = widget.task.reminders;
  late bool _alarm = widget.task.alarm;
  DeviceReminderInfo _device = DeviceReminderInfo.none;

  @override
  void initState() {
    super.initState();
    ReminderHealth.read().then((info) {
      if (mounted) {
        setState(() => _device = info);
      }
    });
  }

  Future<void> _toggle(int offset) async {
    final next = _offsets.contains(offset)
        ? (List.of(_offsets)..remove(offset))
        : [..._offsets, offset];
    setState(() => _offsets = ReminderOffsetsConverter.normalize(next));
    AppHaptics.selection();
    // A reminder needs a day; default to today
    if (widget.task.dueDate == null && _offsets.isNotEmpty) {
      await _repo.setDue(widget.task.id, getIt<DayClock>().value, null);
    }
    await _repo.setReminders(widget.task.id, _offsets);
  }

  Future<void> _setAlarm(bool on) async {
    setState(() => _alarm = on);
    AppHaptics.selection();
    await _repo.setReminders(widget.task.id, _offsets, alarm: on);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final allDay = widget.task.dueTime == null;
    final presets = allDay ? ReminderSheet.allDay : ReminderSheet.timed;
    // Offsets set some other way (older versions, quick add) stay listed
    final options = ReminderOffsetsConverter.normalize([
      ...presets,
      ..._offsets,
    ]);
    final needsFullScreen =
        _alarm && Platform.isAndroid && !_device.fullScreenAllowed;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: Text(l10n.reminders, style: textTheme.titleMedium),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final offset in options)
                  CheckboxListTile(
                    value: _offsets.contains(offset),
                    onChanged: (_) => _toggle(offset),
                    title: Text(TaskFormat.reminder(l10n, offset)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (allDay)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                    child: Text(
                      l10n.reminderAllDayHint,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const Divider(),
                SwitchListTile(
                  value: _alarm,
                  onChanged: _offsets.isEmpty ? null : _setAlarm,
                  secondary: const Icon(Icons.alarm_rounded),
                  title: Text(l10n.alarmStyle),
                  subtitle: Text(
                    Platform.isIOS
                        ? l10n.alarmStyleHintIos
                        : l10n.alarmStyleHintAndroid,
                  ),
                ),
                if (needsFullScreen)
                  ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: scheme.error,
                    ),
                    title: Text(l10n.fullScreenTitle),
                    subtitle: Text(l10n.fullScreenHint),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        await getIt<ReminderService>().requestFullScreen();
                        final info = await ReminderHealth.read();
                        if (mounted) {
                          setState(() => _device = info);
                        }
                      },
                      child: Text(l10n.allowExactAlarms),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionDone),
            ),
          ),
        ],
      ),
    );
  }
}
