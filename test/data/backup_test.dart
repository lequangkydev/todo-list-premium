import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_base/src/core/backup/backup_codec.dart';
import 'package:flutter_base/src/core/backup/backup_folder.dart';
import 'package:flutter_base/src/core/backup/backup_service.dart';
import 'package:flutter_base/src/core/backup/backup_store.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/repositories/backup_repository.dart';
import 'package:flutter_base/src/data/repositories/list_repository.dart';
import 'package:flutter_base/src/data/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what would go to the picked folder
class _FakeFolder implements BackupFolder {
  String? folder;
  final files = <String, Uint8List>{};

  @override
  Future<String?> name() async => folder;

  @override
  Future<String?> pick() async => folder = 'Drive/Backups';

  @override
  Future<void> clear() async => folder = null;

  @override
  Future<bool> write(String fileName, Uint8List bytes) async {
    if (folder == null) {
      return false;
    }
    files[fileName] = bytes;
    return true;
  }

  @override
  Future<void> prune(String prefix, int keep) async {
    final names = files.keys.where((n) => n.startsWith(prefix)).toList()
      ..sort((a, b) => b.compareTo(a));
    names.skip(keep).forEach(files.remove);
  }
}

class _Db {
  _Db() : db = AppDatabase(NativeDatabase.memory()) {
    tasks = TaskRepository(db);
    lists = ListRepository(db);
    backup = BackupRepository(db);
  }

  final AppDatabase db;
  late final TaskRepository tasks;
  late final ListRepository lists;
  late final BackupRepository backup;

  Future<List<Task>> allTasks() =>
      (db.select(db.tasks)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<List<TaskList>> allLists() =>
      (db.select(db.taskLists)..orderBy([(l) => OrderingTerm.asc(l.id)])).get();

  Future<List<ActivityDay>> allActivity() => db.select(db.activityDays).get();
}

/// A realistic little database: lists, timed / all-day / recurring / lunar
/// tasks, reminders, a subtask, completions, a deleted task
Future<void> _seed(_Db d) async {
  final work = await d.lists.create('Work', 0xFF4F7A6B);
  final home = await d.lists.create('Nhà', 0xFFB4543A);
  await d.tasks.create(
    TaskDraft(
      title: 'Họp nhóm',
      listId: work,
      dueDate: DateTime(2026, 11, 18),
      dueTime: 9 * 60 + 30,
      priority: 3,
      reminders: const [0, 15],
      alarm: true,
      estimateMinutes: 45,
      note: 'Phòng 2',
    ),
  );
  await d.tasks.create(
    TaskDraft(
      title: 'Giỗ ông',
      listId: home,
      dueDate: DateTime(2027, 4, 16),
      rrule: 'FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=10;X-CAL=LUNAR',
      reminders: const [1440],
    ),
  );
  final parent = await d.tasks.create(
    TaskDraft(title: 'Dọn nhà', listId: home, dueDate: DateTime(2026, 11, 20)),
  );
  await d.tasks.create(TaskDraft(title: 'Lau kính', parentId: parent));
  final water = await d.tasks.create(
    TaskDraft(
      title: 'Water plants',
      dueDate: DateTime(2026, 11, 13),
      rrule: 'FREQ=DAILY',
    ),
  );
  await d.tasks.complete(
    (await d.tasks.getTask(water))!,
    now: DateTime(2026, 11, 13, 8),
  );
  await d.tasks.create(const TaskDraft(title: 'Inbox idea'));
  final gone = await d.tasks.create(const TaskDraft(title: 'Deleted'));
  await d.tasks.delete(gone);
}

void main() {
  // Platform calls (app version) need the binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('codec', () {
    late _Db a;

    setUp(() => a = _Db());
    tearDown(() => a.db.close());

    test('everything but deleted rows survives encode → decode', () async {
      await _seed(a);
      final data = await a.backup.snapshot(
        appVersion: '2.0.0+20',
        now: DateTime(2026, 11, 17, 10),
      );
      final back = BackupCodec.decode(BackupCodec.encode(data));
      expect(back.tasks, data.tasks);
      expect(back.lists, data.lists);
      expect(back.activity, data.activity);
      expect(back.createdAt, data.createdAt);
      expect(back.appVersion, '2.0.0+20');
      expect(back.schema, a.db.schemaVersion);
      expect(back.tasks.map((t) => t.title), isNot(contains('Deleted')));
      // 'Water plants' (moved on) + its done copy, Họp, Giỗ, Dọn nhà, Inbox
      expect(back.taskCount, 6);
      expect(back.openCount, 5);
    });

    test('days are written as days, moments in UTC', () async {
      await _seed(a);
      final bytes = BackupCodec.encode(await a.backup.snapshot());
      final json =
          jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, Object?>;
      final tasks = (json['tasks']! as List).cast<Map<String, Object?>>();
      final meeting = tasks.firstWhere((t) => t['title'] == 'Họp nhóm');
      // Restores on the 18th in any time zone
      expect(meeting['due'], '2026-11-18');
      expect(meeting['time'], 570);
      expect(meeting['reminders'], [0, 15]);
      expect(meeting['alarm'], isTrue);
      expect(meeting['createdAt'], endsWith('Z'));
      expect(json['format'], 'todobackup');
      expect(json['version'], BackupCodec.version);
    });

    Uint8List pack(Object json) =>
        Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(json))));

    test('an older backup with fewer fields gets the defaults', () {
      final data = BackupCodec.decode(
        pack({
          'format': 'todobackup',
          'version': 1,
          'createdAt': '2026-11-01T02:00:00.000Z',
          'tasks': [
            {
              'id': 't1',
              'title': 'Old',
              'createdAt': '2026-10-01T02:00:00.000Z',
              'updatedAt': '2026-10-01T02:00:00.000Z',
              // Something a future version might add
              'colour': 'teal',
            },
          ],
        }),
      );
      final task = data.tasks.single;
      expect(task.reminderOffsets, isEmpty);
      expect(task.alarm, isFalse);
      expect(task.priority, 0);
      expect(task.isDone, isFalse);
      expect(data.lists, isEmpty);
      expect(data.activity, isEmpty);
    });

    test('damaged or foreign files are refused, clearly', () {
      Matcher fails(BackupError error) => throwsA(
        isA<BackupException>().having((e) => e.error, 'error', error),
      );
      final good = pack({
        'format': 'todobackup',
        'version': 1,
        'createdAt': '2026-11-01T02:00:00.000Z',
      });
      expect(
        () => BackupCodec.decode(utf8.encode('hello')),
        fails(BackupError.unreadable),
      );
      expect(
        () => BackupCodec.decode(good.sublist(0, good.length ~/ 2)),
        fails(BackupError.unreadable),
      );
      expect(
        () => BackupCodec.decode(pack({'tasks': []})),
        fails(BackupError.unreadable),
      );
      expect(
        () => BackupCodec.decode(pack([1, 2, 3])),
        fails(BackupError.unreadable),
      );
      expect(
        () => BackupCodec.decode(
          pack({
            'format': 'todobackup',
            'version': 1,
            'createdAt': '2026-11-01T02:00:00.000Z',
            'tasks': [
              {'id': 't1', 'createdAt': 'x'},
            ],
          }),
        ),
        fails(BackupError.unreadable),
      );
      expect(
        () => BackupCodec.decode(
          pack({
            'format': 'todobackup',
            'version': 1,
            'createdAt': '2026-11-01T02:00:00.000Z',
            'tasks': [
              {
                'id': 't1',
                'title': 'Bad date',
                'due': '18/11/2026',
                'createdAt': '2026-10-01T02:00:00.000Z',
                'updatedAt': '2026-10-01T02:00:00.000Z',
              },
            ],
          }),
        ),
        fails(BackupError.unreadable),
      );
      expect(
        () => BackupCodec.decode(
          pack({'format': 'todobackup', 'version': 99, 'createdAt': 'x'}),
        ),
        fails(BackupError.tooNew),
      );
    });
  });

  group('restore', () {
    late _Db source;
    late _Db target;

    setUp(() {
      source = _Db();
      target = _Db();
    });

    tearDown(() async {
      await source.db.close();
      await target.db.close();
    });

    test('export on one phone, import on another: identical', () async {
      await _seed(source);
      final file = BackupCodec.encode(await source.backup.snapshot());
      // Something already on the new phone that the backup replaces
      await target.tasks.create(const TaskDraft(title: 'Fresh install task'));

      final result = await target.backup.restore(
        BackupCodec.decode(file),
        RestoreMode.replace,
      );

      final alive = (await source.allTasks())
          .where((t) => t.deletedAt == null)
          .toList();
      expect(await target.allTasks(), alive);
      expect(await target.allLists(), await source.allLists());
      expect(await target.allActivity(), await source.allActivity());
      expect(result.tasks, 6);
      expect(result.lists, 2);
    });

    test('merge adds, updates older copies, keeps newer local ones', () async {
      final id = await source.tasks.create(
        TaskDraft(title: 'Shared', dueDate: DateTime(2026, 11, 20)),
      );
      final older = await source.tasks.create(const TaskDraft(title: 'Older'));
      final backup = BackupCodec.decode(
        BackupCodec.encode(await source.backup.snapshot()),
      );
      // The target already has both, edited at different times
      final shared = backup.tasks.firstWhere((t) => t.id == id);
      final olderRow = backup.tasks.firstWhere((t) => t.id == older);
      await target.db
          .into(target.db.tasks)
          .insert(
            shared.copyWith(
              title: 'Shared, edited later here',
              updatedAt: shared.updatedAt.add(const Duration(hours: 1)),
            ),
          );
      await target.db
          .into(target.db.tasks)
          .insert(
            olderRow.copyWith(
              title: 'Older, stale here',
              note: const Value('stale note'),
              updatedAt: olderRow.updatedAt.subtract(const Duration(hours: 1)),
            ),
          );
      final mine = await target.tasks.create(const TaskDraft(title: 'Mine'));
      // The backup has something new too
      final extra = await source.tasks.create(const TaskDraft(title: 'New'));
      final withNew = await source.backup.snapshot();

      final result = await target.backup.restore(withNew, RestoreMode.merge);

      final titles = {for (final t in await target.allTasks()) t.id: t};
      expect(titles[id]!.title, 'Shared, edited later here');
      expect(titles[older]!.title, 'Older');
      // A newer backup copy clears what it doesn't have
      expect(titles[older]!.note, isNull);
      expect(titles[mine]!.title, 'Mine');
      expect(titles[extra]!.title, 'New');
      expect(result.tasks, 2);
    });

    test('merge brings back what was deleted since the backup', () async {
      final list = await target.lists.create('Trip', 0xFF336699);
      final task = await target.tasks.create(
        TaskDraft(title: 'Passport', listId: list),
      );
      final backup = await target.backup.snapshot();
      await target.lists.delete(list);

      await target.backup.restore(backup, RestoreMode.merge);

      final lists = await target.allLists();
      expect(lists.single.deletedAt, isNull);
      expect((await target.tasks.getTask(task))!.deletedAt, isNull);
    });

    test('a task whose list exists nowhere lands in the Inbox', () async {
      final data = BackupData(
        createdAt: DateTime(2026, 11, 17),
        lists: const [],
        activity: const [],
        tasks: [
          Task(
            id: 'orphan',
            listId: 'missing-list',
            title: 'Orphan',
            priority: 0,
            isDone: false,
            reminders: '',
            alarm: false,
            sortOrder: 1,
            createdAt: DateTime(2026, 11),
            updatedAt: DateTime(2026, 11),
          ),
        ],
      );
      await target.backup.restore(data, RestoreMode.merge);
      expect((await target.tasks.getTask('orphan'))!.listId, isNull);
    });

    test('completion counts per day keep the higher one', () async {
      DateTime day(int d) => DateTime(2026, 11, d);
      await target.db
          .into(target.db.activityDays)
          .insert(ActivityDay(day: day(10), completedCount: 5));
      final data = BackupData(
        createdAt: day(17),
        lists: const [],
        tasks: const [],
        activity: [
          ActivityDay(day: day(10), completedCount: 2),
          ActivityDay(day: day(11), completedCount: 3),
        ],
      );
      await target.backup.restore(data, RestoreMode.merge);
      final counts = {
        for (final a in await target.allActivity()) a.day.day: a.completedCount,
      };
      expect(counts, {10: 5, 11: 3});
    });
  });

  group('daily backups', () {
    late _Db d;
    late Directory dir;
    late BackupService service;
    late _FakeFolder folder;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      d = _Db();
      dir = await Directory.systemTemp.createTemp('backups');
      folder = _FakeFolder();
      service = BackupService(d.backup)
        ..folder = folder
        ..directory = (() async => dir);
    });

    tearDown(() async {
      await d.db.close();
      await dir.delete(recursive: true);
    });

    test('nothing to back up yet: no file', () async {
      expect(await service.runDailyIfDue(now: DateTime(2026, 11, 17)), isNull);
      expect(await (await service.store()).list(), isEmpty);
    });

    test('once a day, the newest 7 kept, copied to the folder', () async {
      await d.tasks.create(const TaskDraft(title: 'Something'));
      folder.folder = 'Drive/Backups';
      service.folderName.value = 'Drive/Backups';

      expect(
        await service.runDailyIfDue(now: DateTime(2026, 11, 1, 9)),
        isNotNull,
      );
      // Later the same day: already done
      expect(
        await service.runDailyIfDue(now: DateTime(2026, 11, 1, 18)),
        isNull,
      );
      for (var day = 2; day <= 10; day++) {
        await service.runDailyIfDue(now: DateTime(2026, 11, day, 9));
      }

      final stored = await (await service.store()).list();
      expect(stored.map((b) => b.name), [
        for (var day = 10; day >= 4; day--)
          'todo-auto-2026-11-${day.toString().padLeft(2, '0')}.todobackup',
      ]);
      expect(folder.files.keys.toList()..sort(), [
        for (var day = 4; day <= 10; day++)
          'todo-auto-2026-11-${day.toString().padLeft(2, '0')}.todobackup',
      ]);
      expect(service.lastBackup.value, DateTime(2026, 11, 10, 9));
      // Each one is a real, readable backup
      final read = await service.read(stored.first.file);
      expect(read.tasks.single.title, 'Something');
    });

    test('turned off: no daily backup', () async {
      await d.tasks.create(const TaskDraft(title: 'Something'));
      await service.setAuto(false);
      expect(await service.runDailyIfDue(now: DateTime(2026, 11, 17)), isNull);
    });

    test('a folder that went away is shown as unset', () async {
      await d.tasks.create(const TaskDraft(title: 'Something'));
      service.folderName.value = 'Drive/Backups';
      // folder.folder is null: writes fail, as after revoking access
      await service.backupNow(now: DateTime(2026, 11, 17));
      expect(service.folderName.value, isNull);
    });

    test('restoring saves the current data first', () async {
      await d.tasks.create(const TaskDraft(title: 'Before'));
      final empty = BackupData(
        createdAt: DateTime(2026, 11),
        lists: const [],
        tasks: const [],
        activity: const [],
      );
      await service.restore(
        empty,
        RestoreMode.replace,
        now: DateTime(2026, 11, 17, 10, 30),
      );
      expect(await d.allTasks(), isEmpty);
      final saved = (await (await service.store()).list()).single;
      expect(saved.kind, BackupKind.beforeRestore);
      expect(saved.name, 'todo-before-restore-2026-11-17-1030.todobackup');
      expect((await service.read(saved.file)).tasks.single.title, 'Before');
    });

    test('an unreadable file on disk reports, not crashes', () async {
      final bad = File('${dir.path}/todo-auto-2026-11-01.todobackup')
        ..writeAsStringSync('nope');
      expect(() => service.read(bad), throwsA(isA<BackupException>()));
    });
  });
}
