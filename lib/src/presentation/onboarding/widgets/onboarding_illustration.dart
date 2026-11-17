import 'package:material_ui/material_ui.dart';

import '../../../config/theme/app_theme.dart';
import '../../../shared/extension/context_extension.dart';

enum OnboardingScene { today, quickAdd, reminder, privacy }

/// Illustrations built from the app's own components (no raster art), so
/// they match the theme in light and dark mode. Decorative only.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.scene});

  final OnboardingScene scene;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ExcludeSemantics(
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondaryContainer.withValues(alpha: .7),
              ),
            ),
            SizedBox(
              width: 300,
              child: switch (scene) {
                OnboardingScene.today => const _TodayCard(),
                OnboardingScene.quickAdd => const _QuickAddCard(),
                OnboardingScene.reminder => const _ReminderCard(),
                OnboardingScene.privacy => const _PrivacyCard(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MockCard extends StatelessWidget {
  const _MockCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.taskColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(AppSpace.lg), child: child),
    );
  }
}

class _MockTask extends StatelessWidget {
  const _MockTask(this.title, {this.done = false, this.meta, this.color});

  final String title;
  final bool done;
  final String? meta;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final ring = color ?? context.taskColors.noPriority;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? ring : null,
              border: Border.all(color: ring, width: 2),
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 14, color: scheme.surface)
                : null,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (meta != null) Text(meta!, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _MockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.today, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.xs),
          _MockTask(l10n.onbSampleTask1, meta: '09:00'),
          _MockTask(
            l10n.onbSampleTask2,
            color: context.taskColors.priorityHigh,
            meta: l10n.priorityHigh,
          ),
          _MockTask(l10n.onbSampleTask3, done: true),
        ],
      ),
    );
  }
}

class _QuickAddCard extends StatelessWidget {
  const _QuickAddCard();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final highlight = text.bodyLarge?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w700,
      backgroundColor: scheme.primary.withValues(alpha: .12),
    );
    return _MockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.primary, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.add_rounded, color: scheme.primary),
                const SizedBox(width: AppSpace.sm),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      style: text.bodyLarge,
                      children: [
                        TextSpan(text: '${l10n.onbSampleQuickTitle} '),
                        TextSpan(
                          text: l10n.onbSampleQuickWhen,
                          style: highlight,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              _MiniChip(Icons.event_rounded, l10n.tomorrow),
              _MiniChip(Icons.schedule_rounded, '21:00'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIcon.sm, color: scheme.primary),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return _MockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: AppIcon.sm,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  l10n.app_title,
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text('21:00', style: text.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(l10n.onbSampleQuickTitle, style: text.titleMedium),
          Text(l10n.reminderDue(l10n.today), style: text.bodySmall),
          const SizedBox(height: AppSpace.md),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    l10n.actionDone,
                    style: text.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ),
              ),
              Container(width: 1, height: 36, color: scheme.outlineVariant),
              Expanded(
                child: Center(
                  child: Text(
                    l10n.actionSnooze,
                    style: text.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    Widget row(IconData icon, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: AppIcon.md),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
    return _MockCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 36,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          row(Icons.person_off_outlined, l10n.onbNoAccount),
          row(Icons.cloud_off_outlined, l10n.onbOffline),
          row(Icons.smartphone_rounded, l10n.onbLocalOnly),
        ],
      ),
    );
  }
}
