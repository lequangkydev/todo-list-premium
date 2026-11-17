import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/date/dates.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/recurrence/recurrence.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/list_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_actions.dart';
import '../../shared/helpers/task_format.dart';
import 'widgets/task_tile.dart';

/// Edits a task in place: every change is saved immediately.
class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, required this.taskId});

  final String taskId;

  static Future<void> show(BuildContext context, String taskId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskEditorSheet(taskId: taskId),
    );
  }

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final _repo = getIt<TaskRepository>();
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _subtask = TextEditingController();
  Task? _loaded;
  Timer? _textSave;

  @override
  void dispose() {
    _flushText();
    _title.dispose();
    _note.dispose();
    _subtask.dispose();
    super.dispose();
  }

  void _syncControllers(Task task) {
    if (_loaded?.id == task.id) {
      _loaded = task;
      return;
    }
    _loaded = task;
    _title.text = task.title;
    _note.text = task.note ?? '';
  }

  void _onTextChanged() {
    _textSave?.cancel();
    _textSave = Timer(const Duration(milliseconds: 500), _flushText);
  }

  void _flushText() {
    _textSave?.cancel();
    final task = _loaded;
    if (task == null) {
      return;
    }
    final title = _title.text.trim();
    final note = _note.text.trim();
    if ((title.isEmpty || title == task.title) && note == (task.note ?? '')) {
      return;
    }
    unawaited(
      _repo.patch(
        task.id,
        TasksCompanion(
          title: title.isEmpty ? const Value.absent() : Value(title),
          note: Value(note.isEmpty ? null : note),
        ),
      ),
    );
  }

  Future<void> _addSubtask(Task parent) async {
    final text = _subtask.text.trim();
    if (text.isEmpty) {
      return;
    }
    _subtask.clear();
    await _repo.create(
      TaskDraft(title: text, parentId: parent.id, listId: parent.listId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Task?>(
      stream: _repo.watchTask(widget.taskId),
      builder: (context, snapshot) {
        final task = snapshot.data;
        if (task == null) {
          return const SizedBox(height: 240);
        }
        _syncControllers(task);
        final bottom = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .88,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 16, 24),
              children: [
                _TitleRow(
                  task: task,
                  controller: _title,
                  onChanged: _onTextChanged,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 48),
                  child: TextField(
                    controller: _note,
                    onChanged: (_) => _onTextChanged(),
                    minLines: 1,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: context.l10n.addNote,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Properties(task: task),
                const SizedBox(height: 16),
                if (task.parentId == null) ...[
                  _Subtasks(
                    parent: task,
                    controller: _subtask,
                    onAdd: () => _addSubtask(task),
                  ),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: context.colorScheme.error,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      TaskActions.delete(context, task);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(context.l10n.deleteTask),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.task,
    required this.controller,
    required this.onChanged,
  });

  final Task task;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckCircle(
          checked: task.isDone,
          color: context.taskColors.priority(task.priority),
          semanticLabel: task.title,
          size: 24,
          onChanged: () => TaskActions.toggle(context, task),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

/// Date, time, repeat, reminder, priority and list as tappable chips
class _Properties extends StatelessWidget {
  const _Properties({required this.task});

  final Task task;

  TaskRepository get _repo => getIt<TaskRepository>();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = getIt<DayClock>().value;
    final due = task.dueDate;
    final rec = Recurrence.tryParse(task.rrule);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PropertyChip(
          icon: Icons.event_rounded,
          label: due == null
              ? l10n.noDate
              : TaskFormat.day(context, due, today),
          active: due != null,
          onTap: () => _pickDate(context),
        ),
        if (due != null)
          _PropertyChip(
            icon: Icons.schedule_rounded,
            label: task.dueTime == null
                ? l10n.allDay
                : TaskFormat.time(context, task.dueTime!),
            active: task.dueTime != null,
            onTap: () => _pickTime(context),
          ),
        _PropertyChip(
          icon: Icons.repeat_rounded,
          label: rec == null
              ? l10n.noRepeat
              : TaskFormat.recurrence(context, rec),
          active: rec != null,
          onTap: () => _pickRepeat(context),
        ),
        _PropertyChip(
          icon: Icons.notifications_none_rounded,
          label: task.remindOffset == null
              ? l10n.noReminder
              : TaskFormat.reminder(l10n, task.remindOffset!),
          active: task.remindOffset != null,
          onTap: () => _pickReminder(context),
        ),
        _PropertyChip(
          icon: Icons.flag_rounded,
          iconColor: task.priority > 0
              ? context.taskColors.priority(task.priority)
              : null,
          label: TaskFormat.priority(l10n, task.priority),
          active: task.priority > 0,
          onTap: () => _pickPriority(context),
        ),
        if (task.parentId == null) _ListChip(task: task),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final l10n = context.l10n;
    final today = getIt<DayClock>().value;
    final choice = await _choose<int>(context, [
      (0, Icons.today_rounded, l10n.today),
      (1, Icons.wb_sunny_outlined, l10n.tomorrow),
      (7, Icons.next_week_outlined, l10n.nextWeek),
      (-1, Icons.calendar_month_rounded, l10n.pickDate),
      if (task.dueDate != null) (-2, Icons.event_busy_rounded, l10n.noDate),
    ]);
    if (choice == null || !context.mounted) {
      return;
    }
    DateTime? date;
    switch (choice) {
      case -2:
        date = null;
      case -1:
        date = await showDatePicker(
          context: context,
          initialDate: task.dueDate ?? today,
          firstDate: DateTime(today.year - 5),
          lastDate: DateTime(today.year + 10),
        );
        if (date == null) {
          return;
        }
      case 7:
        date = Dates.addDays(Dates.startOfWeek(today), 7);
      default:
        date = Dates.addDays(today, choice);
    }
    final rec = Recurrence.tryParse(task.rrule);
    if (date != null && rec != null) {
      date = rec.firstOnOrAfter(date);
    }
    await _repo.setDue(task.id, date, task.dueTime);
  }

  Future<void> _pickTime(BuildContext context) async {
    final l10n = context.l10n;
    if (task.dueTime != null) {
      final choice = await _choose<int>(context, [
        (0, Icons.schedule_rounded, l10n.changeTime),
        (1, Icons.wb_twilight_rounded, l10n.allDay),
      ]);
      if (choice == null || !context.mounted) {
        return;
      }
      if (choice == 1) {
        await _repo.patch(
          task.id,
          const TasksCompanion(dueTime: Value(null), snoozedUntil: Value(null)),
        );
        return;
      }
    }
    final current = task.dueTime ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !context.mounted) {
      return;
    }
    await _repo.patch(
      task.id,
      TasksCompanion(
        dueTime: Value(picked.hour * 60 + picked.minute),
        snoozedUntil: const Value(null),
        // Picking a time usually means "remind me then"
        remindOffset: task.remindOffset == null
            ? const Value(0)
            : const Value.absent(),
      ),
    );
    if (context.mounted) {
      await getIt<ReminderService>().ensurePermission(context);
    }
  }

  Future<void> _pickRepeat(BuildContext context) async {
    final l10n = context.l10n;
    final base = task.dueDate ?? getIt<DayClock>().value;
    final options = <Recurrence?>[
      null,
      Recurrence.daily(),
      Recurrence.weekdaysOnly(),
      Recurrence.weekly({base.weekday}),
      Recurrence.monthly(base.day),
      Recurrence.monthly(-1),
      Recurrence.yearly(base.month, base.day),
    ];
    final choice = await _choose<int>(context, [
      for (var i = 0; i < options.length; i++)
        (
          i,
          i == 0 ? Icons.block_rounded : Icons.repeat_rounded,
          options[i] == null
              ? l10n.noRepeat
              : TaskFormat.recurrence(context, options[i]!),
        ),
    ]);
    if (choice == null) {
      return;
    }
    final rec = options[choice];
    await _repo.patch(
      task.id,
      TasksCompanion(
        rrule: Value(rec?.toRule()),
        dueDate: rec == null
            ? const Value.absent()
            : Value(rec.firstOnOrAfter(base)),
      ),
    );
  }

  Future<void> _pickReminder(BuildContext context) async {
    final l10n = context.l10n;
    const offsets = [0, 5, 15, 30, 60, 1440];
    final choice = await _choose<int>(context, [
      (-1, Icons.notifications_off_outlined, l10n.noReminder),
      for (final o in offsets)
        (o, Icons.notifications_none_rounded, TaskFormat.reminder(l10n, o)),
    ], footer: task.dueTime == null ? l10n.reminderAllDayHint : null);
    if (choice == null || !context.mounted) {
      return;
    }
    if (choice == -1) {
      await _repo.patch(
        task.id,
        const TasksCompanion(
          remindOffset: Value(null),
          snoozedUntil: Value(null),
        ),
      );
      return;
    }
    await _repo.patch(
      task.id,
      TasksCompanion(
        remindOffset: Value(choice),
        snoozedUntil: const Value(null),
        // A reminder needs a day; default to today
        dueDate: task.dueDate == null
            ? Value(getIt<DayClock>().value)
            : const Value.absent(),
      ),
    );
    if (context.mounted) {
      await getIt<ReminderService>().ensurePermission(context);
    }
  }

  Future<void> _pickPriority(BuildContext context) async {
    final l10n = context.l10n;
    final choice = await _choose<int>(context, [
      for (final p in [3, 2, 1, 0])
        (p, Icons.flag_rounded, TaskFormat.priority(l10n, p)),
    ], iconColor: (p) => context.taskColors.priority(p));
    if (choice == null) {
      return;
    }
    await _repo.patch(task.id, TasksCompanion(priority: Value(choice)));
  }
}

class _ListChip extends StatelessWidget {
  const _ListChip({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ListWithCount>>(
      stream: getIt<ListRepository>().watchLists(),
      builder: (context, snapshot) {
        final lists = snapshot.data ?? const [];
        final current = lists
            .where((l) => l.list.id == task.listId)
            .firstOrNull
            ?.list;
        return _PropertyChip(
          icon: current == null ? Icons.inbox_rounded : Icons.circle,
          iconColor: current == null ? null : Color(current.colorValue),
          label: current?.name ?? context.l10n.inbox,
          active: current != null,
          onTap: () async {
            final choice = await _choose<String>(
              context,
              [
                ('', Icons.inbox_rounded, context.l10n.inbox),
                for (final l in lists) (l.list.id, Icons.circle, l.list.name),
              ],
              iconColor: (id) {
                final match = lists.where((l) => l.list.id == id).firstOrNull;
                return match == null ? null : Color(match.list.colorValue);
              },
            );
            if (choice == null) {
              return;
            }
            final repo = getIt<TaskRepository>();
            await repo.patch(
              task.id,
              TasksCompanion(listId: Value(choice.isEmpty ? null : choice)),
            );
          },
        );
      },
    );
  }
}

class _Subtasks extends StatelessWidget {
  const _Subtasks({
    required this.parent,
    required this.controller,
    required this.onAdd,
  });

  final Task parent;
  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, bottom: 4),
          child: Text(
            context.l10n.subtasks,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        StreamBuilder<List<Task>>(
          stream: getIt<TaskRepository>().watchSubtasks(parent.id),
          builder: (context, snapshot) {
            final subtasks = snapshot.data ?? const [];
            return Column(
              children: [
                for (final sub in subtasks)
                  Row(
                    children: [
                      CheckCircle(
                        key: ValueKey('sub-${sub.id}-${sub.isDone}'),
                        checked: sub.isDone,
                        color: scheme.outline,
                        size: 20,
                        semanticLabel: sub.title,
                        onChanged: () => TaskActions.toggle(context, sub),
                      ),
                      Expanded(
                        child: Text(
                          sub.title,
                          style: TextStyle(
                            decoration: sub.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: sub.isDone ? scheme.onSurfaceVariant : null,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.delete,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: () => getIt<TaskRepository>().delete(sub.id),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              hintText: context.l10n.addSubtask,
              prefixIcon: const Icon(Icons.add_rounded),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _PropertyChip extends StatelessWidget {
  const _PropertyChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: iconColor ?? (active ? scheme.primary : scheme.onSurfaceVariant),
      ),
      label: Text(label),
      backgroundColor: active
          ? scheme.secondaryContainer.withValues(alpha: .6)
          : null,
      side: active ? BorderSide.none : null,
      onPressed: onTap,
    );
  }
}

/// Simple option sheet; returns the chosen value
Future<T?> _choose<T>(
  BuildContext context,
  List<(T, IconData, String)> options, {
  Color? Function(T value)? iconColor,
  String? footer,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final (value, icon, label) in options)
            ListTile(
              leading: Icon(icon, color: iconColor?.call(value)),
              title: Text(label),
              onTap: () => Navigator.pop(context, value),
            ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text(
                footer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
