import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/local/database/app_database.dart';
import 'text.dart';

/// What the engine would suggest for a task being typed. Every field is
/// optional: the engine stays quiet unless the user's own history is clear.
@immutable
class TaskHints {
  const TaskHints({this.listId, this.priority, this.time, this.duplicate});

  static const none = TaskHints();

  /// List this kind of task usually goes into
  final String? listId;

  /// Priority this kind of task usually gets (1–3, never 0)
  final int? priority;

  /// Usual time of day, minutes after midnight
  final int? time;

  /// An open task that looks like the same thing
  final Task? duplicate;

  bool get isEmpty =>
      listId == null && priority == null && time == null && duplicate == null;
}

/// Learns from the user's own tasks, on the phone, with no model: a naive
/// Bayes classifier over words and word pairs for list and priority, and
/// nearest past tasks for usual time and duration.
///
/// Build a new engine when the history changes; building is cheap (a few ms
/// for thousands of tasks).
class SuggestionEngine {
  SuggestionEngine(Iterable<Task> history) {
    for (final task in history) {
      if (task.deletedAt != null || task.parentId != null) {
        continue;
      }
      final f = features(task.title);
      if (f.isEmpty) {
        continue;
      }
      _lists.add(task.listId, f);
      _priorities.add(task.priority, f);
      final w = words(task.title).toSet();
      if (task.dueTime != null) {
        _timed.add((w, task.dueTime!));
      }
      if (task.estimateMinutes != null) {
        _estimated.add((w, task.estimateMinutes!));
      }
      if (!task.isDone) {
        _open.add((task, trigrams(task.title)));
      }
    }
  }

  final _lists = _NaiveBayes<String?>();
  final _priorities = _NaiveBayes<int>();
  final _timed = <(Set<String>, int)>[];
  final _estimated = <(Set<String>, int)>[];
  final _open = <(Task, Set<String>)>[];

  /// Posterior a suggestion needs before it's shown
  static const confidence = .7;

  /// Tasks a list needs before the engine suggests it
  static const minExamples = 3;

  /// Words in common (Jaccard) for a past task to count as "the same kind"
  static const similar = .5;

  /// Hints for [title] (already without its date words). [listId] is the
  /// list the task will go into anyway; no list is suggested then.
  TaskHints hints(String title, {String? listId, bool hasTime = false}) {
    final f = features(title);
    if (f.isEmpty) {
      return TaskHints.none;
    }
    return TaskHints(
      listId: listId == null ? suggestList(title) : null,
      priority: suggestPriority(title),
      time: hasTime ? null : usualTime(title),
      duplicate: findDuplicate(title),
    );
  }

  /// A user list (never the Inbox) when the words clearly belong to it
  String? suggestList(String title) {
    final best = _lists.classify(features(title));
    if (best == null || best.label == null) {
      return null;
    }
    if (best.probability < confidence ||
        _lists.docs(best.label) < minExamples) {
      return null;
    }
    return best.label;
  }

  /// 1–3 when this kind of task is usually given that priority
  int? suggestPriority(String title) {
    final best = _priorities.classify(features(title));
    if (best == null || best.label == 0 || best.probability < confidence) {
      return null;
    }
    return _priorities.docs(best.label) >= 2 ? best.label : null;
  }

  /// Median time of similar past tasks, if they agree (±45 min)
  int? usualTime(String title) => _agreeing(title, _timed, spread: 45, step: 5);

  /// Median duration of similar past tasks
  int? estimateFor(String title) =>
      _agreeing(title, _estimated, spread: 1 << 20, step: 5, min: 1);

  int? _agreeing(
    String title,
    List<(Set<String>, int)> pool, {
    required int spread,
    required int step,
    int min = 2,
  }) {
    final w = words(title).toSet();
    if (w.isEmpty) {
      return null;
    }
    final values = [
      for (final (other, value) in pool)
        if (jaccard(w, other) >= similar) value,
    ]..sort();
    if (values.length < min) {
      return null;
    }
    final median = values[values.length ~/ 2];
    final close = values.where((v) => (v - median).abs() <= spread).length;
    if (close * 3 < values.length * 2) {
      return null;
    }
    return (median / step).round() * step;
  }

  /// The open task most like [title], when it's nearly the same text
  Task? findDuplicate(String title) {
    final grams = trigrams(title);
    if (grams.length < 4) {
      return null;
    }
    Task? best;
    var bestScore = .7;
    for (final (task, other) in _open) {
      final score = jaccard(grams, other);
      if (score >= bestScore) {
        best = task;
        bestScore = score;
      }
    }
    return best;
  }
}

/// Multinomial naive Bayes with light (Lidstone) smoothing, so a word seen
/// once in a list already counts as real evidence
class _NaiveBayes<L> {
  static const _alpha = .1;

  final _docs = <L, int>{};
  final _counts = <L, Map<String, int>>{};
  final _totals = <L, int>{};
  final _vocab = <String>{};
  var _allDocs = 0;

  void add(L label, List<String> features) {
    _allDocs++;
    _docs[label] = (_docs[label] ?? 0) + 1;
    final counts = _counts.putIfAbsent(label, () => {});
    for (final f in features) {
      counts[f] = (counts[f] ?? 0) + 1;
      _vocab.add(f);
    }
    _totals[label] = (_totals[label] ?? 0) + features.length;
  }

  int docs(L label) => _docs[label] ?? 0;

  /// Most likely label with its posterior, or null when no feature of the
  /// input has been seen in any label (the prior alone isn't evidence)
  ({L label, double probability})? classify(List<String> features) {
    final known = features.where(_vocab.contains).toList();
    if (known.isEmpty || _docs.length < 2) {
      return null;
    }
    final v = _vocab.length;
    final scores = <L, double>{};
    for (final label in _docs.keys) {
      final counts = _counts[label]!;
      final total = _totals[label]!;
      var score = math.log(_docs[label]! / _allDocs);
      for (final f in known) {
        score += math.log(((counts[f] ?? 0) + _alpha) / (total + _alpha * v));
      }
      scores[label] = score;
    }
    // Normalise in log space
    final top = scores.values.reduce(math.max);
    final sum = scores.values.fold<double>(0, (s, x) => s + math.exp(x - top));
    L? bestLabel;
    var bestScore = double.negativeInfinity;
    scores.forEach((label, score) {
      if (score > bestScore) {
        bestScore = score;
        bestLabel = label;
      }
    });
    return (label: bestLabel as L, probability: 1 / sum);
  }
}
