import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/local/database/converters.dart';
import 'backup_codec.dart';

/// Why a backup file was made
enum BackupKind {
  /// Once a day, automatically
  daily('todo-auto-', keep: 7),

  /// The data as it was just before a restore replaced or merged into it
  beforeRestore('todo-before-restore-', keep: 3);

  const BackupKind(this.prefix, {required this.keep});

  final String prefix;

  /// How many of this kind are kept; older ones are deleted
  final int keep;

  static BackupKind? ofName(String name) {
    for (final kind in values) {
      if (name.startsWith(kind.prefix)) {
        return kind;
      }
    }
    return null;
  }
}

/// A backup file in the app's own folder
class StoredBackup {
  const StoredBackup(this.file, this.kind);

  final File file;
  final BackupKind kind;

  String get name => p.basename(file.path);
}

/// The app's backup folder on the device: names, writing, listing, pruning.
class BackupStore {
  BackupStore(this.dir);

  final Directory dir;

  /// `todo-auto-2026-11-17.todobackup`: one per day, a second run that day
  /// replaces the first
  static String nameFor(BackupKind kind, DateTime at) {
    final day = const LocalDateConverter().toSql(at);
    final stamp = switch (kind) {
      BackupKind.daily => day,
      BackupKind.beforeRestore => '$day-${_two(at.hour)}${_two(at.minute)}',
    };
    return '${kind.prefix}$stamp.${BackupCodec.extension}';
  }

  /// `todo-2026-11-17-1030.todobackup`, for sharing
  static String exportName(DateTime at) =>
      'todo-${const LocalDateConverter().toSql(at)}-'
      '${_two(at.hour)}${_two(at.minute)}.${BackupCodec.extension}';

  Future<File> write(BackupKind kind, Uint8List bytes, DateTime at) async {
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, nameFor(kind, at)));
    // Write aside, then rename: a crash never leaves half a backup behind
    final temp = File('${file.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
    await prune(kind);
    return file;
  }

  /// Newest first
  Future<List<StoredBackup>> list() async {
    if (!dir.existsSync()) {
      return const [];
    }
    final backups = <StoredBackup>[];
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      final kind = BackupKind.ofName(name);
      if (entity is File &&
          kind != null &&
          name.endsWith('.${BackupCodec.extension}')) {
        backups.add(StoredBackup(entity, kind));
      }
    }
    // Names carry the date; within a day, the later file first
    backups.sort((a, b) {
      final byStamp = _stamp(b.name).compareTo(_stamp(a.name));
      return byStamp != 0 ? byStamp : b.name.compareTo(a.name);
    });
    return backups;
  }

  Future<void> prune(BackupKind kind) async {
    final ofKind = [
      for (final b in await list())
        if (b.kind == kind) b,
    ];
    for (final old in ofKind.skip(kind.keep)) {
      await old.file.delete();
    }
  }

  static String _stamp(String name) {
    final kind = BackupKind.ofName(name);
    return kind == null ? name : name.substring(kind.prefix.length);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
