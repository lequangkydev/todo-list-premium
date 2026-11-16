import 'package:flutter/material.dart';

/// Design tokens — "Productivity Tool" palette (ui-ux-pro-max) in a flat,
/// minimal style: teal for focus, warm orange only for high priority,
/// slate for secondary text. Every text pair is ≥4.5:1 and every meaningful
/// icon/outline ≥3:1 in both themes (checked when the palette was chosen).
class AppSpace {
  AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter
  static const double gutter = 16;
}

class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
}

class AppIcon {
  AppIcon._();

  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
}

/// Motion tokens. Use [AppMotion.of] so reduced-motion turns them off.
class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 200);
  static const curve = Curves.easeOutCubic;

  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}

const String appFontFamily = 'PlusJakartaSans';

/// Semantic colours Material's scheme doesn't cover
@immutable
class TaskColors extends ThemeExtension<TaskColors> {
  const TaskColors({
    required this.priorityLow,
    required this.priorityMedium,
    required this.priorityHigh,
    required this.noPriority,
    required this.card,
  });

  final Color priorityLow;
  final Color priorityMedium;
  final Color priorityHigh;

  /// Ring of a task without priority (≥3:1 on [card])
  final Color noPriority;

  /// Grouped-list surface
  final Color card;

  Color priority(int p) => switch (p) {
    1 => priorityLow,
    2 => priorityMedium,
    3 => priorityHigh,
    _ => noPriority,
  };

  static const light = TaskColors(
    priorityLow: Color(0xFF2563EB),
    priorityMedium: Color(0xFFA16207),
    priorityHigh: Color(0xFFC2410C),
    noPriority: Color(0xFF64748B),
    card: Color(0xFFFFFFFF),
  );

  static const dark = TaskColors(
    priorityLow: Color(0xFF60A5FA),
    priorityMedium: Color(0xFFFBBF24),
    priorityHigh: Color(0xFFFB923C),
    noPriority: Color(0xFF7B918E),
    card: Color(0xFF152321),
  );

  @override
  TaskColors copyWith({
    Color? priorityLow,
    Color? priorityMedium,
    Color? priorityHigh,
    Color? noPriority,
    Color? card,
  }) => TaskColors(
    priorityLow: priorityLow ?? this.priorityLow,
    priorityMedium: priorityMedium ?? this.priorityMedium,
    priorityHigh: priorityHigh ?? this.priorityHigh,
    noPriority: noPriority ?? this.noPriority,
    card: card ?? this.card,
  );

  @override
  TaskColors lerp(TaskColors? other, double t) {
    if (other == null) {
      return this;
    }
    return TaskColors(
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      noPriority: Color.lerp(noPriority, other.noPriority, t)!,
      card: Color.lerp(card, other.card, t)!,
    );
  }
}

extension TaskColorsX on BuildContext {
  TaskColors get taskColors =>
      Theme.of(this).extension<TaskColors>() ?? TaskColors.light;
}

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0F766E),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFCCFBF1),
  onPrimaryContainer: Color(0xFF134E4A),
  secondary: Color(0xFF0D9488),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFD5F0EB),
  onSecondaryContainer: Color(0xFF134E4A),
  tertiary: Color(0xFFC2410C),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFFEDD5),
  onTertiaryContainer: Color(0xFF7C2D12),
  error: Color(0xFFDC2626),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFEE2E2),
  onErrorContainer: Color(0xFF7F1D1D),
  surface: Color(0xFFF4F8F7),
  onSurface: Color(0xFF134E4A),
  onSurfaceVariant: Color(0xFF475569),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF9FBFB),
  surfaceContainer: Color(0xFFEFF5F4),
  surfaceContainerHigh: Color(0xFFE8F0EF),
  surfaceContainerHighest: Color(0xFFE1EBE9),
  outline: Color(0xFF64748B),
  outlineVariant: Color(0xFFD7E5E2),
  inverseSurface: Color(0xFF1E3532),
  onInverseSurface: Color(0xFFE6F2F0),
  inversePrimary: Color(0xFF5EEAD4),
  surfaceTint: Colors.transparent,
  shadow: Color(0xFF0F2E2B),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF5EEAD4),
  onPrimary: Color(0xFF042F2E),
  primaryContainer: Color(0xFF115E59),
  onPrimaryContainer: Color(0xFFCCFBF1),
  secondary: Color(0xFF2DD4BF),
  onSecondary: Color(0xFF042F2E),
  secondaryContainer: Color(0xFF1D3B38),
  onSecondaryContainer: Color(0xFFCCFBF1),
  tertiary: Color(0xFFFB923C),
  onTertiary: Color(0xFF431407),
  tertiaryContainer: Color(0xFF7C2D12),
  onTertiaryContainer: Color(0xFFFFEDD5),
  error: Color(0xFFF87171),
  onError: Color(0xFF450A0A),
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFFEE2E2),
  surface: Color(0xFF0B1413),
  onSurface: Color(0xFFE6F2F0),
  onSurfaceVariant: Color(0xFFA3B8B5),
  surfaceContainerLowest: Color(0xFF080F0E),
  surfaceContainerLow: Color(0xFF111C1B),
  surfaceContainer: Color(0xFF152321),
  surfaceContainerHigh: Color(0xFF1B2C2A),
  surfaceContainerHighest: Color(0xFF223634),
  outline: Color(0xFF7B918E),
  outlineVariant: Color(0xFF36504D),
  inverseSurface: Color(0xFFE6F2F0),
  onInverseSurface: Color(0xFF134E4A),
  inversePrimary: Color(0xFF0F766E),
  surfaceTint: Colors.transparent,
  shadow: Color(0xFF000000),
);

TextTheme _textTheme(ColorScheme scheme) {
  // 16 base, 1.4–1.5 line height for body; tighter for headings
  final base = Typography.material2021().black.apply(
    fontFamily: appFontFamily,
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  return base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
    bodySmall: base.bodySmall?.copyWith(
      fontSize: 13,
      height: 1.35,
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = isDark ? _darkScheme : _lightScheme;
  final colors = isDark ? TaskColors.dark : TaskColors.light;
  final text = _textTheme(scheme);
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    textTheme: text,
    extensions: [colors],
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: AppSpace.gutter + 4,
      titleTextStyle: text.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.card,
      indicatorColor: scheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
      height: 68,
      elevation: 0,
      labelTextStyle: WidgetStateTextStyle.resolveWith(
        (states) => text.labelMedium!.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: AppIcon.lg,
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: AppSpace.md,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: 14,
      ),
      hintStyle: text.bodyLarge?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.card,
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
      labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 44),
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: text.labelLarge,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      // Scrim strong enough to isolate the sheet in both themes
      modalBarrierColor: Colors.black.withValues(alpha: isDark ? .6 : .4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg + 8),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      highlightElevation: 0,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
