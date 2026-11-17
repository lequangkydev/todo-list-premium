import 'dart:io';

import 'package:flutter_ads/ads_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../config/di/di.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/activation/setup_guide.dart';
import '../../../shared/extension/context_extension.dart';
import '../../../shared/helpers/app_haptics.dart';
import '../../tasks/quick_add_sheet.dart';

/// Getting started on the Today tab: three steps that tick themselves off.
/// Shows nothing once they're done or the user hides it.
class SetupCard extends StatelessWidget {
  const SetupCard({super.key});

  @override
  Widget build(BuildContext context) {
    final guide = getIt<SetupGuide>();
    return ValueListenableBuilder(
      valueListenable: guide.state,
      builder: (context, state, _) => AnimatedSize(
        duration: AppMotion.of(context, AppMotion.medium),
        curve: AppMotion.curve,
        alignment: Alignment.topCenter,
        child: state.visible
            ? _Card(guide: guide, state: state)
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.guide, required this.state});

  final SetupGuide guide;
  final SetupState state;

  Future<void> _addWidget(BuildContext context) async {
    // The launcher's dialog takes the app to the background for a moment
    MyAds.instance.appLifecycleReactor?.setIsExcludeScreen(true);
    if (await guide.requestWidget() || !context.mounted) {
      return;
    }
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.widgets_outlined),
        title: Text(l10n.setupWidgetHowTitle),
        content: Text(
          Platform.isIOS ? l10n.setupWidgetHowIos : l10n.setupWidgetHowAndroid,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  /// The steps as (step, title, hint, button, action)
  List<(SetupStep, String, String, String, VoidCallback)> _steps(
    BuildContext context,
  ) {
    final l10n = context.l10n;
    return [
      (
        SetupStep.task,
        l10n.setupTask,
        l10n.setupTaskHint,
        l10n.setupAdd,
        () => QuickAddSheet.show(context),
      ),
      (
        SetupStep.notifications,
        l10n.setupNotifications,
        l10n.setupNotificationsHint,
        l10n.turnOn,
        () {
          MyAds.instance.appLifecycleReactor?.setIsExcludeScreen(true);
          guide.turnOnNotifications();
        },
      ),
      (
        SetupStep.widget,
        l10n.setupWidget,
        l10n.setupWidgetHint,
        l10n.setupAdd,
        () => _addWidget(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final steps = _steps(context);
    // Once there are tasks, they come first: the card shrinks to one row
    // with only the next step
    if (state.hasTask) {
      final (_, title, _, action, onTap) = steps.firstWhere(
        (s) => !state.isDone(s.$1),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpace.lg,
              top: AppSpace.xs,
              bottom: AppSpace.xs,
            ),
            child: Row(
              children: [
                _StepsDots(done: state.doneCount),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                FilledButton.tonal(
                  onPressed: () {
                    AppHaptics.selection();
                    onTap();
                  },
                  child: Text(action),
                ),
                IconButton(
                  tooltip: l10n.setupHide,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: guide.dismiss,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.xs,
            AppSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l10n.setupTitle, style: text.titleMedium),
                    ),
                  ),
                  Text(
                    '${state.doneCount}/${SetupStep.values.length}',
                    style: text.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.setupHide,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: guide.dismiss,
                  ),
                ],
              ),
              for (final (step, title, hint, action, onTap) in steps)
                _Step(
                  done: state.isDone(step),
                  title: title,
                  hint: hint,
                  action: action,
                  onTap: onTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three dots, filled for the steps already done
class _StepsDots extends StatelessWidget {
  const _StepsDots({required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      label: '$done/${SetupStep.values.length}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < SetupStep.values.length; i++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsetsDirectional.only(end: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done ? scheme.primary : scheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.done,
    required this.title,
    required this.hint,
    required this.action,
    required this.onTap,
  });

  final bool done;
  final String title;
  final String hint;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpace.sm,
        bottom: AppSpace.sm,
        end: AppSpace.md,
      ),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyLarge?.copyWith(
                    color: done ? scheme.onSurfaceVariant : null,
                  ),
                ),
                if (!done)
                  Text(
                    hint,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (!done) ...[
            const SizedBox(width: AppSpace.sm),
            FilledButton.tonal(
              onPressed: () {
                AppHaptics.selection();
                onTap();
              },
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }
}
