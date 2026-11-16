import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../config/di/di.dart';
import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/day_clock.dart';
import '../tasks/widgets/task_sources.dart';
import '../tasks/widgets/task_tile.dart';

/// Searches titles and notes of open and completed tasks.
@RoutePage()
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _results = KeyedStream<String, List<Task>>(
    getIt<TaskRepository>().search,
  );
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final today = getIt<DayClock>().value;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            hintText: context.l10n.searchHint,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
      body: _query.isEmpty
          ? const SizedBox.shrink()
          : StreamBuilder<List<Task>>(
              stream: _results.of(_query),
              builder: (context, snapshot) {
                final tasks = snapshot.data;
                if (tasks == null) {
                  return const SizedBox.shrink();
                }
                if (tasks.isEmpty) {
                  return Center(
                    child: CalmEmptyState(
                      icon: Icons.search_off_rounded,
                      title: context.l10n.noResults(_query),
                    ),
                  );
                }
                return TaskLookupsBuilder(
                  builder: (context, lookups) => ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                );
              },
            ),
    );
  }
}
