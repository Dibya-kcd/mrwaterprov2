import 'package:firebase_auth/firebase_auth.dart';

/// Global company session for the current Firebase owner identity.
///
/// The app uses this session as the identity anchor for Firestore and
/// Realtime Database company-scoped reads and writes.
class CompanySession {
  static String? _companyId;
  static String? _companyName;

  static String get companyId => _companyId ?? '';
  static String get companyName => _companyName ?? '';
  static bool get isLoggedIn => _companyId != null && _companyId!.isNotEmpty;

  static void init(String uid, {String? name}) {
    _companyId = uid;
    _companyName = name;
  }

  static Future<void> firebaseSignOut() async {
    await FirebaseAuth.instance.signOut();
    _companyId = null;
    _companyName = null;
  }
}
