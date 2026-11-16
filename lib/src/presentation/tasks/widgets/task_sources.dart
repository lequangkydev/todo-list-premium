import 'package:flutter/material.dart';

import '../../../config/di/di.dart';
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

/// Small uppercase-free section header used by Today / Upcoming
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
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
        child: Row(
          children: [
            Flexible(child: Text(title, style: style)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: style?.copyWith(fontWeight: FontWeight.w400),
              ),
            ],
            if (expanded != null)
              Icon(
                expanded!
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            const Spacer(),
            ?trailing,
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: .6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
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
