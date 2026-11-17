import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/ai/day_planner.dart';
import '../../core/ai/smart_suggestions.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/day_clock.dart';
import '../../shared/helpers/task_format.dart';
import '../../shared/widgets/motion.dart';

/// Shows a proposed timeline for today and applies it only on request.
/// Timed tasks stay put; the rest are fitted around them.
class PlanDaySheet extends StatelessWidget {
  const PlanDaySheet({super.key, required this.plan});

  final DayPlan plan;

  /// [tasks]: today's and overdue open tasks
  static Future<void> show(BuildContext context, List<Task> tasks) {
    final plan = getIt<SmartSuggestions>().planDay(tasks);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AppMotion.sheet(context),
      builder: (_) => PlanDaySheet(plan: plan),
    );
  }

  Future<void> _apply(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final today = getIt<DayClock>().value;
    final placed = plan.placed.toList();
    final undo = await getIt<TaskRepository>().schedule({
      for (final p in placed) p.task: (date: today, time: p.start),
    });
    AppHaptics.light();
    if (context.mounted) {
      Navigator.pop(context);
    }
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.planApplied(placed.length)),
          action: SnackBarAction(label: l10n.undo, onPressed: undo),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final hasPlan = plan.placed.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.sm,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.planMyDay, style: text.titleLarge),
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            0,
            AppSpace.xl,
            AppSpace.sm,
          ),
          child: Text(
            hasPlan ? l10n.planIntro : l10n.planNothing,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            children: [
              for (final (i, item) in plan.items.indexed)
                Entrance(
                  delay: Duration(milliseconds: 30 * i.clamp(0, 10)),
                  child: _SlotRow(item: item),
                ),
              if (plan.later.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.xl,
                    AppSpace.lg,
                    AppSpace.xl,
                    AppSpace.xs,
                  ),
                  child: Text(
                    l10n.planLater,
                    style: text.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final task in plan.later)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xl,
                    ),
                    leading: ExcludeSemantics(
                      child: Icon(
                        Icons.schedule_rounded,
                        color: scheme.outline,
                        size: AppIcon.md,
                      ),
                    ),
                    title: Text(task.title),
                  ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.xs,
            AppSpace.xl,
            AppSpace.lg,
          ),
          child: FilledButton.icon(
            onPressed: hasPlan ? () => _apply(context) : null,
            icon: const Icon(Icons.schedule_rounded),
            label: Text(l10n.planApply),
          ),
        ),
      ],
    );
  }
}

/// "9:15  ● Write report  45 min" — fixed tasks are quieter, with a lock
class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.item});

  final PlannedTask item;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final color = context.taskColors.priority(item.task.priority);
    final muted = item.fixed;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              TaskFormat.time(context, item.start),
              style: text.labelLarge?.copyWith(
                color: muted ? scheme.onSurfaceVariant : scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          ExcludeSemantics(
            child: Icon(
              muted ? Icons.lock_clock_outlined : Icons.circle,
              size: muted ? AppIcon.sm : 10,
              color: muted ? scheme.outline : color,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              item.task.title,
              style: text.bodyLarge?.copyWith(
                color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(
            TaskFormat.duration(l10n, item.minutes),
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
