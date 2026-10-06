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
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: _transitions,
    splashFactory: InkSparkle.splashFactory,
    hoverColor: const Color(0x0D174B85),
    highlightColor: const Color(0x08174B85),
    brightness: Brightness.light,
    fontFamily: 'Google Sans',
    scaffoldBackgroundColor: pageBackground,
    canvasColor: pageBackground,
    colorScheme: ThemeData.light().colorScheme.copyWith(
      surface: pageBackground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: pageBackground,
      surfaceTintColor: Colors.transparent,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: _transitions,
    splashFactory: InkSparkle.splashFactory,
    brightness: Brightness.dark,
    fontFamily: 'Google Sans',
  );
}
