import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/date/dates.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/notifications/reminder_settings.dart';
import '../../core/notifications/snooze.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/task_format.dart';

/// "Snooze…" on a notification: when should it ring again?
class SnoozeSheet extends StatelessWidget {
  const SnoozeSheet({super.key, required this.now});

  final DateTime now;

  /// Snoozes [taskId] to the chosen time and confirms it; returns that time
  static Future<DateTime?> show(BuildContext context, String taskId) async {
    final until = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: AppMotion.sheet(context),
      builder: (_) => SnoozeSheet(now: DateTime.now()),
    );
    if (until == null) {
      return null;
    }
    await getIt<TaskRepository>().snoozeUntil(taskId, until);
    if (context.mounted) {
      showSnoozedSnackBar(context, until);
    }
    return until;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final digest = getIt<ReminderSettings>().digest.value;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              l10n.snoozeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final option in SnoozeOption.availableAt(now))
            Builder(
              builder: (context) {
                final until = snoozeTime(option, now, digest);
                return ListTile(
                  leading: const Icon(Icons.snooze_rounded),
                  title: Text(snoozeLabel(l10n, option)),
                  trailing: Text(_when(context, until)),
                  onTap: () => Navigator.pop(context, until),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: Text(l10n.snoozePickTime),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(
                  now.add(const Duration(hours: 1)),
                ),
              );
              if (picked == null || !context.mounted) {
                return;
              }
              var until = Dates.atMinutes(
                Dates.dateOnly(now),
                picked.hour * 60 + picked.minute,
              );
              // A time already gone today means tomorrow
              if (!until.isAfter(now)) {
                until = Dates.addDays(until, 1);
              }
              Navigator.pop(context, until);
            },
          ),
        ],
      ),
    );
  }

  String _when(BuildContext context, DateTime until) {
    final time = TaskFormat.time(context, until.hour * 60 + until.minute);
    return Dates.isSameDay(until, now)
        ? time
        : '${TaskFormat.day(context, until, Dates.dateOnly(now))} $time';
  }
}

/// "I'll remind you at 19:00"
void showSnoozedSnackBar(BuildContext context, DateTime until) {
  final now = DateTime.now();
  final time = TaskFormat.time(context, until.hour * 60 + until.minute);
  final when = Dates.isSameDay(until, now)
      ? time
      : '${TaskFormat.day(context, until, Dates.dateOnly(now))} $time';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.l10n.snoozedUntil(when))));
}
