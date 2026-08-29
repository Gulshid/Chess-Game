import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constant/app_colors.dart';

/// App-wide [ThemeData]. Board color themes (wood/marble/classic) are a
/// separate concern added in Phase 5 — this only covers app chrome
/// (app bar, buttons, scaffold background, typography).
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.seed,
        brightness: Brightness.dark,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      textTheme: GoogleFonts.baloo2TextTheme(base.textTheme),
    );
  }

  static ThemeData get light {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.seed),
    );
    return base.copyWith(
      textTheme: GoogleFonts.baloo2TextTheme(base.textTheme),
    );
  }
}
