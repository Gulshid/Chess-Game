import '../domain/app_settings.dart';

/// What the app needs to persist [AppSettings] locally. See
/// [AppSettings]'s class doc for why this stays local-only rather than
/// syncing through Firestore like [ProfileRepository]/
/// [SavedGamesRepository] do.
abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}
