// ════════════════════════════════════════════════════════════════════════════
// firebase_config.dart  — credentials via --dart-define (Web + Mobile safe)
//
// ⚠️  ADD THIS FILE TO .gitignore  ⚠️
//     echo "lib/core/services/firebase_config.dart" >> .gitignore
//
// WHY NOT .env:
//   flutter_dotenv reads files at runtime — not supported on Flutter Web
//   because the web build doesn't have filesystem access.
//
// HOW TO USE (--dart-define works on ALL platforms including Web):
//
//   Development:
//     flutter run \
//       --dart-define=FIREBASE_API_KEY=AIzaSy... \
//       --dart-define=FIREBASE_AUTH_DOMAIN=project.firebaseapp.com \
//       --dart-define=FIREBASE_DATABASE_URL=https://project-rtdb.firebaseio.com \
//       --dart-define=FIREBASE_PROJECT_ID=your-project-id \
//       --dart-define=FIREBASE_STORAGE_BUCKET=project.firebasestorage.app \
//       --dart-define=FIREBASE_MESSAGING_SENDER_ID=123456789 \
//       --dart-define=FIREBASE_APP_ID=1:123:web:abc
//
//   Or save to a file (dart_defines.env) and use:
//     flutter run --dart-define-from-file=dart_defines.env
//
//   Production build:
//     flutter build web --dart-define-from-file=dart_defines.env
//
//   dart_defines.env format (JSON — NOT .env format):
//   {
//     "FIREBASE_API_KEY": "AIzaSy...",
//     "FIREBASE_AUTH_DOMAIN": "project.firebaseapp.com",
//     "FIREBASE_DATABASE_URL": "https://project-rtdb.firebaseio.com",
//     "FIREBASE_PROJECT_ID": "your-project-id",
//     "FIREBASE_STORAGE_BUCKET": "project.firebasestorage.app",
//     "FIREBASE_MESSAGING_SENDER_ID": "123456789",
//     "FIREBASE_APP_ID": "1:123:web:abc"
//   }
//
//   Add dart_defines.env to .gitignore too:
//     echo "dart_defines.env" >> .gitignore
//
// NOTE ON WEB SECURITY:
//   Firebase Web API keys are visible in the compiled JS — this is by design.
//   Protection comes from:
//     1. HTTP referrer restrictions in Google Cloud Console (most important)
//     2. Firebase Security Rules (auth != null for all reads/writes)
//   Never put server-side service account keys in client code.
// ════════════════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseConfig {
  FirebaseConfig._();

  // ── Read from --dart-define at compile time ───────────────────────────────
  // These are baked into the binary at build time — not readable as plain text
  // in the compiled output (unlike a .env file bundled as an asset).
  static const _apiKeyRaw = String.fromEnvironment('FIREBASE_API_KEY');
  static const _apiKeyAndroidRaw =
      String.fromEnvironment('FIREBASE_API_KEY_ANDROID');
  static const _authDomainRaw = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _databaseUrlRaw =
      String.fromEnvironment('FIREBASE_DATABASE_URL');
  static const _projectIdRaw = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _storageRaw = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _senderIdRaw =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _appIdRaw = String.fromEnvironment('FIREBASE_APP_ID');
  static const _appIdWebRaw = String.fromEnvironment('FIREBASE_APP_ID_WEB');
  static const _appIdAndroidRaw =
      String.fromEnvironment('FIREBASE_APP_ID_ANDROID');

  // ── Getters with Trimming (Sanitize values from CI/CD) ──────────────────
  // Trimming and cleaning is crucial because CI/CD secrets can sometimes
  // contain hidden whitespace, backticks, or quotes which break initialization.
  static String _clean(String s) =>
      s.trim().replaceAll('`', '').replaceAll('"', '').replaceAll("'", '');

  static String get apiKey => _clean(_apiKeyRaw);
  static String get apiKeyAndroid => _clean(_apiKeyAndroidRaw);
  static String get authDomain => _clean(_authDomainRaw);

  static String get databaseUrl {
    var url = _clean(_databaseUrlRaw);
    // Remove trailing slash if present (can cause "Invalid token in path" error)
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static String get projectId => _clean(_projectIdRaw);
  static String get storageBucket => _clean(_storageRaw);
  static String get senderId => _clean(_senderIdRaw);

  /// App ID with fallback: looks for FIREBASE_APP_ID then FIREBASE_APP_ID_WEB
  static String get appId {
    final id = _clean(_appIdRaw);
    if (id.isNotEmpty) return id;
    return _clean(_appIdWebRaw);
  }

  static String get apiKeyForPlatform {
    if (kIsWeb) return apiKey;
    return apiKeyAndroid.isNotEmpty ? apiKeyAndroid : apiKey;
  }

  /// Android App ID with fallback
  static String get appIdAndroid {
    final id = _clean(_appIdAndroidRaw);
    if (id.isNotEmpty) return id;
    // Fallback to generic App ID if specific Android one is missing
    return _clean(_appIdRaw);
  }

  /// Returns true if credentials were supplied at build time.
  /// Call this in main() to catch missing --dart-define flags early.
  static bool get isConfigured =>
      (apiKey.isNotEmpty || apiKeyAndroid.isNotEmpty) &&
      projectId.isNotEmpty &&
      databaseUrl.isNotEmpty;

  // ── RTDB node paths ───────────────────────────────────────────────────────
  static const nodeSettings = 'settings';
  static const nodeStaff = 'staff';
  static const nodeCustomers = 'customers';
  static const nodeTransactions = 'transactions';
  static const nodeInventory = 'inventory';
  static const nodeExpenses = 'expenses';
  static const nodeLoadUnload = 'load_unload';
  static const nodeAuditLog = 'auditLog';
  static const nodeAreas = 'areas';
  static const nodeVehicles = 'vehicles';
  static const nodeLedgerEntries = 'ledgerEntries';
  static const nodeRevisions = 'transactionRevisions';
  static const nodeInventoryMovements = 'inventoryMovements';
  static const nodePayments = 'payments';

  // ── FirebaseOptions ───────────────────────────────────────────────────────
  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: apiKeyForPlatform,
        appId: kIsWeb ? appId : appIdAndroid,
        messagingSenderId: senderId,
        projectId: projectId,
        authDomain: kIsWeb ? authDomain : null,
        databaseURL: databaseUrl,
        storageBucket: storageBucket,
      );
}
