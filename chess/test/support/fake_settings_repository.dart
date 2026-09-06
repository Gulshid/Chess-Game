import 'package:chess/features/account/data/settings_repository.dart';
import 'package:chess/features/account/domain/app_settings.dart';

/// In-memory [SettingsRepository] — stands in for Hive so
/// [SettingsProvider] tests don't need `Hive.initFlutter()`/a real box.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({AppSettings initial = const AppSettings()}) : _stored = initial;

  AppSettings _stored;

  /// How many times [save] was called — tests use this to confirm a
  /// setter actually persisted rather than only updating in-memory state.
  int saveCount = 0;

  @override
  Future<AppSettings> load() async => _stored;

  @override
  Future<void> save(AppSettings settings) async {
    _stored = settings;
    saveCount++;
  }
}
