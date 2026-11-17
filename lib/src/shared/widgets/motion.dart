import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import '../../config/theme/app_theme.dart';

/// Plays once when first built: fades in while rising [offset] pixels (and
/// optionally growing from [scale]). Use [delay] to stagger siblings by
/// 30–50 ms. Reduced motion shows the child immediately.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 6,
    this.scale = 1,
    this.duration = AppMotion.medium,
    this.curve = AppMotion.enter,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  /// Starting scale; 1 means no scaling
  final double scale;
  final Duration duration;
  final Curve curve;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final _curved = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (!AppMotion.enabled(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) {
        final t = _curved.value;
        return Opacity(
          opacity: _controller.value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: widget.scale == 1
                ? child
                : Transform.scale(
                    scale: widget.scale + (1 - widget.scale) * t,
                    child: child,
                  ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Sinks slightly while pressed and springs back on release — tactile
/// feedback for primary buttons. Doesn't intercept the child's taps.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.pressedScale = .97});

  final Widget child;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController.unbounded(vsync: this, value: 1);

  void _to(double target) {
    if (!AppMotion.enabled(context)) {
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        AppMotion.springBouncy,
        _controller.value,
        target,
        _controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _to(widget.pressedScale),
      onPointerUp: (_) => _to(1),
      onPointerCancel: (_) => _to(1),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}
