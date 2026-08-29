import 'package:flutter/material.dart';

/// Centralized color palette.
///
/// Board-square colors live here too (rather than in a Phase-5-only file)
/// because `AppTheme` needs `scaffoldBackground` and the seed color right
/// now for `main.dart`, and it's one less place to look later when the
/// board UI (Phase 5) picks a default theme.
class AppColors {
  const AppColors._();

  static const Color scaffoldBackground = Color(0xFF121212);

  /// Seed color used to derive the whole Material 3 color scheme.
  static const Color seed = Color(0xFF7C4DFF);

  static const Color accent = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFE53935);

  // Default board theme ("classic green"). Additional themes (wood,
  // marble, dark) are added in Phase 5 as a selectable list, not just a
  // single pair of constants.
  static const Color boardLightSquare = Color(0xFFEEEED2);
  static const Color boardDarkSquare = Color(0xFF769656);
  static const Color boardHighlight = Color(0x807C4DFF);
  static const Color boardLastMove = Color(0x80F6F669);
  static const Color boardCheck = Color(0x80E53935);
}
