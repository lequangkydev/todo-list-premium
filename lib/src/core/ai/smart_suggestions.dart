import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../data/local/database/app_database.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/cubit/smart_suggestions_cubit.dart';
import 'ai_provider.dart';
import 'day_planner.dart';
import 'suggestion_engine.dart';

/// The app's assistant. Keeps a [SuggestionEngine] in step with the task
/// history and routes text work to the best available [AiProvider].
///
/// Everything runs on the phone; nothing is sent anywhere.
@lazySingleton
class SmartSuggestions {
  SmartSuggestions(this._repo, this._settings) {
    _sub = _repo.watchHistory().listen((tasks) {
      _debounce?.cancel();
      // Rebuilding is cheap, but a burst of edits only needs one
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _engine = SuggestionEngine(tasks);
      });
    });
  }

  final TaskRepository _repo;
  final SmartSuggestionsCubit _settings;
  late final StreamSubscription<List<Task>> _sub;
  Timer? _debounce;
  SuggestionEngine _engine = SuggestionEngine(const []);

  /// Tier 0 for now; better tiers slot in front of it later
  final AiProvider provider = RuleBasedProvider();

  /// Whether passive suggestions are on
  bool get enabled => _settings.state;

  /// Hints while typing; empty when the user turned suggestions off
  TaskHints hints(String title, {String? listId, bool hasTime = false}) =>
      enabled
      ? _engine.hints(title, listId: listId, hasTime: hasTime)
      : TaskHints.none;

  /// The task's own duration, or one learned from similar tasks
  int? estimateOf(Task task) =>
      task.estimateMinutes ?? _engine.estimateFor(task.title);

  /// Learned duration for a title, ignoring the switch (used when the user
  /// asks for it, e.g. the duration picker)
  int? estimateFor(String title) => _engine.estimateFor(title);

  DayPlan planDay(List<Task> tasks, {DateTime? now}) => DayPlanner.plan(
    tasks: tasks,
    now: now ?? DateTime.now(),
    estimateOf: estimateOf,
  );

  @disposeMethod
  Future<void> dispose() async {
    _debounce?.cancel();
    await _sub.cancel();
  }
}
