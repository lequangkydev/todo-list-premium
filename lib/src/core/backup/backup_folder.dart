import 'package:flutter/services.dart';

import '../../shared/helpers/logger_utils.dart';

/// A folder outside the app that the user picked — Google Drive or any
/// folder on Android (Storage Access Framework), iCloud Drive or any Files
/// location on iOS — where daily backups are copied, so they survive losing
/// the phone. Access is kept across launches (persisted URI permission /
/// security-scoped bookmark). No account or server of ours involved.
class BackupFolder {
  const BackupFolder();

  static const _channel = MethodChannel('todolist/backup_folder');

  /// The picked folder's name, or null when none is set (or it's gone)
  Future<String?> name() => _call<String>('name');

  /// Lets the user pick a folder; returns its name, or null if cancelled
  Future<String?> pick() => _call<String>('pick');

  Future<void> clear() => _call<void>('clear');

  /// Writes (or overwrites) [fileName] in the folder. False when there is
  /// no folder or it can't be written any more.
  Future<bool> write(String fileName, Uint8List bytes) async =>
      await _call<bool>('write', {'name': fileName, 'bytes': bytes}) ?? false;

  /// Deletes all but the newest [keep] files whose name starts with [prefix]
  Future<void> prune(String prefix, int keep) =>
      _call<void>('prune', {'prefix': prefix, 'keep': keep});

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      logger.e(e);
      return null;
    } on MissingPluginException {
      // Tests, or a platform without it
      return null;
    }
  }
}
