import 'package:flutter/material.dart';

import '../widgets/app_motion.dart';

class AppTheme {
  static final _transitions = PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const AppPageTransitions(),
    },
  );
  static const pageBackground = Color(0xFFF7F6F2);
  static const primaryBlue = Color(0xFF174B85);
  static const darkBackground = Color(0xFF111820);

  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? darkBackground : pageBackground;
    final colors =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFF9BC9FF) : primaryBlue,
          onPrimary: dark ? const Color(0xFF082D53) : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF203D5B)
              : const Color(0xFFE2EEFB),
          onPrimaryContainer: dark
              ? const Color(0xFFD8EAFF)
              : const Color(0xFF123B68),
          secondary: dark ? const Color(0xFFB5C8DE) : const Color(0xFF45617E),
          onSecondary: dark ? const Color(0xFF1B3148) : Colors.white,
          secondaryContainer: dark
              ? const Color(0xFF2B3E51)
              : const Color(0xFFE6EDF5),
          onSecondaryContainer: dark
              ? const Color(0xFFD8E5F4)
              : const Color(0xFF253E58),
          tertiary: dark ? const Color(0xFF9BC9FF) : primaryBlue,
          onTertiary: dark ? const Color(0xFF082D53) : Colors.white,
          tertiaryContainer: dark
              ? const Color(0xFF203D5B)
              : const Color(0xFFE2EEFB),
          onTertiaryContainer: dark
              ? const Color(0xFFD8EAFF)
              : const Color(0xFF123B68),
          surface: background,
          onSurface: dark ? const Color(0xFFE7EDF5) : const Color(0xFF1E293B),
          onSurfaceVariant: dark
              ? const Color(0xFFB5C1D0)
              : const Color(0xFF526174),
          surfaceDim: dark ? darkBackground : const Color(0xFFE5E8EB),
          surfaceBright: dark ? const Color(0xFF303D4C) : Colors.white,
          surfaceContainerLowest: dark ? const Color(0xFF0C1219) : Colors.white,
          surfaceContainerLow: dark ? const Color(0xFF18222E) : Colors.white,
          surfaceContainer: dark
              ? const Color(0xFF1E2A38)
              : const Color(0xFFF0F3F6),
          surfaceContainerHigh: dark
              ? const Color(0xFF263443)
              : const Color(0xFFE9EEF3),
          surfaceContainerHighest: dark
              ? const Color(0xFF2E3D4E)
              : const Color(0xFFE1E8F0),
          outline: dark ? const Color(0xFF7D8EA2) : const Color(0xFF718196),
          outlineVariant: dark
              ? const Color(0xFF3D4D60)
              : const Color(0xFFD6DFE9),
          surfaceTint: dark ? const Color(0xFF9BC9FF) : primaryBlue,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _transitions,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: colors.primary.withValues(alpha: .05),
      highlightColor: colors.primary.withValues(alpha: .03),
      brightness: brightness,
      fontFamily: 'Google Sans',
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: colors,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
          textStyle: const TextStyle(
            fontFamily: 'Google Sans',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: colors.outlineVariant),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorMaxLines: 3,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: .22),
        selectionHandleColor: colors.primary,
      ),
    );
  }
}
