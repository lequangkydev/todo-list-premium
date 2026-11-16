import 'package:flutter/material.dart';

import '../../config/di/di.dart';
import '../../core/date/dates.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_format.dart';
import '../tasks/widgets/quick_add_field.dart';
import '../tasks/widgets/task_sources.dart';
import '../tasks/widgets/task_tile.dart';

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
            toolbarHeight: 72,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.today),
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
              return TaskLookupsBuilder(
                builder: (context, lookups) => CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                            onPressed: () => repo.rescheduleOverdue(today),
                            child: Text(context.l10n.moveToToday),
                          ),
                        ),
                      ),
                      if (_showOverdue)
                        SliverList.list(
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
                        ),
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          title: context.l10n.today,
                          count: dueToday.length,
                        ),
                      ),
                    ],
                    if (all != null && dueToday.isEmpty)
                      SliverToBoxAdapter(
                        child: CalmEmptyState(
                          icon: Icons.spa_outlined,
                          title: overdue.isEmpty
                              ? context.l10n.todayEmptyTitle
                              : context.l10n.todayEmptyWithOverdue,
                          message: overdue.isEmpty
                              ? context.l10n.todayEmptyMessage
                              : null,
                        ),
                      ),
                    SliverList.list(
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
                    SliverToBoxAdapter(
                      child: _DoneToday(stream: _done.of(today)),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// "3 done today" — acknowledgement without streak pressure
class _DoneToday extends StatelessWidget {
  const _DoneToday({required this.stream});

  final Stream<int> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.doneToday(count),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
