import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';

void main() {
  runApp(const IDireksyonApp());
}

class IDireksyonApp extends StatelessWidget {
  const IDireksyonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IDireksyon',
      debugShowCheckedModeBanner: false,

      // App themes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // App routing
      initialRoute: '/',
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}