import 'package:flutter/material.dart';

import 'routes/app_router.dart';

class IDireksyonApp extends StatelessWidget {
  const IDireksyonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IDireksyon',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: AppRouter.homeRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
