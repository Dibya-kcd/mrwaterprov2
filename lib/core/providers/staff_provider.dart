// staff_provider.dart
// ══════════════════════════════════════════════════════════════════════════════
// RE-EXPORT ONLY — do not define any providers here.
//
// StaffNotifier, staffProvider, sessionUserProvider, authStateProvider,
// pinUnlockedProvider, and lastActivityProvider are all defined in app_state.dart.
//
// This file exists so that screens importing staff_provider.dart continue to
// compile. All symbols come from the single canonical definition in app_state.dart.
// Having duplicate definitions here caused Riverpod to create two separate
// notifier instances — one with CompanySession.companyId == '' (empty), causing
// all staff writes to go to companies//users/... instead of companies/{uid}/users/...
// ══════════════════════════════════════════════════════════════════════════════
export 'app_state.dart'
    show
        StaffMember,
        StaffNotifier,
        staffProvider,
        sessionUserProvider,
        authStateProvider,
        pinUnlockedProvider,
        lastActivityProvider;
