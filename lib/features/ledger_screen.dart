import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LEDGER SCREEN  — per-customer chronological ledger with inline editing
// ══════════════════════════════════════════════════════════════════════════════

/// Entry point — pass a customerId or open as full page.
class LedgerScreen extends ConsumerStatefulWidget {
  final String customerId;
  const LedgerScreen({super.key, required this.customerId});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  String _filter = 'All';
  // Track which date groups are expanded. Today always starts expanded.
  final Set<String> _expandedDates = {};
  bool _initialised = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTx = ref.watch(transactionsProvider);
    final custs = ref.watch(customersProvider);
    final Customer? cust = custs.cast<Customer?>().firstWhere(
      (c) => c!.id == widget.customerId, orElse: () => null);

    if (cust == null) {
      return const Scaffold(body: Center(child: Text('Customer not found')));
    }

    // All txns for this customer, newest first
    final raw = allTx.where((t) => t.customerId == widget.customerId).toList()
      ..sort((a, b) {
        final dc = b.date.compareTo(a.date);
        return dc != 0 ? dc : b.createdAt.compareTo(a.createdAt);
      });

    final filtered = raw.where((t) => switch (_filter) {
      'Deliveries' => t.coolDelivered > 0 || t.petDelivered > 0,
      'Returns'    => t.coolReturned > 0 || t.petReturned > 0,
      'Payments'   => t.amountCollected > 0 && t.coolDelivered == 0 && t.petDelivered == 0,
      'Unpaid'     => t.balance > 0,
      'Edited'     => t.editHistory.isNotEmpty,
      _            => true,
    }).toList();

    // Running balance — computed oldest→newest over ALL txns (not filtered)
    final ordered = [...raw]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final Map<String, double> runningBalance = {};
    double rb = 0.0;
    for (final t in ordered) {
      rb -= (t.billedAmount - t.amountCollected);
      runningBalance[t.id] = rb;
    }

    // Group filtered txns by date (yyyy-MM-dd), newest date first
    final Map<String, List<JarTransaction>> byDate = {};
    for (final t in filtered) {
      byDate.putIfAbsent(t.date, () => []).add(t);
    }
    final sortedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    // Auto-expand today and the most recent date on first load
    if (!_initialised && sortedDates.isNotEmpty) {
      _initialised = true;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _expandedDates.add(sortedDates.first); // always expand latest
      if (sortedDates.contains(today)) _expandedDates.add(today);
    }

    // Build flat item list: [header, ...cards] per group
    // Items: ('header', date) | ('entry', tx)
    final items = <({String kind, String? date, JarTransaction? tx})>[];
    for (final date in sortedDates) {
      items.add((kind: 'header', date: date, tx: null));
      if (_expandedDates.contains(date)) {
        for (final tx in byDate[date]!) {
          items.add((kind: 'entry', date: date, tx: tx));
        }
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        _LedgerHeader(cust: cust, isDark: isDark),

        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Wrap(
            spacing: 6, runSpacing: 6,
            children: ['All', 'Deliveries', 'Returns', 'Payments', 'Unpaid', 'Edited']
                .map((f) => _FilterChip(
                      label: f, active: f == _filter,
                      onTap: () => setState(() => _filter = f),
                    ))
                .toList(),
          ),
        ),

        _DrCrSummaryBar(txns: filtered, isDark: isDark),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(transactionsProvider.notifier).refreshAll(ref),
            child: filtered.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(height: 300, child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.receipt_long_rounded, size: 56,
                            color: AppColors.inkMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('No entries',
                            style: GoogleFonts.inter(color: AppColors.inkMuted, fontSize: 15)),
                      ]),
                    )),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      if (item.kind == 'header') {
                        final date   = item.date!;
                        final isOpen = _expandedDates.contains(date);
                        final count  = byDate[date]!.length;
                        return _DateGroupHeader(
                          date: date,
                          count: count,
                          isExpanded: isOpen,
                          isDark: isDark,
                          onTap: () => setState(() {
                            if (isOpen) {
                              _expandedDates.remove(date);
                            } else {
                              _expandedDates.add(date);
                            }
                          }),
                        );
                      }
                      final tx = item.tx!;
                      return _LedgerEntry(
                        tx: tx,
                        runningBalance: runningBalance[tx.id] ?? 0,
                        isDark: isDark,
                        onEdit: () => _openEditor(ctx, tx),
                        onCollect: tx.balance > 0
                            ? () => _collectPayment(ctx, tx)
                            : null,
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }

  Future<void> _openEditor(BuildContext ctx, JarTransaction tx) async {
    await showMrSheet(ctx,
      title: '✏️ Edit Ledger Entry',
      builder: (_) => LedgerEditor(tx: tx),
    );
  }

  Future<void> _collectPayment(BuildContext ctx, JarTransaction tx) async {
    await showMrSheet(ctx,
      title: '💵 Collect Payment',
      builder: (_) => _CollectPaymentSheet(tx: tx),
    );
  }
}

// ── Date Group Header ─────────────────────────────────────────────────────────
class _DateGroupHeader extends StatelessWidget {
  final String date;
  final int count;
  final bool isExpanded, isDark;
  final VoidCallback onTap;
  const _DateGroupHeader({required this.date, required this.count,
      required this.isExpanded, required this.isDark, required this.onTap});

  String _label() {
    try {
      final d     = DateTime.parse(date);
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day   = DateTime(d.year, d.month, d.day);
      if (day == today) return 'Today';
      if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
      return DateFormat('EEE, dd MMM yyyy').format(d);
    } catch (_) { return date; }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isToday = _label() == 'Today';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isToday
              ? primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.surface2Dark : AppColors.surface2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isToday
                ? primary.withValues(alpha: 0.25)
                : (isDark ? AppColors.separatorDark : AppColors.separator),
          ),
        ),
        child: Row(children: [
          Icon(
            isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
            size: 18,
            color: isToday ? primary : AppColors.inkMuted,
          ),
          const SizedBox(width: 6),
          Text(_label(), style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: isToday ? primary : (isDark ? AppColors.inkDark : AppColors.ink))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: (isToday ? primary : AppColors.inkMuted).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count txn', style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: isToday ? primary : AppColors.inkMuted)),
          ),
        ]),
      ),
    );
  }
}

// ── DR / CR Summary Bar ──────────────────────────────────────────────────────
class _DrCrSummaryBar extends StatelessWidget {
  final List<JarTransaction> txns;
  final bool isDark;
  const _DrCrSummaryBar({required this.txns, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final totalDr = txns.fold(0.0, (s, t) => s + t.billedAmount);
    final totalCr = txns.fold(0.0, (s, t) => s + t.amountCollected);
    // net > 0 → customer has advance; net < 0 → customer owes
    final net  = totalCr - totalDr;
    final netC = net >= 0 ? AppColors.successColor(isDark) : AppColors.dangerColor(isDark);
    final netLabel = net >= 0 ? 'NET ADV' : 'NET DUE';
    // Show absolute amount — no confusing minus sign
    final netDisplay = '₹${net.abs().toInt()}';
    if (txns.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2Dark : AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
      ),
      child: Row(children: [
        _SumCell('BILLED', '₹${totalDr.toInt()}', AppColors.dangerColor(isDark)),
        _vDiv(isDark),
        _SumCell('COLLECTED', '₹${totalCr.toInt()}', AppColors.successColor(isDark)),
        _vDiv(isDark),
        _SumCell(netLabel, netDisplay, netC),
        _vDiv(isDark),
        _SumCell('TXN', '${txns.length}', AppColors.inkMuted),
      ]),
    );
  }

  Widget _vDiv(bool isDark) => Container(
      width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isDark ? AppColors.separatorDark : AppColors.separator);
}

class _SumCell extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumCell(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w800,
        color: AppColors.inkMuted, letterSpacing: 0.5)),
    const SizedBox(height: 2),
    FittedBox(fit: BoxFit.scaleDown,
      child: Text(value, style: GoogleFonts.jetBrainsMono(
          fontSize: 13, fontWeight: FontWeight.w800, color: color))),
  ]));
}

// ── Ledger Header — customer summary ─────────────────────────────────────────
class _LedgerHeader extends StatelessWidget {
  final Customer cust;
  final bool isDark;
  const _LedgerHeader({required this.cust, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final coolC   = AppColors.coolColor(isDark);
    final petC    = AppColors.petColor(isDark);
    final dangerC = AppColors.dangerColor(isDark);
    final okC     = AppColors.successColor(isDark);
    final balColor = cust.balance > 0 ? okC : cust.balance < 0 ? dangerC : AppColors.inkMuted;
    final balLabel = cust.balance > 0 ? 'Advance' : cust.balance < 0 ? 'Due' : 'Clear';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withValues(alpha: 0.10), primary.withValues(alpha: 0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Row 1: Avatar + name + balance
        Row(children: [
          CustomerAvatar(initials: cust.initials, size: 40),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cust.name,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            Text(
              cust.area.isNotEmpty ? '${cust.phone} · ${cust.area}' : cust.phone,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ])),
          const SizedBox(width: 8),
          // Balance badge — compact
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: balColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: balColor.withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(balLabel, style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w800, color: balColor, letterSpacing: 0.4)),
              if (cust.balance != 0)
                Text('₹${cust.balance.abs().toInt()}',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 16, fontWeight: FontWeight.w800, color: balColor)),
            ]),
          ),
        ]),

        const SizedBox(height: 10),

        // Row 2: jar balance chips — always fits any width
        Row(children: [
          Expanded(child: _JarChip(
            icon: CoolJarIcon(size: 13, color: coolC),
            label: 'Cool',
            count: cust.coolOut,
            color: coolC, isDark: isDark,
          )),
          const SizedBox(width: 8),
          Expanded(child: _JarChip(
            icon: PetJarIcon(size: 13, color: petC),
            label: 'PET',
            count: cust.petOut,
            color: petC, isDark: isDark,
          )),
        ]),
      ]),
    );
  }
}

class _JarChip extends StatelessWidget {
  final Widget icon;
  final String label;
  final int count;
  final Color color;
  final bool isDark;
  const _JarChip({required this.icon, required this.label, required this.count,
      required this.color, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: isDark ? AppColors.bgDark.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(children: [
      icon, const SizedBox(width: 6),
      Text('$count', style: GoogleFonts.jetBrainsMono(
          fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(width: 4),
      Expanded(child: Text(label, style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w600, color: color),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final activeColor = switch (label) {
      'Unpaid'  => AppColors.dangerColor(isDark),
      'Edited'  => AppColors.warningColor(isDark),
      'Returns' => AppColors.coolColor(isDark),
      'Payments'=> AppColors.successColor(isDark),
      _         => primary,
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? AppColors.surface2Dark : AppColors.surface2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? activeColor : (isDark ? AppColors.separatorDark : AppColors.separator),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? activeColor : AppColors.inkMuted)),
      ),
    );
  }
}

// ── Ledger Entry Card ─────────────────────────────────────────────────────────
class _LedgerEntry extends StatefulWidget {
  final JarTransaction tx;
  final double runningBalance;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback? onCollect;
  const _LedgerEntry({required this.tx, required this.runningBalance,
      required this.isDark, required this.onEdit, this.onCollect});

  @override
  State<_LedgerEntry> createState() => _LedgerEntryState();
}

class _LedgerEntryState extends State<_LedgerEntry> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tx      = widget.tx;
    final isDark  = widget.isDark;
    final coolC   = AppColors.coolColor(isDark);
    final petC    = AppColors.petColor(isDark);
    final hasHistory = tx.editHistory.isNotEmpty;

    final (entryColor, entryIcon, _) = _entryMeta(tx, isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasHistory
              ? AppColors.warningColor(isDark).withValues(alpha: 0.35)
              : (isDark ? AppColors.separatorDark : AppColors.separator),
          width: hasHistory ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: entryColor.withValues(alpha: isDark ? 0.04 : 0.03),
            blurRadius: 6, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Main tappable row ──────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

              // Left: coloured icon box
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: entryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(entryIcon, size: 17, color: entryColor),
              ),
              const SizedBox(width: 10),

              // Centre: title + time + flag + jar pills
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Title + edit flag on the right
                Row(children: [
                  Expanded(child: Text(_entryTitle(tx),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  // 🚩 Edit flag — tappable, shows history sheet
                  if (hasHistory) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showHistory(context, tx, isDark),
                      child: Tooltip(
                        message: 'Edited ${tx.editHistory.length}× — tap to view history',
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.warningColor(isDark).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.flag_rounded, size: 13,
                              color: AppColors.warningColor(isDark)),
                        ),
                      ),
                    ),
                  ],
                ]),

                const SizedBox(height: 2),

                // Time only (date is in group header)
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 10, color: AppColors.inkMuted),
                  const SizedBox(width: 3),
                  Text(_fmtTime(tx.createdAt),
                      style: GoogleFonts.inter(fontSize: 10,
                          color: AppColors.inkMuted.withValues(alpha: 0.8))),
                  // Event name if applicable
                  if (tx.deliveryType == 'event' &&
                      tx.eventName != null && tx.eventName!.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Flexible(child: Text('· ${tx.eventName}',
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.purple,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis)),
                  ],
                  // Note snippet
                  if (tx.note.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Flexible(child: Text('· ${tx.note}',
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ]),

                // Jar pills
                if (tx.coolDelivered > 0 || tx.petDelivered > 0 ||
                    tx.coolReturned  > 0 || tx.petReturned  > 0) ...[
                  const SizedBox(height: 5),
                  Wrap(spacing: 5, runSpacing: 3, children: [
                    if (tx.coolDelivered > 0)
                      _JarPill(icon: const CoolJarIcon(size: 10, color: Colors.white),
                          label: '↓${tx.coolDelivered}', bg: coolC),
                    if (tx.coolReturned > 0)
                      _JarPill(icon: CoolJarIcon(size: 10, color: coolC),
                          label: '↑${tx.coolReturned}',
                          bg: coolC.withValues(alpha: 0.15), textColor: coolC),
                    if (tx.petDelivered > 0)
                      _JarPill(icon: const PetJarIcon(size: 10, color: Colors.white),
                          label: '↓${tx.petDelivered}', bg: petC),
                    if (tx.petReturned > 0)
                      _JarPill(icon: PetJarIcon(size: 10, color: petC),
                          label: '↑${tx.petReturned}',
                          bg: petC.withValues(alpha: 0.15), textColor: petC),
                    if (tx.coolDamaged + tx.petDamaged > 0)
                      _JarPill(
                          icon: const Icon(Icons.warning_rounded, size: 10, color: Colors.white),
                          label: '⚠${tx.coolDamaged + tx.petDamaged}',
                          bg: AppColors.dangerColor(isDark)),
                  ]),
                ],
              ])),

              const SizedBox(width: 8),

              // Right: DR / CR + running balance
              _DrCrColumn(tx: tx, runningBalance: widget.runningBalance, isDark: isDark),
            ]),
          ),
        ),

        // ── Expanded detail panel ──────────────────────────────────────────
        if (_expanded) ...[
          Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _DetailRow('Payment mode', _modeLabel(tx.paymentMode)),
              if (tx.coolPrice > 0)    _DetailRow('Cool price', '₹${tx.coolPrice.toInt()}/jar'),
              if (tx.petPrice > 0)     _DetailRow('PET price',  '₹${tx.petPrice.toInt()}/jar'),
              if (tx.damageCharge > 0) _DetailRow('Damage',     '₹${tx.damageCharge.toInt()}'),
              if (tx.transportFee > 0) _DetailRow('Transport',  '₹${tx.transportFee.toInt()}'),
              if (tx.deliveryType == 'event' && tx.eventName != null)
                _DetailRow('Event', tx.eventName!),
              _DetailRow('Ref #', tx.id.substring(0, math.min(8, tx.id.length))),
              if (tx.updatedAt != null)
                _DetailRow('Last edited', _fmtTs(tx.updatedAt!)),

              const SizedBox(height: 10),

              Wrap(spacing: 8, runSpacing: 6, children: [
                _ActionChip(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: Theme.of(context).colorScheme.primary,
                  onTap: widget.onEdit,
                ),
                if (widget.onCollect != null)
                  _ActionChip(
                    icon: Icons.payments_rounded,
                    label: 'Collect ₹${tx.balance.toInt()}',
                    color: AppColors.successColor(isDark),
                    onTap: widget.onCollect!,
                  ),
                if (hasHistory)
                  _ActionChip(
                    icon: Icons.history_rounded,
                    label: 'History (${tx.editHistory.length})',
                    color: AppColors.warningColor(isDark),
                    onTap: () => _showHistory(context, tx, isDark),
                  ),
              ]),

              if (hasHistory) ...[
                const SizedBox(height: 8),
                ...tx.editHistory.take(2).map((h) => _HistoryChip(h: h, isDark: isDark)),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  void _showHistory(BuildContext ctx, JarTransaction tx, bool isDark) =>
      showMrSheet(ctx, title: '📋 Edit History',
          builder: (_) => _HistorySheet(tx: tx, isDark: isDark));

  /// Returns (color, icon, typeTag label) for this transaction.
  (Color, IconData, String) _entryMeta(JarTransaction tx, bool isDark) {
    final isPayment = tx.billedAmount == 0 && tx.amountCollected > 0;
    final isReturn  = tx.coolDelivered == 0 && tx.petDelivered == 0
                   && (tx.coolReturned > 0 || tx.petReturned > 0);
    if (isPayment && tx.paymentMode == 'advance') {
      return (AppColors.purple, Icons.savings_rounded, 'Advance');
    }
    if (isPayment) {
      return (AppColors.successColor(isDark), Icons.payments_rounded, 'Payment');
    }
    if (isReturn) {
      return (AppColors.coolColor(isDark), Icons.swap_vert_rounded, 'Return');
    }
    if (tx.deliveryType == 'event') {
      return (AppColors.purple, Icons.celebration_rounded, 'Event');
    }
    if (tx.coolDelivered > 0 || tx.petDelivered > 0) {
      return (Theme.of(context).colorScheme.primary, Icons.local_shipping_rounded, 'Daily');
    }
    return (AppColors.inkMuted, Icons.receipt_rounded, 'Txn');
  }

  String _entryTitle(JarTransaction tx) {
    final isPayment = tx.billedAmount == 0 && tx.amountCollected > 0;
    if (isPayment && tx.paymentMode == 'advance') {
      return 'Advance deposited';
    }
    if (isPayment) {
      return 'Payment received';
    }
    if (tx.deliveryType == 'event') {
      return tx.eventName?.isNotEmpty == true ? tx.eventName! : 'Event delivery';
    }
    if (tx.coolDelivered > 0 && tx.coolReturned > 0) {
      return 'Delivery & return';
    }
    if (tx.coolDelivered > 0 || tx.petDelivered > 0) {
      return 'Delivery';
    }
    if (tx.coolReturned  > 0 || tx.petReturned  > 0) {
      return 'Return';
    }
    return 'Transaction';
  }

  // ignore: unused_element
  String _fmtDate(String d) {
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d)); }
    catch (_) { return d; }
  }

  String _fmtTime(String ts) {
    try { return DateFormat('h:mm a').format(DateTime.parse(ts).toLocal()); }
    catch (_) { return ''; }
  }

  String _fmtTs(String ts) {
    try { return DateFormat('dd MMM, h:mm a').format(DateTime.parse(ts).toLocal()); }
    catch (_) { return ts; }
  }

  String _modeLabel(String m) => switch (m) {
    'cash'    => '💵 Cash',
    'upi'     => '📱 UPI',
    'bank'    => '🏦 Bank',
    'advance' => '💳 Advance',
    _         => m,
  };
}

/// Small action chip used in the expanded section.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

// ── Jar pill badge ────────────────────────────────────────────────────────────
class _JarPill extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color bg;
  final Color? textColor;
  const _JarPill({required this.icon, required this.label,
      required this.bg, this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      icon, const SizedBox(width: 4),
      Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700,
          color: textColor ?? Colors.white)),
    ]),
  );
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Flexible(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted),
          overflow: TextOverflow.ellipsis, maxLines: 1)),
      const SizedBox(width: 8),
      Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis, maxLines: 1),
    ]),
  );
}

class _HistoryChip extends StatelessWidget {
  final TxEditHistory h;
  final bool isDark;
  const _HistoryChip({required this.h, required this.isDark});

  @override
  Widget build(BuildContext context) {
    String ts;
    try { ts = DateFormat('dd MMM, hh:mm a').format(DateTime.parse(h.editedAt)); }
    catch (_) { ts = h.editedAt; }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warningColor(isDark).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.history_rounded, size: 12, color: AppColors.warningColor(isDark)),
        const SizedBox(width: 6),
        Expanded(child: Text(
          h.note.isNotEmpty ? '${h.note} · $ts' : 'Edited $ts',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        )),
        Text('by ${h.editedBy}',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted),
            overflow: TextOverflow.ellipsis, maxLines: 1),
      ]),
    );
  }
}

// ── Full history sheet ────────────────────────────────────────────────────────
class _HistorySheet extends StatelessWidget {
  final JarTransaction tx;
  final bool isDark;
  const _HistorySheet({required this.tx, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningColor(isDark).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warningColor(isDark)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Delivery date is preserved. Only amounts, jar counts and payment details can change.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.warningColor(isDark), height: 1.4),
          )),
        ]),
      ),
      const SizedBox(height: 16),

      // Current state
      _HistoryVersion(
        label: 'Current version',
        ts: tx.updatedAt ?? tx.createdAt,
        isLatest: true,
        isDark: isDark,
        cool: tx.coolDelivered, pet: tx.petDelivered,
        coolR: tx.coolReturned, petR: tx.petReturned,
        billed: tx.billedAmount, collected: tx.amountCollected,
        mode: tx.paymentMode,
      ),

      // Past versions
      ...tx.editHistory.map((h) => _HistoryVersion(
        label: h.note.isNotEmpty ? h.note : 'Previous version',
        ts: h.editedAt,
        isLatest: false,
        isDark: isDark,
        cool: h.coolDelivered, pet: h.petDelivered,
        coolR: h.coolReturned, petR: h.petReturned,
        billed: h.billedAmount, collected: h.amountCollected,
        mode: h.paymentMode,
      )),
    ]);
  }
}

class _HistoryVersion extends StatelessWidget {
  final String label, ts, mode;
  final bool isLatest, isDark;
  final int cool, pet, coolR, petR;
  final double billed, collected;
  const _HistoryVersion({required this.label, required this.ts, required this.isLatest,
      required this.isDark, required this.cool, required this.pet,
      required this.coolR, required this.petR, required this.billed,
      required this.collected, required this.mode});

  @override
  Widget build(BuildContext context) {
    final color = isLatest ? AppColors.successColor(isDark) : AppColors.inkMuted;
    String fmtTs;
    try { fmtTs = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(ts)); }
    catch (_) { fmtTs = ts; }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2Dark : AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 12,
              fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          Text(fmtTs, style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (cool > 0) _tag('Cool ↓$cool'),
          if (coolR > 0) _tag('Cool ↑$coolR'),
          if (pet > 0) _tag('PET ↓$pet'),
          if (petR > 0) _tag('PET ↑$petR'),
          _tag('₹${billed.toInt()} billed'),
          _tag('₹${collected.toInt()} paid', green: true),
          _tag(mode),
        ]),
      ]),
    );
  }

  Widget _tag(String label, {bool green = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (green ? AppColors.success : AppColors.inkMuted).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
        color: green ? AppColors.success : AppColors.inkMuted)),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// LEDGER EDITOR — inline editing of any transaction field
// ══════════════════════════════════════════════════════════════════════════════
class LedgerEditor extends ConsumerStatefulWidget {
  final JarTransaction tx;
  const LedgerEditor({super.key, required this.tx});

  @override
  ConsumerState<LedgerEditor> createState() => _LedgerEditorState();
}

class _LedgerEditorState extends ConsumerState<LedgerEditor> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  final _editReasonCtrl = TextEditingController();

  late int _cd, _pd, _cr, _pr, _cdmg, _pdmg;
  late double _coolPrice, _petPrice, _amtCollected, _transportFee;
  late String _mode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.tx;
    _cd = tx.coolDelivered; _pd = tx.petDelivered;
    _cr = tx.coolReturned; _pr = tx.petReturned;
    _cdmg = tx.coolDamaged; _pdmg = tx.petDamaged;
    _coolPrice = tx.coolPrice; _petPrice = tx.petPrice;
    _amtCollected = tx.amountCollected;
    _transportFee = tx.transportFee;
    _mode = tx.paymentMode;
    _noteCtrl.text = tx.note;
  }

  @override
  void dispose() {
    _noteCtrl.dispose(); _editReasonCtrl.dispose(); super.dispose();
  }

  double get _billed => (_cd * _coolPrice) + (_pd * _petPrice)
      + ((_cdmg + _pdmg) * ref.read(settingsProvider).damageChargePerJar)
      + _transportFee;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = ref.watch(inventoryProvider);
    final tx = widget.tx;
    final coolC = AppColors.coolColor(isDark);
    final petC  = AppColors.petColor(isDark);

    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Info banner ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warningColor(isDark).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warningColor(isDark).withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 15, color: AppColors.warningColor(isDark)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delivery date: ${_fmtDate(tx.date)} · Locked',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.warningColor(isDark))),
              Text('All changes save to history. Jar status and balance auto-update.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted, height: 1.4)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Edit reason (required) ────────────────────────────────────────
        const FieldLabel('Reason for edit *'),
        TextFormField(
          controller: _editReasonCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g. Wrong count entered, customer paid partial...',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please state the reason for editing' : null,
        ),
        const SizedBox(height: 20),

        // ── Jar counts ───────────────────────────────────────────────────────
        const SectionHeader(title: 'Jar Counts'),
        _JarEditorRow(
          jarIcon: CoolJarIcon(size: 20, color: coolC),
          label: 'Cool Jars', color: coolC, isDark: isDark,
          delivered: _cd, returned: _cr, damaged: _cdmg,
          maxDeliver: inv.coolStock + tx.coolDelivered,
          maxReturn: inv.coolOut + tx.coolReturned,
          maxDamaged: _cr,
          onDeliverChanged: (v) => setState(() => _cd = v),
          onReturnChanged: (v) => setState(() => _cr = v),
          onDamagedChanged: (v) => setState(() => _cdmg = v),
        ),
        const SizedBox(height: 8),
        _JarEditorRow(
          jarIcon: PetJarIcon(size: 20, color: petC),
          label: 'PET Jars', color: petC, isDark: isDark,
          delivered: _pd, returned: _pr, damaged: _pdmg,
          maxDeliver: inv.petStock + tx.petDelivered,
          maxReturn: inv.petOut + tx.petReturned,
          maxDamaged: _pr,
          onDeliverChanged: (v) => setState(() => _pd = v),
          onReturnChanged: (v) => setState(() => _pr = v),
          onDamagedChanged: (v) => setState(() => _pdmg = v),
        ),
        const SizedBox(height: 20),

        // ── Pricing ──────────────────────────────────────────────────────────
        const SectionHeader(title: 'Pricing'),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('Cool ₹/jar'),
            _PriceInput(value: _coolPrice, color: coolC, isDark: isDark,
                onChanged: (v) => setState(() => _coolPrice = v)),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel('PET ₹/jar'),
            _PriceInput(value: _petPrice, color: petC, isDark: isDark,
                onChanged: (v) => setState(() => _petPrice = v)),
          ])),
        ]),
        if (tx.deliveryType == 'event') ...[
          const SizedBox(height: 12),
          const FieldLabel('Transport Fee'),
          _PriceInput(value: _transportFee, color: AppColors.purple, isDark: isDark,
              onChanged: (v) => setState(() => _transportFee = v)),
        ],
        const SizedBox(height: 20),

        // ── Payment ──────────────────────────────────────────────────────────
        const SectionHeader(title: 'Payment'),
        // Billed preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0A1F6E), Color(0xFF1A6BFF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Text('Billed', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
            const Spacer(),
            Text('₹${_billed.toInt()}', style: GoogleFonts.jetBrainsMono(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 12),
        const FieldLabel('Amount Collected'),
        _CollectedInput(
          value: _amtCollected, billed: _billed, isDark: isDark,
          onChanged: (v) => setState(() => _amtCollected = v),
          onFullPay: () => setState(() => _amtCollected = _billed),
        ),
        const SizedBox(height: 12),
        const FieldLabel('Payment Mode'),
        PaymentModePicker(selected: _mode, onSelect: (m) => setState(() => _mode = m)),
        const SizedBox(height: 12),
        const FieldLabel('Note (optional)'),
        TextFormField(
          controller: _noteCtrl,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Any notes...'),
        ),
        const SizedBox(height: 24),

        // ── Save ─────────────────────────────────────────────────────────────
        GradientButton(
          label: 'Save & Update Ledger',
          loading: _saving,
          onTap: _save,
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Extra guard: ensure no negative jar counts
    if (_cd < 0 || _pd < 0 || _cr < 0 || _pr < 0 || _cdmg < 0 || _pdmg < 0) {
      showToast(context, '❌ Jar counts cannot be negative');
      return;
    }
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 200));

    final neu = widget.tx.copyWith(
      coolDelivered: _cd.clamp(0, 9999), petDelivered: _pd.clamp(0, 9999),
      coolReturned: _cr.clamp(0, 9999), petReturned: _pr.clamp(0, 9999),
      coolDamaged: _cdmg.clamp(0, 9999), petDamaged: _pdmg.clamp(0, 9999),
      coolPrice: _coolPrice, petPrice: _petPrice,
      billedAmount: _billed,
      amountCollected: _amtCollected.clamp(0, _billed),
      damageCharge: (_cdmg + _pdmg) * ref.read(settingsProvider).damageChargePerJar,
      transportFee: _transportFee,
      paymentMode: _mode,
      note: _noteCtrl.text.trim(),
    );

    ref.read(transactionsProvider.notifier).edit(
      widget.tx, neu,
      editNote: _editReasonCtrl.text.trim(),
    );

    if (context.mounted) {
      Navigator.pop(context);  // ignore: use_build_context_synchronously
      showToast(context, '✅ Ledger updated — jar status & balance synced', success: true);  // ignore: use_build_context_synchronously
    }
  }

  String _fmtDate(String d) {
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
  }
}

// ── Jar editor row — delivered / returned / damaged (editable text fields) ────
class _JarEditorRow extends StatefulWidget {
  final Widget jarIcon;
  final String label;
  final Color color;
  final bool isDark;
  final int delivered, returned, damaged, maxDeliver, maxReturn, maxDamaged;
  final ValueChanged<int> onDeliverChanged, onReturnChanged, onDamagedChanged;

  const _JarEditorRow({
    required this.jarIcon, required this.label, required this.color, required this.isDark,
    required this.delivered, required this.returned, required this.damaged,
    required this.maxDeliver, required this.maxReturn, required this.maxDamaged,
    required this.onDeliverChanged, required this.onReturnChanged, required this.onDamagedChanged,
  });

  @override
  State<_JarEditorRow> createState() => _JarEditorRowState();
}

class _JarEditorRowState extends State<_JarEditorRow> {
  late TextEditingController _inCtrl, _outCtrl, _dmgCtrl;

  @override
  void initState() {
    super.initState();
    _inCtrl  = TextEditingController(text: '${widget.delivered}');
    _outCtrl = TextEditingController(text: '${widget.returned}');
    _dmgCtrl = TextEditingController(text: '${widget.damaged}');
  }

  @override
  void didUpdateWidget(_JarEditorRow old) {
    super.didUpdateWidget(old);
    // Sync if parent changes value externally
    if (old.delivered != widget.delivered && _inCtrl.text != '${widget.delivered}') {
      _inCtrl.text = '${widget.delivered}';
    }
    if (old.returned != widget.returned && _outCtrl.text != '${widget.returned}') {
      _outCtrl.text = '${widget.returned}';
    }
    if (old.damaged != widget.damaged && _dmgCtrl.text != '${widget.damaged}') {
      _dmgCtrl.text = '${widget.damaged}';
    }
  }

  @override
  void dispose() {
    _inCtrl.dispose(); _outCtrl.dispose(); _dmgCtrl.dispose(); super.dispose();
  }

  int _parse(String v) => int.tryParse(v.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final c       = widget.color;
    final isDark  = widget.isDark;
    final okC     = AppColors.successColor(isDark);
    final dangerC = AppColors.dangerColor(isDark);
    final w       = MediaQuery.of(context).size.width;
    final compact = w < 380;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2Dark : AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          widget.jarIcon, const SizedBox(width: 8),
          Text(widget.label, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: c)),
          const Spacer(),
          // Current values summary pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('↓${widget.delivered}  ↑${widget.returned}',
                style: GoogleFonts.jetBrainsMono(fontSize: 11,
                    fontWeight: FontWeight.w700, color: c)),
          ),
        ]),
        const SizedBox(height: 10),
        // Three input cells in a row
        Row(children: [
          Expanded(child: _EditCell(
            label: '↓ IN', ctrl: _inCtrl, color: c, isDark: isDark,
            max: widget.maxDeliver,
            onChanged: (v) {
              final n = _parse(v).clamp(0, widget.maxDeliver);
              widget.onDeliverChanged(n);
              // If dmg > new OUT, clamp dmg
              if (widget.damaged > widget.returned) {
                widget.onDamagedChanged(widget.returned);
              }
            },
          )),
          const SizedBox(width: 6),
          Expanded(child: _EditCell(
            label: '↑ OUT', ctrl: _outCtrl, color: okC, isDark: isDark,
            max: widget.maxReturn,
            onChanged: (v) {
              final n = _parse(v).clamp(0, widget.maxReturn);
              widget.onReturnChanged(n);
              if (widget.damaged > n) {
                widget.onDamagedChanged(n);
              }
            },
          )),
          const SizedBox(width: 6),
          Expanded(child: _EditCell(
            label: '⚠ DMG', ctrl: _dmgCtrl, color: dangerC, isDark: isDark,
            max: widget.maxDamaged,
            onChanged: (v) {
              final n = _parse(v).clamp(0, widget.maxDamaged);
              widget.onDamagedChanged(n);
            },
          )),
        ]),
      ]),
    );
  }
}

// ── Single editable counter cell ──────────────────────────────────────────────
class _EditCell extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final Color color;
  final bool isDark;
  final int max;
  final ValueChanged<String> onChanged;

  const _EditCell({required this.label, required this.ctrl, required this.color,
      required this.isDark, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label, textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
              color: color, letterSpacing: 0.3)),
      const SizedBox(height: 5),
      Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(children: [
          // Decrement button
          GestureDetector(
            onTap: () {
              final cur = int.tryParse(ctrl.text) ?? 0;
              if (cur > 0) {
                ctrl.text = '${cur - 1}';
                onChanged(ctrl.text);
              }
            },
            child: Container(
              width: 32, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9), bottomLeft: Radius.circular(9)),
              ),
              child: Icon(Icons.remove_rounded, size: 14, color: color),
            ),
          ),
          // Number field
          Expanded(child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: onChanged,
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              if (n == null) return '?';
              if (n < 0) return '≥0';
              if (n > max) return '≤$max';
              return null;
            },
            style: GoogleFonts.jetBrainsMono(
                fontSize: 16, fontWeight: FontWeight.w800, color: color),
            decoration: InputDecoration(
              border: InputBorder.none, filled: false,
              contentPadding: EdgeInsets.zero,
              hintText: '0',
              hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 16, color: color.withValues(alpha: 0.25)),
              errorStyle: const TextStyle(fontSize: 0, height: 0),
            ),
          )),
          // Increment button
          GestureDetector(
            onTap: () {
              final cur = int.tryParse(ctrl.text) ?? 0;
              if (cur < max) {
                ctrl.text = '${cur + 1}';
                onChanged(ctrl.text);
              }
            },
            child: Container(
              width: 32, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(9), bottomRight: Radius.circular(9)),
              ),
              child: Icon(Icons.add_rounded, size: 14, color: color),
            ),
          ),
        ]),
      ),
      // Max hint
      Text('max $max', textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 9, color: AppColors.inkMuted)),
    ]);
  }
}

class _PriceInput extends StatelessWidget {
  final double value;
  final Color color;
  final bool isDark;
  final ValueChanged<double> onChanged;
  const _PriceInput({required this.value, required this.color,
      required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    decoration: BoxDecoration(
      color: isDark ? AppColors.bgDark : AppColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
    ),
    child: Row(children: [
      Padding(padding: const EdgeInsets.only(left: 10),
        child: Text('₹', style: GoogleFonts.jetBrainsMono(
            fontSize: 14, fontWeight: FontWeight.w700, color: color))),
      Expanded(child: TextFormField(
        initialValue: value > 0 ? value.toStringAsFixed(0) : '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => onChanged(double.tryParse(v) ?? value),
        style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: color),
        decoration: InputDecoration(
          hintText: value.toStringAsFixed(0),
          border: InputBorder.none, filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          hintStyle: GoogleFonts.jetBrainsMono(fontSize: 15, color: color.withValues(alpha: 0.35)),
        ),
      )),
    ]),
  );
}

class _CollectedInput extends StatelessWidget {
  final double value, billed;
  final bool isDark;
  final ValueChanged<double> onChanged;
  final VoidCallback onFullPay;
  const _CollectedInput({required this.value, required this.billed, required this.isDark,
      required this.onChanged, required this.onFullPay});

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    decoration: BoxDecoration(
      color: isDark ? AppColors.surface2Dark : AppColors.surface2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
    ),
    child: Row(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('₹', style: GoogleFonts.jetBrainsMono(fontSize: 18,
            fontWeight: FontWeight.w700, color: AppColors.inkMuted))),
      Expanded(child: TextFormField(
        initialValue: value > 0 ? value.toStringAsFixed(0) : '',
        keyboardType: TextInputType.number,
        onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
        style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: billed.toInt().toString(),
          border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
          hintStyle: GoogleFonts.jetBrainsMono(color: AppColors.inkMuted, fontSize: 20),
        ),
      )),
      if (value < billed)
        GestureDetector(
          onTap: onFullPay,
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.successColor(isDark).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Full pay', style: GoogleFonts.inter(fontSize: 11,
                fontWeight: FontWeight.w700, color: AppColors.successColor(isDark))),
          ),
        ),
    ]),
  );
}

// ── DR / CR Column (entry-level amount display) ───────────────────────────────
class _DrCrColumn extends StatelessWidget {
  final JarTransaction tx;
  final double runningBalance;
  final bool isDark;
  const _DrCrColumn({required this.tx, required this.runningBalance, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final dangerC = AppColors.dangerColor(isDark);
    final okC     = AppColors.successColor(isDark);
    // runningBalance < 0  → customer owes (due)
    // runningBalance >= 0 → customer has advance
    final isDue   = runningBalance < 0;
    final rbColor = isDue ? dangerC : okC;
    final rbLabel = isDue ? 'due' : 'adv';
    // Display just the absolute amount — no confusing minus sign
    final rbAmt   = '₹${runningBalance.abs().toInt()}';

    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min,
        children: [
      // DR / CR amount line
      if (tx.billedAmount > 0)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('DR ', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700,
              color: dangerC.withValues(alpha: 0.7))),
          Text('₹${tx.billedAmount.toInt()}', style: GoogleFonts.jetBrainsMono(
              fontSize: 15, fontWeight: FontWeight.w800, color: dangerC)),
        ]),
      if (tx.amountCollected > 0)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('CR ', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700,
              color: okC.withValues(alpha: 0.7))),
          Text('₹${tx.amountCollected.toInt()}', style: GoogleFonts.jetBrainsMono(
              fontSize: 13, fontWeight: FontWeight.w700, color: okC)),
        ]),
      const SizedBox(height: 5),
      // Running balance chip — single source of truth, no duplicate
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: rbColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: rbColor.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(rbAmt, style: GoogleFonts.jetBrainsMono(
              fontSize: 12, fontWeight: FontWeight.w800, color: rbColor)),
          Text(rbLabel, style: GoogleFonts.inter(
              fontSize: 8, fontWeight: FontWeight.w700,
              color: rbColor.withValues(alpha: 0.85))),
        ]),
      ),
    ]);
  }
}

// ── Collect Payment Sheet ─────────────────────────────────────────────────────
class _CollectPaymentSheet extends ConsumerStatefulWidget {
  final JarTransaction tx;
  const _CollectPaymentSheet({required this.tx});

  @override
  ConsumerState<_CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends ConsumerState<_CollectPaymentSheet> {
  late double _amount;
  String _mode = 'cash';
  bool _saving = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _amount = widget.tx.balance;
    _ctrl = TextEditingController(text: widget.tx.balance.toInt().toString());
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tx = widget.tx;
    final okC = AppColors.successColor(isDark);
    final dangerC = AppColors.dangerColor(isDark);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Outstanding info banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dangerC.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dangerC.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CustomerAvatar(initials: _initials(tx.customerName), size: 32),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx.customerName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Delivery on ${_fmt(tx.date)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Outstanding', style: GoogleFonts.inter(fontSize: 9, color: dangerC, fontWeight: FontWeight.w700)),
              Text('₹${tx.balance.toInt()}', style: GoogleFonts.jetBrainsMono(
                  fontSize: 20, fontWeight: FontWeight.w800, color: dangerC)),
            ]),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (tx.billedAmount > 0)
              _InfoPill('Billed ₹${tx.billedAmount.toInt()}', Theme.of(context).colorScheme.primary),
            if (tx.amountCollected > 0)
              _InfoPill('Paid ₹${tx.amountCollected.toInt()}', okC),
            _InfoPill('Balance ₹${tx.balance.toInt()}', dangerC),
          ]),
        ]),
      ),
      const SizedBox(height: 20),

      const FieldLabel('Amount to Collect'),
      Container(
        height: 60,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        child: Row(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('₹', style: GoogleFonts.jetBrainsMono(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.inkMuted))),
          Expanded(child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (v) => setState(() => _amount = double.tryParse(v) ?? 0),
            style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
              hintText: tx.balance.toInt().toString(),
              hintStyle: GoogleFonts.jetBrainsMono(fontSize: 24, color: AppColors.inkMuted),
            ),
          )),
          if (_amount < tx.balance)
            GestureDetector(
              onTap: () => setState(() {
                _amount = tx.balance;
                _ctrl.text = tx.balance.toInt().toString();
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: okC.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Full ₹${tx.balance.toInt()}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: okC)),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 16),

      const FieldLabel('Payment Mode'),
      PaymentModePicker(selected: _mode, onSelect: (m) => setState(() => _mode = m)),
      const SizedBox(height: 24),

      GradientButton(
        label: _amount <= 0
            ? 'Enter amount'
            : _amount >= tx.balance
                ? '✅ Mark Fully Paid'
                : '✅ Record Partial ₹${_amount.toInt()}',
        loading: _saving,
        onTap: _amount > 0 ? _save : null,
        gradient: _amount <= 0
            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
            : LinearGradient(colors: [okC, okC.withValues(alpha: 0.7)]),
      ),
    ]);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final newCollected = (widget.tx.amountCollected + _amount).clamp(0.0, widget.tx.billedAmount);
    final neu = widget.tx.copyWith(amountCollected: newCollected, paymentMode: _mode);
    ref.read(transactionsProvider.notifier).edit(
      widget.tx, neu,
      editNote: 'Payment collected: ₹${_amount.toInt()} via $_mode',
    );
    if (mounted) {
      Navigator.pop(context);
      showToast(context, '✅ ₹${_amount.toInt()} collected — balance updated', success: true);
    }
  }

  String _initials(String n) {
    final p = n.trim().split(' ');
    return (p.length >= 2 ? '${p[0][0]}${p[1][0]}' : n.substring(0, n.length >= 2 ? 2 : 1)).toUpperCase();
  }
  String _fmt(String d) {
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoPill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}
