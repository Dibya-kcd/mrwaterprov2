// ════════════════════════════════════════════════════════════════════════════
// auth_repository.dart
// FIX v2: companyId is now read lazily via a getter closure.
// ════════════════════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';
import '../providers/app_state.dart';
import '../services/rtdb_user_datasource.dart';
import '../utils/pin_hash_util.dart';

class AuthRepository {
  /// FIX: accept a getter so companyId is always the live value, not whatever
  /// was in CompanySession at the moment the provider was first constructed.
  AuthRepository({required String Function() companyIdGetter})
      : _companyIdGetter = companyIdGetter;

  final String Function() _companyIdGetter;
  String get companyId => _companyIdGetter();

  final _datasource = RTDBUserDataSource.instance;

  Future<StaffMember> ensureOwnerRecord(User user) async {
    final data = await _datasource.getUser(companyId, user.uid);
    if (data != null) {
      return StaffMember.fromJson(data);
    }

    final owner = StaffMember(
      id: user.uid,
      name: user.displayName ?? user.email ?? 'Owner',
      phone: user.phoneNumber ?? '',
      pin: '',
      isActive: true,
      permissions: const [
        'dashboard', 'transactions', 'customers', 'inventory',
        'load_unload', 'payments', 'reports', 'notifications',
        'settings', 'expenses', 'smart_entry',
      ],
      pinHash: '',
      pinSalt: user.uid,
      role: UserRole.owner,
    );
    await _datasource.setUser(companyId, user.uid, owner.toJson());
    return owner;
  }

  Future<StaffMember?> loadUser(String userId) async {
    final data = await _datasource.getUser(companyId, userId);
    return data == null ? null : StaffMember.fromJson(data);
  }

  Future<void> createOwnerPin(String ownerUid, String pin) async {
    final salt = ownerUid;
    final hash = PinHashUtil.hash(pin: pin, salt: salt);
    await _datasource.updateUser(companyId, ownerUid, {
      'pin': '',
      'pinHash': hash,
      'pinSalt': salt,
    });
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
