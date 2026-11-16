import 'package:drift/native.dart';
import 'package:flutter_base/src/data/local/database/app_database.dart';
import 'package:flutter_base/src/data/repositories/list_repository.dart';
import 'package:flutter_base/src/data/repositories/task_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TaskRepository tasks;
  late ListRepository lists;
  final today = DateTime(2026, 11, 13);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tasks = TaskRepository(db);
    lists = ListRepository(db);
  });

  tearDown(() => db.close());

  test('today shows overdue + today, not future or done', () async {
    await tasks.create(
      TaskDraft(title: 'old', dueDate: DateTime(2026, 11, 10)),
    );
    await tasks.create(TaskDraft(title: 'now', dueDate: today));
    await tasks.create(
      TaskDraft(title: 'later', dueDate: DateTime(2026, 11, 20)),
    );
    final doneId = await tasks.create(TaskDraft(title: 'done', dueDate: today));
    await tasks.complete((await tasks.getTask(doneId))!, now: today);

    final due = await tasks.watchDueBy(today).first;
    expect(due.map((t) => t.title), ['old', 'now']);
    final upcoming = await tasks.watchUpcoming(today).first;
    expect(upcoming.map((t) => t.title), ['later']);
  });

  test(
    'completing a recurring task keeps history and moves the date',
    () async {
      final id = await tasks.create(
        TaskDraft(title: 'gym', dueDate: today, rrule: 'FREQ=WEEKLY;BYDAY=FR'),
      );
      final undo = await tasks.complete(
        (await tasks.getTask(id))!,
        now: DateTime(2026, 11, 13, 18),
      );

      final moved = (await tasks.getTask(id))!;
      expect(moved.isDone, isFalse);
      expect(moved.dueDate, DateTime(2026, 11, 20));
      final history = await tasks.watchCompleted().first;
      expect(history, hasLength(1));
      expect(history.single.title, 'gym');
      expect(history.single.rrule, isNull);
      expect(await tasks.watchDoneOn(today).first, 1);

      await undo();
      expect((await tasks.getTask(id))!.dueDate, today);
      expect(await tasks.watchCompleted().first, isEmpty);
      expect(await tasks.watchDoneOn(today).first, 0);
    },
  );

  test('recurring task without a date starts on the rule', () async {
    final id = await tasks.create(
      const TaskDraft(title: 'rent', rrule: 'FREQ=MONTHLY;BYMONTHDAY=-1'),
    );
    final task = (await tasks.getTask(id))!;
    final now = DateTime.now();
    expect(task.dueDate!.month, now.month);
  });

  test('delete and undo include subtasks', () async {
    final parent = await tasks.create(TaskDraft(title: 'trip', dueDate: today));
    await tasks.create(TaskDraft(title: 'pack', parentId: parent));
    final undo = await tasks.delete(parent);
    expect(await tasks.watchDueBy(today).first, isEmpty);
    expect(await tasks.watchSubtasks(parent).first, isEmpty);
    await undo();
    expect(await tasks.watchDueBy(today).first, hasLength(1));
    expect(await tasks.watchSubtasks(parent).first, hasLength(1));
  });

  test('subtask counts', () async {
    final parent = await tasks.create(const TaskDraft(title: 'p'));
    await tasks.create(TaskDraft(title: 'a', parentId: parent));
    final b = await tasks.create(TaskDraft(title: 'b', parentId: parent));
    await tasks.complete((await tasks.getTask(b))!);
    final counts = await tasks.watchSubtaskCounts().first;
    expect(counts[parent]!.done, 1);
    expect(counts[parent]!.total, 2);
  });

  test('lists: counts, delete with tasks, undo', () async {
    final work = await lists.create('Work', listColors.first);
    await tasks.create(TaskDraft(title: 'a', listId: work));
    await tasks.create(TaskDraft(title: 'b', listId: work));
    await tasks.create(const TaskDraft(title: 'inbox'));

    var all = await lists.watchLists().first;
    expect(all.single.openCount, 2);
    expect(await lists.watchInboxCount().first, 1);

    final undo = await lists.delete(work);
    expect(await lists.watchLists().first, isEmpty);
    expect(await tasks.watchList(work).first, isEmpty);

    await undo();
    all = await lists.watchLists().first;
    expect(all.single.openCount, 2);
  });

  test('reschedule overdue moves them to today', () async {
    await tasks.create(TaskDraft(title: 'old', dueDate: DateTime(2026, 11, 1)));
    await tasks.rescheduleOverdue(today);
    final due = await tasks.watchDueBy(today).first;
    expect(due.single.dueDate, today);
  });

  test('reorder persists manual order', () async {
    final a = await tasks.create(const TaskDraft(title: 'a'));
    final b = await tasks.create(const TaskDraft(title: 'b'));
    final c = await tasks.create(const TaskDraft(title: 'c'));
    final rows = [
      (await tasks.getTask(c))!,
      (await tasks.getTask(a))!,
      (await tasks.getTask(b))!,
    ];
    await tasks.reorder(rows);
    final list = await tasks.watchList(null).first;
    expect(list.map((t) => t.title), ['c', 'a', 'b']);
  });

  test('search matches title and note, escapes wildcards', () async {
    await tasks.create(const TaskDraft(title: 'Buy milk'));
    await tasks.create(const TaskDraft(title: 'Call', note: 'about milk'));
    await tasks.create(const TaskDraft(title: '100% done'));
    expect(await tasks.search('milk').first, hasLength(2));
    expect(await tasks.search('%').first, hasLength(1));
  });
}
