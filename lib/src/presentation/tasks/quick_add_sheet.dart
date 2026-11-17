import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/day_clock.dart';
import 'widgets/quick_add_field.dart';

/// The quick-add field on its own, with the keyboard up — what the widget's
/// "+", the Quick Settings tile and the "Add a task" shortcut open.
class QuickAddSheet extends StatelessWidget {
  const QuickAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AppMotion.sheet(context),
      builder: (_) => const QuickAddSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          AppSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.l10n.addTask,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            QuickAddField(
              autofocus: true,
              defaultDate: getIt<DayClock>().value,
              onSubmitted: () => Navigator.maybePop(context),
            ),
          ],
        ),
      ),
    );
  }
}
