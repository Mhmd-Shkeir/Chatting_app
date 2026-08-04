import 'package:flutter/material.dart';

// Placeholder seed color until docs/05-design-system.md finalizes the palette.
const _seedColor = Colors.indigo;

// Matches the Inputs border radius already specified in docs/05-design-system.md.
const _inputDecorationTheme = InputDecorationTheme(
  filled: true,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  ),
);

class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: _seedColor,
        inputDecorationTheme: _inputDecorationTheme,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: _seedColor,
        inputDecorationTheme: _inputDecorationTheme,
      );
}
