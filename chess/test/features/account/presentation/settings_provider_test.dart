import 'package:chess/features/account/domain/app_settings.dart';
import 'package:chess/features/account/presentation/settings_provider.dart';
import 'package:chess/features/ai/domain/ai_difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_settings_repository.dart';

void main() {
  test('loads persisted settings on construction', () async {
    final repo = FakeSettingsRepository(
      initial: const AppSettings(boardThemeName: 'Midnight', soundEnabled: false),
    );
    final provider = SettingsProvider(repository: repo);
    await Future<void>.delayed(Duration.zero);

    expect(provider.isLoading, isFalse);
    expect(provider.settings.boardThemeName, 'Midnight');
    expect(provider.settings.soundEnabled, isFalse);
  });

  test('defaults to AppSettings() when nothing was ever saved', () async {
    final provider = SettingsProvider(repository: FakeSettingsRepository());
    await Future<void>.delayed(Duration.zero);
    expect(provider.settings, const AppSettings());
  });

  test('every setter updates in-memory state immediately and persists it', () async {
    final repo = FakeSettingsRepository();
    final provider = SettingsProvider(repository: repo);
    await Future<void>.delayed(Duration.zero);

    await provider.setBoardTheme('Wood');
    expect(provider.settings.boardThemeName, 'Wood');

    await provider.setSoundEnabled(false);
    expect(provider.settings.soundEnabled, isFalse);

    await provider.setHapticsEnabled(false);
    expect(provider.settings.hapticsEnabled, isFalse);

    await provider.setDefaultAiDifficulty(AiDifficulty.hard);
    expect(provider.settings.defaultAiDifficulty, AiDifficulty.hard);

    await provider.setDefaultTimeControlLabel('Rapid · 10+0');
    expect(provider.settings.defaultTimeControlLabel, 'Rapid · 10+0');

    await provider.setShowLegalMoveDots(false);
    expect(provider.settings.showLegalMoveDots, isFalse);

    await provider.setShowCoordinates(false);
    expect(provider.settings.showCoordinates, isFalse);

    expect(repo.saveCount, 7);
  });

  test('other settings are untouched when only one is changed', () async {
    final provider = SettingsProvider(repository: FakeSettingsRepository());
    await Future<void>.delayed(Duration.zero);

    await provider.setSoundEnabled(false);

    expect(provider.settings.hapticsEnabled, isTrue);
    expect(provider.settings.boardThemeName, const AppSettings().boardThemeName);
  });
}
