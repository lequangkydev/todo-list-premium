import 'package:flutter/material.dart';

import '../../../config/di/di.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/list_repository.dart';
import '../../../data/repositories/task_repository.dart';

/// Lookups every task row needs: subtask progress and list by id.
class TaskLookups {
  const TaskLookups({this.subtasks = const {}, this.lists = const {}});

  final Map<String, SubtaskCount> subtasks;
  final Map<String, TaskList> lists;

  TaskList? listOf(Task task) =>
      task.listId == null ? null : lists[task.listId];
}

/// Provides [TaskLookups] to a subtree
class TaskLookupsBuilder extends StatefulWidget {
  const TaskLookupsBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, TaskLookups lookups) builder;

  @override
  State<TaskLookupsBuilder> createState() => _TaskLookupsBuilderState();
}

class _TaskLookupsBuilderState extends State<TaskLookupsBuilder> {
  late final _subtasks = getIt<TaskRepository>().watchSubtaskCounts();
  late final _lists = getIt<ListRepository>().watchLists();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, SubtaskCount>>(
      stream: _subtasks,
      builder: (context, subtasks) {
        return StreamBuilder<List<ListWithCount>>(
          stream: _lists,
          builder: (context, lists) {
            return widget.builder(
              context,
              TaskLookups(
                subtasks: subtasks.data ?? const {},
                lists: {
                  for (final l in lists.data ?? const <ListWithCount>[])
                    l.list.id: l.list,
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Caches a stream per key (e.g. per day) across rebuilds
class KeyedStream<K, T> {
  KeyedStream(this._create);

  final Stream<T> Function(K key) _create;
  K? _key;
  Stream<T>? _stream;

  Stream<T> of(K key) {
    if (_stream == null || key != _key) {
      _key = key;
      _stream = _create(key);
    }
    return _stream!;
  }
}

/// Section header used by Today / Upcoming / Completed. The whole row is
/// tappable (≥48dp) when [onTap] is set, and announces expanded state.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
    this.onTap,
    this.expanded,
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant);
    final header = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter + 4,
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: title,
                  children: [
                    if (count != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: AppSpace.sm,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '$count',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                    if (expanded != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: ExcludeSemantics(
                          child: AnimatedRotation(
                            turns: expanded! ? 0 : -.25,
                            duration: AppMotion.of(context, AppMotion.medium),
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: AppIcon.md,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                style: style,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    if (onTap == null) {
      return Semantics(header: true, child: header);
    }
    return Semantics(
      header: true,
      button: true,
      expanded: expanded,
      child: InkWell(onTap: onTap, child: header),
    );
  }
}

/// Calm empty state: icon, one line, optional hint
class CalmEmptyState extends StatelessWidget {
  const CalmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xxl + 8,
        vertical: AppSpace.xxl + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(AppSpace.xl - 4),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: scheme.primary),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpace.xs + 2),
            Text(
              message!,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
