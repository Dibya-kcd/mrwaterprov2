// ════════════════════════════════════════════════════════════════════════════
// staff_provider.dart — Staff management provider
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/staff_member.dart';
import '../services/company_session.dart';
import '../services/rtdb_user_datasource.dart';
import '../utils/pin_hash_util.dart';         // FIX 5: added import

/// Deep-cast a Firebase snapshot value to Map<String, dynamic>.
/// Flutter Web Firebase SDK returns LinkedMap<Object?, Object?> at every level.
Map<String, dynamic> _deepCast(dynamic data) {
  if (data is Map) {
    return data.map((k, v) => MapEntry(k.toString(), _deepCastValue(v)));
  }
  return {};
}

dynamic _deepCastValue(dynamic v) {
  if (v is Map)  return _deepCast(v);
  if (v is List) return v.map(_deepCastValue).toList();
  return v;
}

class StaffNotifier extends StateNotifier<List<StaffMember>> {
  StaffNotifier() : super([]) { Future.microtask(_init); }

  StreamSubscription? _sub;

  void _init() {
    _sub?.cancel();
    if (CompanySession.companyId.isEmpty) {
      state = [];
      return;
    }

    _sub = RTDBUserDataSource.instance
        .watchUsers(CompanySession.companyId)
        .listen((documents) {
      if (!mounted) return;
      state = documents
          .map((e) => StaffMember.fromJson(_deepCast(e)))
          .toList();
    });
  }

  void reinit() => _init();

  void _assertAuth() {
    if (FirebaseAuth.instance.currentUser == null ||
        CompanySession.companyId.isEmpty) {
      throw StateError('Not authenticated — cannot save staff data.');
    }
  }

  Future<void> add(StaffMember s) async {
    _assertAuth();
    await RTDBUserDataSource.instance.setUser(
        CompanySession.companyId, s.id, s.toJson());
  }

  Future<void> update(StaffMember s) async {
    await RTDBUserDataSource.instance.updateUser(
        CompanySession.companyId, s.id, s.toJson());
  }

  Future<void> remove(String id) async {
    await RTDBUserDataSource.instance.deleteUser(
        CompanySession.companyId, id);
  }

  // FIX 5: byPin() now supports hashed PINs and auto-upgrades legacy plain-text
  // records on first match. The old version always returned null for hashed staff.
  StaffMember? byPin(String pin) {
    for (final s in state) {
      if (!s.isActive) continue;

      if (s.hasPinHash) {
        // Verify against stored hash
        final match = PinHashUtil.verify(
          pin: pin,
          salt: s.pinSalt,
          storedHash: s.pinHash,
        );
        if (match) return s;
      } else if (s.pin == pin) {
        // Legacy plain-text match — transparently upgrade to hashed PIN
        final upgraded = s.copyWith(
          pinHash: PinHashUtil.hash(pin: pin, salt: s.id),
          pinSalt: s.id,
          pin: '',
        );
        // Fire-and-forget upgrade write; don't await so caller stays sync
        update(upgraded);
        return upgraded;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final staffProvider =
    StateNotifierProvider<StaffNotifier, List<StaffMember>>(
        (ref) => StaffNotifier());

/// Current session: null = owner mode, non-null = logged-in staff member.
/// Convention: owner authenticates via Firebase PIN but sessionUserProvider
/// stays null — every owner-only check uses `sessionUserProvider == null`.
final sessionUserProvider = StateProvider<StaffMember?>((ref) => null);

/// Firebase Auth state stream — emits current Firebase User (null if signed out).
final authStateProvider = StreamProvider<User?>(
    (ref) => FirebaseAuth.instance.authStateChanges());

/// Global flag: true once the user has passed the PIN screen.
final pinUnlockedProvider = StateProvider<bool>((ref) => false);

/// Tracks the last user-activity timestamp for inactivity auto-lock.
/// Update on every meaningful interaction or use ActivityDetector wrapper.
final lastActivityProvider =
    StateProvider<DateTime>((ref) => DateTime.now());
