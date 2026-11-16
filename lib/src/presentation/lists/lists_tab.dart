import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
import '../../config/theme/app_theme.dart';
import '../../data/repositories/list_repository.dart';
import '../../shared/extension/context_extension.dart';
import 'list_form_sheet.dart';

/// Inbox, user lists (unlimited) and the Completed archive.
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

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
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
              Card(
                child: Column(
                  children: [
                    StreamBuilder<int>(
                      stream: _inbox,
                      builder: (context, count) => _ListRow(
                        leading: Icon(
                          Icons.inbox_rounded,
                          color: scheme.primary,
                          size: AppIcon.lg,
                        ),
                        title: context.l10n.inbox,
                        count: count.data ?? 0,
                        onTap: () => context.pushRoute(ListDetailRoute()),
                      ),
                    ),
                    const Divider(indent: 60),
                    _ListRow(
                      leading: Icon(
                        Icons.task_alt_rounded,
                        color: scheme.onSurfaceVariant,
                        size: AppIcon.lg,
                      ),
                      title: context.l10n.completed,
                      onTap: () => context.pushRoute(const CompletedRoute()),
                    ),
                  ],
                ),
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
                        leading: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Color(item.list.colorValue),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: item.list.name,
                        count: item.openCount,
                        onTap: () => context.pushRoute(
                          ListDetailRoute(listId: item.list.id),
                        ),
                        onLongPress: () =>
                            ListFormSheet.show(context, list: item.list),
                      ),
                      const Divider(indent: 60),
                    ],
                    // Inline action — no FAB to collide with snackbars
                    _ListRow(
                      leading: Icon(
                        Icons.add_rounded,
                        color: scheme.primary,
                        size: AppIcon.lg,
                      ),
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

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.count,
    this.onLongPress,
    this.titleColor,
    this.showChevron = true,
  });

  final Widget leading;
  final String title;
  final int? count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? titleColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    return ListTile(
      minTileHeight: 56,
      leading: ExcludeSemantics(
        child: SizedBox(width: 28, child: Center(child: leading)),
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
                    style: text.bodyMedium?.copyWith(
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
