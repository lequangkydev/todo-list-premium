import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../shared/extension/context_extension.dart';
import '../../../shared/helpers/task_actions.dart';
import '../../../shared/helpers/task_format.dart';
import '../task_editor_sheet.dart';

/// A task row: round check, title, and a quiet line of details.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.today,
    this.subtasks,
    this.list,
    this.showDate = true,
    this.dismissible = true,
  });

  final Task task;
  final DateTime today;
  final SubtaskCount? subtasks;

  /// Shown as a coloured dot + name when set
  final TaskList? list;
  final bool showDate;
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => TaskEditorSheet.show(context, task.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckCircle(
                checked: task.isDone,
                color: priorityColor(scheme, task.priority),
                semanticLabel: task.title,
                onChanged: () => TaskActions.toggle(context, task),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: task.isDone
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      _Details(
                        task: task,
                        today: today,
                        subtasks: subtasks,
                        list: list,
                        showDate: showDate,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!dismissible) {
      return tile;
    }
    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: scheme.errorContainer,
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onErrorContainer,
          semanticLabel: context.l10n.delete,
        ),
      ),
      onDismissed: (_) => TaskActions.delete(context, task),
      child: tile,
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.task,
    required this.today,
    required this.subtasks,
    required this.list,
    required this.showDate,
  });

  final Task task;
  final DateTime today;
  final SubtaskCount? subtasks;
  final TaskList? list;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final items = <Widget>[];

    void add(IconData icon, String? text) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            if (text != null) ...[
              const SizedBox(width: 3),
              Text(text, style: style),
            ],
          ],
        ),
      );
    }

    final due = task.dueDate;
    if (showDate && due != null) {
      add(Icons.event_rounded, TaskFormat.due(context, task, today));
    } else if (!showDate && task.dueTime != null) {
      add(Icons.schedule_rounded, TaskFormat.time(context, task.dueTime!));
    }
    if (task.rrule != null) {
      add(Icons.repeat_rounded, null);
    }
    if (task.remindOffset != null && !task.isDone) {
      add(Icons.notifications_none_rounded, null);
    }
    final count = subtasks;
    if (count != null && count.total > 0) {
      add(Icons.checklist_rounded, '${count.done}/${count.total}');
    }
    if (task.note != null) {
      add(Icons.notes_rounded, null);
    }
    final l = list;
    if (l != null) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(l.colorValue),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(l.name, style: style),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return const SizedBox(height: 11);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 8),
      child: Wrap(spacing: 10, runSpacing: 2, children: items),
    );
  }
}

/// Round checkbox with a short fill animation before the action fires, so
/// the tick is visible even though the row then disappears.
class CheckCircle extends StatefulWidget {
  const CheckCircle({
    super.key,
    required this.checked,
    required this.color,
    required this.onChanged,
    required this.semanticLabel,
    this.size = 22,
  });

  final bool checked;
  final Color color;
  final VoidCallback onChanged;
  final String semanticLabel;
  final double size;

  @override
  State<CheckCircle> createState() => _CheckCircleState();
}

class _CheckCircleState extends State<CheckCircle> {
  late bool _checked = widget.checked;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant CheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy) {
      _checked = widget.checked;
    }
  }

  Future<void> _tap() async {
    if (_busy) {
      return;
    }
    _busy = true;
    setState(() => _checked = !_checked);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _busy = false;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Semantics(
      checked: _checked,
      label: widget.semanticLabel,
      button: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: InkResponse(
          onTap: _tap,
          radius: 22,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _checked ? color : color.withValues(alpha: .08),
                border: Border.all(color: color, width: 1.8),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _checked ? 1 : 0,
                child: Icon(
                  Icons.check_rounded,
                  size: widget.size - 6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
