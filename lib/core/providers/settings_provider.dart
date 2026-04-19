// ════════════════════════════════════════════════════════════════════════════
// settings_provider.dart — Application settings provider
// FIX v2:
//   • save() now calls s.toFirebaseJson() instead of s.toJson() so that
//     logoLocalPath (a device-specific filesystem path) is NEVER written to
//     Firebase and silently broken on every other device / browser.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../services/firebase_config.dart';
import '../services/firebase_service.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    Future.microtask(_init);
  }

  void _init() {
    FirebaseService.instance.watch(FirebaseConfig.nodeSettings).listen((data) {
      if (data != null) state = AppSettings.fromJson(data);
    });
  }

  /// Persist settings to Firebase.
  /// FIX: uses toFirebaseJson() which excludes logoLocalPath.
  /// logoLocalPath is a device-local path — syncing it to Firebase causes it
  /// to appear on other devices where that path does not exist.
  Future<void> save(AppSettings s) async {
    await FirebaseService.instance
        .write(FirebaseConfig.nodeSettings, s.toFirebaseJson());
    // Update local state immediately (optimistic) regardless of Firebase result
    state = s;
  }

  /// Save just the logoLocalPath locally — this never goes to Firebase.
  /// Call this after the user picks a logo from their device gallery.
  void setLogoLocalPath(String path) {
    state = state.copyWith(logoLocalPath: path);
    // Intentionally NOT calling save() — local path stays on this device only.
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
        (ref) => SettingsNotifier());

final themeModeProvider = Provider<ThemeMode>((ref) {
  final s = ref.watch(settingsProvider);
  return switch (s.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});
