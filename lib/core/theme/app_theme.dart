import 'package:flutter/material.dart';

import '../widgets/app_motion.dart';

class AppTheme {
  // Existing IDireksyon colors from Home, onboarding and journey progress.
  static const navy = Color(0xFF103765);
  static const primaryBlue = Color(0xFF174B85);
  static const royalBlue = Color(0xFF0B4295);
  static const accentGold = Color(0xFFFFD576);
  // Existing Directory quick-action gold, stronger against a white surface.
  static const progressGold = Color(0xFFAA7309);
  static const pageBackground = Color(0xFFF3F8FF);
  static const completedGreen = Color(0xFF2E7D32);

  static final _transitions = PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const AppPageTransitions(),
    },
  );

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFA8CCFA) : primaryBlue,
          onPrimary: dark ? navy : Colors.white,
          primaryContainer: dark ? navy : const Color(0xFFD5E7FA),
          onPrimaryContainer: dark ? const Color(0xFFA8CCFA) : navy,
          surfaceTint: dark ? const Color(0xFFA8CCFA) : primaryBlue,
          secondary: dark ? const Color(0xFFA8CCFA) : royalBlue,
          onSecondary: dark ? navy : Colors.white,
          secondaryContainer: dark ? navy : pageBackground,
          onSecondaryContainer: dark ? const Color(0xFFA8CCFA) : navy,
          tertiary: accentGold,
          onTertiary: navy,
          tertiaryContainer: dark ? navy : accentGold,
          onTertiaryContainer: dark ? accentGold : navy,
          surface: dark ? const Color(0xFF111B28) : Colors.white,
          surfaceContainerLowest: dark ? const Color(0xFF111B28) : Colors.white,
          surfaceContainerLow: dark ? const Color(0xFF172536) : pageBackground,
          surfaceContainer: dark ? const Color(0xFF1C2B3D) : pageBackground,
          surfaceContainerHigh: dark
              ? const Color(0xFF24344A)
              : const Color(0xFFD5E7FA),
          surfaceContainerHighest: dark
              ? const Color(0xFF2C4058)
              : const Color(0xFFD5E7FA),
        );
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _transitions,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: const Color(0x0D174B85),
      highlightColor: const Color(0x08174B85),
      brightness: brightness,
      fontFamily: 'Google Sans',
      scaffoldBackgroundColor: dark ? scheme.surface : pageBackground,
      canvasColor: dark ? scheme.surface : Colors.white,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? scheme.surface : Colors.white,
        foregroundColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static final ThemeData lightTheme = _theme(Brightness.light);
  static final ThemeData darkTheme = _theme(Brightness.dark);
}
