import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/di/di.dart';
import '../../config/navigation/app_router.dart';
import '../../config/theme/app_theme.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/list_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/day_clock.dart';
import '../tasks/widgets/task_sources.dart';
import '../tasks/widgets/task_tile.dart';

enum _Filter { highPriority, withReminder }

/// Searches titles and notes. Never blank: before typing it offers recent
/// searches, quick filters and the user's lists.
@RoutePage()
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _recentKey = 'recent_searches';
  static const _maxRecent = 6;

  final _repo = getIt<TaskRepository>();
  late final _results = KeyedStream<String, List<Task>>(_repo.search);
  final _controller = TextEditingController();
  late final _lists = getIt<ListRepository>().watchLists();
  String _query = '';
  _Filter? _filter;
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _recent = prefs.getStringList(_recentKey) ?? const []);
    }
  }

  Future<void> _remember(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return;
    }
    final next = [q, ..._recent.where((r) => r != q)].take(_maxRecent).toList();
    setState(() => _recent = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, next);
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }

  void _useQuery(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    setState(() {
      _query = q;
      _filter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() {
            _query = value.trim();
            _filter = null;
          }),
          onSubmitted: _remember,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.isNotEmpty || _filter != null)
            IconButton(
              tooltip: l10n.cancel,
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                setState(() {
                  _query = '';
                  _filter = null;
                });
              },
            ),
        ],
      ),
      body: _filter != null
          ? _results$(
              _filter == _Filter.highPriority
                  ? _repo.watchHighPriority()
                  : _repo.watchWithReminders(),
              emptyTitle: l10n.noResults(_filterLabel(context, _filter!)),
            )
          : _query.isEmpty
          ? _Suggestions(
              recent: _recent,
              lists: _lists,
              onRecent: _useQuery,
              onClearRecent: _clearRecent,
              onFilter: (f) => setState(() => _filter = f),
            )
          : _results$(
              _results.of(_query),
              emptyTitle: l10n.noResults(_query),
              onOpen: () => _remember(_query),
            ),
    );
  }

  Widget _results$(
    Stream<List<Task>> stream, {
    required String emptyTitle,
    VoidCallback? onOpen,
  }) {
    final today = getIt<DayClock>().value;
    return StreamBuilder<List<Task>>(
      stream: stream,
      builder: (context, snapshot) {
        final tasks = snapshot.data;
        if (tasks == null) {
          return const SizedBox.shrink();
        }
        if (tasks.isEmpty) {
          return Center(
            child: CalmEmptyState(
              icon: Icons.search_off_rounded,
              accent: context.taskColors.priorityMedium,
              title: emptyTitle,
            ),
          );
        }
        return TaskLookupsBuilder(
          builder: (context, lookups) => Listener(
            // Remember the query once the user engages with a result
            onPointerDown: (_) => onOpen?.call(),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              children: [
                TaskGroup(
                  children: [
                    for (final task in tasks)
                      TaskTile(
                        key: ValueKey(task.id),
                        task: task,
                        today: today,
                        subtasks: lookups.subtasks[task.id],
                        list: lookups.listOf(task),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _filterLabel(BuildContext context, _Filter f) => switch (f) {
  _Filter.highPriority => context.l10n.filterHighPriority,
  _Filter.withReminder => context.l10n.filterWithReminder,
};

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.recent,
    required this.lists,
    required this.onRecent,
    required this.onClearRecent,
    required this.onFilter,
  });

  final List<String> recent;
  final Stream<List<ListWithCount>> lists;
  final ValueChanged<String> onRecent;
  final VoidCallback onClearRecent;
  final ValueChanged<_Filter> onFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.taskColors;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpace.gutter,
        AppSpace.sm,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: [
        if (recent.isNotEmpty) ...[
          _Heading(
            l10n.recentSearches,
            trailing: TextButton(
              onPressed: onClearRecent,
              child: Text(l10n.clearRecent),
            ),
          ),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final r in recent)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 18),
                  label: Text(r),
                  onPressed: () => onRecent(r),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
        ],
        _Heading(l10n.suggestions),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            _TintChip(
              color: colors.priorityHigh,
              icon: Icons.flag_rounded,
              label: l10n.filterHighPriority,
              onTap: () => onFilter(_Filter.highPriority),
            ),
            _TintChip(
              color: context.colorScheme.primary,
              icon: Icons.notifications_active_rounded,
              label: l10n.filterWithReminder,
              onTap: () => onFilter(_Filter.withReminder),
            ),
          ],
        ),
        StreamBuilder<List<ListWithCount>>(
          stream: lists,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <ListWithCount>[];
            if (items.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.xl),
                _Heading(l10n.myLists),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final item in items)
                      _TintChip(
                        color: Color(item.list.colorValue),
                        icon: Icons.format_list_bulleted_rounded,
                        label: item.list.name,
                        onTap: () => context.pushRoute(
                          ListDetailRoute(listId: item.list.id),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Chip with a soft fill of its own colour
class _TintChip extends StatelessWidget {
  const _TintChip({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: onTint(context, color)),
      label: Text(label),
      backgroundColor: tint(color, context.taskColors.card, isDark ? .22 : .12),
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}
