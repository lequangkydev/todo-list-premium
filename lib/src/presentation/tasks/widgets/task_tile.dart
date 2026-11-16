import 'dart:math' as math;

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
          padding: const EdgeInsetsDirectional.fromSTEB(
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
      final c = context.taskColors.priority(task.priority);
      items.add(
        _Pill(
          color: c,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.flag_rounded, size: 13, color: c),
              ),
              const SizedBox(width: 3),
              Text(
                TaskFormat.priority(l10n, task.priority),
                style: style?.copyWith(color: c, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
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
      final c = Color(l.colorValue);
      items.add(
        _Pill(
          color: c,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpace.xs + 1),
              Text(
                l.name,
                style: style?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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

/// Small pill with a soft fill of [color]
class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tint(color, context.taskColors.card, isDark ? .14 : .08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: child,
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

class _CheckCircleState extends State<CheckCircle>
    with SingleTickerProviderStateMixin {
  late bool _checked = widget.checked;
  bool _busy = false;

  /// Drives the bounce + spark burst when a task gets completed
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(covariant CheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy) {
      _checked = widget.checked;
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_busy) {
      return;
    }
    _busy = true;
    final completing = !_checked;
    setState(() => _checked = !_checked);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (completing && !reduced) {
      // Peak moment: a short, celebratory burst before the row leaves
      await _burst.forward(from: 0);
    } else if (!reduced) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
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
          child: AnimatedBuilder(
            animation: _burst,
            builder: (context, child) {
              final t = _burst.value;
              // 1 → 1.25 → 1 over the first half
              final bounce = t < .5 ? 1 + .5 * t : 1.25 - .5 * (t - .5);
              return CustomPaint(
                painter: _SparkPainter(progress: t, color: color),
                child: Center(
                  child: Transform.scale(
                    scale: _burst.isAnimating ? bounce : 1,
                    child: child,
                  ),
                ),
              );
            },
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
    );
  }
}

/// Eight short rays that fly out and fade — the "done!" sparkle
class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) {
      return;
    }
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(progress);
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progress).clamp(0, 1))
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    const rays = 8;
    for (var i = 0; i < rays; i++) {
      final angle = i * 2 * math.pi / rays;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final start = 12 + 8 * eased;
      final end = start + 6 * (1 - eased) + 2;
      canvas.drawLine(center + dir * start, center + dir * end, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress || old.color != color;
}
