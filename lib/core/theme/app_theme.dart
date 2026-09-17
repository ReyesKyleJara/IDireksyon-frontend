import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Google Sans',
    scaffoldBackgroundColor: Color(0xFFF7F6F2),
    canvasColor: Color(0xFFF7F6F2),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Google Sans',
  );
}