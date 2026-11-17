import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../core/backup/backup_codec.dart';
import '../local/database/app_database.dart';

enum RestoreMode {
  /// Add what's new, update what the backup has a newer copy of, keep the rest
  merge,

  /// Make the app exactly what the backup holds
  replace,
}

class RestoreResult {
  const RestoreResult({required this.tasks, required this.lists});

  /// Top-level tasks added or updated
  final int tasks;

  /// Lists added or updated
  final int lists;
}

/// Reads the whole database into a [BackupData] and writes one back.
@lazySingleton
class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  Future<BackupData> snapshot({String? appVersion, DateTime? now}) async {
    final lists =
        await (_db.select(_db.taskLists)
              ..where((l) => l.deletedAt.isNull())
              ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
            .get();
    final tasks =
        await (_db.select(_db.tasks)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final activity = await (_db.select(
      _db.activityDays,
    )..orderBy([(a) => OrderingTerm.asc(a.day)])).get();
    return BackupData(
      createdAt: now ?? DateTime.now(),
      schema: _db.schemaVersion,
      appVersion: appVersion,
      lists: lists,
      tasks: tasks,
      activity: activity,
    );
  }

  /// Applies [data] in one transaction: if anything fails, nothing changes.
  Future<RestoreResult> restore(BackupData data, RestoreMode mode) {
    return _db.transaction(() async {
      final listsBefore = {
        for (final l in await _db.select(_db.taskLists).get()) l.id: l,
      };
      final tasksBefore = mode == RestoreMode.replace
          ? const <String, Task>{}
          : {for (final t in await _db.select(_db.tasks).get()) t.id: t};
      if (mode == RestoreMode.replace) {
        // Tasks point at lists: remove them first
        await _db.delete(_db.tasks).go();
        await _db.delete(_db.taskLists).go();
        await _db.delete(_db.activityDays).go();
        listsBefore.clear();
      }

      var lists = 0;
      for (final list in data.lists) {
        final local = listsBefore[list.id];
        // Deleted here since the backup: bring it back with its tasks
        if (local == null ||
            local.deletedAt != null ||
            list.updatedAt.isAfter(local.updatedAt)) {
          // Upsert, never "replace": that would delete the row its tasks
          // point at. Every column is written, nulls included, so a
          // deleted list comes back.
          await _db
              .into(_db.taskLists)
              .insertOnConflictUpdate(list.toCompanion(false));
          lists++;
        }
      }

      // A task whose list exists nowhere goes to the Inbox
      final knownLists = {
        ...listsBefore.keys,
        for (final l in data.lists) l.id,
      };
      var tasks = 0;
      for (final task in data.tasks) {
        final local = tasksBefore[task.id];
        if (local != null &&
            local.deletedAt == null &&
            !task.updatedAt.isAfter(local.updatedAt)) {
          continue;
        }
        final listId = task.listId;
        final row = listId == null || knownLists.contains(listId)
            ? task
            : task.copyWith(listId: const Value(null));
        await _db
            .into(_db.tasks)
            .insertOnConflictUpdate(row.toCompanion(false));
        if (task.parentId == null) {
          tasks++;
        }
      }

      // Completions per day: the higher count of the two
      final activityBefore = {
        for (final a in await _db.select(_db.activityDays).get()) a.day: a,
      };
      for (final day in data.activity) {
        final local = activityBefore[day.day];
        await _db
            .into(_db.activityDays)
            .insertOnConflictUpdate(
              ActivityDay(
                day: day.day,
                completedCount: math.max(
                  day.completedCount,
                  local?.completedCount ?? 0,
                ),
              ),
            );
      }
      return RestoreResult(tasks: tasks, lists: lists);
    });
  }
}
