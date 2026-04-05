import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';
import '../providers/app_state.dart';
import '../services/rtdb_user_datasource.dart';
import '../utils/pin_hash_util.dart';

class AuthRepository {
  AuthRepository({required this.companyId});

  final String companyId;
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
      permissions: [
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
