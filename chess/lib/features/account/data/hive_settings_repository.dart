import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../domain/app_settings.dart';
import 'settings_repository.dart';

/// Local-only [SettingsRepository] backed by Hive — chosen over Drift
/// (SQLite) for this specific job because settings are a single small
/// key/value blob with no querying needs; Drift's relational/SQL layer
/// (used instead by anything that *does* need querying — see
/// `HiveCachedSavedGamesRepository`'s doc for why saved games also
/// landed on Hive rather than Drift here) would be pure overhead for
/// one JSON object.
class HiveSettingsRepository implements SettingsRepository {
  HiveSettingsRepository({Box<String>? box}) : _box = box;

  Box<String>? _box;

  static const String boxName = 'app_settings';
  static const String _key = 'settings';

  Future<Box<String>> _openBox() async {
    return _box ??= await Hive.openBox<String>(boxName);
  }

  @override
  Future<AppSettings> load() async {
    final Box<String> box = await _openBox();
    final String? raw = box.get(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromMap(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return const AppSettings(); // Corrupt/old-format entry — fall back to defaults.
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final Box<String> box = await _openBox();
    await box.put(_key, jsonEncode(settings.toMap()));
  }
}
