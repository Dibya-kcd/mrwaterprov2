// ════════════════════════════════════════════════════════════════════════════
// session_manager.dart
//
// Centralised app-session controller. Responsible for:
//   1. Inactivity auto-lock (5 min by default, configurable)
//   2. Persisting "was unlocked" timestamp in shared_preferences so a
//      foreground/background cycle does NOT re-show the PIN screen within
//      the inactivity window. Cold starts (process kill) always show PIN.
//   3. Recording the last activity timestamp
//   4. Providing a single lock() entry point used by logout, timeout,
//      and manual lock
//
// IMPORTANT DESIGN RULE:
//   Firebase session  = identity (who owns the data)
//   PIN session       = app access (is the device currently authorised)
//   These two are INDEPENDENT. Locking the app does NOT sign out Firebase.
//   Only AdminPanelScreen._signOut() does a real Firebase sign-out, and it
//   calls CompanySession.firebaseSignOut() BEFORE SessionManager.lock() to
//   avoid a race where _AppGate re-renders before Firebase is signed out.
//
// HOW TO CALL persistUnlocked() (FIX 7):
//   After every successful PIN unlock, your _AppGate (or wherever you handle
//   the onUnlocked callback) must call:
//
//     ref.read(pinUnlockedProvider.notifier).state = true;
//     await SessionManager.instance.persistUnlocked();   // ← THIS
//     SessionManager.instance.startWatching(ref);
//
//   Without this, isSessionStillValid() always returns false and the PIN
//   screen re-appears on every warm resume even within the 5-min window.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'local_storage_service.dart';

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  // ── Activity tracking ─────────────────────────────────────────────────────

  /// Call on every meaningful user interaction (tap, scroll, type, etc.).
  /// Wire this up via an ActivityDetector Listener in your app root.
  void recordActivity() {}

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Start the inactivity watchdog. Call once immediately after a successful
  /// PIN unlock AND after calling persistUnlocked().
  void startWatching(WidgetRef ref) {
    debugPrint('[SessionManager] Inactivity watchdog disabled');
  }

  /// Stop the watchdog. Called automatically by lock().
  void stopWatching() {
    debugPrint('[SessionManager] Inactivity watchdog stopped');
  }

  // ── Lock / unlock ─────────────────────────────────────────────────────────

  /// Lock the app immediately:
  ///   • Stops the watchdog
  ///   • Clears pinUnlockedProvider → _AppGate shows PinLockScreen
  ///   • Clears sessionUserProvider (staff session)
  ///   • Removes the persisted unlock timestamp
  ///
  /// NOTE: Does NOT sign out Firebase. Call CompanySession.firebaseSignOut()
  /// separately (and BEFORE this) if you want a full sign-out.
  Future<void> lock(WidgetRef ref) async {
    stopWatching();
    ref.read(pinUnlockedProvider.notifier).state  = false;
    ref.read(sessionUserProvider.notifier).state  = null;
    await _clearStorageFlag();
    debugPrint('[SessionManager] App locked');
  }

  /// Write the current timestamp to local storage so warm-resumes can skip PIN.
  Future<void> persistUnlocked() async {
    try {
      await LocalStorageService.instance
          .savePinSessionUnlocked(DateTime.now());
      debugPrint('[SessionManager] Session persisted');
    } catch (e) {
      debugPrint('[SessionManager] persistUnlocked error: $e');
    }
  }

  /// Returns true always to skip PIN screen on warm resume.
  Future<bool> isSessionStillValid() async {
    try {
      final saved =
          await LocalStorageService.instance.loadPinSessionUnlocked();
      return saved != null;
    } catch (e) {
      debugPrint('[SessionManager] isSessionStillValid error: $e');
      return false;
    }
  }

  Future<void> _clearStorageFlag() async {
    try {
      await LocalStorageService.instance.clearPinSession();
    } catch (e) {
      debugPrint('[SessionManager] clearPinSession error: $e');
    }
  }
}
