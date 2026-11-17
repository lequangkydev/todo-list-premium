import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/date/dates.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_format.dart';
import '../tasks/widgets/quick_add_field.dart';
import '../tasks/widgets/task_sources.dart';
import '../tasks/widgets/task_tile.dart';

/// Next 7 days grouped by day, then everything later.
class UpcomingTab extends StatefulWidget {
  const UpcomingTab({super.key, required this.actions});

  final List<Widget> actions;

  @override
  State<UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends State<UpcomingTab> {
  final _stream = KeyedStream<DateTime, List<Task>>(
    getIt<TaskRepository>().watchUpcoming,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: getIt<DayClock>(),
      builder: (context, today, _) {
        final tomorrow = Dates.addDays(today, 1);
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 84,
            title: Text(
              context.l10n.upcoming,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            actions: widget.actions,
          ),
          body: StreamBuilder<List<Task>>(
            stream: _stream.of(today),
            builder: (context, snapshot) {
              final tasks = snapshot.data;
              final weekEnd = Dates.addDays(today, 7);
              final byDay = <DateTime, List<Task>>{};
              final later = <Task>[];
              for (final task in tasks ?? const <Task>[]) {
                final due = task.dueDate!;
                if (due.isAfter(weekEnd)) {
                  later.add(task);
                } else {
                  byDay.putIfAbsent(due, () => []).add(task);
                }
              }
              return TaskLookupsBuilder(
                builder: (context, lookups) => CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        4,
                        16,
                        8,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: QuickAddField(defaultDate: tomorrow),
                      ),
                    ),
                    if (tasks != null && tasks.isEmpty)
                      SliverToBoxAdapter(
                        child: CalmEmptyState(
                          icon: Icons.event_available_rounded,
                          accent: context.taskColors.priorityLow,
                          title: context.l10n.upcomingEmptyTitle,
                          message: context.l10n.upcomingEmptyMessage,
                        ),
                      ),
                    for (final entry in byDay.entries) ...[
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          title: _dayTitle(context, entry.key, today),
                          count: entry.value.length,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: TaskGroup(
                          children: [
                            for (final task in entry.value)
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
                    ],
                    if (later.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          title: context.l10n.laterSection,
                          count: later.length,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: TaskGroup(
                          children: [
                            for (final task in later)
                              TaskTile(
                                key: ValueKey(task.id),
                                task: task,
                                today: today,
                                subtasks: lookups.subtasks[task.id],
                                list: lookups.listOf(task),
                              ),
                          ],
                        ),
                      ),
                    ],
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

  /// "Tomorrow · Sat, 14 Nov"
  String _dayTitle(BuildContext context, DateTime day, DateTime today) {
    final label = TaskFormat.day(context, day, today);
    final long = TaskFormat.shortDay(context, day);
    return label == long ? label : '$label · $long';
  }
}
