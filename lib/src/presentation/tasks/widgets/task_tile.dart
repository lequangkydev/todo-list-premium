import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../shared/extension/context_extension.dart';
import '../../../shared/helpers/task_actions.dart';
import '../../../shared/helpers/task_format.dart';
import '../task_editor_sheet.dart';

/// Groups task rows in one rounded card with inset dividers
class TaskGroup extends StatelessWidget {
  const TaskGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Card(
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(indent: 60, height: 1),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

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
    final text = Theme.of(context).textTheme;
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => TaskEditorSheet.show(context, task.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xs + 2,
            AppSpace.xs,
            AppSpace.lg,
            AppSpace.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckCircle(
                checked: task.isDone,
                color: context.taskColors.priority(task.priority),
                semanticLabel: task.title,
                onChanged: () => TaskActions.toggle(context, task),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: AppMotion.of(context, AppMotion.medium),
                        style: text.bodyLarge!.copyWith(
                          color: task.isDone
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: scheme.onSurfaceVariant,
                        ),
                        child: Text(task.title),
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
    // Swipe is a shortcut; the editor's Delete button is the alternative
    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: scheme.errorContainer,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.delete,
                  style: text.labelLarge?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                ExcludeSemantics(
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
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
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall;
    final items = <Widget>[];

    /// Icon + optional text. Icon-only items carry [label] for screen
    /// readers; when text is visible the icon is decorative.
    void add(IconData icon, {String? text, String? label, Color? color}) {
      final iconWidget = Icon(
        icon,
        size: AppIcon.sm,
        color: color ?? scheme.onSurfaceVariant,
      );
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text == null)
              Semantics(
                label: label,
                child: ExcludeSemantics(child: iconWidget),
              )
            else
              ExcludeSemantics(child: iconWidget),
            if (text != null) ...[
              const SizedBox(width: AppSpace.xs),
              Text(text, style: style?.copyWith(color: color)),
            ],
          ],
        ),
      );
    }

    final due = task.dueDate;
    if (showDate && due != null) {
      add(Icons.event_rounded, text: TaskFormat.due(context, task, today));
    } else if (!showDate && task.dueTime != null) {
      add(
        Icons.schedule_rounded,
        text: TaskFormat.time(context, task.dueTime!),
      );
    }
    if (task.priority > 0) {
      // Text + shape, not colour alone
      add(
        Icons.flag_rounded,
        text: TaskFormat.priority(l10n, task.priority),
        color: context.taskColors.priority(task.priority),
      );
    }
    if (task.rrule != null) {
      add(Icons.repeat_rounded, label: l10n.repeats);
    }
    if (task.remindOffset != null && !task.isDone) {
      add(Icons.notifications_none_rounded, label: l10n.hasReminder);
    }
    final count = subtasks;
    if (count != null && count.total > 0) {
      add(Icons.checklist_rounded, text: '${count.done}/${count.total}');
    }
    if (task.note != null) {
      add(Icons.notes_rounded, label: l10n.hasNote);
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
            const SizedBox(width: AppSpace.xs + 2),
            Text(l.name, style: style),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: Wrap(
        spacing: AppSpace.md,
        runSpacing: AppSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }
}

/// Round checkbox with a short fill animation before the action fires, so
/// the tick is visible even though the row then disappears. 48dp target.
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
    final delay = AppMotion.of(context, const Duration(milliseconds: 220));
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    _busy = false;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final duration = AppMotion.of(context, AppMotion.medium);
    return Semantics(
      checked: _checked,
      label: widget.semanticLabel,
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: InkResponse(
          onTap: _tap,
          radius: 24,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.curve,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _checked ? color : color.withValues(alpha: .08),
                border: Border.all(color: color, width: 2),
              ),
              child: AnimatedOpacity(
                duration: duration,
                opacity: _checked ? 1 : 0,
                child: AnimatedScale(
                  duration: duration,
                  curve: Curves.easeOutBack,
                  scale: _checked ? 1 : .6,
                  child: Icon(
                    Icons.check_rounded,
                    size: widget.size - 6,
                    color: context.colorScheme.surface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
