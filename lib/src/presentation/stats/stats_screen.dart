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
import '../../shared/widgets/motion.dart';
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
                  // Sections arrive one after another, top to bottom
                  for (final (i, section) in [
                    _Hero(stats: stats),
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
                  ].indexed)
                    Entrance(
                      key: ValueKey(i),
                      delay: Duration(milliseconds: 60 * i),
                      offset: 12,
                      child: section,
                    ),
                ],
              ),
            ),
    );
  }
}

/// Three numbers at a glance: done this week, focus time, active days
class _Hero extends StatelessWidget {
  const _Hero({required this.stats});

  final TaskStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final colors = context.taskColors;
    final focus = stats.weekFocusMinutes;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _HeroTile(
                color: scheme.primary,
                icon: Icons.task_alt_rounded,
                label: l10n.completed,
                value: stats.weekDone,
                format: (v) => '$v',
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: _HeroTile(
                color: colors.priorityHigh,
                icon: Icons.timer_outlined,
                label: l10n.focus,
                value: focus,
                // Hours:minutes reads the same in every language
                format: (v) =>
                    '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}',
                semantics: TaskFormat.duration(l10n, focus),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: _HeroTile(
                color: colors.priorityLow,
                icon: Icons.local_fire_department_outlined,
                label: l10n.statsActivity,
                value: stats.activeDays,
                format: (v) => '$v',
                suffix: '/${TaskStats.periodDays}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
    this.suffix,
    this.semantics,
  });

  final Color color;
  final IconData icon;
  final String label;
  final int value;
  final String Function(int value) format;
  final String? suffix;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: '$label: ${semantics ?? '${format(value)}${suffix ?? ''}'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: tint(color, context.taskColors.card, isDark ? .22 : .12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppIcon.md, color: onTint(context, color)),
            const SizedBox(height: AppSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: CountUp(
                    value: value,
                    builder: (context, v) => Text(
                      format(v),
                      maxLines: 1,
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (suffix != null)
                  Text(
                    suffix!,
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
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
        SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, day) in stats.week.indexed)
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
                        GrowIn(
                          delay: Duration(milliseconds: 40 * i),
                          child: Container(
                            height: day.done == 0 ? 4 : 8 + 80 * day.done / max,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              // Today in full colour, the days before it
                              // a step back
                              color: day.done == 0
                                  ? scheme.surfaceContainerHighest
                                  : i == stats.week.length - 1
                                  ? scheme.primary
                                  : scheme.primary.withValues(alpha: .45),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.E(locale).format(day.day),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: text.labelSmall?.copyWith(
                            color: i == stats.week.length - 1
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: i == stats.week.length - 1
                                ? FontWeight.w700
                                : null,
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
              // Square cells that exactly fill the width, with even gaps
              const gap = 4.0;
              final cell = (box.maxWidth - gap * (weeks - 1)) / weeks;
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
                                  borderRadius: BorderRadius.circular(4),
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
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: stat.rate),
                        duration: AppMotion.of(
                          context,
                          const Duration(milliseconds: 600),
                        ),
                        curve: AppMotion.enter,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          color: color,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
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
