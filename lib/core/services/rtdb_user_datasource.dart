// ════════════════════════════════════════════════════════════════════════════
// rtdb_user_datasource.dart — RTDB version of FirestoreUserDataSource
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_config.dart';

// ── Deep-cast helper ──────────────────────────────────────────────────────────
// Flutter Web Firebase SDK returns LinkedMap<Object?, Object?> at every level.
// A shallow Map<String, dynamic>.from() only converts top-level keys; nested
// maps and lists remain as LinkedMap and cause TypeErrors in fromJson().
// _deepCast() recursively converts the entire tree to proper Dart types.
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

  static const String _usersNode = 'users';

  DatabaseReference _usersRef(String companyId) {
    return FirebaseDatabase.instanceFor(
      app: FirebaseDatabase.instance.app,
      databaseURL: FirebaseConfig.databaseUrl,
    ).ref('companies/$companyId/$_usersNode');
  }

  // FIX 9: apply _deepCast to the entire snapshot value, not just one level.
  // The old code cast `entry.value as Map<dynamic, dynamic>` but nested fields
  // (like the `permissions` list) remained as LinkedMap<Object?, Object?> on
  // Flutter Web and caused a crash inside StaffMember.fromJson().
  Stream<List<Map<String, dynamic>>> watchUsers(String companyId) {
    if (companyId.isEmpty) return const Stream.empty();
    return _usersRef(companyId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];

      // _deepCast the whole snapshot first, then iterate entries
      final data = _deepCast(event.snapshot.value);
      return data.entries.map((entry) {
        return <String, dynamic>{
          'id': entry.key,
          ..._deepCast(entry.value),
        };
      }).toList();
    });
  }

  Future<Map<String, dynamic>?> getUser(
      String companyId, String userId) async {
    final snap =
        await _usersRef(companyId).child(userId).get();
    if (!snap.exists || snap.value == null) return null;
    return <String, dynamic>{
      'id': userId,
      ..._deepCast(snap.value),
    };
  }

  Future<void> setUser(
      String companyId, String userId, Map<String, dynamic> value) async {
    await _usersRef(companyId).child(userId).set(value);
  }

  Future<void> updateUser(
      String companyId, String userId, Map<String, dynamic> value) async {
    await _usersRef(companyId).child(userId).update(value);
  }

  Future<void> deleteUser(String companyId, String userId) async {
    await _usersRef(companyId).child(userId).remove();
  }
}
