import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';
import '../providers/app_state.dart';
import '../services/company_session.dart';
import '../services/rtdb_user_datasource.dart';
import '../utils/pin_hash_util.dart';

// ════════════════════════════════════════════════════════════════════════════
// auth_repository.dart
//
// IMPORTANT: companyId is read from CompanySession on every call — NOT stored
// as a final field. Storing it as final String companyId in the constructor
// locks the repository to whatever companyId was when the Riverpod provider
// was first built (often '' at app start), causing all writes to go to
// companies//users/... — creating anonymous company nodes.
//
// The fix: always call CompanySession.companyId at the moment of each
// Firebase operation, so it always reflects the current session.
// ════════════════════════════════════════════════════════════════════════════

class AuthRepository {
  AuthRepository();

  // Always reads the live companyId — never cached.
  String get _companyId => CompanySession.companyId;

  final _datasource = RTDBUserDataSource.instance;

  Future<StaffMember> ensureOwnerRecord(User user) async {
    final id = _companyId;
    assert(id.isNotEmpty, '[AuthRepository] companyId is empty — CompanySession.init() must be called before ensureOwnerRecord()');
    final data = await _datasource.getUser(id, user.uid);
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
    await _datasource.setUser(id, user.uid, owner.toJson());
    return owner;
  }

  Future<StaffMember?> loadUser(String userId) async {
    final id = _companyId;
    if (id.isEmpty) return null;
    final data = await _datasource.getUser(id, userId);
    return data == null ? null : StaffMember.fromJson(data);
  }

  Future<void> createOwnerPin(String ownerUid, String pin) async {
    final id = _companyId;
    if (id.isEmpty) return;
    final salt = ownerUid;
    final hash = PinHashUtil.hash(pin: pin, salt: salt);
    await _datasource.updateUser(id, ownerUid, {
      'pin': '',
      'pinHash': hash,
      'pinSalt': salt,
    });
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
