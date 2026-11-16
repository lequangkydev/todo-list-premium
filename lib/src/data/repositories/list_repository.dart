import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';
import 'task_repository.dart';

/// A list with its number of open top-level tasks
class ListWithCount {
  const ListWithCount(this.list, this.openCount);

  final TaskList list;
  final int openCount;
}

/// Calm, colour-blind-friendly list colours
const listColors = <int>[
  0xFF4F7A6B, // sage
  0xFF3B6EA8, // blue
  0xFF8A6BBE, // lavender
  0xFFC2733A, // amber
  0xFFB45A73, // rose
  0xFF4A8C9C, // teal
  0xFF7A7F3A, // olive
  0xFF6B7280, // slate
];

@lazySingleton
class ListRepository {
  ListRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<ListWithCount>> watchLists() {
    final l = _db.taskLists;
    final t = _db.tasks;
    final open = t.id.count();
    final query =
        _db.select(l).join([
            leftOuterJoin(
              t,
              t.listId.equalsExp(l.id) &
                  t.deletedAt.isNull() &
                  t.isDone.equals(false) &
                  t.parentId.isNull(),
              useColumns: false,
            ),
          ])
          ..addColumns([open])
          ..where(l.deletedAt.isNull())
          ..groupBy([l.id])
          ..orderBy([OrderingTerm.asc(l.sortOrder)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          ListWithCount(row.readTable(l), row.read(open) ?? 0),
      ],
    );
  }

  /// Open top-level tasks in the Inbox
  Stream<int> watchInboxCount() {
    final t = _db.tasks;
    final count = t.id.count();
    return (_db.selectOnly(t)
          ..addColumns([count])
          ..where(
            t.listId.isNull() &
                t.deletedAt.isNull() &
                t.isDone.equals(false) &
                t.parentId.isNull(),
          ))
        .map((r) => r.read(count) ?? 0)
        .watchSingle();
  }

  Stream<TaskList?> watchList(String id) => (_db.select(
    _db.taskLists,
  )..where((l) => l.id.equals(id))).watchSingleOrNull();

  Future<String> create(String name, int color) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final max = _db.taskLists.sortOrder.max();
    final last = await (_db.selectOnly(
      _db.taskLists,
    )..addColumns([max])).map((r) => r.read(max)).getSingleOrNull();
    await _db
        .into(_db.taskLists)
        .insert(
          TaskListsCompanion.insert(
            id: id,
            name: name.trim(),
            colorValue: color,
            sortOrder: (last ?? 0) + 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(String id, {String? name, int? color}) {
    return (_db.update(_db.taskLists)..where((l) => l.id.equals(id))).write(
      TaskListsCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        colorValue: color == null ? const Value.absent() : Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft-deletes the list and its tasks together so undo restores both
  Future<Undo> delete(String id) async {
    final at = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.taskLists)..where((l) => l.id.equals(id))).write(
        TaskListsCompanion(deletedAt: Value(at)),
      );
      await (_db.update(_db.tasks)
            ..where((t) => t.listId.equals(id) & t.deletedAt.isNull()))
          .write(TasksCompanion(deletedAt: Value(at)));
      // Subtasks don't carry listId
      await _db.customUpdate(
        'UPDATE tasks SET deleted_at = ? WHERE deleted_at IS NULL AND '
        'parent_id IN (SELECT id FROM tasks WHERE list_id = ?)',
        variables: [Variable.withDateTime(at), Variable.withString(id)],
        updates: {_db.tasks},
      );
    });
    return () => _db.transaction(() async {
      await (_db.update(_db.taskLists)..where((l) => l.id.equals(id))).write(
        const TaskListsCompanion(deletedAt: Value(null)),
      );
      await (_db.update(_db.tasks)..where((t) => t.deletedAt.equals(at))).write(
        const TasksCompanion(deletedAt: Value(null)),
      );
    });
  }
}
