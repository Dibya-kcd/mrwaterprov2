// ════════════════════════════════════════════════════════════════════════════
// session_manager.dart
//
// Centralised app-session controller. Responsible for:
//   1. Inactivity auto-lock (5 min by default, configurable)
//   2. Persisting "was unlocked" flag in flutter_secure_storage so a
//      hot-restart does NOT skip the PIN screen
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
// USAGE (in _AppGate / any widget):
//   SessionManager.instance.recordActivity();   // call on every user tap
//   SessionManager.instance.lock(ref);          // force-lock immediately
//   SessionManager.instance.startWatching(ref); // start timeout loop
//   SessionManager.instance.stopWatching();     // clean up on app dispose
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_state.dart';

/// How long of inactivity before the app auto-locks (PIN screen shown again).
const kInactivityTimeout = Duration(minutes: 5);

/// flutter_secure_storage key for the "pin was unlocked" session flag.
const _kSessionKey = 'pin_session_unlocked';

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  DateTime _lastActivity = DateTime.now();
  Timer?   _timer;
  WidgetRef? _ref;

  // ── Activity tracking ─────────────────────────────────────────────────────

  /// Call this on every meaningful user interaction (tap, scroll, type, etc.).
  /// The easiest way: wrap MaterialApp with a GestureDetector in main.dart.
  void recordActivity() => _lastActivity = DateTime.now();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Start the inactivity watchdog. Call once after PIN is verified.
  void startWatching(WidgetRef ref) {
    _ref = ref;
    _timer?.cancel();
    _lastActivity = DateTime.now();
    // Check every 30 s — lightweight enough, fast enough to catch 5-min window
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    debugPrint('[SessionManager] Inactivity watchdog started');
  }

  /// Stop the watchdog. Call when app is disposed or user is locked out.
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
  ///   • Clears the secure-storage session flag
  ///   • Clears the staff session (back to no-one logged in)
  ///   • Stops the inactivity watchdog
  Future<void> lock(WidgetRef ref) async {
    stopWatching();
    ref.read(pinUnlockedProvider.notifier).state = false;
    ref.read(sessionUserProvider.notifier).state = null;
    await _clearStorageFlag();
    debugPrint('[SessionManager] App locked');
  }

  /// Persist the "unlocked" flag so a foreground/background cycle doesn't
  /// treat the session as lost. On a COLD START (process kill) the flag is
  /// intentionally NOT read — we always force PIN on cold start.
  Future<void> persistUnlocked() async {
    try {
      await _storage.write(
          key: _kSessionKey,
          value: DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[SessionManager] secure_storage write error: $e');
    }
  }

  /// Returns true if a recent secure-storage flag exists AND it is within
  /// the inactivity window. Used by _AppGate on warm resume (not cold start).
  Future<bool> isSessionStillValid() async {
    try {
      final val = await _storage.read(key: _kSessionKey);
      if (val == null) return false;
      final saved = DateTime.tryParse(val);
      if (saved == null) return false;
      return DateTime.now().difference(saved) < kInactivityTimeout;
    } catch (e) {
      debugPrint('[SessionManager] secure_storage read error: $e');
      return false;
    }
  }

  Future<void> _clearStorageFlag() async {
    try {
      await _storage.delete(key: _kSessionKey);
    } catch (e) {
      debugPrint('[SessionManager] secure_storage delete error: $e');
    }
  }
}
