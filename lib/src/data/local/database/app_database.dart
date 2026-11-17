import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.steps.dart';
import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [TaskLists, Tasks, ActivityDays])
class AppDatabase extends _$AppDatabase {
  /// [executor] replaces the on-disk database (tests, migration checks)
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'todo',
              native: DriftNativeOptions(
                // Shared across isolates so notification actions handled in the
                // background (Done / Snooze) refresh the UI streams.
                shareAcrossIsolates: true,
                databasePath: () async {
                  final dir = await getApplicationSupportDirectory();
                  return p.join(dir.path, 'todo.sqlite');
                },
              ),
            ),
      );

  AppDatabase.forTesting(QueryExecutor executor) : this(executor);

  /// Changing the schema:
  /// 1. Edit the tables and bump this number.
  /// 2. Run `dart run drift_dev make-migrations`. It snapshots the new schema
  ///    in `drift_schemas/`, generates `app_database.steps.dart` and
  ///    migration tests in `test/drift/`.
  /// 3. Add the step to `onUpgrade: stepByStep(...)` in [migration] below
  ///    and make the generated tests pass.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.tasks, schema.tasks.estimateMinutes);
      },
      from2To3: (m, schema) async {
        // One reminder per task (remind_offset) becomes a list, plus the
        // alarm flag. Rebuilding the table drops the old column.
        await m.alterTable(
          TableMigration(
            schema.tasks,
            columnTransformer: {
              schema.tasks.reminders: const CustomExpression<String>(
                "COALESCE(CAST(remind_offset AS TEXT), '')",
              ),
            },
            newColumns: [schema.tasks.alarm],
          ),
        );
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
