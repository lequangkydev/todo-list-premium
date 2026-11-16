import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';
import '../../../shared/extension/context_extension.dart';

/// Today at a glance: a progress ring (done / planned) and one calm line.
/// No streaks, no scores — just where the day stands.
class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({super.key, required this.open, required this.done});

  final int open;
  final int done;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final total = open + done;
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = open == 0 && done > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      container: true,
      label: '${l10n.summaryRemaining(open)}. ${l10n.doneToday(done)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg + 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg + 4),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [scheme.primaryContainer, scheme.surfaceContainerHigh]
                : [const Color(0xFFD7F5EE), const Color(0xFFEAF6FF)],
          ),
          boxShadow: AppShadow.soft(context),
        ),
        child: Row(
          children: [
            _ProgressRing(progress: progress, done: done, total: total),
            const SizedBox(width: AppSpace.lg + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allDone ? l10n.allDoneTitle : l10n.summaryRemaining(open),
                    style: text.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    done > 0 ? l10n.doneToday(done) : l10n.summaryStart,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: .8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.done,
    required this.total,
  });

  final double progress;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final duration = AppMotion.of(context, const Duration(milliseconds: 600));
    return SizedBox.square(
      dimension: 64,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: duration,
        curve: AppMotion.curve,
        builder: (context, value, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                color: scheme.primary,
                backgroundColor: scheme.primary.withValues(alpha: .15),
              ),
            ),
            if (progress >= 1)
              Icon(Icons.check_rounded, color: scheme.primary, size: 30)
            else
              Text(
                '$done/$total',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
