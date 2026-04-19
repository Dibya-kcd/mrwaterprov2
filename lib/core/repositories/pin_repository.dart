// ════════════════════════════════════════════════════════════════════════════
// pin_repository.dart
// FIX v2: companyId is now read lazily via a getter closure.
// ════════════════════════════════════════════════════════════════════════════

import '../providers/app_state.dart';
import '../services/rtdb_user_datasource.dart';
import '../utils/pin_hash_util.dart';

class PinRepository {
  /// FIX: accept a getter so companyId is always the live value, not whatever
  /// was in CompanySession at the moment the provider was first constructed.
  PinRepository({required String Function() companyIdGetter})
      : _companyIdGetter = companyIdGetter;

  final String Function() _companyIdGetter;
  String get companyId => _companyIdGetter();

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

  /// Create or reset a hashed PIN for [userId].
  /// Call this when adding a new staff member or when an owner resets a PIN.
  Future<void> createPinForUser(String userId, String pin) async {
    final salt = userId;
    final hash = PinHashUtil.hash(pin: pin, salt: salt);
    await _datasource.updateUser(companyId, userId, {
      'pin': '',         // clear any legacy plain-text pin
      'pinHash': hash,
      'pinSalt': salt,
    });
  }
}
