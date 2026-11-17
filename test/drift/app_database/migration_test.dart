// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 keeps every row', () async {
    const list = (
      id: 'l1',
      name: 'Groceries',
      colorValue: 0xFF4F7A6B,
      sortOrder: 1.0,
      createdAt: 1763000000,
      updatedAt: 1763000000,
    );
    final oldTaskListsData = <v1.TaskListsData>[
      v1.TaskListsData(
        id: list.id,
        name: list.name,
        colorValue: list.colorValue,
        sortOrder: list.sortOrder,
        createdAt: list.createdAt,
        updatedAt: list.updatedAt,
      ),
    ];
    final expectedNewTaskListsData = <v2.TaskListsData>[
      v2.TaskListsData(
        id: list.id,
        name: list.name,
        colorValue: list.colorValue,
        sortOrder: list.sortOrder,
        createdAt: list.createdAt,
        updatedAt: list.updatedAt,
      ),
    ];

    final oldTasksData = <v1.TasksData>[
      const v1.TasksData(
        id: 't1',
        listId: 'l1',
        title: 'Buy milk',
        note: 'Oat',
        dueDate: '2026-11-14',
        dueTime: 540,
        priority: 2,
        isDone: 0,
        rrule: 'FREQ=WEEKLY;BYDAY=SA',
        remindOffset: 0,
        sortOrder: 1,
        createdAt: 1763000000,
        updatedAt: 1763000000,
      ),
    ];
    final expectedNewTasksData = <v2.TasksData>[
      const v2.TasksData(
        id: 't1',
        listId: 'l1',
        title: 'Buy milk',
        note: 'Oat',
        dueDate: '2026-11-14',
        dueTime: 540,
        priority: 2,
        isDone: 0,
        rrule: 'FREQ=WEEKLY;BYDAY=SA',
        remindOffset: 0,
        sortOrder: 1,
        createdAt: 1763000000,
        updatedAt: 1763000000,
      ),
    ];

    final oldActivityDaysData = <v1.ActivityDaysData>[
      const v1.ActivityDaysData(day: '2026-11-13', completedCount: 3),
    ];
    final expectedNewActivityDaysData = <v2.ActivityDaysData>[
      const v2.ActivityDaysData(day: '2026-11-13', completedCount: 3),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.taskLists, oldTaskListsData);
        batch.insertAll(oldDb.tasks, oldTasksData);
        batch.insertAll(oldDb.activityDays, oldActivityDaysData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewTaskListsData,
          await newDb.select(newDb.taskLists).get(),
        );
        expect(expectedNewTasksData, await newDb.select(newDb.tasks).get());
        expect(
          expectedNewActivityDaysData,
          await newDb.select(newDb.activityDays).get(),
        );
      },
    );
  });
}
