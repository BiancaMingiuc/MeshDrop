// state/app_settings_provider.dart
// Riverpod provider for AppSettings.
// Loads settings from SharedPreferences on app startup and exposes
// a notifier so the UI can update and persist them.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_settings.dart';

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const _prefsKey = 'meshdrop_app_settings';

  AppSettingsNotifier(super.initial);

  /// Updates a single field and persists the entire settings object.
  Future<void> update({
    String? downloadDirectory,
    int? chunkSizeBytes,
    bool? autoAccept,
  }) async {
    state = state.copyWith(
      downloadDirectory: downloadDirectory,
      chunkSizeBytes: chunkSizeBytes,
      autoAccept: autoAccept,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  /// Loads persisted settings, falling back to defaults on first run.
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupted data — fall through to defaults.
      }
    }
    final defaultDir = await getApplicationDocumentsDirectory();
    return AppSettings(downloadDirectory: defaultDir.path);
  }
}

/// Initialized asynchronously in main() before runApp().
/// See [appSettingsProvider].
late final StateNotifierProvider<AppSettingsNotifier, AppSettings>
    appSettingsProvider;

/// Call once in main() to bootstrap the settings provider with loaded data.
Future<void> initAppSettingsProvider() async {
  final settings = await AppSettingsNotifier.load();
  appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>(
    (ref) => AppSettingsNotifier(settings),
  );
}
