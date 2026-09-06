import 'dart:ui';

import 'package:chess/features/board_ui/domain/board_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BoardTheme.all includes the Phase 11 High Contrast theme', () {
    expect(BoardTheme.all, contains(BoardTheme.highContrast));
    expect(BoardTheme.highContrast.name, 'High Contrast');
  });

  test('every theme in BoardTheme.all has a unique name', () {
    final names = BoardTheme.all.map((t) => t.name).toList();
    expect(names.toSet().length, names.length,
        reason: 'duplicate theme names would collide in AppSettings.boardTheme lookups '
            'and in the settings screen\'s RadioListTile group');
  });

  test('High Contrast keeps light/dark squares far apart in luminance', () {
    // A rough proxy for "high contrast": the light square should be
    // much brighter than the dark square. Uses simple channel-average
    // luminance rather than a full perceptual formula since this is a
    // sanity check on the theme's intent, not a WCAG contrast audit.
    double luminance(Color c) => (c.red + c.green + c.blue) / 3;

    final double lightLuminance = luminance(BoardTheme.highContrast.lightSquare);
    final double darkLuminance = luminance(BoardTheme.highContrast.darkSquare);
    expect(lightLuminance - darkLuminance, greaterThan(100));
  });
}
