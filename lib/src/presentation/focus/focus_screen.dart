import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/di/di.dart';
import '../../config/theme/app_theme.dart';
import '../../core/focus/focus_service.dart';
import '../../core/focus/focus_timer.dart';
import '../../data/repositories/task_repository.dart';
import '../../shared/extension/context_extension.dart';
import '../../shared/helpers/app_haptics.dart';
import '../../shared/helpers/task_format.dart';

/// The focus timer: one block of focused time, optionally for a task, then
/// a break. Leaving the screen doesn't stop it.
@RoutePage()
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, this.taskId});

  /// Offer to focus on this task (when nothing is running)
  final String? taskId;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final _service = getIt<FocusService>();
  Timer? _second;
  String? _offeredTitle;

  @override
  void initState() {
    super.initState();
    _service.state.addListener(_onState);
    _onState();
    final id = widget.taskId;
    if (id != null) {
      getIt<TaskRepository>().getTask(id).then((task) {
        if (mounted) {
          setState(() => _offeredTitle = task?.title);
        }
      });
    }
  }

  @override
  void dispose() {
    _service.state.removeListener(_onState);
    _second?.cancel();
    super.dispose();
  }

  /// Repaint every second only while something counts down
  void _onState() {
    _second?.cancel();
    _second = _service.state.value.running
        ? Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}))
        : null;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _finishTask() async {
    final id = _service.state.value.taskId;
    await _service.stop();
    if (id == null) {
      return;
    }
    final repo = getIt<TaskRepository>();
    final task = await repo.getTask(id);
    if (task != null && !task.isDone) {
      await repo.complete(task);
    }
    AppHaptics.medium();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _pickLengths() async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      sheetAnimationStyle: AppMotion.sheet(context),
      builder: (context) => SafeArea(
        child: ValueListenableBuilder(
          valueListenable: _service.settings,
          builder: (context, settings, _) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.focusLength,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpace.sm),
                _Choices(
                  values: FocusService.focusChoices,
                  selected: settings.focus,
                  onSelected: (m) => _service.setSettings(focus: m),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  l10n.focusBreakLength,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpace.sm),
                _Choices(
                  values: FocusService.restChoices,
                  selected: settings.rest,
                  onSelected: (m) => _service.setSettings(rest: m),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final state = _service.state.value;
    final now = DateTime.now();
    final idle = state.phase == FocusPhase.idle;
    final settings = _service.settings.value;
    final remaining = idle
        ? Duration(minutes: settings.focus)
        : state.remainingAt(now);
    final resting = state.phase == FocusPhase.rest;
    final title = idle ? _offeredTitle : _service.taskTitle.value;
    final status = switch (state.phase) {
      FocusPhase.idle => null,
      FocusPhase.focus => l10n.focusFocusing,
      FocusPhase.paused => l10n.focusPaused,
      FocusPhase.focusDone => l10n.focusOverTitle,
      FocusPhase.rest => l10n.focusResting,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.focus),
        actions: [
          IconButton(
            tooltip: l10n.focusLength,
            icon: const Icon(Icons.tune_rounded),
            onPressed: _pickLengths,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: SizedBox.square(
                  dimension: 240,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: idle ? 0 : state.progressAt(now),
                      track: scheme.surfaceContainerHighest,
                      color: resting ? scheme.tertiary : scheme.primary,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _clock(remaining),
                            style: textTheme.displayMedium?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            semanticsLabel: TaskFormat.duration(
                              l10n,
                              (remaining.inSeconds / 60).ceil(),
                            ),
                          ),
                          if (status != null)
                            Text(
                              status,
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                title ?? l10n.focusNoTask,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: title == null
                    ? textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )
                    : textTheme.titleMedium,
              ),
              const Spacer(),
              ..._controls(context, state, settings),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _controls(
    BuildContext context,
    FocusState state,
    FocusSettings settings,
  ) {
    final l10n = context.l10n;
    const gap = SizedBox(height: AppSpace.sm);
    final big = FilledButton.styleFrom(minimumSize: const Size.fromHeight(52));
    return switch (state.phase) {
      FocusPhase.idle => [
        FilledButton.icon(
          style: big,
          onPressed: () {
            AppHaptics.light();
            _service.startFocus(taskId: widget.taskId);
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            '${l10n.focusStart} · ${l10n.durationMinutes(settings.focus)}',
          ),
        ),
      ],
      FocusPhase.focus => [
        FilledButton.tonalIcon(
          style: big,
          onPressed: _service.pause,
          icon: const Icon(Icons.pause_rounded),
          label: Text(l10n.focusPause),
        ),
        gap,
        TextButton(onPressed: _service.stop, child: Text(l10n.focusStop)),
      ],
      FocusPhase.paused => [
        FilledButton.icon(
          style: big,
          onPressed: _service.resume,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l10n.focusResume),
        ),
        gap,
        TextButton(onPressed: _service.stop, child: Text(l10n.focusStop)),
      ],
      FocusPhase.focusDone => [
        FilledButton.icon(
          style: big,
          onPressed: _service.startBreak,
          icon: const Icon(Icons.free_breakfast_outlined),
          label: Text(l10n.focusTakeBreak(settings.rest)),
        ),
        gap,
        FilledButton.tonal(
          onPressed: _service.focusAgain,
          child: Text(l10n.focusAgain),
        ),
        if (state.taskId != null) ...[
          gap,
          OutlinedButton.icon(
            onPressed: _finishTask,
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.focusFinishTask),
          ),
        ],
        gap,
        TextButton(onPressed: _service.stop, child: Text(l10n.focusStop)),
      ],
      FocusPhase.rest => [
        FilledButton.tonal(
          style: big,
          onPressed: _service.stop,
          child: Text(l10n.focusSkipBreak),
        ),
      ],
    };
  }

  static String _clock(Duration d) {
    final seconds = (d.inMilliseconds / 1000).ceil();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<int> values;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final minutes in values)
          ChoiceChip(
            label: Text(context.l10n.durationMinutes(minutes)),
            selected: minutes == selected,
            onSelected: (_) {
              AppHaptics.selection();
              onSelected(minutes);
            },
          ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(
        arc,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}
