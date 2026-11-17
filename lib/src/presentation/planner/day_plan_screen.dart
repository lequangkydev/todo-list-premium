import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/ai/smart_suggestions.dart';
import '../../core/analytics/app_events.dart';
import '../../core/date/dates.dart';
import '../../core/planner/timeline_layout.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_actions.dart';
import '../../shared/helpers/task_format.dart';
import '../tasks/quick_add_sheet.dart';
import '../tasks/task_editor_sheet.dart';
import '../tasks/widgets/task_sources.dart';

/// One day by the hour: timed tasks as blocks, the rest in a tray to place.
///
/// Dragging is never the only way: a tap on a tray task picks a time, a tap
/// on a block offers change time / all day / done. Long-press and drag is
/// the shortcut.
@RoutePage()
class DayPlanScreen extends StatefulWidget {
  const DayPlanScreen({super.key, this.day});

  /// Today when not given
  final DateTime? day;

  /// Tall enough that a 30-minute block is a comfortable touch target
  static const hourHeight = 72.0;

  /// Room for the hour labels
  static const gutter = 56.0;

  static const topPad = 12.0;

  @override
  State<DayPlanScreen> createState() => _DayPlanScreenState();
}

class _DayPlanScreenState extends State<DayPlanScreen> {
  final _repo = getIt<TaskRepository>();
  final _gridKey = GlobalKey();
  late final DateTime _today = getIt<DayClock>().value;
  late DateTime _day = Dates.dateOnly(widget.day ?? _today);
  late Stream<List<Task>> _tasks;
  late Stream<List<Task>> _leftovers;
  late final ScrollController _scroll;

  /// Where a dragged task would land (minutes after midnight)
  int? _ghost;

  /// Keeps the "now" line moving
  Timer? _minute;

  bool get _isToday => Dates.isSameDay(_day, _today);

  @override
  void initState() {
    super.initState();
    _watch();
    // Open on the part of the day that matters: now, or the morning
    final now = DateTime.now();
    final startHour = _isToday ? (now.hour - 1).clamp(0, 18) : 7;
    _scroll = ScrollController(
      initialScrollOffset: startHour * DayPlanScreen.hourHeight,
    );
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isToday) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _minute?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _watch() {
    _tasks = _repo.watchRange(_day, _day);
    // Still open from before this day: overdue, or today's when planning
    // tomorrow
    _leftovers = _repo.watchDueBy(Dates.addDays(_day, -1));
  }

  void _go(DateTime day) {
    AppHaptics.selection();
    setState(() {
      _day = Dates.dateOnly(day);
      _ghost = null;
      _watch();
    });
  }

  // ---------------------------------------------------------------- actions

  Future<void> _setTime(Task task, int? minutes) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final label = minutes == null
        ? l10n.allDay
        : l10n.timeSet(TaskFormat.time(context, minutes));
    await _repo.setDue(task.id, _day, minutes);
    AppHaptics.light();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(label),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => _repo.setDue(task.id, task.dueDate, task.dueTime),
          ),
        ),
      );
  }

  Future<void> _pickTime(Task task) async {
    final current = task.dueTime ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked != null && mounted) {
      await _setTime(task, picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _blockActions(Task task) async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: AppMotion.sheet(context),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final (value, icon, label) in [
              (0, Icons.check_rounded, l10n.actionDone),
              (1, Icons.schedule_rounded, l10n.changeTime),
              (2, Icons.wb_twilight_rounded, l10n.allDay),
              (3, Icons.open_in_full_rounded, l10n.openTask),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) {
      return;
    }
    switch (choice) {
      case 0:
        await TaskActions.complete(context, task);
      case 1:
        await _pickTime(task);
      case 2:
        await _setTime(task, null);
      case 3:
        await TaskEditorSheet.show(context, task.id);
    }
  }

  /// Fits the untimed tasks around the timed ones
  Future<void> _arrange(List<Task> dayTasks) async {
    final l10n = context.l10n;
    final plan = getIt<SmartSuggestions>().planDay(
      dayTasks,
      // A day ahead is planned from its morning, today from now
      now: _isToday ? null : Dates.atMinutes(_day, 8 * 60),
    );
    final placed = plan.placed.toList();
    if (placed.isEmpty) {
      return;
    }
    final undo = await _repo.schedule({
      for (final p in placed) p.task: (date: _day, time: p.start),
    });
    AppEvents.dayPlanned(placed.length);
    AppHaptics.light();
    if (mounted) {
      TaskActions.showUndo(context, l10n.planApplied(placed.length), undo);
    }
  }

  /// Brings what's still open from earlier days onto this one, keeping
  /// each task's time
  Future<void> _moveHere(List<Task> leftovers) async {
    final l10n = context.l10n;
    for (final task in leftovers) {
      await _repo.setDue(task.id, _day, task.dueTime);
    }
    AppHaptics.light();
    if (mounted) {
      TaskActions.showUndo(
        context,
        l10n.movedCount(leftovers.length),
        () async {
          for (final task in leftovers) {
            await _repo.updateTask(task);
          }
        },
      );
    }
  }

  // ------------------------------------------------------------------- drag

  int? _minutesFor(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return null;
    }
    final dy = box.globalToLocal(global).dy - DayPlanScreen.topPad;
    return TimelineLayout.minutesAt(dy, DayPlanScreen.hourHeight);
  }

  void _onDragMove(DragTargetDetails<Task> details) {
    final minutes = _minutesFor(details.offset);
    if (minutes != _ghost) {
      // A tick for each quarter hour passed
      AppHaptics.selection();
      setState(() => _ghost = minutes);
    }
  }

  void _onDrop(DragTargetDetails<Task> details) {
    final minutes = _minutesFor(details.offset);
    setState(() => _ghost = null);
    if (minutes != null && minutes != details.data.dueTime) {
      unawaited(_setTime(details.data, minutes));
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final relative = TaskFormat.day(context, _day, _today);
    final long = TaskFormat.longDay(context, _day);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(relative == long ? l10n.dayPlan : relative),
            Text(
              long,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).previousPageTooltip,
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => _go(Dates.addDays(_day, -1)),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _go(Dates.addDays(_day, 1)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addTask,
        onPressed: () => QuickAddSheet.show(context, defaultDate: _day),
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<Task>>(
        stream: _tasks,
        builder: (context, snapshot) {
          final tasks = snapshot.data;
          if (tasks == null) {
            return const SizedBox.shrink();
          }
          final untimed = [
            for (final t in tasks)
              if (t.dueTime == null) t,
          ];
          final blocks = TimelineLayout.layout(
            tasks,
            estimateOf: getIt<SmartSuggestions>().estimateOf,
          );
          return Column(
            children: [
              // Past days have nothing to carry over to
              if (!_day.isBefore(_today))
                StreamBuilder<List<Task>>(
                  stream: _leftovers,
                  builder: (context, left) {
                    final leftovers = left.data ?? const <Task>[];
                    return leftovers.isEmpty
                        ? const SizedBox.shrink()
                        : _Leftovers(
                            count: leftovers.length,
                            onMove: () => _moveHere(leftovers),
                          );
                  },
                ),
              if (untimed.isNotEmpty)
                _Tray(
                  tasks: untimed,
                  onTap: _pickTime,
                  onArrange: () => _arrange(tasks),
                ),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: CalmEmptyState(
                          icon: Icons.view_timeline_outlined,
                          title: l10n.dayPlanEmpty,
                          message: l10n.dayPlanEmptyHint,
                        ),
                      )
                    : _grid(context, blocks),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _grid(BuildContext context, List<TimelineBlock> blocks) {
    const hour = DayPlanScreen.hourHeight;
    const gutter = DayPlanScreen.gutter;
    const top = DayPlanScreen.topPad;
    final scheme = context.colorScheme;
    final ghost = _ghost;
    final now = DateTime.now();
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 96),
      child: DragTarget<Task>(
        onMove: _onDragMove,
        onLeave: (_) => setState(() => _ghost = null),
        onAcceptWithDetails: _onDrop,
        builder: (context, _, _) => LayoutBuilder(
          builder: (context, box) {
            final lane = box.maxWidth - gutter - AppSpace.gutter;
            return SizedBox(
              key: _gridKey,
              height: hour * 24 + top,
              child: Stack(
                children: [
                  for (var h = 0; h < 24; h++) ...[
                    PositionedDirectional(
                      top: top + h * hour,
                      start: gutter,
                      end: 0,
                      child: Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: .6),
                      ),
                    ),
                    PositionedDirectional(
                      top: top + h * hour - 8,
                      start: 0,
                      width: gutter - 8,
                      child: ExcludeSemantics(
                        child: Text(
                          TaskFormat.time(context, h * 60),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                  for (final block in blocks)
                    PositionedDirectional(
                      top: top + block.start / 60 * hour,
                      start: gutter + lane * block.column / block.columns,
                      width: lane / block.columns,
                      height: block.minutes / 60 * hour,
                      child: _DraggableBlock(
                        block: block,
                        width: lane / block.columns,
                        height: block.minutes / 60 * hour,
                        onTap: () => _blockActions(block.task),
                      ),
                    ),
                  if (_isToday)
                    PositionedDirectional(
                      top: top + (now.hour * 60 + now.minute) / 60 * hour - 4,
                      start: gutter - 4,
                      end: 0,
                      child: const _NowLine(),
                    ),
                  if (ghost != null)
                    PositionedDirectional(
                      top: top + ghost / 60 * hour,
                      start: gutter,
                      end: AppSpace.gutter,
                      child: _Ghost(label: TaskFormat.time(context, ghost)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "3 still open from before — move here"
class _Leftovers extends StatelessWidget {
  const _Leftovers({required this.count, required this.onMove});

  final int count;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.sm,
        AppSpace.gutter,
        0,
      ),
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpace.lg,
            end: AppSpace.sm,
            top: AppSpace.xs,
            bottom: AppSpace.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.leftoverCount(count),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              TextButton(onPressed: onMove, child: Text(l10n.moveHere)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The day's tasks with no time yet: tap to pick one, or drag onto the grid
class _Tray extends StatelessWidget {
  const _Tray({
    required this.tasks,
    required this.onTap,
    required this.onArrange,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onTap;
  final VoidCallback onArrange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpace.gutter + 4,
            end: AppSpace.sm,
            top: AppSpace.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    '${l10n.unscheduled} · ${tasks.length}',
                    style: text.titleSmall,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onArrange,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(l10n.arrangeForMe),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (context, i) {
              final task = tasks[i];
              final chip = _TrayChip(task: task);
              return LongPressDraggable<Task>(
                data: task,
                onDragStarted: AppHaptics.medium,
                feedback: Material(
                  color: Colors.transparent,
                  child: Opacity(opacity: .92, child: chip),
                ),
                childWhenDragging: Opacity(opacity: .35, child: chip),
                child: Semantics(
                  button: true,
                  label: '${task.title}. ${l10n.changeTime}',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => onTap(task),
                    child: chip,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter + 4,
            AppSpace.xs,
            AppSpace.gutter,
            AppSpace.sm,
          ),
          child: Text(
            l10n.unscheduledHint,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _TrayChip extends StatelessWidget {
  const _TrayChip({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final color = context.taskColors.priority(task.priority);
    return Container(
      height: 48,
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        color: context.taskColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableBlock extends StatelessWidget {
  const _DraggableBlock({
    required this.block,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final TimelineBlock block;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final task = block.task;
    final time = TaskFormat.time(context, block.start);
    final card = _Block(task: task, time: time, compact: height < 56);
    return LongPressDraggable<Task>(
      data: task,
      // Keeps the block's top edge — its start time — under the same spot
      onDragStarted: AppHaptics.medium,
      feedback: Material(
        color: Colors.transparent,
        elevation: 6,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(width: width, height: height, child: card),
      ),
      childWhenDragging: Opacity(opacity: .3, child: card),
      child: Semantics(
        button: true,
        label: '$time, ${task.title}',
        excludeSemantics: true,
        onTap: onTap,
        child: Padding(
          // Blocks side by side or back to back stay separate targets
          padding: const EdgeInsetsDirectional.only(end: 6, bottom: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: onTap,
            child: card,
          ),
        ),
      ),
    );
  }
}

/// A task on the timeline: tinted card, priority bar, title, start time
class _Block extends StatelessWidget {
  const _Block({required this.task, required this.time, required this.compact});

  final Task task;
  final String time;

  /// Too short for two lines: time and title share one
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = task.priority == 0
        ? scheme.primary
        : context.taskColors.priority(task.priority);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tint(accent, context.taskColors.card, isDark ? .28 : .14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: 4,
              ),
              child: compact
                  ? Row(
                      children: [
                        Text(
                          time,
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                        Text(
                          time,
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.error;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 2, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Where a dragged task would start
class _Ghost extends StatelessWidget {
  const _Ghost({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return IgnorePointer(
      child: Container(
        height: DayPlanScreen.hourHeight / 2,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: scheme.primary, width: 1.5),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
      ),
    );
  }
}
