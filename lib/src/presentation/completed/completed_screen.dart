import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../config/di/di.dart';
import '../../core/date/dates.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_format.dart';
import '../tasks/widgets/task_sources.dart';
import '../tasks/widgets/task_tile.dart';

/// Completed history grouped by the day it was done; tap the tick to restore.
@RoutePage()
class CompletedScreen extends StatefulWidget {
  const CompletedScreen({super.key});

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen> {
  late final _stream = getIt<TaskRepository>().watchCompleted();

  @override
  Widget build(BuildContext context) {
    final today = getIt<DayClock>().value;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.completed)),
      body: StreamBuilder<List<Task>>(
        stream: _stream,
        builder: (context, snapshot) {
          final tasks = snapshot.data;
          if (tasks == null) {
            return const SizedBox.shrink();
          }
          if (tasks.isEmpty) {
            return Center(
              child: CalmEmptyState(
                icon: Icons.task_alt_rounded,
                title: context.l10n.completedEmptyTitle,
              ),
            );
          }
          final byDay = <DateTime, List<Task>>{};
          for (final task in tasks) {
            final day = Dates.dateOnly(task.doneAt ?? task.updatedAt);
            byDay.putIfAbsent(day, () => []).add(task);
          }
          return TaskLookupsBuilder(
            builder: (context, lookups) => CustomScrollView(
              slivers: [
                for (final entry in byDay.entries) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: TaskFormat.day(context, entry.key, today),
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
                            list: lookups.listOf(task),
                          ),
                      ],
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
          );
        },
      ),
    );
  }
}
