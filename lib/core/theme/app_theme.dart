import 'package:flutter/material.dart';

// Placeholder seed color until docs/05-design-system.md finalizes the palette.
const _seedColor = Colors.indigo;

class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: _seedColor,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: _seedColor,
      );
}
