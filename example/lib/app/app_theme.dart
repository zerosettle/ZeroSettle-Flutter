import 'package:flutter/material.dart';

/// Shared Material 3 theme. Kept lean — JustOne's identity is mostly in
/// the green check-off button and emoji habit icons, not a custom palette.
class AppTheme {
  AppTheme._();

  static const Color brandGreen = Color(0xFF6CA358);

  static ThemeData light() => ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      );

  static ThemeData dark() => ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      );
}
