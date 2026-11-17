import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/date/dates.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_format.dart';
import '../tasks/widgets/quick_add_field.dart';
import '../tasks/widgets/task_sources.dart';
import '../tasks/widgets/task_tile.dart';
import 'plan_day_sheet.dart';
import 'widgets/today_summary_card.dart';

/// Today: only what's due today. Overdue work waits quietly in "Still open"
/// instead of shouting in red.
class TodayTab extends StatefulWidget {
  const TodayTab({super.key, required this.actions});

  final List<Widget> actions;

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  bool _showOverdue = true;
  final _due = KeyedStream<DateTime, List<Task>>(
    getIt<TaskRepository>().watchDueBy,
  );
  final _done = KeyedStream<DateTime, int>(getIt<TaskRepository>().watchDoneOn);

  @override
  Widget build(BuildContext context) {
    final clock = getIt<DayClock>();
    return ValueListenableBuilder<DateTime>(
      valueListenable: clock,
      builder: (context, today, _) {
        final repo = getIt<TaskRepository>();
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 84,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.today,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  TaskFormat.longDay(context, today),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: widget.actions,
          ),
          body: StreamBuilder<List<Task>>(
            stream: _due.of(today),
            builder: (context, snapshot) {
              final all = snapshot.data;
              final overdue = [
                for (final t in all ?? const <Task>[])
                  if (t.dueDate!.isBefore(today)) t,
              ];
              final dueToday = [
                for (final t in all ?? const <Task>[])
                  if (Dates.isSameDay(t.dueDate!, today)) t,
              ];
              return StreamBuilder<int>(
                stream: _done.of(today),
                builder: (context, doneSnap) {
                  final doneCount = doneSnap.data ?? 0;
                  final allDone =
                      all != null && dueToday.isEmpty && doneCount > 0;
                  return TaskLookupsBuilder(
                    builder: (context, lookups) => CustomScrollView(
                      slivers: [
                        if (dueToday.isNotEmpty || doneCount > 0)
                          SliverPadding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              AppSpace.gutter,
                              AppSpace.xs,
                              AppSpace.gutter,
                              AppSpace.md,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: TodaySummaryCard(
                                open: dueToday.length,
                                done: doneCount,
                                // Worth planning once 2+ tasks need a slot
                                onPlan:
                                    [...overdue, ...dueToday]
                                            .where(
                                              (t) =>
                                                  t.dueTime == null ||
                                                  t.dueDate!.isBefore(today),
                                            )
                                            .length >=
                                        2
                                    ? () => PlanDaySheet.show(context, [
                                        ...overdue,
                                        ...dueToday,
                                      ])
                                    : null,
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpace.gutter,
                            AppSpace.xs,
                            AppSpace.gutter,
                            AppSpace.sm,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: QuickAddField(defaultDate: today),
                          ),
                        ),
                        if (overdue.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: SectionHeader(
                              title: context.l10n.stillOpen,
                              count: overdue.length,
                              expanded: _showOverdue,
                              onTap: () =>
                                  setState(() => _showOverdue = !_showOverdue),
                              trailing: TextButton(
                                onPressed: () {
                                  AppHaptics.light();
                                  repo.rescheduleOverdue(today);
                                },
                                child: Text(context.l10n.moveToToday),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: AnimatedSize(
                              duration: AppMotion.of(context, AppMotion.medium),
                              curve: AppMotion.curve,
                              alignment: Alignment.topCenter,
                              child: _showOverdue
                                  ? TaskGroup(
                                      children: [
                                        for (final task in overdue)
                                          TaskTile(
                                            key: ValueKey(task.id),
                                            task: task,
                                            today: today,
                                            subtasks: lookups.subtasks[task.id],
                                            list: lookups.listOf(task),
                                          ),
                                      ],
                                    )
                                  : const SizedBox(width: double.infinity),
                            ),
                          ),
                          if (dueToday.isNotEmpty)
                            SliverToBoxAdapter(
                              child: SectionHeader(
                                title: context.l10n.today,
                                count: dueToday.length,
                              ),
                            ),
                        ],
                        if (all != null && dueToday.isEmpty)
                          SliverToBoxAdapter(
                            child: allDone
                                ? CalmEmptyState(
                                    icon: Icons.celebration_rounded,
                                    accent: context.taskColors.priorityMedium,
                                    title: context.l10n.allDoneMessage,
                                  )
                                : CalmEmptyState(
                                    icon: Icons.spa_rounded,
                                    title: overdue.isEmpty
                                        ? context.l10n.todayEmptyTitle
                                        : context.l10n.todayEmptyWithOverdue,
                                    message: overdue.isEmpty
                                        ? context.l10n.todayEmptyMessage
                                        : null,
                                  ),
                          ),
                        if (dueToday.isNotEmpty)
                          SliverPadding(
                            padding: EdgeInsets.only(
                              top: overdue.isEmpty ? AppSpace.sm : 0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: TaskGroup(
                                children: [
                                  for (final task in dueToday)
                                    TaskTile(
                                      key: ValueKey(task.id),
                                      task: task,
                                      today: today,
                                      showDate: false,
                                      subtasks: lookups.subtasks[task.id],
                                      list: lookups.listOf(task),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 96)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
