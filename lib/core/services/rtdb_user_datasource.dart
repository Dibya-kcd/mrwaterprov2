// ════════════════════════════════════════════════════════════════════════════
// rtdb_user_datasource.dart — RTDB version of FirestoreUserDataSource
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_config.dart';

// ── Deep-cast helper ──────────────────────────────────────────────────────────
Map<String, dynamic> _deepCast(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _deepCastValue(v)));
  }
  return {};
}

dynamic _deepCastValue(dynamic v) {
  if (v is Map)  return _deepCast(v);
  if (v is List) return v.map(_deepCastValue).toList();
  return v;
}

class RTDBUserDataSource {
  RTDBUserDataSource._();
  static final instance = RTDBUserDataSource._();

  // Use 'users' node in RTDB, similar to Firestore
  static const String _usersNode = 'users';

  DatabaseReference _usersRef(String companyId) {
    return FirebaseDatabase.instanceFor(
      app: FirebaseDatabase.instance.app,
      databaseURL: FirebaseConfig.databaseUrl,
    ).ref('companies/$companyId/$_usersNode');
  }

  Stream<List<Map<String, dynamic>>> watchUsers(String companyId) {
    if (companyId.isEmpty) return const Stream.empty();
    return _usersRef(companyId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];
      final data = event.snapshot.value;
      if (data is! Map) return [];
      return data.entries.map((entry) {
        final userData = entry.value;
        if (userData is! Map) return <String, dynamic>{'id': entry.key.toString()};
        return <String, dynamic>{'id': entry.key.toString(), ..._deepCast(userData)};
      }).toList();
    });
  }

  Future<Map<String, dynamic>?> getUser(String companyId, String userId) async {
    if (companyId.isEmpty || userId.isEmpty) return null;
    final snap = await _usersRef(companyId).child(userId).get();
    if (!snap.exists || snap.value == null) return null;
    final data = snap.value;
    if (data is! Map) return null;
    return <String, dynamic>{'id': userId, ..._deepCast(data)};
  }

  Future<void> setUser(String companyId, String userId, Map<String, dynamic> value) async {
    await _usersRef(companyId).child(userId).set(value);
  }

  Future<void> updateUser(String companyId, String userId, Map<String, dynamic> value) async {
    await _usersRef(companyId).child(userId).update(value);
  }

  Future<void> deleteUser(String companyId, String userId) async {
    await _usersRef(companyId).child(userId).remove();
  }

  /// Checks if any company is already registered in the system.
  /// Reads metadata/owner_registered which is publicly readable per DB rules.
  /// This is the ONLY check — we do NOT read root 'companies/' (denied by rules).
  Future<bool> anyCompanyExists() async {
    try {
      final metaSnap = await FirebaseDatabase.instanceFor(
        app: FirebaseDatabase.instance.app,
        databaseURL: FirebaseConfig.databaseUrl,
      ).ref('metadata/owner_registered').get();
      return metaSnap.exists && metaSnap.value == true;
    } catch (e) {
      debugPrint('anyCompanyExists check failed: $e');
      // Fail-open: if we cannot check, allow signup to proceed.
      // _ensureOwnerRecord will be idempotent anyway.
      return false;
    }
  }

  /// Sets the global flag that an owner has been registered.
  Future<void> markOwnerRegistered() async {
    try {
      await FirebaseDatabase.instanceFor(
        app: FirebaseDatabase.instance.app,
        databaseURL: FirebaseConfig.databaseUrl,
      ).ref('metadata/owner_registered').set(true);
    } catch (e) {
      debugPrint('Error marking owner registered: $e');
    }
  }
}