import 'package:material_ui/material_ui.dart';

/// App mark drawn in code (teal tile + check) — scales crisply and follows
/// the theme. Replace with the final brand logo when it exists.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(size * .28),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: .25),
              blurRadius: size * .25,
              offset: Offset(0, size * .1),
            ),
          ],
        ),
        child: Icon(
          Icons.check_rounded,
          size: size * .62,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}
