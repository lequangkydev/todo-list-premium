import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart' show openFile;
import 'package:flutter_ads/ads_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../module/tracking_screen/loggable_widget.dart';
import '../../config/di/di.dart';
import '../../core/backup/backup_codec.dart';
import '../../core/backup/backup_service.dart';
import '../../core/backup/backup_store.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/logger_utils.dart';
import 'backup_labels.dart';
import 'restore_sheet.dart';

/// Backups without an account: daily copies on the phone and in a folder
/// the user picks, export through the share sheet, restore from either.
@RoutePage()
class BackupScreen extends StatefulLoggableWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = getIt<BackupService>();
  late Future<List<StoredBackup>> _stored = _list();
  bool _busy = false;

  Future<List<StoredBackup>> _list() async => (await _service.store()).list();

  void _reload() => setState(() => _stored = _list());

  /// Leaving for a system picker or share sheet shouldn't bring an app-open
  /// ad back with us
  void _leavingApp() =>
      MyAds.instance.appLifecycleReactor?.setIsExcludeScreen(true);

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await work();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _backupNow() => _run(() async {
    final saved = await _service.backupNow();
    if (!mounted) {
      return;
    }
    AppHaptics.light();
    _snack(saved == null ? context.l10n.backupEmpty : context.l10n.backupDone);
    _reload();
  });

  Future<void> _export(BuildContext buttonContext) => _run(() async {
    final export = await _service.export();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, export.name));
    await file.writeAsBytes(export.bytes, flush: true);
    if (!buttonContext.mounted) {
      return;
    }
    final box = buttonContext.findRenderObject() as RenderBox?;
    _leavingApp();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/octet-stream')],
        // iPad anchors the share sheet here
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  });

  Future<void> _pickFolder() => _run(() async {
    _leavingApp();
    await _service.pickFolder();
    _reload();
  });

  Future<void> _restoreFromFile() async {
    _leavingApp();
    final picked = await openFile();
    if (picked == null || !mounted) {
      return;
    }
    final BackupData data;
    try {
      data = BackupCodec.decode(await picked.readAsBytes());
    } on BackupException catch (e) {
      logger.e(e);
      return _showError(e.error);
    }
    await _restore(data);
  }

  Future<void> _restoreStored(StoredBackup backup) async {
    try {
      await _restore(await _service.read(backup.file));
    } on BackupException catch (e) {
      logger.e(e);
      await _showError(e.error);
    }
  }

  Future<void> _restore(BackupData data) async {
    if (!mounted) {
      return;
    }
    final mode = await RestoreSheet.show(context, data);
    if (mode == null || !mounted) {
      return;
    }
    await _run(() async {
      final result = await _service.restore(data, mode);
      if (!mounted) {
        return;
      }
      AppHaptics.medium();
      _snack(context.l10n.restoredSummary(result.tasks));
      _reload();
    });
  }

  Future<void> _showError(BackupError error) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded),
        title: Text(l10n.restoreFailedTitle),
        content: Text(switch (error) {
          BackupError.unreadable => l10n.backupUnreadable,
          BackupError.tooNew => l10n.backupTooNew,
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupTitle),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Status(service: _service),
          _Group(
            title: l10n.backupSection,
            children: [
              ValueListenableBuilder(
                valueListenable: _service.autoOn,
                builder: (context, on, _) => SwitchListTile(
                  secondary: const Icon(Icons.history_rounded),
                  title: Text(l10n.backupDaily),
                  subtitle: Text(l10n.backupDailyHint),
                  value: on,
                  onChanged: (on) {
                    AppHaptics.selection();
                    unawaited(_service.setAuto(on));
                  },
                ),
              ),
              const Divider(indent: 56, height: 1),
              ValueListenableBuilder(
                valueListenable: _service.folderName,
                builder: (context, folder, _) => ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(l10n.backupFolder),
                  subtitle: Text(
                    folder ??
                        (Platform.isIOS
                            ? l10n.backupFolderHintIos
                            : l10n.backupFolderHintAndroid),
                  ),
                  onTap: _busy ? null : _pickFolder,
                  trailing: folder == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                          tooltip: l10n.backupFolderRemove,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _service.clearFolder,
                        ),
                ),
              ),
              const Divider(indent: 56, height: 1),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(l10n.backupNow),
                onTap: _busy ? null : _backupNow,
              ),
              const Divider(indent: 56, height: 1),
              Builder(
                builder: (buttonContext) => ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: Text(l10n.backupExport),
                  subtitle: Text(l10n.backupExportHint),
                  onTap: _busy ? null : () => _export(buttonContext),
                ),
              ),
            ],
          ),
          _Group(
            title: l10n.restoreSection,
            children: [
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: Text(l10n.restoreFromFile),
                subtitle: Text(l10n.restoreFromFileHint),
                onTap: _busy ? null : _restoreFromFile,
              ),
              FutureBuilder(
                future: _stored,
                builder: (context, snapshot) {
                  final stored = snapshot.data ?? const <StoredBackup>[];
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox.shrink();
                  }
                  if (stored.isEmpty) {
                    return ListTile(
                      leading: const SizedBox(width: 24),
                      subtitle: Text(l10n.restoreNoBackups),
                    );
                  }
                  return Column(
                    children: [
                      for (final backup in stored) ...[
                        const Divider(indent: 56, height: 1),
                        _StoredTile(
                          backup: backup,
                          service: _service,
                          onTap: _busy ? null : () => _restoreStored(backup),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Last backup: today 9:00 · also in “Backups”"
class _Status extends StatelessWidget {
  const _Status({required this.service});

  final BackupService service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([service.lastBackup, service.folderName]),
      builder: (context, _) {
        final last = service.lastBackup.value;
        final folder = service.folderName.value;
        return Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  last == null
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                  size: 32,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        last == null
                            ? l10n.backupNone
                            : l10n.backupLast(backupWhen(context, last)),
                        style: textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        folder == null
                            ? l10n.backupOnDeviceOnly
                            : l10n.backupAlsoIn(folder),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One backup on the phone: when, why, what's in it
class _StoredTile extends StatefulWidget {
  const _StoredTile({
    required this.backup,
    required this.service,
    required this.onTap,
  });

  final StoredBackup backup;
  final BackupService service;
  final VoidCallback? onTap;

  @override
  State<_StoredTile> createState() => _StoredTileState();
}

class _StoredTileState extends State<_StoredTile> {
  late final Future<BackupData?> _data = _read();

  Future<BackupData?> _read() async {
    try {
      return await widget.service.read(widget.backup.file);
    } on BackupException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = switch (widget.backup.kind) {
      BackupKind.daily => l10n.backupAuto,
      BackupKind.beforeRestore => l10n.backupBeforeRestore,
    };
    return FutureBuilder(
      future: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final done = snapshot.connectionState == ConnectionState.done;
        return ListTile(
          leading: Icon(
            widget.backup.kind == BackupKind.daily
                ? Icons.restore_rounded
                : Icons.undo_rounded,
          ),
          title: Text(
            data == null
                ? widget.backup.name
                : '${backupWhen(context, data.createdAt)} · $kind',
          ),
          subtitle: Text(
            data != null
                ? backupContents(context, data)
                : done
                ? l10n.backupUnreadableItem
                : '',
          ),
          enabled: data != null,
          onTap: widget.onTap,
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
