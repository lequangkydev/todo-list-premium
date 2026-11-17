import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/theme/app_theme.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../shared/extension/context_extension.dart';
import '../../../shared/helpers/app_haptics.dart';
import '../../../shared/helpers/task_actions.dart';
import '../../../shared/helpers/task_format.dart';
import '../task_editor_sheet.dart';

export 'task_group.dart';

/// A task row: round check, title, and a quiet line of details.
///
/// Swipe towards the end to complete; swipe towards the start for
/// "Tomorrow" and "Delete". The same actions are offered to screen readers
/// as custom actions, and the editor remains the non-gesture path.
class TaskTile extends StatefulWidget {
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

  /// Whether swipe actions are available
  final bool dismissible;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile>
    with SingleTickerProviderStateMixin {
  late final _slidable = SlidableController(this);

  /// Done state shown while the check animation plays, before the database
  /// confirms it
  bool? _pendingDone;

  /// Swipe position past which letting go completes the task
  static const _completeThreshold = .4;
  bool _pastThreshold = false;

  /// Set once a full swipe is released, so the pane closing again doesn't
  /// tick a second time
  bool _released = false;

  Task get task => widget.task;

  @override
  void initState() {
    super.initState();
    _slidable.animation.addListener(_onSlide);
  }

  @override
  void didUpdateWidget(covariant TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Any saved change ends the optimistic state — including a repeating
    // task that stays open and moves to its next date
    if (oldWidget.task != task || _pendingDone == task.isDone) {
      _pendingDone = null;
    }
  }

  @override
  void dispose() {
    _slidable.animation.removeListener(_onSlide);
    _slidable.dispose();
    super.dispose();
  }

  /// One light tap when a full swipe would complete the task, and again if
  /// the finger pulls back
  void _onSlide() {
    if (_slidable.ratio == 0) {
      _released = false;
      _pastThreshold = false;
      return;
    }
    if (_released) {
      return;
    }
    final past = _slidable.ratio >= _completeThreshold;
    if (past != _pastThreshold) {
      _pastThreshold = past;
      AppHaptics.selection();
    }
  }

  Future<void> _complete() {
    AppHaptics.light();
    return TaskActions.complete(context, task);
  }

  Future<void> _tomorrow() => TaskActions.moveToTomorrow(context, task);

  Future<void> _delete() => TaskActions.delete(context, task);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final done = _pendingDone ?? task.isDone;
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
                onWillChange: (checked) =>
                    setState(() => _pendingDone = checked),
                onChanged: () => TaskActions.toggle(context, task),
              ),
              const SizedBox(width: AppSpace.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StrikeText(
                        task.title,
                        struck: done,
                        style: text.bodyLarge!,
                        color: done
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                      _Details(
                        task: task,
                        today: widget.today,
                        subtasks: widget.subtasks,
                        list: widget.list,
                        showDate: widget.showDate,
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
    if (!widget.dismissible) {
      return tile;
    }
    final open = !task.isDone;
    return Semantics(
      customSemanticsActions: {
        if (open) CustomSemanticsAction(label: l10n.actionDone): _complete,
        if (open) CustomSemanticsAction(label: l10n.tomorrow): _tomorrow,
        CustomSemanticsAction(label: l10n.delete): _delete,
      },
      child: Slidable(
        key: ValueKey('slide-${task.id}'),
        controller: _slidable,
        startActionPane: open
            ? ActionPane(
                motion: const BehindMotion(),
                extentRatio: .25,
                // A full swipe completes, then the pane closes again; the
                // group animates the row away if it leaves this list. Never
                // let the pane dismiss itself: rows that stay (search,
                // repeating tasks) would be left collapsed.
                dismissible: DismissiblePane(
                  dismissThreshold: _completeThreshold,
                  closeOnCancel: true,
                  confirmDismiss: () async {
                    _released = true;
                    setState(() => _pendingDone = true);
                    unawaited(_complete());
                    return false;
                  },
                  onDismissed: () {},
                ),
                children: [
                  _SwipeAction(
                    icon: Icons.check_rounded,
                    label: l10n.actionDone,
                    color: scheme.primary,
                    onColor: scheme.onPrimary,
                    onPressed: _complete,
                  ),
                ],
              )
            : null,
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: open ? .5 : .25,
          children: [
            if (open)
              _SwipeAction(
                icon: Icons.east_rounded,
                label: l10n.tomorrow,
                color: scheme.secondaryContainer,
                onColor: scheme.onSecondaryContainer,
                onPressed: _tomorrow,
              ),
            _SwipeAction(
              icon: Icons.delete_outline_rounded,
              label: l10n.delete,
              color: scheme.errorContainer,
              onColor: scheme.onErrorContainer,
              onPressed: _delete,
            ),
          ],
        ),
        child: tile,
      ),
    );
  }
}

/// A swipe action whose icon grows from 80% to full size as it's revealed
class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final controller = Slidable.of(context);
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: onColor);
    return CustomSlidableAction(
      backgroundColor: color,
      foregroundColor: onColor,
      onPressed: (_) => onPressed(),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller == null || !AppMotion.enabled(context))
              Icon(icon, color: onColor)
            else
              AnimatedBuilder(
                animation: controller.animation,
                builder: (context, child) => Transform.scale(
                  scale: .8 + .2 * (controller.ratio.abs() * 4).clamp(0, 1),
                  child: child,
                ),
                child: Icon(icon, color: onColor),
              ),
            const SizedBox(height: AppSpace.xs),
            Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Text whose strike-through draws across it (start to end, line by line)
/// when [struck] turns on, instead of snapping in
class StrikeText extends StatelessWidget {
  const StrikeText(
    this.text, {
    super.key,
    required this.struck,
    required this.style,
    required this.color,
  });

  final String text;
  final bool struck;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, const Duration(milliseconds: 260));
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: struck ? 1 : 0),
      duration: duration,
      curve: AppMotion.curve,
      builder: (context, progress, child) => CustomPaint(
        foregroundPainter: progress == 0
            ? null
            : _StrikePainter(
                text: text,
                style: resolved,
                progress: progress,
                color: context.colorScheme.onSurfaceVariant,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              ),
        child: child,
      ),
      child: AnimatedDefaultTextStyle(
        duration: duration,
        style: style.copyWith(color: color),
        child: Text(text),
      ),
    );
  }
}

class _StrikePainter extends CustomPainter {
  _StrikePainter({
    required this.text,
    required this.style,
    required this.progress,
    required this.color,
    required this.textDirection,
    required this.textScaler,
  });

  final String text;
  final TextStyle style;
  final double progress;
  final Color color;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    final lines = painter.computeLineMetrics();
    painter.dispose();
    final total = lines.fold<double>(0, (sum, l) => sum + l.width);
    if (total == 0) {
      return;
    }
    final fontSize = textScaler.scale(style.fontSize ?? 16);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    var remaining = total * progress;
    for (final line in lines) {
      if (remaining <= 0) {
        break;
      }
      final length = remaining.clamp(0, line.width).toDouble();
      remaining -= length;
      final y = line.baseline - fontSize * .3;
      final rtl = textDirection == TextDirection.rtl;
      final from = rtl ? line.left + line.width : line.left;
      final to = rtl ? from - length : from + length;
      canvas.drawLine(Offset(from, y), Offset(to, y), paint);
    }
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      old.progress != progress ||
      old.text != text ||
      old.style != style ||
      old.color != color ||
      old.textDirection != textDirection ||
      old.textScaler != textScaler;
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
    this.onWillChange,
    this.size = 22,
  });

  final bool checked;
  final Color color;

  /// Fires after the animation, when the change should be saved
  final VoidCallback onChanged;

  /// Fires on tap with the new value, before the animation plays
  final ValueChanged<bool>? onWillChange;
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
    widget.onWillChange?.call(_checked);
    if (completing) {
      AppHaptics.light();
    }
    final reduced = !AppMotion.enabled(context);
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
