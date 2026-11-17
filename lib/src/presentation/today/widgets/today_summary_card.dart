import 'package:material_ui/material_ui.dart';

import '../../../config/theme/app_theme.dart';
import '../../../core/date/dates.dart';
import '../../../shared/extension/context_extension.dart';
import '../../../shared/helpers/app_haptics.dart';

/// Today at a glance: a progress ring (done / planned) and one calm line.
/// No streaks, no scores — just where the day stands.
class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({super.key, required this.open, required this.done});

  final int open;
  final int done;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final total = open + done;
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = open == 0 && done > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      container: true,
      label: '${l10n.summaryRemaining(open)}. ${l10n.doneToday(done)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg + 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg + 4),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [scheme.primaryContainer, scheme.surfaceContainerHigh]
                : [const Color(0xFFD7F5EE), const Color(0xFFEAF6FF)],
          ),
          boxShadow: AppShadow.soft(context),
        ),
        child: Row(
          children: [
            _ProgressRing(progress: progress, done: done, total: total),
            const SizedBox(width: AppSpace.lg + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.of(context, AppMotion.medium),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [...previous, ?current],
                    ),
                    child: Text(
                      allDone ? l10n.allDoneTitle : l10n.summaryRemaining(open),
                      key: ValueKey(allDone ? -1 : open),
                      style: text.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    done > 0 ? l10n.doneToday(done) : l10n.summaryStart,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: .8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ring of done / planned. The count rolls to its new value; reaching 100%
/// pops a check and sends one soft ripple outward (once a day).
class _ProgressRing extends StatefulWidget {
  const _ProgressRing({
    required this.progress,
    required this.done,
    required this.total,
  });

  final double progress;
  final int done;
  final int total;

  @override
  State<_ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<_ProgressRing>
    with SingleTickerProviderStateMixin {
  /// Day the "all done" moment last played, so Undo + redo doesn't repeat it
  static DateTime? _celebratedOn;

  late final _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(covariant _ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reached = widget.progress >= 1 && oldWidget.progress < 1;
    final today = Dates.today();
    if (reached && _celebratedOn != today) {
      _celebratedOn = today;
      AppHaptics.medium();
      if (AppMotion.enabled(context)) {
        _ripple.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final duration = AppMotion.of(context, const Duration(milliseconds: 600));
    final complete = widget.progress >= 1;
    return SizedBox.square(
      dimension: 64,
      child: CustomPaint(
        painter: _RipplePainter(animation: _ripple, color: scheme.primary),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.progress),
          duration: duration,
          curve: AppMotion.curve,
          builder: (context, value, child) => Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: scheme.primary,
                  backgroundColor: scheme.primary.withValues(alpha: .15),
                ),
              ),
              child!,
            ],
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.slow),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: complete
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('done'),
                    color: scheme.primary,
                    size: 30,
                  )
                : _RollingCount(
                    key: const ValueKey('count'),
                    done: widget.done,
                    total: widget.total,
                  ),
          ),
        ),
      ),
    );
  }
}

/// "3/5" where the done number slides up to its new value
class _RollingCount extends StatelessWidget {
  const _RollingCount({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: context.colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.medium),
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.exit,
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(done);
            return ClipRect(
              child: SlideTransition(
                position: Tween(
                  begin: Offset(0, incoming ? .6 : -.6),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
            );
          },
          child: Text('$done', key: ValueKey(done), style: style),
        ),
        Text('/$total', style: style),
      ],
    );
  }
}

/// One ring that grows past the progress ring and fades out
class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.animation, required this.color})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) {
      return;
    }
    final eased = Curves.easeOutCubic.transform(t);
    final radius = size.width / 2 + 18 * eased;
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - eased) + .5
        ..color = color.withValues(alpha: .45 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.color != color;
}
