import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.lists), actions: widget.actions),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ListFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.newList),
      ),
      body: StreamBuilder<List<ListWithCount>>(
        stream: _lists,
        builder: (context, snapshot) {
          final lists = snapshot.data ?? const <ListWithCount>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
                        ),
                        title: context.l10n.inbox,
                        count: count.data ?? 0,
                        onTap: () => context.pushRoute(ListDetailRoute()),
                      ),
                    ),
                    const Divider(indent: 56),
                    _ListRow(
                      leading: Icon(
                        Icons.check_circle_outline_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: context.l10n.completed,
                      onTap: () => context.pushRoute(const CompletedRoute()),
                    ),
                  ],
                ),
              ),
              if (lists.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                  child: Text(
                    context.l10n.myLists,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < lists.length; i++) ...[
                        if (i > 0) const Divider(indent: 56),
                        _ListRow(
                          leading: Icon(
                            Icons.circle,
                            size: 14,
                            color: Color(lists[i].list.colorValue),
                          ),
                          title: lists[i].list.name,
                          count: lists[i].openCount,
                          onTap: () => context.pushRoute(
                            ListDetailRoute(listId: lists[i].list.id),
                          ),
                          onLongPress: () =>
                              ListFormSheet.show(context, list: lists[i].list),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else if (snapshot.hasData)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 24, 8, 0),
                  child: Text(
                    context.l10n.listsHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
  });

  final Widget leading;
  final String title;
  final int? count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(width: 24, child: Center(child: leading)),
      title: Text(title),
      trailing: count == null || count == 0
          ? const Icon(Icons.chevron_right_rounded)
          : Text(
              '$count',
              style: TextStyle(color: context.colorScheme.onSurfaceVariant),
            ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
