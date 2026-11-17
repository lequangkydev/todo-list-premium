import 'package:material_ui/material_ui.dart';

import '../../core/backup/backup_codec.dart';
import '../../core/date/dates.dart';
import '../../shared/extension/context_extension.dart';

/// "Today 9:00", "Mon 9:00", "Nov 3 9:00"
String backupWhen(BuildContext context, DateTime at) {
  final today = Dates.dateOnly(DateTime.now());
  final time = TimeOfDay.fromDateTime(at);
  final day = Dates.daysBetween(today, Dates.dateOnly(at)) == 0
      ? context.l10n.today
      : MaterialLocalizations.of(context).formatShortMonthDay(at);
  final clock = MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$day $clock';
}

/// "42 tasks · 5 lists"
String backupContents(BuildContext context, BackupData data) {
  final l10n = context.l10n;
  return '${l10n.backupTaskCount(data.taskCount)} · '
      '${l10n.backupListCount(data.lists.length)}';
}
