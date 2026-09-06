import 'package:flutter/material.dart';

/// A selectable visual theme for the board itself — square colors and
/// highlight tints. Separate from [AppTheme] (app chrome) on purpose:
/// the roadmap calls for "multiple visual themes (wood, marble, classic
/// green, dark mode)" as a swappable list, not a single hardcoded pair
/// of colors.
@immutable
class BoardTheme {
  const BoardTheme({
    required this.name,
    required this.lightSquare,
    required this.darkSquare,
    required this.selectedHighlight,
    required this.lastMoveHighlight,
    required this.checkHighlight,
    required this.legalMoveDot,
    required this.coordinateColor,
  });

  final String name;
  final Color lightSquare;
  final Color darkSquare;
  final Color selectedHighlight;
  final Color lastMoveHighlight;
  final Color checkHighlight;
  final Color legalMoveDot;
  final Color coordinateColor;

  static const BoardTheme classicGreen = BoardTheme(
    name: 'Classic Green',
    lightSquare: Color(0xFFEEEED2),
    darkSquare: Color(0xFF769656),
    selectedHighlight: Color(0x807C4DFF),
    lastMoveHighlight: Color(0x80F6F669),
    checkHighlight: Color(0x80E53935),
    legalMoveDot: Color(0x8A2E2E2E),
    coordinateColor: Color(0x99000000),
  );

  static const BoardTheme wood = BoardTheme(
    name: 'Wood',
    lightSquare: Color(0xFFE8C89A),
    darkSquare: Color(0xFF8B5A2B),
    selectedHighlight: Color(0x80FFC107),
    lastMoveHighlight: Color(0x80FFE082),
    checkHighlight: Color(0x80E53935),
    legalMoveDot: Color(0x8A3E2A15),
    coordinateColor: Color(0x993E2A15),
  );

  static const BoardTheme marble = BoardTheme(
    name: 'Marble',
    lightSquare: Color(0xFFF3F1EE),
    darkSquare: Color(0xFF9A9490),
    selectedHighlight: Color(0x8000C853),
    lastMoveHighlight: Color(0x80B39DDB),
    checkHighlight: Color(0x80E53935),
    legalMoveDot: Color(0x8A2E2E2E),
    coordinateColor: Color(0x992E2E2E),
  );

  static const BoardTheme midnight = BoardTheme(
    name: 'Midnight',
    lightSquare: Color(0xFF4A5568),
    darkSquare: Color(0xFF1A202C),
    selectedHighlight: Color(0x807C4DFF),
    lastMoveHighlight: Color(0x8000C853),
    checkHighlight: Color(0x80E53935),
    legalMoveDot: Color(0x8AE2E8F0),
    coordinateColor: Color(0x99CBD5E0),
  );

  /// Phase 11 accessibility pass: "color-blind friendly themes,
  /// adjustable piece/board contrast." Square colors use a blue/amber
  /// palette rather than the red/green pairing that's hardest to tell
  /// apart under the common forms of color-vision deficiency, and the
  /// light/dark squares sit much further apart in luminance than any
  /// other theme here for low-vision users. The check highlight is
  /// still a red tint for sighted users who expect that convention, but
  /// [ChessBoard] backs it with a pulsing animation rather than color
  /// alone (see `_CheckPulseHighlight`), so which square is in check
  /// doesn't depend on distinguishing that red from anything else.
  static const BoardTheme highContrast = BoardTheme(
    name: 'High Contrast',
    lightSquare: Color(0xFFF5F0E6),
    darkSquare: Color(0xFF26282B),
    selectedHighlight: Color(0x990091EA),
    lastMoveHighlight: Color(0x99FFAB00),
    checkHighlight: Color(0x99D50000),
    legalMoveDot: Color(0xCC0091EA),
    coordinateColor: Color(0xFFFFAB00),
  );

  static const List<BoardTheme> all = <BoardTheme>[
    classicGreen,
    wood,
    marble,
    midnight,
    highContrast,
  ];
}
