// ════════════════════════════════════════════════════════════════════════════
// pin_hash_util.dart
//
// Utility for hashing and verifying PINs using SHA-256.
//
// WHY SHA-256 AND NOT BCRYPT:
//   bcrypt is the gold standard for password hashing, but Flutter does not
//   have a well-maintained, null-safe bcrypt package that works across
//   iOS/Android/Web. The `crypto` package (SHA-256) is Google's own,
//   production-grade, and works on all platforms.
//
//   To compensate for SHA-256 being fast (and thus brute-forcible for short
//   PINs), we add a per-user salt stored alongside the hash in Firestore.
//   The salt is a random UUID — this means two users with the same PIN will
//   have different hashes, and rainbow-table attacks are defeated.
//
// USAGE:
//   final hash = PinHashUtil.hash(pin: '1234', salt: uid);
//   final ok   = PinHashUtil.verify(pin: '1234', salt: uid, storedHash: hash);
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinHashUtil {
  PinHashUtil._();

  /// Hashes a PIN with a salt using SHA-256.
  /// [salt] should be unique per user — use the user's UID or a random UUID.
  /// Returns a lowercase hex string (64 chars).
  static String hash({required String pin, required String salt}) {
    final input  = utf8.encode('$salt:$pin'); // salt:pin prevents length extension
    final digest = sha256.convert(input);
    return digest.toString();
  }

  /// Returns true if [pin] + [salt] produces [storedHash].
  static bool verify({
    required String pin,
    required String salt,
    required String storedHash,
  }) {
    if (pin.isEmpty || salt.isEmpty || storedHash.isEmpty) return false;
    return hash(pin: pin, salt: salt) == storedHash;
  }

  /// Validates that a PIN string is 4–6 numeric digits.
  static bool isValid(String pin) =>
      RegExp(r'^\d{4,6}$').hasMatch(pin);

  /// Returns an error string if invalid, null if OK.
  static String? validate(String pin) {
    if (pin.isEmpty)             return 'PIN cannot be empty';
    if (!RegExp(r'^\d+$').hasMatch(pin)) return 'PIN must contain digits only';
    if (pin.length < 4)          return 'PIN must be at least 4 digits';
    if (pin.length > 6)          return 'PIN must be at most 6 digits';
    return null;
  }
}
