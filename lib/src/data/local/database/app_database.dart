import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [TaskLists, Tasks, ActivityDays])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
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

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
