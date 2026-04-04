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
//   Only CompanyLoginScreen._confirmFirebaseSignOut() does a real sign-out.
//
// NOTE ON STORAGE:
//   Uses shared_preferences (already a project dependency) instead of
//   flutter_secure_storage to avoid adding a new package dependency.
//   The session flag stores only a timestamp — no secrets are persisted here.
//   PIN hashes live in Firebase (app_state.dart / StaffMember.pinHash).
//
// USAGE (in _AppGate / any widget):
//   SessionManager.instance.recordActivity();    // call on every user tap
//   SessionManager.instance.lock(ref);           // force-lock immediately
//   SessionManager.instance.startWatching(ref);  // start timeout loop
//   SessionManager.instance.stopWatching();      // clean up on dispose
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'local_storage_service.dart';

/// How long of inactivity before the app auto-locks (PIN screen shown again).
const kInactivityTimeout = Duration(minutes: 5);

/// shared_preferences key for the last-unlocked timestamp.

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  DateTime   _lastActivity = DateTime.now();
  Timer?     _timer;
  WidgetRef? _ref;

  // ── Activity tracking ─────────────────────────────────────────────────────

  /// Call this on every meaningful user interaction (tap, scroll, etc.).
  /// Wired up via the ActivityDetector Listener wrapper in main.dart.
  void recordActivity() => _lastActivity = DateTime.now();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Start the inactivity watchdog. Call once after PIN is verified.
  void startWatching(WidgetRef ref) {
    _ref = ref;
    _timer?.cancel();
    _lastActivity = DateTime.now();
    // Poll every 30 s — lightweight, fast enough to catch a 5-min window.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    debugPrint('[SessionManager] Inactivity watchdog started');
  }

  /// Stop the watchdog. Call when the app is disposed or the user is locked.
  void stopWatching() {
    _timer?.cancel();
    _timer = null;
    _ref   = null;
    debugPrint('[SessionManager] Inactivity watchdog stopped');
  }

  void _check() {
    final idle = DateTime.now().difference(_lastActivity);
    if (idle >= kInactivityTimeout) {
      debugPrint('[SessionManager] Inactivity timeout — locking app');
      if (_ref != null) lock(_ref!);
    }
  }

  // ── Lock / unlock ─────────────────────────────────────────────────────────

  /// Lock the app immediately:
  ///   • Clears the Riverpod PIN-unlocked flag → _AppGate shows PinLockScreen
  ///   • Clears the shared_preferences session timestamp
  ///   • Clears the staff session (reverts to no role logged in)
  ///   • Stops the inactivity watchdog
  Future<void> lock(WidgetRef ref) async {
    stopWatching();
    ref.read(pinUnlockedProvider.notifier).state = false;
    ref.read(sessionUserProvider.notifier).state = null;
    await _clearStorageFlag();
    debugPrint('[SessionManager] App locked');
  }

  /// Write the current timestamp to secure storage.
  /// Called right after a successful PIN unlock so warm resumes within the
  /// inactivity window can skip the PIN screen.
  Future<void> persistUnlocked() async {
    try {
      await LocalStorageService.instance.savePinSessionUnlocked(DateTime.now());
    } catch (e) {
      debugPrint('[SessionManager] secure storage write error: $e');
    }
  }

  /// Returns true if the persisted timestamp is within the inactivity window.
  /// Used by _AppGate on warm resume (app brought to foreground).
  /// Always returns false on cold start because prefs are cleared on lock.
  Future<bool> isSessionStillValid() async {
    try {
      final saved = await LocalStorageService.instance.loadPinSessionUnlocked();
      if (saved == null) return false;
      return DateTime.now().difference(saved) < kInactivityTimeout;
    } catch (e) {
      debugPrint('[SessionManager] secure storage read error: $e');
      return false;
    }
  }

  Future<void> _clearStorageFlag() async {
    try {
      await LocalStorageService.instance.clearPinSession();
    } catch (e) {
      debugPrint('[SessionManager] secure storage delete error: $e');
    }
  }
}
