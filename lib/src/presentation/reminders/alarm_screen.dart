import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/date/dates.dart';
import '../../core/notifications/reminder_health.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/notifications/snooze.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/task_format.dart';
import '../tasks/task_editor_sheet.dart';
import 'snooze_sheet.dart';

/// An alarm-style reminder rang: the task, full screen (over the lock screen
/// on Android), with Done and snooze one tap away. Leaving it in any way
/// stops the ringing.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, required this.task});

  final Task task;

  static Future<void> show(BuildContext context, String taskId) async {
    final task = await getIt<TaskRepository>().getTask(taskId);
    if (task == null || task.isDone || task.deletedAt != null) {
      // Nothing left to do: just stop the sound
      await ReminderHealth.releaseLockScreen();
      if (task != null) {
        await getIt<ReminderService>().dismissShown(task);
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    final next = await Navigator.of(context).push<_Next>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AlarmScreen(task: task),
      ),
    );
    if (!context.mounted) {
      return;
    }
    switch (next) {
      case _Snoozed(:final until):
        showSnoozedSnackBar(context, until);
      case _Open():
        unawaited(TaskEditorSheet.show(context, task.id));
      case null:
        break;
    }
  }

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

sealed class _Next {
  const _Next();
}

class _Snoozed extends _Next {
  const _Snoozed(this.until);

  final DateTime until;
}

class _Open extends _Next {
  const _Open();
}

class _AlarmScreenState extends State<AlarmScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  final _service = getIt<ReminderService>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.enabled(context)) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    unawaited(_service.dismissShown(widget.task));
    unawaited(ReminderHealth.releaseLockScreen());
    super.dispose();
  }

  Future<void> _done() async {
    AppHaptics.medium();
    await getIt<TaskRepository>().complete(widget.task);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _snooze(SnoozeOption option) async {
    AppHaptics.selection();
    final until = await _service.snoozeTask(widget.task.id, option);
    if (mounted) {
      Navigator.pop(context, _Snoozed(until));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final task = widget.task;
    final now = DateTime.now();
    final today = Dates.dateOnly(now);
    final due = task.dueDate;
    final when = due == null
        ? null
        : [
            TaskFormat.day(context, due, today),
            if (task.dueTime != null) TaskFormat.time(context, task.dueTime!),
          ].join(' · ');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
              Center(
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.08).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.alarm_rounded,
                      size: 48,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                task.title,
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (when != null) ...[
                const SizedBox(height: 8),
                Text(
                  when,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Spacer(),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in SnoozeOption.availableAt(now))
                    OutlinedButton.icon(
                      onPressed: () => _snooze(option),
                      icon: const Icon(Icons.snooze_rounded, size: 18),
                      label: Text(snoozeLabel(l10n, option)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _done,
                icon: const Icon(Icons.check_rounded),
                label: Text(l10n.actionDone),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, const _Open()),
                child: Text(l10n.openTask),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
