// ════════════════════════════════════════════════════════════════════════════
// firebase_service.dart  — Centralised Firebase RTDB read / write layer
// All providers call through here — screens never touch FirebaseDatabase directly.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_config.dart';
import 'company_session.dart';

// ── Deep-cast helper ──────────────────────────────────────────────────────────
// Flutter Web Firebase returns LinkedMap<Object?, Object?> instead of
// Map<String, dynamic>. A shallow Map<String, dynamic>.from() only converts
// the top level — nested maps and lists remain as LinkedMap<Object?, Object?>
// and cause TypeErrors in every fromJson method that reads nested fields
// (e.g. editHistory entries inside a JarTransaction → transaction disappears).
// _deepCast() recursively converts the entire tree to properly typed Dart objects.
Map<String, dynamic> _deepCast(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _deepCastValue(v)));
  }
  return {};
}

dynamic _deepCastValue(dynamic v) {
  if (v is Map)  return _deepCast(v);
  if (v is List) return v.map(_deepCastValue).toList();
  return v;
}

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  // Lazily-initialised database reference using the URL from FirebaseConfig
  late final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: FirebaseConfig.databaseUrl,
  );

  String get _companyId => CompanySession.companyId;

  /// Returns null if CompanySession not yet initialised OR if Firebase Auth
  /// is not currently authenticated.
  ///
  /// FIX: The original version only guarded against an empty companyId.
  /// When the SessionManager inactivity watchdog locks the app it clears the
  /// Riverpod PIN state but does NOT sign out Firebase — Firebase Auth stays
  /// signed in. However, any async write that was in-flight (e.g. a user tapped
  /// "Submit Load" a split second before the timeout fired) can still reach this
  /// method after the lock. On web, the RTDB security rules require auth.uid to
  /// match the company ID. If the browser tab was backgrounded long enough that
  /// the Firebase Auth token expired (tokens last 1 hour), the next write gets
  /// permission_denied even though currentUser != null (the SDK hasn't refreshed
  /// the token yet). Returning null here silently drops the write — the user will
  /// see the form still open (they were locked out mid-save) and can re-enter
  /// after unlocking rather than getting a silent data-loss or a crash.
  DatabaseReference? _ref(String node) {
    if (_companyId.isEmpty) return null;          // CompanySession not ready
    if (FirebaseAuth.instance.currentUser == null) return null; // not authenticated
    return _db.ref('companies/$_companyId/$node');
  }

  // ── Generic helpers ───────────────────────────────────────────────────────

  /// Read a node once and return its value as a Map, or null if missing/uninit.
  Future<Map<String, dynamic>?> readOnce(String node) async {
    final ref = _ref(node);
    if (ref == null) return null;          // CompanySession not ready yet
    final snap = await ref.get();
    if (!snap.exists || snap.value == null) return null;
    return _deepCast(snap.value);
  }

  /// Stream every change to a node as a Map.
  ///
  /// If CompanySession is not yet initialised, this method retries every 200ms
  /// until it is, then subscribes to Firebase.  This means ALL providers that
  /// call watch() in their constructors will automatically get live data once
  /// CompanySession.init() is called — no manual reinit() needed.
  Stream<Map<String, dynamic>?> watch(String node) {
    // If already ready, subscribe immediately
    final ref = _ref(node);
    if (ref != null) {
      return ref.onValue.map((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) return null;
        return _deepCast(event.snapshot.value);
      });
    }

    // Not ready yet — use StreamController that waits for CompanySession
    final controller = StreamController<Map<String, dynamic>?>.broadcast();
    _waitAndSubscribe(node, controller);
    return controller.stream;
  }

  /// Polls every 200ms until CompanySession is ready, then subscribes.
  void _waitAndSubscribe(String node,
      StreamController<Map<String, dynamic>?> controller) {
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final ref = _ref(node);
      if (ref == null) return; // still not ready, keep polling
      timer.cancel();
      if (controller.isClosed) return;
      ref.onValue.listen(
        (event) {
          if (controller.isClosed) return;
          if (!event.snapshot.exists || event.snapshot.value == null) {
            controller.add(null);
          } else {
            controller.add(_deepCast(event.snapshot.value));
          }
        },
        onError: (e) { if (!controller.isClosed) controller.addError(e); },
        onDone:  ()  { if (!controller.isClosed) controller.close(); },
      );
    });
  }

  /// Write (set) a whole node. No-op if not initialised.
  Future<void> write(String node, Map<String, dynamic> data) async {
    final ref = _ref(node);
    if (ref == null) return;
    await ref.set(data);
  }

  /// Merge-update fields inside a node (PATCH semantics). No-op if not init.
  Future<void> update(String node, Map<String, dynamic> data) async {
    final ref = _ref(node);
    if (ref == null) return;
    await ref.update(data);
  }

  /// Write a single child key inside a node. No-op if not initialised.
  Future<void> setChild(String node, String childId, Map<String, dynamic> data) async {
    final ref = _ref(node);
    if (ref == null) return;
    await ref.child(childId).set(data);
  }

  /// Remove a single child. No-op if not initialised.
  Future<void> removeChild(String node, String childId) async {
    final ref = _ref(node);
    if (ref == null) return;
    await ref.child(childId).remove();
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> readSettings() =>
      readOnce(FirebaseConfig.nodeSettings);

  Future<void> writeSettings(Map<String, dynamic> data) =>
      write(FirebaseConfig.nodeSettings, data);

  // ── Inventory ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> readInventory() =>
      readOnce(FirebaseConfig.nodeInventory);

  Future<void> writeInventory(Map<String, dynamic> data) =>
      write(FirebaseConfig.nodeInventory, data);

  Stream<Map<String, dynamic>?> watchInventory() =>
      watch(FirebaseConfig.nodeInventory);

  // ── Customers ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> readCustomers() =>
      readOnce(FirebaseConfig.nodeCustomers);

  Future<void> setCustomer(String id, Map<String, dynamic> data) =>
      setChild(FirebaseConfig.nodeCustomers, id, data);

  Stream<Map<String, dynamic>?> watchCustomers() =>
      watch(FirebaseConfig.nodeCustomers);

  // ── Transactions ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> readTransactions() =>
      readOnce(FirebaseConfig.nodeTransactions);

  Future<void> setTransaction(String id, Map<String, dynamic> data) =>
      setChild(FirebaseConfig.nodeTransactions, id, data);

  Future<void> removeTransaction(String id) =>
      removeChild(FirebaseConfig.nodeTransactions, id);

  Stream<Map<String, dynamic>?> watchTransactions() =>
      watch(FirebaseConfig.nodeTransactions);

  // ── Staff ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> readStaff() =>
      readOnce(FirebaseConfig.nodeStaff);

  Future<void> setStaff(String id, Map<String, dynamic> data) =>
      setChild(FirebaseConfig.nodeStaff, id, data);

  Future<void> removeStaff(String id) =>
      removeChild(FirebaseConfig.nodeStaff, id);

  // ── Expenses ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> readExpenses() =>
      readOnce(FirebaseConfig.nodeExpenses);

  Future<void> setExpense(String id, Map<String, dynamic> data) =>
      setChild(FirebaseConfig.nodeExpenses, id, data);

  Future<void> removeExpense(String id) =>
      removeChild(FirebaseConfig.nodeExpenses, id);

  // ── Audit ─────────────────────────────────────────────────────────────────
  Future<void> appendAudit(String id, Map<String, dynamic> data) =>
      setChild(FirebaseConfig.nodeAuditLog, id, data);

  // ── Diagnostics ──────────────────────────────────────────────────────────
  // Used only by DiagnosticsScreen — returns a DiagResult per node/field.

  /// Attempt a test read on a path; returns latency in ms or an error string.
  Future<DiagResult> testRead(String path) async {
    final sw = Stopwatch()..start();
    try {
      await _db.ref(path).get();
      sw.stop();
      return DiagResult.ok(path, sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      return DiagResult.error(path, e.toString());
    }
  }

  /// Attempt a test write then immediately delete on a scratch path.
  Future<DiagResult> testWrite(String path) async {
    final testPath = '$path/__diag_test__';
    final sw = Stopwatch()..start();
    try {
      await _db.ref(testPath).set({'ts': DateTime.now().toIso8601String()});
      await _db.ref(testPath).remove();
      sw.stop();
      return DiagResult.ok(path, sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      return DiagResult.error(path, e.toString());
    }
  }
}

// ── Diagnostic result model ───────────────────────────────────────────────────
class DiagResult {
  final String path;
  final bool success;
  final int? latencyMs;
  final String? error;

  const DiagResult._({
    required this.path,
    required this.success,
    this.latencyMs,
    this.error,
  });

  factory DiagResult.ok(String path, int latencyMs) =>
      DiagResult._(path: path, success: true, latencyMs: latencyMs);

  factory DiagResult.error(String path, String error) =>
      DiagResult._(path: path, success: false, error: error);
}
