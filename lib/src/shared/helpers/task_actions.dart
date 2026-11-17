import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../core/date/dates.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../extension/context_extension.dart';
import 'day_clock.dart';

/// Task actions that show an Undo snackbar
class TaskActions {
  TaskActions._();

  static TaskRepository get _repo => getIt<TaskRepository>();

  static Future<void> toggle(BuildContext context, Task task) {
    return task.isDone ? _repo.reopen(task) : complete(context, task);
  }

  static Future<void> complete(BuildContext context, Task task) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final undo = await _repo.complete(task);
    if (task.parentId != null) {
      return;
    }
    _show(
      messenger,
      task.rrule == null ? l10n.taskCompleted : l10n.taskCompletedRepeat,
      l10n.undo,
      undo,
    );
  }

  /// Moves an open task to tomorrow, keeping its time
  static Future<void> moveToTomorrow(BuildContext context, Task task) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final tomorrow = Dates.addDays(getIt<DayClock>().value, 1);
    await _repo.setDue(task.id, tomorrow, task.dueTime);
    _show(messenger, l10n.movedToTomorrow, l10n.undo, () async {
      await _repo.updateTask(task);
    });
  }

  static Future<void> delete(BuildContext context, Task task) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final undo = await _repo.delete(task.id);
    _show(messenger, l10n.taskDeleted, l10n.undo, undo);
  }

  static void showUndo(BuildContext context, String message, Undo undo) {
    _show(ScaffoldMessenger.maybeOf(context), message, context.l10n.undo, undo);
  }

  static void _show(
    ScaffoldMessengerState? messenger,
    String message,
    String undoLabel,
    Undo undo,
  ) {
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: undoLabel, onPressed: undo),
        ),
      );
  }
}
