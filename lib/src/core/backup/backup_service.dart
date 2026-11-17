import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/backup_repository.dart';
import '../../shared/helpers/logger_utils.dart';
import '../date/dates.dart';
import 'backup_codec.dart';
import 'backup_folder.dart';
import 'backup_store.dart';

/// Backups without an account: a copy on the device every day (the newest
/// [BackupKind.daily] `keep`), the same copy in a folder the user picked
/// (Drive, iCloud Drive…), export through the share sheet, and restore that
/// first saves what's there now.
@lazySingleton
class BackupService with WidgetsBindingObserver {
  BackupService(this._repo);

  final BackupRepository _repo;

  /// Replaceable in tests
  @visibleForTesting
  BackupFolder folder = const BackupFolder();

  @visibleForTesting
  Future<Directory> Function() directory = _defaultDirectory;

  static const _autoKey = 'backup_auto';
  static const _lastKey = 'backup_last';

  final autoOn = ValueNotifier<bool>(true);

  /// When the last daily backup was made
  final lastBackup = ValueNotifier<DateTime?>(null);

  /// Name of the folder backups are copied to, if any
  final folderName = ValueNotifier<String?>(null);

  Future<StoredBackup?>? _running;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    final prefs = await SharedPreferences.getInstance();
    autoOn.value = prefs.getBool(_autoKey) ?? true;
    lastBackup.value = DateTime.tryParse(prefs.getString(_lastKey) ?? '');
    folderName.value = await folder.name();
    WidgetsBinding.instance.addObserver(this);
    await runDailyIfDue();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(runDailyIfDue());
    }
  }

  Future<BackupStore> store() async => BackupStore(await directory());

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'backups'),
  );

  /// Makes today's backup unless there already is one (or it's turned off)
  Future<StoredBackup?> runDailyIfDue({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final last = lastBackup.value;
    if (!autoOn.value || (last != null && Dates.isSameDay(last, at))) {
      return null;
    }
    return backupNow(now: at);
  }

  /// Today's backup, now: on the device and in the picked folder. Null when
  /// there is nothing to back up yet, or it failed.
  Future<StoredBackup?> backupNow({DateTime? now}) {
    // A resume while the first backup is still writing shouldn't start
    // another
    return _running ??= _backup(
      now ?? DateTime.now(),
    ).whenComplete(() => _running = null);
  }

  Future<StoredBackup?> _backup(DateTime at) async {
    try {
      final data = await _repo.snapshot(
        appVersion: await _appVersion(),
        now: at,
      );
      if (data.isEmpty) {
        return null;
      }
      final bytes = BackupCodec.encode(data);
      final file = await (await store()).write(BackupKind.daily, bytes, at);
      await _copyToFolder(BackupStore.nameFor(BackupKind.daily, at), bytes);
      lastBackup.value = at;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastKey, at.toIso8601String());
      return StoredBackup(file, BackupKind.daily);
    } on Exception catch (e) {
      logger.e(e);
      return null;
    }
  }

  Future<void> _copyToFolder(String name, Uint8List bytes) async {
    if (folderName.value == null) {
      return;
    }
    if (await folder.write(name, bytes)) {
      await folder.prune(BackupKind.daily.prefix, BackupKind.daily.keep);
    } else {
      // Folder removed, or access revoked: show that it's no longer set
      folderName.value = await folder.name();
    }
  }

  /// A backup file to hand to the share sheet
  Future<({String name, Uint8List bytes})> export({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final data = await _repo.snapshot(appVersion: await _appVersion(), now: at);
    return (name: BackupStore.exportName(at), bytes: BackupCodec.encode(data));
  }

  /// Reads a backup file, or throws [BackupException]
  Future<BackupData> read(File file) async {
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw BackupException(BackupError.unreadable, e);
    }
    return BackupCodec.decode(bytes);
  }

  /// Restores [data]. What's in the app now is saved first (kept among the
  /// backups as "before restore"), so a wrong choice can be undone.
  Future<RestoreResult> restore(
    BackupData data,
    RestoreMode mode, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final current = await _repo.snapshot(
      appVersion: await _appVersion(),
      now: at,
    );
    if (!current.isEmpty) {
      await (await store()).write(
        BackupKind.beforeRestore,
        BackupCodec.encode(current),
        at,
      );
    }
    return _repo.restore(data, mode);
  }

  Future<void> setAuto(bool on) async {
    autoOn.value = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoKey, on);
    if (on) {
      await runDailyIfDue();
    }
  }

  /// Lets the user pick the folder, then puts today's backup in it right
  /// away so they can see it worked. Returns the folder name.
  Future<String?> pickFolder() async {
    final name = await folder.pick();
    if (name == null) {
      return null;
    }
    folderName.value = name;
    await backupNow();
    return name;
  }

  Future<void> clearFolder() async {
    await folder.clear();
    folderName.value = null;
  }

  static Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } on Exception {
      return null;
    }
  }

  @disposeMethod
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
