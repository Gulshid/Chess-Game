import '../../ai/domain/ai_difficulty.dart';
import '../../board_ui/domain/board_theme.dart';
import '../../multiplayer/domain/time_control.dart';

/// User preferences persisted across launches — Phase 9's "Persist user
/// preferences: board theme, piece set, sound/haptics toggle, default
/// time control" line item.
///
/// Stored locally only (Hive — see `HiveSettingsRepository`), not in
/// Firestore: these are device/app preferences, not account data that
/// needs to follow the player to a new device the way [UserProfile] and
/// saved games do. That keeps them readable before sign-in even
/// completes and off the Firestore read/write quota entirely.
class AppSettings {
  const AppSettings({
    this.boardThemeName = 'Classic Green',
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.defaultAiDifficulty = AiDifficulty.medium,
    this.defaultTimeControlLabel = 'Blitz · 5+0',
    this.showLegalMoveDots = true,
    this.showCoordinates = true,
  });

  final String boardThemeName;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final AiDifficulty defaultAiDifficulty;
  final String defaultTimeControlLabel;
  final bool showLegalMoveDots;
  final bool showCoordinates;

  BoardTheme get boardTheme => BoardTheme.all.firstWhere(
        (t) => t.name == boardThemeName,
        orElse: () => BoardTheme.classicGreen,
      );

  TimeControl get defaultTimeControl => TimeControl.presets.firstWhere(
        (tc) => tc.label == defaultTimeControlLabel,
        orElse: () => TimeControl.blitz5,
      );

  AppSettings copyWith({
    String? boardThemeName,
    bool? soundEnabled,
    bool? hapticsEnabled,
    AiDifficulty? defaultAiDifficulty,
    String? defaultTimeControlLabel,
    bool? showLegalMoveDots,
    bool? showCoordinates,
  }) {
    return AppSettings(
      boardThemeName: boardThemeName ?? this.boardThemeName,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      defaultAiDifficulty: defaultAiDifficulty ?? this.defaultAiDifficulty,
      defaultTimeControlLabel: defaultTimeControlLabel ?? this.defaultTimeControlLabel,
      showLegalMoveDots: showLegalMoveDots ?? this.showLegalMoveDots,
      showCoordinates: showCoordinates ?? this.showCoordinates,
    );
  }

  factory AppSettings.fromMap(Map<String, Object?> map) {
    final AiDifficulty difficulty = AiDifficulty.values.firstWhere(
      (d) => d.name == map['defaultAiDifficulty'],
      orElse: () => AiDifficulty.medium,
    );
    return AppSettings(
      boardThemeName: map['boardThemeName'] as String? ?? 'Classic Green',
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      hapticsEnabled: map['hapticsEnabled'] as bool? ?? true,
      defaultAiDifficulty: difficulty,
      defaultTimeControlLabel: map['defaultTimeControlLabel'] as String? ?? 'Blitz · 5+0',
      showLegalMoveDots: map['showLegalMoveDots'] as bool? ?? true,
      showCoordinates: map['showCoordinates'] as bool? ?? true,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'boardThemeName': boardThemeName,
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
        'defaultAiDifficulty': defaultAiDifficulty.name,
        'defaultTimeControlLabel': defaultTimeControlLabel,
        'showLegalMoveDots': showLegalMoveDots,
        'showCoordinates': showCoordinates,
      };
}
