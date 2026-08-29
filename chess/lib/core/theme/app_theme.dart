import 'package:flutter/material.dart';

/// App-wide [ThemeData]. Board color themes (wood/marble/classic) are a
/// separate concern added in Phase 5 — this only covers app chrome
/// (app bar, buttons, scaffold background) so Phase 1 has a runnable app.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
      );
}
