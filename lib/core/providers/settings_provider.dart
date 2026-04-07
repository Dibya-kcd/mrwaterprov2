// settings_provider.dart
// ══════════════════════════════════════════════════════════════════════════════
// RE-EXPORT ONLY — do not define any providers here.
//
// SettingsNotifier, settingsProvider, and themeModeProvider are all defined
// in app_state.dart. This file re-exports them so existing imports continue
// to work without creating duplicate provider instances.
// ══════════════════════════════════════════════════════════════════════════════
export 'app_state.dart'
    show
        AppSettings,
        SettingsNotifier,
        settingsProvider,
        themeModeProvider;
