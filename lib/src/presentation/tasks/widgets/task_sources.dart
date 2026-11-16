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
        padding: const EdgeInsetsDirectional.fromSTEB(
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

/// Empty state with a small composed illustration (tinted circle, a tilted
/// mini task card and an icon badge in [accent]) instead of a bare icon.
class CalmEmptyState extends StatelessWidget {
  const CalmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Defaults to the brand primary
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = accent ?? scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xxl + 8,
        vertical: AppSpace.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: _EmptyIllustration(icon: icon, color: color),
          ),
          const SizedBox(height: AppSpace.xl),
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

class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = context.taskColors.card;
    Widget line(double width, {bool strong = false}) => Container(
      width: width,
      height: 8,
      decoration: BoxDecoration(
        color: strong
            ? color.withValues(alpha: .35)
            : scheme.outlineVariant.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return SizedBox(
      width: 168,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint(color, scheme.surface, .14),
            ),
          ),
          Transform.rotate(
            angle: -.08,
            child: Container(
              width: 112,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadow.soft(context),
                border: AppShadow.hairline(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpace.sm),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == 0 ? color : null,
                            border: Border.all(color: color, width: 2),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        line(i == 1 ? 44 : 60, strong: i == 0),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          PositionedDirectional(
            end: 10,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 3),
              ),
              child: Icon(icon, size: 22, color: scheme.surface),
            ),
          ),
        ],
      ),
    );
  }
}
