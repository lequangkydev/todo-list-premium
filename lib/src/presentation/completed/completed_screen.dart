import 'package:auto_route/auto_route.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
import '../../config/theme/app_theme.dart';
import '../../core/ai/weekly_recap.dart';
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
      appBar: AppBar(
        title: Text(context.l10n.completed),
        actions: [
          IconButton(
            tooltip: context.l10n.stats,
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.pushRoute(const StatsRoute()),
          ),
        ],
      ),
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.sm,
                    AppSpace.gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _WeeklyRecapCard(
                      recap: WeeklyRecap.of(tasks, today),
                      lists: lookups.lists,
                    ),
                  ),
                ),
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

/// The last 7 days in one calm card: how much got done, and where
class _WeeklyRecapCard extends StatelessWidget {
  const _WeeklyRecapCard({required this.recap, required this.lists});

  final WeeklyRecap recap;
  final Map<String, TaskList> lists;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final best = recap.bestDay;
    final top = lists[recap.topListId];
    final lines = [
      if (best != null) l10n.recapBestDay(DateFormat.EEEE(locale).format(best)),
      if (top != null) l10n.recapTopList(top.name),
    ];
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: tint(scheme.primary, context.taskColors.card, .1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recapTitle,
              style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(l10n.recapDone(recap.done), style: text.titleLarge),
            for (final line in lines) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                line,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
