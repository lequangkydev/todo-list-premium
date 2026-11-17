import 'package:material_ui/material_ui.dart';

import '../../config/theme/app_theme.dart';
import '../../core/backup/backup_codec.dart';
import '../../data/repositories/backup_repository.dart';
import '../../shared/extension/context_extension.dart';
import 'backup_labels.dart';

/// What's in a backup, and how to restore it: merge (the default, deletes
/// nothing) or replace (asks again, naming what it removes).
class RestoreSheet extends StatelessWidget {
  const RestoreSheet({super.key, required this.data});

  final BackupData data;

  static Future<RestoreMode?> show(BuildContext context, BackupData data) {
    return showModalBottomSheet<RestoreMode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AppMotion.sheet(context),
      builder: (_) => RestoreSheet(data: data),
    );
  }

  Future<void> _replace(BuildContext context) async {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.restoreReplaceConfirmTitle),
        content: Text(l10n.restoreReplaceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.restoreReplaceAction),
          ),
        ],
      ),
    );
    if ((sure ?? false) && context.mounted) {
      Navigator.pop(context, RestoreMode.replace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.restoreTitle, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.restoreMade(backupWhen(context, data.createdAt)),
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(backupContents(context, data), style: textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, RestoreMode.merge),
              child: Text(l10n.restoreMerge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
              child: Text(l10n.restoreMergeHint, style: textTheme.bodySmall),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
              ),
              onPressed: () => _replace(context),
              child: Text(l10n.restoreReplace),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
              child: Text(l10n.restoreReplaceHint, style: textTheme.bodySmall),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.restoreSafetyNote,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
