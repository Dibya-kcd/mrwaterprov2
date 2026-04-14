// ════════════════════════════════════════════════════════════════════════════
// settings_provider.dart — Application settings provider
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../services/firebase_config.dart';
import '../services/firebase_service.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) { Future.microtask(_init); }

  void _init() {
    FirebaseService.instance.watch(FirebaseConfig.nodeSettings).listen((data) {
      if (data != null) state = AppSettings.fromJson(data);
    });
  }

  Future<void> save(AppSettings s) async {
    await FirebaseService.instance.write(FirebaseConfig.nodeSettings, s.toJson());
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier());

final themeModeProvider = Provider<ThemeMode>((ref) {
  final s = ref.watch(settingsProvider);
  return switch (s.themeMode) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
});