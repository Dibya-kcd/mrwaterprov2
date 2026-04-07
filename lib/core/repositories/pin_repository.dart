import '../providers/app_state.dart';
import '../services/company_session.dart';
import '../services/rtdb_user_datasource.dart';
import '../utils/pin_hash_util.dart';

// ════════════════════════════════════════════════════════════════════════════
// pin_repository.dart
//
// IMPORTANT: companyId is read from CompanySession on every call — NOT stored
// as a final field. See auth_repository.dart for the full explanation.
// ════════════════════════════════════════════════════════════════════════════

class PinRepository {
  PinRepository();

  // Always reads the live companyId — never cached.
  String get _companyId => CompanySession.companyId;

  final _datasource = RTDBUserDataSource.instance;

  Future<StaffMember?> verifyPin(String pin, List<StaffMember> users) async {
    for (final user in users) {
      if (!user.isActive) continue;
      if (user.hasPinHash) {
        final match = PinHashUtil.verify(
          pin: pin,
          salt: user.pinSalt,
          storedHash: user.pinHash,
        );
        if (match) return user;
      }
    }
    return null;
  }

  Future<bool> verifyOwnerPin(String pin, StaffMember? ownerRecord) async {
    if (ownerRecord == null || !ownerRecord.isOwner) return false;
    if (!ownerRecord.hasPinHash) return false;
    return PinHashUtil.verify(
      pin: pin,
      salt: ownerRecord.pinSalt,
      storedHash: ownerRecord.pinHash,
    );
  }

  Future<void> createPinForUser(String userId, String pin) async {
    final id = _companyId;
    if (id.isEmpty) return;
    final salt = userId;
    final hash = PinHashUtil.hash(pin: pin, salt: salt);
    await _datasource.updateUser(id, userId, {
      'pin': '',
      'pinHash': hash,
      'pinSalt': salt,
    });
  }
}
