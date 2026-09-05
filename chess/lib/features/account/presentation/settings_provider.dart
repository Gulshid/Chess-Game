import 'package:flutter/foundation.dart';

import '../../ai/domain/ai_difficulty.dart';
import '../data/hive_settings_repository.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

/// Loads [AppSettings] on startup and persists every change through
/// [SettingsRepository] — the provider-layer counterpart screens read
/// (`Consumer<SettingsProvider>` / `context.watch`) instead of touching
/// the repository directly, matching every other provider in this app.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SettingsRepository? repository})
      : _repository = repository ?? HiveSettingsRepository() {
    _load();
  }

  final SettingsRepository _repository;

  AppSettings _settings = const AppSettings();
  bool _isLoading = true;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  Future<void> _load() async {
    _settings = await _repository.load();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _update(AppSettings Function(AppSettings) transform) async {
    _settings = transform(_settings);
    notifyListeners();
    await _repository.save(_settings);
  }

  Future<void> setBoardTheme(String themeName) => _update((s) => s.copyWith(boardThemeName: themeName));

  Future<void> setSoundEnabled(bool enabled) => _update((s) => s.copyWith(soundEnabled: enabled));

  Future<void> setHapticsEnabled(bool enabled) =>
      _update((s) => s.copyWith(hapticsEnabled: enabled));

  Future<void> setDefaultAiDifficulty(AiDifficulty difficulty) =>
      _update((s) => s.copyWith(defaultAiDifficulty: difficulty));

  Future<void> setDefaultTimeControlLabel(String label) =>
      _update((s) => s.copyWith(defaultTimeControlLabel: label));

  Future<void> setShowLegalMoveDots(bool show) =>
      _update((s) => s.copyWith(showLegalMoveDots: show));

  Future<void> setShowCoordinates(bool show) => _update((s) => s.copyWith(showCoordinates: show));
}
