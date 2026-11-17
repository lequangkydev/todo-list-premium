import 'package:material_ui/material_ui.dart';

import '../../../config/theme/app_theme.dart';

/// Groups task rows in one rounded card with inset dividers.
///
/// Rows are matched by key between builds: new rows grow in, removed rows
/// fade and collapse in place, so completing or moving a task never makes
/// the list jump. Every child must have a unique key. Reduced motion makes
/// both changes instant.
class TaskGroup extends StatefulWidget {
  const TaskGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  State<TaskGroup> createState() => _TaskGroupState();
}

class _Entry {
  _Entry(this.key, this.widget, this.controller);

  final Key key;
  Widget widget;
  final AnimationController controller;
  bool exiting = false;

  late final size = CurvedAnimation(
    parent: controller,
    curve: AppMotion.enter,
    reverseCurve: AppMotion.exit.flipped,
  );

  /// Finishes after the row has mostly opened, starts once it begins closing
  late final fade = CurvedAnimation(
    parent: controller,
    curve: const Interval(.3, 1, curve: Curves.easeOut),
  );

  void dispose() {
    size.dispose();
    fade.dispose();
    controller.dispose();
  }
}

class _TaskGroupState extends State<TaskGroup> with TickerProviderStateMixin {
  final List<_Entry> _entries = [];

  static const _enter = Duration(milliseconds: 280);

  /// Exits are quicker than entries so the list feels responsive
  static const _exit = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    // Rows already there when the screen opens don't animate
    for (final child in widget.children) {
      _entries.add(_Entry(_keyOf(child), child, _controller(1)));
    }
  }

  @override
  void didUpdateWidget(covariant TaskGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final animate = AppMotion.enabled(context);
    final byKey = {for (final e in _entries) e.key: e};
    final incoming = <Key>{};
    final next = <_Entry>[];

    for (final child in widget.children) {
      final key = _keyOf(child);
      incoming.add(key);
      final existing = byKey[key];
      if (existing != null) {
        existing.widget = child;
        if (existing.exiting) {
          // Came back while leaving (e.g. Undo): grow back from where it is
          existing.exiting = false;
          existing.controller.forward();
        }
        next.add(existing);
      } else {
        final entry = _Entry(key, child, _controller(animate ? 0 : 1));
        if (animate) {
          entry.controller.forward();
        }
        next.add(entry);
      }
    }

    // Keep leaving rows where they were, after their old predecessor
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (incoming.contains(entry.key)) {
        continue;
      }
      if (!animate) {
        entry.dispose();
        continue;
      }
      if (!entry.exiting) {
        entry.exiting = true;
        entry.controller.reverse().whenComplete(() => _remove(entry));
      }
      final before = i == 0 ? null : _entries[i - 1];
      final at = before == null ? -1 : next.indexOf(before);
      next.insert(at + 1, entry);
    }

    _entries
      ..clear()
      ..addAll(next);
  }

  AnimationController _controller(double value) => AnimationController(
    vsync: this,
    value: value,
    duration: _enter,
    reverseDuration: _exit,
  );

  Key _keyOf(Widget child) {
    assert(child.key != null, 'TaskGroup children need unique keys');
    return child.key ?? ObjectKey(child);
  }

  void _remove(_Entry entry) {
    if (!mounted || !entry.exiting) {
      return;
    }
    setState(() => _entries.remove(entry));
    entry.dispose();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Card(
        // Swipe action backgrounds stay inside the rounded corners
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < _entries.length; i++)
              _AnimatedRow(
                key: _entries[i].key,
                size: _entries[i].size,
                fade: _entries[i].fade,
                exiting: _entries[i].exiting,
                divider: i > 0,
                child: _entries[i].widget,
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedRow extends StatelessWidget {
  const _AnimatedRow({
    super.key,
    required this.size,
    required this.fade,
    required this.exiting,
    required this.divider,
    required this.child,
  });

  final Animation<double> size;
  final Animation<double> fade;
  final bool exiting;
  final bool divider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: size,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: fade,
        child: IgnorePointer(
          ignoring: exiting,
          child: ExcludeSemantics(
            excluding: exiting,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (divider) const Divider(indent: 60, height: 1),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
