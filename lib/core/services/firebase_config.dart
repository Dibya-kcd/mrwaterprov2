// ════════════════════════════════════════════════════════════════════════════
// firebase_config.dart  — credentials via --dart-define (Web + Mobile safe)
// FIX v2: added nodeDayLogs constant (separate from nodeLoadUnload).
//         DayLogNotifier previously watched nodeLoadUnload — same as
//         LoadUnloadNotifier — causing schema conflicts between TripEntry
//         and DayLog records stored under the same node.
// ════════════════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseConfig {
  FirebaseConfig._();

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

  static String _clean(String s) =>
      s.trim().replaceAll('`', '').replaceAll('"', '').replaceAll("'", '');

  static String get apiKey => _clean(_apiKeyRaw);
  static String get apiKeyAndroid => _clean(_apiKeyAndroidRaw);
  static String get authDomain => _clean(_authDomainRaw);

  static String get databaseUrl {
    var url = _clean(_databaseUrlRaw);
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  static String get projectId => _clean(_projectIdRaw);
  static String get storageBucket => _clean(_storageRaw);
  static String get senderId => _clean(_senderIdRaw);

  static String get appId {
    final id = _clean(_appIdRaw);
    if (id.isNotEmpty) return id;
    return _clean(_appIdWebRaw);
  }

  static String get apiKeyForPlatform {
    if (kIsWeb) return apiKey;
    return apiKeyAndroid.isNotEmpty ? apiKeyAndroid : apiKey;
  }

  static String get appIdAndroid {
    final id = _clean(_appIdAndroidRaw);
    if (id.isNotEmpty) return id;
    return _clean(_appIdRaw);
  }

  static bool get isConfigured =>
      (apiKey.isNotEmpty || apiKeyAndroid.isNotEmpty) &&
      projectId.isNotEmpty &&
      databaseUrl.isNotEmpty;

  // ── RTDB node paths ───────────────────────────────────────────────────────
  static const nodeSettings         = 'settings';
  static const nodeStaff            = 'staff';
  static const nodeCustomers        = 'customers';
  static const nodeTransactions     = 'transactions';
  static const nodeInventory        = 'inventory';
  static const nodeExpenses         = 'expenses';
  static const nodeLoadUnload       = 'load_unload';       // TripEntry records (UUID-keyed)
  static const nodeDayLogs          = 'day_logs';          // FIX: DayLog records (date-keyed)
  static const nodeAuditLog         = 'auditLog';
  static const nodeAreas            = 'areas';
  static const nodeVehicles         = 'vehicles';
  static const nodeLedgerEntries    = 'ledgerEntries';
  static const nodeRevisions        = 'transactionRevisions';
  static const nodeInventoryMovements = 'inventoryMovements';
  static const nodePayments         = 'payments';

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
