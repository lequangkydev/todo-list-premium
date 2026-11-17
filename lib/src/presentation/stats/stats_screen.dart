import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/date/dates.dart';
import '../../core/stats/task_stats.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/focus_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_format.dart';
import '../tasks/widgets/task_sources.dart';

/// What got done lately: the week, an activity heatmap, how each list is
/// going, focus time. Counts only — no streaks, nothing to lose by resting.
@RoutePage()
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  /// Weeks shown in the heatmap
  static const heatmapWeeks = 16;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _subs = <StreamSubscription<Object>>[];
  List<Task>? _done;
  List<Task>? _open;
  List<ActivityDay>? _activity;
  List<FocusSession>? _sessions;
  late final DateTime _today = getIt<DayClock>().value;

  @override
  void initState() {
    super.initState();
    final tasks = getIt<TaskRepository>();
    final from = Dates.addDays(_today, -(TaskStats.periodDays - 1));
    final heatFrom = Dates.addDays(_today, -StatsScreen.heatmapWeeks * 7);
    _subs
      ..add(tasks.watchDoneSince(from).listen((v) => setState(() => _done = v)))
      ..add(tasks.watchOpen().listen((v) => setState(() => _open = v)))
      ..add(
        tasks
            .watchActivitySince(heatFrom)
            .listen((v) => setState(() => _activity = v)),
      )
      ..add(
        getIt<FocusRepository>()
            .watchSince(Dates.addDays(_today, -6))
            .listen((v) => setState(() => _sessions = v)),
      );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = _done;
    final open = _open;
    final activity = _activity;
    final sessions = _sessions;
    final ready =
        done != null && open != null && activity != null && sessions != null;
    final stats = ready
        ? TaskStats.compute(
            today: _today,
            done: done,
            open: open,
            activity: activity,
            sessions: sessions,
          )
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.stats)),
      body: stats == null
          ? const SizedBox.shrink()
          : stats.isEmpty
          ? Center(
              child: CalmEmptyState(
                icon: Icons.insights_rounded,
                title: l10n.statsEmptyTitle,
                message: l10n.statsEmptyHint,
              ),
            )
          : TaskLookupsBuilder(
              builder: (context, lookups) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.sm,
                  AppSpace.gutter,
                  AppSpace.xxl,
                ),
                children: [
                  _Section(
                    title: l10n.statsWeek,
                    child: _Week(stats: stats),
                  ),
                  _Section(
                    title: l10n.statsActivity,
                    child: _Heatmap(stats: stats, today: _today),
                  ),
                  if (stats.lists.isNotEmpty)
                    _Section(
                      title: l10n.statsLists,
                      child: _Lists(stats: stats, lists: lookups.lists),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Seven bars, one per day, with the count on top
class _Week extends StatelessWidget {
  const _Week({required this.stats});

  final TaskStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final max = stats.week.fold(1, (m, d) => d.done > m ? d.done : m);
    final best = stats.bestHour;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.recapDone(stats.weekDone), style: text.titleLarge),
        const SizedBox(height: AppSpace.lg),
        SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in stats.week)
                Expanded(
                  child: Semantics(
                    label:
                        '${DateFormat.EEEE(locale).format(day.day)}: '
                        '${l10n.recapDone(day.done)}',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          day.done == 0 ? '' : '${day.done}',
                          style: text.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: day.done == 0 ? 4 : 8 + 80 * day.done / max,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: day.done == 0
                                ? scheme.surfaceContainerHighest
                                : scheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.E(locale).format(day.day),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
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
        ),
        if (stats.focusSessions > 0) ...[
          const SizedBox(height: AppSpace.md),
          _Line(
            icon: Icons.timer_outlined,
            text: l10n.statsFocusTotal(
              stats.focusSessions,
              TaskFormat.duration(l10n, stats.weekFocusMinutes),
            ),
          ),
        ],
        if (best != null) ...[
          const SizedBox(height: AppSpace.sm),
          _Line(
            icon: Icons.schedule_rounded,
            text: l10n.statsBestTime(
              TaskFormat.time(context, best * 60),
              TaskFormat.time(context, (best + 2) % 24 * 60),
            ),
          ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Weeks as columns, Monday on top; darker = more done that day
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.stats, required this.today});

  final TaskStats stats;
  final DateTime today;

  static double level(int count) => switch (count) {
    0 => 0,
    < 3 => .35,
    < 6 => .65,
    _ => 1,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    const weeks = StatsScreen.heatmapWeeks;
    final firstMonday = Dates.addDays(
      Dates.startOfWeek(today),
      -(weeks - 1) * 7,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: l10n.statsActiveDays(stats.activeDays),
          excludeSemantics: true,
          child: LayoutBuilder(
            builder: (context, box) {
              const gap = 3.0;
              final cell = ((box.maxWidth - gap * (weeks - 1)) / weeks).clamp(
                6.0,
                18.0,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var w = 0; w < weeks; w++)
                    Column(
                      children: [
                        for (var d = 0; d < 7; d++)
                          Builder(
                            builder: (context) {
                              final day = Dates.addDays(firstMonday, w * 7 + d);
                              final future = day.isAfter(today);
                              final amount = level(stats.heatmap[day] ?? 0);
                              return Container(
                                width: cell,
                                height: cell,
                                margin: const EdgeInsets.only(bottom: gap),
                                decoration: BoxDecoration(
                                  color: future
                                      ? Colors.transparent
                                      : amount == 0
                                      ? scheme.surfaceContainerHighest
                                      : scheme.primary.withValues(
                                          alpha: amount,
                                        ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          l10n.statsActiveDays(stats.activeDays),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Each list: done lately out of done + still open
class _Lists extends StatelessWidget {
  const _Lists({required this.stats, required this.lists});

  final TaskStats stats;
  final Map<String, TaskList> lists;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stat in stats.lists.take(8)) ...[
          Builder(
            builder: (context) {
              final list = lists[stat.listId];
              final color = list == null
                  ? scheme.primary
                  : Color(list.colorValue);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            list?.name ?? l10n.inbox,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge,
                          ),
                        ),
                        Text(
                          '${stat.done}/${stat.total}',
                          style: text.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stat.rate,
                        minHeight: 6,
                        color: color,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        Text(
          l10n.statsListHint,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
