// ════════════════════════════════════════════════════════════════════════════
// diagnostics_screen.dart — Firebase RTDB read/write diagnostics
// Accessible from Settings → 🔬 Firebase Diagnostics
// Tests every node in FirebaseConfig with a read AND a timed write/delete cycle.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/firebase_config.dart';
import '../core/services/firebase_service.dart';
import '../core/theme/app_colors.dart';

// ── Status enum ──────────────────────────────────────────────────────────────
enum _Status { idle, running, ok, error, empty }

// ── Per-node result ───────────────────────────────────────────────────────────
class _NodeResult {
  final String node;
  final String label;
  final String emoji;
  // Payload written during the WRITE test — must satisfy the node's .validate rule.
  // Each node has different required fields; a generic {diag,ts,node} fails them all.
  final Map<String, dynamic> scratchPayload;
  _Status readStatus  = _Status.idle;
  _Status writeStatus = _Status.idle;
  int? readMs;
  int? writeMs;
  int? recordCount;   // how many child records exist
  String? readError;
  String? writeError;

  _NodeResult({
    required this.node,
    required this.label,
    required this.emoji,
    required this.scratchPayload,
  });

  bool get allOk   => readStatus == _Status.ok  && writeStatus == _Status.ok;
  bool get hasError=> readStatus == _Status.error || writeStatus == _Status.error;
  bool get running => readStatus == _Status.running || writeStatus == _Status.running;
}

// ── All nodes to test ─────────────────────────────────────────────────────────
// Each scratchPayload satisfies the node's Firebase .validate rule so the
// diagnostic WRITE test passes without relaxing security rules.
List<_NodeResult> _buildNodes() {
  const ts = '__diag__';
  return [
    // settings: validate requires appName + businessName (written at node root, not child)
    _NodeResult(
      node: FirebaseConfig.nodeSettings, label: 'Settings', emoji: '⚙️',
      scratchPayload: {'appName': '__diag__', 'businessName': '__diag__'},
    ),
    // customers/$id: requires id, name, phone, createdAt
    _NodeResult(
      node: FirebaseConfig.nodeCustomers, label: 'Customers', emoji: '👥',
      scratchPayload: {'id': ts, 'name': ts, 'phone': ts, 'createdAt': ts},
    ),
    // transactions/$txId: requires id, customerId, customerName, date, createdAt, billedAmount
    _NodeResult(
      node: FirebaseConfig.nodeTransactions, label: 'Transactions', emoji: '📦',
      scratchPayload: {'id': ts, 'customerId': ts, 'customerName': ts,
        'date': ts, 'createdAt': ts, 'billedAmount': 0},
    ),
    // ledgerEntries/$id: requires id, customerId, txId, date, type, debit, credit, balance
    _NodeResult(
      node: FirebaseConfig.nodeLedgerEntries, label: 'Ledger Entries', emoji: '📒',
      scratchPayload: {'id': ts, 'customerId': ts, 'txId': ts,
        'date': ts, 'type': ts, 'debit': 0, 'credit': 0, 'balance': 0},
    ),
    // inventory: validate requires coolTotal, coolStock, petTotal, petStock (root node, not child)
    _NodeResult(
      node: FirebaseConfig.nodeInventory, label: 'Inventory', emoji: '🏭',
      scratchPayload: {'coolTotal': 0, 'coolStock': 0, 'petTotal': 0, 'petStock': 0},
    ),
    // payments/$id: requires paymentId, txId, customerId, amount, mode, date, type
    _NodeResult(
      node: FirebaseConfig.nodePayments, label: 'Payments', emoji: '💳',
      scratchPayload: {'paymentId': ts, 'txId': ts, 'customerId': ts,
        'amount': 0, 'mode': ts, 'date': ts, 'type': ts},
    ),
    // transactionRevisions/$revId: requires revId, txId, revNumber, createdAt, editedBy
    _NodeResult(
      node: FirebaseConfig.nodeRevisions, label: 'TX Revisions', emoji: '🔁',
      scratchPayload: {'revId': ts, 'txId': ts, 'revNumber': 1,
        'createdAt': ts, 'editedBy': ts},
    ),
    // inventoryMovements/$invId: requires invId, type, coolDelta, petDelta, createdAt
    _NodeResult(
      node: FirebaseConfig.nodeInventoryMovements, label: 'Inventory Movements', emoji: '📊',
      scratchPayload: {'invId': ts, 'type': ts,
        'coolDelta': 0, 'petDelta': 0, 'createdAt': ts},
    ),
    // load_unload/$tripId: requires id, date, coolLoaded, petLoaded
    _NodeResult(
      node: FirebaseConfig.nodeLoadUnload, label: 'Load / Unload Trips', emoji: '🚛',
      scratchPayload: {'id': ts, 'date': ts, 'coolLoaded': 0, 'petLoaded': 0},
    ),
    // expenses/$id: requires id, amount, category, date
    _NodeResult(
      node: FirebaseConfig.nodeExpenses, label: 'Expenses', emoji: '🧾',
      scratchPayload: {'id': ts, 'amount': 0, 'category': ts, 'date': ts},
    ),
    // staff/$userId: requires id, name, isActive
    _NodeResult(
      node: FirebaseConfig.nodeStaff, label: 'Staff', emoji: '👷',
      scratchPayload: {'id': ts, 'name': ts, 'isActive': false},
    ),
    // auditLog/$auditId: requires id, type, description, performedBy, createdAt
    _NodeResult(
      node: FirebaseConfig.nodeAuditLog, label: 'Audit Log', emoji: '🕵️',
      scratchPayload: {'id': ts, 'type': ts, 'description': ts,
        'performedBy': ts, 'createdAt': ts},
    ),
    // areas/$areaId: requires id, name
    _NodeResult(
      node: FirebaseConfig.nodeAreas, label: 'Areas', emoji: '📍',
      scratchPayload: {'id': ts, 'name': ts},
    ),
    // vehicles/$vehicleId: requires id, name, number
    _NodeResult(
      node: FirebaseConfig.nodeVehicles, label: 'Vehicles', emoji: '🚗',
      scratchPayload: {'id': ts, 'name': ts, 'number': ts},
    ),
  ];
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ════════════════════════════════════════════════════════════════════════════
class FirebaseDiagnosticsScreen extends ConsumerStatefulWidget {
  const FirebaseDiagnosticsScreen({super.key});
  @override
  ConsumerState<FirebaseDiagnosticsScreen> createState() => _DiagState();
}

class _DiagState extends ConsumerState<FirebaseDiagnosticsScreen> {
  final List<_NodeResult> _nodes = _buildNodes();
  bool _running = false;
  DateTime? _lastRun;
  int _passCount = 0;
  int _failCount = 0;

  // ── Run all nodes ───────────────────────────────────────────────────────────
  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _passCount = 0;
      _failCount = 0;
      for (final n in _nodes) {
        n.readStatus  = _Status.idle;
        n.writeStatus = _Status.idle;
        n.readMs = n.writeMs = n.recordCount = null;
        n.readError = n.writeError = null;
      }
    });

    for (final node in _nodes) {
      await _testNode(node);
    }

    setState(() {
      _running  = false;
      _lastRun  = DateTime.now();
      _passCount = _nodes.where((n) => n.allOk).length;
      _failCount = _nodes.where((n) => n.hasError).length;
    });
  }

  // ── Run a single node ───────────────────────────────────────────────────────
  Future<void> _testNode(_NodeResult node) async {
    // ── READ ────────────────────────────────────────────────────────────────
    setState(() => node.readStatus = _Status.running);
    try {
      final sw = Stopwatch()..start();
      final data = await FirebaseService.instance.readOnce(node.node);
      sw.stop();
      setState(() {
        node.readMs     = sw.elapsedMilliseconds;
        node.readStatus = _Status.ok;
        node.recordCount = data == null ? 0 : data.length;
      });
    } catch (e) {
      setState(() {
        node.readStatus = _Status.error;
        node.readError  = e.toString().split('\n').first;
      });
    }

    // ── WRITE (write a schema-valid scratch record, then delete it) ────────────
    // Uses node.scratchPayload which matches each node's .validate rule exactly.
    // Root-object nodes (inventory, settings) don't have per-child validation
    // so we write a harmless child flag and remove it immediately.
    setState(() => node.writeStatus = _Status.running);
    final isRootNode = node.node == FirebaseConfig.nodeInventory ||
        node.node == FirebaseConfig.nodeSettings;
    const scratchKey = '__diag__';
    try {
      final sw = Stopwatch()..start();
      if (isRootNode) {
        // Root nodes: write + delete a harmless child to confirm write access.
        await FirebaseService.instance.setChild(
            node.node, scratchKey, {'__diag': true});
        await FirebaseService.instance.removeChild(node.node, scratchKey);
      } else {
        // Collection nodes: write a schema-valid record then immediately delete it.
        await FirebaseService.instance.setChild(
            node.node, scratchKey, node.scratchPayload);
        await FirebaseService.instance.removeChild(node.node, scratchKey);
      }
      sw.stop();
      setState(() {
        node.writeMs     = sw.elapsedMilliseconds;
        node.writeStatus = _Status.ok;
      });
    } catch (e) {
      try { await FirebaseService.instance.removeChild(node.node, scratchKey); } catch (_) {}
      setState(() {
        node.writeStatus = _Status.error;
        node.writeError  = e.toString().split('\n').first;
      });
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Firebase Diagnostics',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (_lastRun != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Re-run', style: GoogleFonts.inter(fontSize: 13)),
                onPressed: _running ? null : _runAll,
              ),
            ),
        ],
      ),
      body: Column(children: [

        // ── Summary bar ─────────────────────────────────────────────────────
        _SummaryBar(
          nodes:      _nodes,
          running:    _running,
          lastRun:    _lastRun,
          passCount:  _passCount,
          failCount:  _failCount,
          isDark:     isDark,
          primary:    primary,
          onRun:      _running ? null : _runAll,
        ),

        // ── Node list ───────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: _nodes.length,
            itemBuilder: (_, i) => _NodeCard(
              result:  _nodes[i],
              isDark:  isDark,
              primary: primary,
              onRun:   _running ? null : () => _testNode(_nodes[i]).then((_) {
                setState(() {
                  _passCount = _nodes.where((n) => n.allOk).length;
                  _failCount = _nodes.where((n) => n.hasError).length;
                });
              }),
            ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUMMARY BAR
// ════════════════════════════════════════════════════════════════════════════
class _SummaryBar extends StatelessWidget {
  final List<_NodeResult> nodes;
  final bool running;
  final DateTime? lastRun;
  final int passCount, failCount;
  final bool isDark;
  final Color primary;
  final VoidCallback? onRun;

  const _SummaryBar({
    required this.nodes, required this.running, required this.lastRun,
    required this.passCount, required this.failCount,
    required this.isDark, required this.primary, required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final okC       = AppColors.successColor(isDark);
    final errC      = AppColors.dangerColor(isDark);

    String statusLabel;
    Color  statusColor;
    IconData statusIcon;

    if (running) {
      statusLabel = 'Running tests…';
      statusColor = AppColors.warningColor(isDark);
      statusIcon  = Icons.sync_rounded;
    } else if (lastRun == null) {
      statusLabel = 'Tap Run All Tests to start';
      statusColor = AppColors.inkMuted;
      statusIcon  = Icons.info_outline_rounded;
    } else if (failCount == 0) {
      statusLabel = 'All ${nodes.length} nodes healthy';
      statusColor = okC;
      statusIcon  = Icons.check_circle_rounded;
    } else {
      statusLabel = '$failCount node${failCount > 1 ? 's' : ''} with errors';
      statusColor = errC;
      statusIcon  = Icons.error_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
          blurRadius: 10, offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Status row
        Row(children: [
          if (running)
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
              strokeWidth: 2, color: statusColor))
          else
            Icon(statusIcon, size: 18, color: statusColor),
          const SizedBox(width: 8),
          Expanded(child: Text(statusLabel,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                  color: statusColor))),
          if (lastRun != null)
            Text('${_elapsed(lastRun!)} ago',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
        ]),

        // KPI row
        if (lastRun != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            _Kpi('Passed',  '$passCount/${nodes.length}', okC,  isDark),
            const SizedBox(width: 8),
            _Kpi('Failed',  '$failCount',                 failCount > 0 ? errC : okC, isDark),
            const SizedBox(width: 8),
            _Kpi('Nodes',   '${nodes.length}',            primary, isDark),
          ]),
        ],

        const SizedBox(height: 14),

        // Run button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onRun,
            icon: Icon(running ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
                size: 16),
            label: Text(running ? 'Running…' : 'Run All Tests',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),

        // Legend
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Legend('Read', Icons.download_rounded, primary, isDark),
          const SizedBox(width: 16),
          _Legend('Write', Icons.upload_rounded, AppColors.warningColor(isDark), isDark),
          const SizedBox(width: 16),
          _Legend('OK',   Icons.check_circle_rounded, okC, isDark),
          const SizedBox(width: 16),
          _Legend('Error',Icons.error_rounded, errC, isDark),
        ]),

        // DB info
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.storage_rounded, size: 13, color: AppColors.inkMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(
              '${FirebaseConfig.projectId} · ${FirebaseConfig.databaseUrl}',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.inkMuted),
              overflow: TextOverflow.ellipsis,
            )),
            GestureDetector(
              onTap: () => Clipboard.setData(
                  ClipboardData(text: FirebaseConfig.databaseUrl)),
              child: const Icon(Icons.copy_rounded, size: 13, color: AppColors.inkMuted),
            ),
          ]),
        ),
      ]),
    );
  }

  String _elapsed(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _Kpi(this.label, this.value, this.color, this.isDark);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 18,
          fontWeight: FontWeight.w800, color: color)),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  ));
}

class _Legend extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _Legend(this.label, this.icon, this.color, this.isDark);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: color),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
// NODE CARD
// ════════════════════════════════════════════════════════════════════════════
class _NodeCard extends StatelessWidget {
  final _NodeResult result;
  final bool isDark;
  final Color primary;
  final VoidCallback? onRun;

  const _NodeCard({
    required this.result, required this.isDark,
    required this.primary, required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final okC   = AppColors.successColor(isDark);
    final errC  = AppColors.dangerColor(isDark);
    final warnC = AppColors.warningColor(isDark);

    Color cardBorderColor;
    if (result.running) {
      cardBorderColor = warnC.withValues(alpha: 0.5);
    } else if (result.hasError) {
      cardBorderColor = errC.withValues(alpha: 0.4);
    } else if (result.allOk) {
      cardBorderColor = okC.withValues(alpha: 0.3);
    } else {
      cardBorderColor = isDark ? AppColors.separatorDark : AppColors.separator;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorderColor, width: result.hasError ? 1.5 : 1),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header: emoji + label + node path + retry button ─────────────
          Row(children: [
            Text(result.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(result.label,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.inkDark : AppColors.ink)),
              Text(result.node,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.inkMuted)),
            ])),
            // Record count badge
            if (result.recordCount != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${result.recordCount} records',
                    style: GoogleFonts.inter(fontSize: 10,
                        fontWeight: FontWeight.w700, color: primary)),
              ),
            // Retry single node
            GestureDetector(
              onTap: onRun,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: result.running
                    ? SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: warnC))
                    : const Icon(Icons.refresh_rounded, size: 14, color: AppColors.inkMuted),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // ── Read / Write pill row ─────────────────────────────────────────
          Row(children: [
            Expanded(child: _OpPill(
              op:     'READ',
              icon:   Icons.download_rounded,
              status: result.readStatus,
              ms:     result.readMs,
              error:  result.readError,
              isDark: isDark,
            )),
            const SizedBox(width: 8),
            Expanded(child: _OpPill(
              op:     'WRITE',
              icon:   Icons.upload_rounded,
              status: result.writeStatus,
              ms:     result.writeMs,
              error:  result.writeError,
              isDark: isDark,
            )),
          ]),

          // ── Error detail ──────────────────────────────────────────────────
          if (result.readError != null || result.writeError != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: errC.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: errC.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (result.readError != null) ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('READ  ', style: GoogleFonts.jetBrainsMono(fontSize: 10,
                        fontWeight: FontWeight.w800, color: errC)),
                    Expanded(child: Text(result.readError!,
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: errC),
                        maxLines: 3, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                if (result.writeError != null) ...[
                  if (result.readError != null) const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('WRITE ', style: GoogleFonts.jetBrainsMono(fontSize: 10,
                        fontWeight: FontWeight.w800, color: errC)),
                    Expanded(child: Text(result.writeError!,
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: errC),
                        maxLines: 3, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Operation pill (READ / WRITE with status + latency) ──────────────────────
class _OpPill extends StatelessWidget {
  final String op;
  final IconData icon;
  final _Status status;
  final int? ms;
  final String? error;
  final bool isDark;

  const _OpPill({
    required this.op, required this.icon, required this.status,
    required this.isDark, this.ms, this.error,
  });

  @override
  Widget build(BuildContext context) {
    final okC   = AppColors.successColor(isDark);
    final errC  = AppColors.dangerColor(isDark);
    final warnC = AppColors.warningColor(isDark);

    Color bg, border, textC, iconC;
    Widget statusWidget;

    switch (status) {
      case _Status.idle:
        bg = isDark ? AppColors.surface2Dark : AppColors.surface2;
        border = isDark ? AppColors.separatorDark : AppColors.separator;
        textC = AppColors.inkMuted;
        iconC = AppColors.inkMuted;
        statusWidget = Text('—', style: GoogleFonts.jetBrainsMono(
            fontSize: 12, color: AppColors.inkMuted));

      case _Status.running:
        bg = warnC.withValues(alpha: 0.08);
        border = warnC.withValues(alpha: 0.3);
        textC = warnC;
        iconC = warnC;
        statusWidget = SizedBox(width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: warnC));

      case _Status.ok:
        bg     = okC.withValues(alpha: 0.08);
        border = okC.withValues(alpha: 0.25);
        textC  = okC;
        iconC  = okC;
        statusWidget = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_rounded, size: 12, color: okC),
          const SizedBox(width: 3),
          Text(ms != null ? '${ms}ms' : 'OK',
              style: GoogleFonts.jetBrainsMono(fontSize: 11,
                  fontWeight: FontWeight.w700, color: okC)),
        ]);

      case _Status.error:
        bg     = errC.withValues(alpha: 0.08);
        border = errC.withValues(alpha: 0.3);
        textC  = errC;
        iconC  = errC;
        statusWidget = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.close_rounded, size: 12, color: errC),
          const SizedBox(width: 3),
          Text('FAIL', style: GoogleFonts.jetBrainsMono(fontSize: 11,
              fontWeight: FontWeight.w700, color: errC)),
        ]);

      case _Status.empty:
        bg = isDark ? AppColors.surface2Dark : AppColors.surface2;
        border = isDark ? AppColors.separatorDark : AppColors.separator;
        textC = AppColors.inkMuted;
        iconC = AppColors.inkMuted;
        statusWidget = Text('empty', style: GoogleFonts.jetBrainsMono(
            fontSize: 11, color: AppColors.inkMuted));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: iconC),
        const SizedBox(width: 5),
        Text(op, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800,
            color: textC)),
        const Spacer(),
        statusWidget,
      ]),
    );
  }
}
