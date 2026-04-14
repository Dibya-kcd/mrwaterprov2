// ════════════════════════════════════════════════════════════════════════════
// staff_provider.dart — Staff management provider
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/staff_member.dart';
import '../services/company_session.dart';
import '../services/rtdb_user_datasource.dart';

/// Deep-cast a Firebase snapshot value to Map<String, dynamic>.
/// Flutter Web Firebase SDK returns LinkedMap<Object?, Object?> at every level.
/// Map<String, dynamic>.from() only converts the outer keys — nested maps and
/// lists still contain LinkedMap entries, causing fromJson() to throw.
/// This recursive helper converts the entire tree.
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
      state = documents.map((e) => StaffMember.fromJson(_deepCast(e))).toList();
    });
  }

  void reinit() => _init();

  Future<void> add(StaffMember s) async {
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

  StaffMember? byPin(String pin) {
    try {
      return state.firstWhere((s) => s.pin == pin && s.isActive);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final staffProvider = StateNotifierProvider<StaffNotifier, List<StaffMember>>(
    (ref) => StaffNotifier());

// Current session: null = owner, non-null = logged-in staff member
final sessionUserProvider = StateProvider<StaffMember?>((ref) => null);

// Firebase Auth state: emits current Firebase user (null if not logged in)
final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

// Global flag to indicate if the user has passed the PIN screen
final pinUnlockedProvider = StateProvider<bool>((ref) => false);

// ── Inactivity auto-lock provider ─────────────────────────────────────────────
// Tracks the last user-activity timestamp.  SessionManager polls this every
// 30 s and locks the app when idle > kInactivityTimeout (5 min).
// Call: ref.read(lastActivityProvider.notifier).state = DateTime.now()
// on every meaningful user interaction, OR use the ActivityDetector wrapper.
final lastActivityProvider = StateProvider<DateTime>((ref) => DateTime.now());