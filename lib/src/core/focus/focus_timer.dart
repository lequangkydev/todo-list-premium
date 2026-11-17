import 'package:flutter/foundation.dart';

enum FocusPhase {
  idle,

  /// Counting down a focus block
  focus,

  /// A focus block on hold
  paused,

  /// A focus block just ran out: break, another block, or done
  focusDone,

  /// Counting down a break
  rest,
}

/// Where the focus timer is. Running phases keep an absolute end time, so
/// the countdown is right after the app was in the background or killed.
@immutable
class FocusState {
  const FocusState({
    this.phase = FocusPhase.idle,
    this.taskId,
    this.plannedMinutes = 0,
    this.startedAt,
    this.endsAt,
    this.remaining,
  });

  static const idle = FocusState();

  final FocusPhase phase;

  /// The task this focus is for, if any
  final String? taskId;

  /// Length of the current focus block (or break)
  final int plannedMinutes;

  /// When the current focus block began
  final DateTime? startedAt;

  /// When the running block ends ([FocusPhase.focus], [FocusPhase.rest])
  final DateTime? endsAt;

  /// What's left of a paused block
  final Duration? remaining;

  bool get running => phase == FocusPhase.focus || phase == FocusPhase.rest;

  /// Something to show (a pill on Home, the notification)
  bool get active => phase != FocusPhase.idle;

  Duration remainingAt(DateTime now) => switch (phase) {
    FocusPhase.focus || FocusPhase.rest => _positive(endsAt!.difference(now)),
    FocusPhase.paused => remaining!,
    _ => Duration.zero,
  };

  /// 0 → 1 through the current block
  double progressAt(DateTime now) {
    final total = plannedMinutes * 60;
    if (total == 0) {
      return phase == FocusPhase.focusDone ? 1 : 0;
    }
    final left = remainingAt(now).inMilliseconds / 1000;
    return (1 - left / total).clamp(0, 1).toDouble();
  }

  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'task': taskId,
    'planned': plannedMinutes,
    'startedAt': startedAt?.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
    'remaining': remaining?.inMilliseconds,
  };

  static FocusState fromJson(Map<String, Object?> json) {
    final phase = FocusPhase.values.asNameMap()[json['phase']];
    if (phase == null) {
      return idle;
    }
    DateTime? at(Object? v) => v is String ? DateTime.tryParse(v) : null;
    final remaining = json['remaining'];
    final state = FocusState(
      phase: phase,
      taskId: json['task'] as String?,
      plannedMinutes: json['planned'] as int? ?? 0,
      startedAt: at(json['startedAt']),
      endsAt: at(json['endsAt']),
      remaining: remaining is int ? Duration(milliseconds: remaining) : null,
    );
    // Anything inconsistent (an older format, a damaged value) starts over
    final ok = switch (phase) {
      FocusPhase.focus => state.endsAt != null && state.startedAt != null,
      FocusPhase.rest => state.endsAt != null,
      FocusPhase.paused => state.remaining != null && state.startedAt != null,
      FocusPhase.focusDone || FocusPhase.idle => true,
    };
    return ok ? state : idle;
  }

  @override
  bool operator ==(Object other) =>
      other is FocusState &&
      other.phase == phase &&
      other.taskId == taskId &&
      other.plannedMinutes == plannedMinutes &&
      other.startedAt == startedAt &&
      other.endsAt == endsAt &&
      other.remaining == remaining;

  @override
  int get hashCode =>
      Object.hash(phase, taskId, plannedMinutes, startedAt, endsAt, remaining);

  static Duration _positive(Duration d) => d.isNegative ? Duration.zero : d;
}

/// A focus block to remember
@immutable
class FocusRecord {
  const FocusRecord({
    required this.taskId,
    required this.startedAt,
    required this.endedAt,
    required this.focusMinutes,
    required this.plannedMinutes,
    required this.completed,
  });

  final String? taskId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int focusMinutes;
  final int plannedMinutes;
  final bool completed;
}

/// The result of acting on the timer: its next state, and a block to save
typedef FocusStep = ({FocusState state, FocusRecord? record});

/// The focus timer's rules, with the clock passed in.
class FocusTimer {
  FocusTimer._();

  /// Stopped blocks shorter than this aren't worth a record
  static const minRecordMinutes = 1;

  static FocusState start(
    DateTime now, {
    required int minutes,
    String? taskId,
  }) => FocusState(
    phase: FocusPhase.focus,
    taskId: taskId,
    plannedMinutes: minutes,
    startedAt: now,
    endsAt: now.add(Duration(minutes: minutes)),
  );

  static FocusState pause(FocusState state, DateTime now) {
    if (state.phase != FocusPhase.focus) {
      return state;
    }
    return FocusState(
      phase: FocusPhase.paused,
      taskId: state.taskId,
      plannedMinutes: state.plannedMinutes,
      startedAt: state.startedAt,
      remaining: state.remainingAt(now),
    );
  }

  static FocusState resume(FocusState state, DateTime now) {
    if (state.phase != FocusPhase.paused) {
      return state;
    }
    return FocusState(
      phase: FocusPhase.focus,
      taskId: state.taskId,
      plannedMinutes: state.plannedMinutes,
      startedAt: state.startedAt,
      endsAt: now.add(state.remaining!),
    );
  }

  static FocusState startBreak(DateTime now, {required int minutes}) =>
      FocusState(
        phase: FocusPhase.rest,
        plannedMinutes: minutes,
        endsAt: now.add(Duration(minutes: minutes)),
      );

  /// Moves on when the running block has run out: a finished focus block is
  /// recorded and waits for the user; a finished break ends.
  static FocusStep tick(FocusState state, DateTime now) {
    final ends = state.endsAt;
    if (ends == null || now.isBefore(ends)) {
      return (state: state, record: null);
    }
    if (state.phase == FocusPhase.rest) {
      return (state: FocusState.idle, record: null);
    }
    if (state.phase != FocusPhase.focus) {
      return (state: state, record: null);
    }
    return (
      state: FocusState(
        phase: FocusPhase.focusDone,
        taskId: state.taskId,
        plannedMinutes: state.plannedMinutes,
      ),
      record: FocusRecord(
        taskId: state.taskId,
        startedAt: state.startedAt!,
        endedAt: ends,
        focusMinutes: state.plannedMinutes,
        plannedMinutes: state.plannedMinutes,
        completed: true,
      ),
    );
  }

  /// Stops whatever is going on. Focus time already spent is recorded
  /// (unless it's under a minute).
  static FocusStep stop(FocusState state, DateTime now) {
    final checked = tick(state, now);
    if (checked.record != null) {
      // It had already run out: that counts as finished
      return (state: FocusState.idle, record: checked.record);
    }
    final inFocus =
        state.phase == FocusPhase.focus || state.phase == FocusPhase.paused;
    if (!inFocus) {
      return (state: FocusState.idle, record: null);
    }
    final spent =
        Duration(minutes: state.plannedMinutes) - state.remainingAt(now);
    final minutes = spent.inMinutes;
    return (
      state: FocusState.idle,
      record: minutes < minRecordMinutes
          ? null
          : FocusRecord(
              taskId: state.taskId,
              startedAt: state.startedAt!,
              endedAt: now,
              focusMinutes: minutes,
              plannedMinutes: state.plannedMinutes,
              completed: false,
            ),
    );
  }
}
