import 'package:animations/animations.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/list_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../completed/completed_screen.dart';
import 'list_detail_screen.dart';
import 'list_form_sheet.dart';

/// Inbox and Completed as colour tiles, then user lists (unlimited), each
/// with its own tinted icon.
class ListsTab extends StatefulWidget {
  const ListsTab({super.key, required this.actions});

  final List<Widget> actions;

  @override
  State<ListsTab> createState() => _ListsTabState();
}

class _ListsTabState extends State<ListsTab> {
  final _repo = getIt<ListRepository>();
  late final _lists = _repo.watchLists();
  late final _inbox = _repo.watchInboxCount();
  late final _completed = getIt<TaskRepository>().watchCompleted();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final colors = context.taskColors;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        title: Text(context.l10n.lists, style: text.headlineMedium),
        actions: widget.actions,
      ),
      body: StreamBuilder<List<ListWithCount>>(
        stream: _lists,
        builder: (context, snapshot) {
          final lists = snapshot.data ?? const <ListWithCount>[];
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpace.gutter,
              AppSpace.xs,
              AppSpace.gutter,
              AppSpace.xxl,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<int>(
                      stream: _inbox,
                      builder: (context, count) => _ColorTile(
                        color: scheme.primary,
                        icon: Icons.inbox_rounded,
                        label: context.l10n.inbox,
                        count: count.data ?? 0,
                        page: const ListDetailScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: StreamBuilder<List<Task>>(
                      stream: _completed,
                      builder: (context, done) => _ColorTile(
                        color: colors.priorityLow,
                        icon: Icons.task_alt_rounded,
                        label: context.l10n.completed,
                        count: done.data?.length ?? 0,
                        page: const CompletedScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpace.xs,
                  AppSpace.xl,
                  AppSpace.xs,
                  AppSpace.sm,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    context.l10n.myLists,
                    style: text.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    for (final item in lists) ...[
                      _ListRow(
                        color: Color(item.list.colorValue),
                        icon: Icons.format_list_bulleted_rounded,
                        title: item.list.name,
                        count: item.openCount,
                        page: ListDetailScreen(listId: item.list.id),
                        onLongPress: () =>
                            ListFormSheet.show(context, list: item.list),
                      ),
                      const Divider(indent: 68),
                    ],
                    // Inline action — no FAB to collide with snackbars
                    _ListRow(
                      color: scheme.primary,
                      icon: Icons.add_rounded,
                      title: context.l10n.newList,
                      titleColor: scheme.primary,
                      showChevron: false,
                      onTap: () => ListFormSheet.show(context),
                    ),
                  ],
                ),
              ),
              if (snapshot.hasData && lists.isEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpace.xs,
                    AppSpace.md,
                    AppSpace.xs,
                    0,
                  ),
                  child: Text(
                    context.l10n.listsHint,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Soft colour tile: icon badge, big count, label underneath
class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.color,
    required this.icon,
    required this.label,
    required this.count,
    required this.page,
  });

  final Color color;
  final IconData icon;
  final String label;
  final int count;

  /// Opened with a container transform from this tile
  final Widget page;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = tint(color, context.taskColors.card, isDark ? .22 : .12);
    return _ContainerLink(
      page: page,
      color: fill,
      radius: AppRadius.lg,
      builder: (context, open) => Semantics(
        button: true,
        label: '$label, $count',
        onTap: open,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpace.sm),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        icon,
                        color: scheme.surface,
                        size: AppIcon.md,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$count',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.color,
    required this.icon,
    required this.title,
    this.onTap,
    this.page,
    this.count,
    this.onLongPress,
    this.titleColor,
    this.showChevron = true,
  }) : assert((onTap == null) != (page == null), 'Pass onTap or page');

  final Color color;
  final IconData icon;
  final String title;
  final int? count;
  final VoidCallback? onTap;

  /// Opened with a container transform from this row
  final Widget? page;
  final VoidCallback? onLongPress;
  final Color? titleColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = page;
    if (target != null) {
      return _ContainerLink(
        page: target,
        color: context.taskColors.card,
        radius: 0,
        builder: (context, open) => _tile(context, scheme, text, isDark, open),
      );
    }
    return _tile(context, scheme, text, isDark, onTap!);
  }

  Widget _tile(
    BuildContext context,
    ColorScheme scheme,
    TextTheme text,
    bool isDark,
    VoidCallback onTap,
  ) {
    return ListTile(
      minTileHeight: 60,
      leading: ExcludeSemantics(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tint(color, context.taskColors.card, isDark ? .28 : .16),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: onTint(context, color), size: AppIcon.md),
        ),
      ),
      title: Text(title, style: text.bodyLarge?.copyWith(color: titleColor)),
      trailing: !showChevron
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count != null && count! > 0)
                  Text(
                    '$count',
                    style: text.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: AppSpace.xs),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// Opens [page] by growing it out of the tapped surface (container
/// transform), so the user sees where the screen came from and returns to
class _ContainerLink extends StatelessWidget {
  const _ContainerLink({
    required this.page,
    required this.color,
    required this.radius,
    required this.builder,
  });

  final Widget page;

  /// Fill of the closed surface
  final Color color;
  final double radius;
  final Widget Function(BuildContext context, VoidCallback open) builder;

  @override
  Widget build(BuildContext context) {
    return OpenContainer<void>(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: AppMotion.of(context, AppMotion.slow),
      closedElevation: 0,
      openElevation: 0,
      closedColor: color,
      middleColor: color,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      tappable: false,
      closedBuilder: builder,
      openBuilder: (context, _) => page,
    );
  }
}
