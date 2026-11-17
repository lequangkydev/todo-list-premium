import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/list_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/day_clock.dart';
import '../tasks/widgets/quick_add_field.dart';
import '../tasks/widgets/task_sources.dart';
import '../tasks/widgets/task_tile.dart';
import 'list_form_sheet.dart';

/// One list (or the Inbox when [listId] is null) with drag-to-reorder.
@RoutePage()
class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({super.key, this.listId});

  final String? listId;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  final _repo = getIt<TaskRepository>();
  late final _tasks = _repo.watchList(widget.listId);
  late final _list = widget.listId == null
      ? Stream<TaskList?>.value(null)
      : getIt<ListRepository>().watchList(widget.listId!);

  /// Order shown while a drag is being saved, so rows don't jump back
  List<Task>? _optimistic;

  Future<void> _reorder(List<Task> tasks, int oldIndex, int newIndex) async {
    final ordered = [...tasks];
    // onReorderItem already accounts for the removed row
    ordered.insert(newIndex, ordered.removeAt(oldIndex));
    setState(() => _optimistic = ordered);
    await _repo.reorder(ordered);
    if (mounted) {
      setState(() => _optimistic = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskList?>(
      stream: _list,
      builder: (context, listSnapshot) {
        final list = listSnapshot.data;
        final title = widget.listId == null
            ? context.l10n.inbox
            : list?.name ?? '';
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                if (list != null) ...[
                  Icon(Icons.circle, size: 14, color: Color(list.colorValue)),
                  const SizedBox(width: 10),
                ],
                Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              ],
            ),
            actions: [
              if (list != null)
                IconButton(
                  tooltip: context.l10n.editList,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final deleted = await ListFormSheet.show(
                      context,
                      list: list,
                    );
                    if ((deleted ?? false) && context.mounted) {
                      context.maybePop();
                    }
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                child: QuickAddField(listId: widget.listId),
              ),
              Expanded(
                child: StreamBuilder<List<Task>>(
                  stream: _tasks,
                  builder: (context, snapshot) {
                    final tasks = _optimistic ?? snapshot.data;
                    if (tasks == null) {
                      return const SizedBox.shrink();
                    }
                    if (tasks.isEmpty) {
                      return SingleChildScrollView(
                        child: CalmEmptyState(
                          icon: Icons.add_task_rounded,
                          accent: list == null ? null : Color(list.colorValue),
                          title: context.l10n.listEmptyTitle,
                          message: context.l10n.listEmptyMessage,
                        ),
                      );
                    }
                    final today = getIt<DayClock>().value;
                    return TaskLookupsBuilder(
                      builder: (context, lookups) =>
                          ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpace.gutter,
                              AppSpace.xs,
                              AppSpace.gutter,
                              AppSpace.xxl,
                            ),
                            buildDefaultDragHandles: false,
                            itemCount: tasks.length,
                            onReorderItem: (a, b) => _reorder(tasks, a, b),
                            onReorderStart: (_) => AppHaptics.selection(),
                            onReorderEnd: (_) => AppHaptics.light(),
                            proxyDecorator: (child, index, animation) =>
                                _LiftedRow(animation: animation, child: child),
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey(task.id),
                                index: index,
                                child: _CardSlice(
                                  first: index == 0,
                                  last: index == tasks.length - 1,
                                  child: TaskTile(
                                    task: task,
                                    today: today,
                                    subtasks: lookups.subtasks[task.id],
                                  ),
                                ),
                              );
                            },
                          ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One row of a card split across a scrolling list: rounded only at the
/// ends, with a divider between rows, so the list reads as one card
class _CardSlice extends StatelessWidget {
  const _CardSlice({
    required this.first,
    required this.last,
    required this.child,
  });

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    const r = Radius.circular(AppRadius.lg);
    final side = BorderSide(color: scheme.outlineVariant);
    return Container(
      decoration: BoxDecoration(
        color: context.taskColors.card,
        borderRadius: BorderRadius.vertical(
          top: first ? r : Radius.zero,
          bottom: last ? r : Radius.zero,
        ),
        border: Border(
          left: side,
          right: side,
          top: first ? side : BorderSide.none,
          bottom: side,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// The row being dragged: lifts off the card (slight scale + shadow) and
/// settles back when dropped
class _LiftedRow extends StatelessWidget {
  const _LiftedRow({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lift = AppMotion.enabled(context) ? .02 : 0.0;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = AppMotion.enter.transform(animation.value);
        return Transform.scale(
          scale: 1 + lift * t,
          child: Material(
            elevation: 8 * t,
            shadowColor: context.colorScheme.primary.withValues(alpha: .35),
            color: context.taskColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
