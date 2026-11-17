import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
import '../../core/notifications/reminder_health.dart';
import '../../core/notifications/reminder_service.dart';
import '../../shared/extension/context_extension.dart';

const _askedOemKey = 'asked_oem_check';

/// After the user sets a reminder: ask for notification (and exact-alarm)
/// permission, then — once, on phones known to kill background apps —
/// offer the reminder check.
Future<void> afterReminderSet(BuildContext context) async {
  await getIt<ReminderService>().ensurePermission(context);
  if (!Platform.isAndroid || !context.mounted) {
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_askedOemKey) ?? false) {
    return;
  }
  final info = await ReminderHealth.read();
  if (info.oem == Oem.other || !context.mounted) {
    return;
  }
  await prefs.setBool(_askedOemKey, true);
  if (!context.mounted) {
    return;
  }
  final l10n = context.l10n;
  final check = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.battery_alert_rounded),
      title: Text(l10n.oemNudgeTitle(info.brandName)),
      content: Text(l10n.oemNudgeMessage(info.brandName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.checkNow),
        ),
      ],
    ),
  );
  if ((check ?? false) && context.mounted) {
    await context.pushRoute(const ReminderCheckRoute());
  }
}
