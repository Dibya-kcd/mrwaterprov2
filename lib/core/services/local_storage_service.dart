import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalStorageService {
  LocalStorageService._();
  static final instance = LocalStorageService._();

  static const _kPinSessionKey = 'pin_session_unlocked_at';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> savePinSessionUnlocked(DateTime timestamp) async {
    await _storage.write(
      key: _kPinSessionKey,
      value: timestamp.toIso8601String(),
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    );
  }

  Future<DateTime?> loadPinSessionUnlocked() async {
    final value = await _storage.read(
      key: _kPinSessionKey,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    );
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> clearPinSession() async {
    await _storage.delete(
      key: _kPinSessionKey,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    );
  }
}
