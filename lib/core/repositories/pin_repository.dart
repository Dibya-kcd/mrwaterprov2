import '../providers/app_state.dart';
import '../services/rtdb_user_datasource.dart';
import '../utils/pin_hash_util.dart';

class PinRepository {
  PinRepository({required this.companyId});

  final String companyId;
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
    final salt = userId;
    final hash = PinHashUtil.hash(pin: pin, salt: salt);
    await _datasource.updateUser(companyId, userId, {
      'pin': '',
      'pinHash': hash,
      'pinSalt': salt,
    });
  }
}
