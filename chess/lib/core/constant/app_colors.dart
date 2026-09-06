import 'package:flutter/material.dart';

/// Centralized color palette for app chrome (app bar, buttons, scaffold
/// background, seed color, gradients).
///
/// Redesigned palette: a deep, near-black indigo base (instead of flat
/// `0xFF121212` grey) paired with a warm gold accent — reads as a
/// premium "gameroom" feel rather than a generic Material dark theme.
/// Board-square colors live separately in
/// `features/board_ui/domain/board_theme.dart`.
class AppColors {
  const AppColors._();

  /// Deep indigo-black. Slightly tinted (not pure grey) so gradients and
  /// glows read intentionally rather than muddy.
  static const Color scaffoldBackground = Color(0xFF0B0E1A);
  static const Color surface = Color(0xFF141A2E);
  static const Color surfaceElevated = Color(0xFF1B2340);

  /// Seed color used to derive the whole Material 3 color scheme.
  /// A richer violet-blue than the old flat purple, tuned to sit well
  /// against the gold accent.
  static const Color seed = Color(0xFF6C63FF);

  /// Warm gold — the app's signature accent. Used sparingly (primary CTA,
  /// splash mark, highlights) so it stays special rather than everywhere.
  static const Color gold = Color(0xFFE8B84B);
  static const Color goldDim = Color(0xFFB8923A);

  static const Color accent = Color(0xFF29D398);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFEF5350);

  /// Background gradient used behind hero/splash content.
  static const List<Color> heroGradient = <Color>[
    Color(0xFF161B33),
    Color(0xFF0B0E1A),
  ];

  static const List<Color> goldGradient = <Color>[
    Color(0xFFF3CD70),
    Color(0xFFE8B84B),
    Color(0xFFC6902E),
  ];

  // Default board theme ("classic green") mirror — kept for any code
  // that hasn't migrated to `BoardTheme` yet.
  static const Color boardLightSquare = Color(0xFFEEEED2);
  static const Color boardDarkSquare = Color(0xFF769656);
  static const Color boardHighlight = Color(0x806C63FF);
  static const Color boardLastMove = Color(0x80F6F669);
  static const Color boardCheck = Color(0x80EF5350);
}
