// ════════════════════════════════════════════════════════════════════════════
// payments_screen.dart  — Customer payment list + detail sheet
//
// List  : All customers, search bar, name + phone + balance + Due/Credit tag
// Sheet : Customer header → Settle/Advance buttons → "Last Paid Bill" table
//         (Date | Collected By | Amount) → Monthly bill accordion
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PAYMENTS SCREEN  — full customer list with search
// ══════════════════════════════════════════════════════════════════════════════
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsState();
}

class _PaymentsState extends ConsumerState<PaymentsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    // Show ALL active customers (not just dues/advances)
    final allCusts = ref.watch(customersProvider)
        .where((c) => c.isActive)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final filtered = _search.isEmpty
        ? allCusts
        : allCusts.where((c) =>
            c.name.toLowerCase().contains(_search.toLowerCase()) ||
            c.phone.contains(_search)).toList();

    final dueCount = allCusts.where((c) => c.hasDues).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [

        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface2Dark : AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? AppColors.separatorDark : AppColors.separator),
            ),
            child: Row(children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.search_rounded,
                    color: AppColors.inkMuted, size: 18),
              ),
              Expanded(child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: GoogleFonts.inter(
                      color: AppColors.inkMuted, fontSize: 14),
                ),
              )),
            ]),
          ),
        ),

        // ── Column header row ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : const Color(0xFFE8F4FD),
            border: Border(
              bottom: BorderSide(
                  color: isDark
                      ? AppColors.separatorDark
                      : AppColors.separator),
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Text('Customer Name',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white70
                          : const Color(0xFF1A6BFF))),
            ),
            Row(children: [
              if (dueCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.dangerColor(isDark)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$dueCount Due',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dangerColor(isDark))),
                ),
              Text('Due/Credit',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white70
                          : const Color(0xFF1A6BFF))),
            ]),
          ]),
        ),

        // ── Customer list ───────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(transactionsProvider.notifier).refreshAll(ref),
            child: filtered.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.search_off_rounded, size: 48,
                      color: AppColors.inkMuted.withValues(alpha: 0.35)),
                  const SizedBox(height: 12),
                  Text('No customers found',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w600)),
                ]))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.separatorDark
                            : AppColors.separator),
                    itemBuilder: (ctx, i) => _CustRow(
                      customer: filtered[i],
                      isDark: isDark,
                      onTap: () => showMrSheet(ctx,
                          title: filtered[i].name,
                          builder: (_) => _CustomerPaymentSheet(
                              customer: filtered[i])),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

// ── Customer row ──────────────────────────────────────────────────────────────
class _CustRow extends StatelessWidget {
  final Customer customer;
  final bool isDark;
  final VoidCallback onTap;
  const _CustRow(
      {required this.customer, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dangerC = AppColors.dangerColor(isDark);
    final okC     = AppColors.successColor(isDark);

    final hasDue    = customer.hasDues;
    final hasCredit = customer.hasCredit;
    final amt       = customer.balance.abs();

    Color amtColor = AppColors.inkMuted;
    String tag = '';
    if (hasDue)    { amtColor = dangerC; tag = 'Due'; }
    if (hasCredit) { amtColor = okC;     tag = 'Credit'; }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          CustomerAvatar(initials: customer.initials, size: 38),
          const SizedBox(width: 12),

          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.name,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            Text(customer.phone,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.inkMuted)),
          ])),

          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              Text('₹ ',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: amtColor)),
              Text(
                amt == 0
                    ? '0'
                    : amt.toStringAsFixed(
                        amt.truncateToDouble() == amt ? 0 : 1),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: amtColor)),
            ]),
            if (tag.isNotEmpty)
              Text(tag,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: amtColor)),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CUSTOMER PAYMENT SHEET  — Daily | Event tabs
// ══════════════════════════════════════════════════════════════════════════════
class _CustomerPaymentSheet extends ConsumerStatefulWidget {
  final Customer customer;
  const _CustomerPaymentSheet({required this.customer});
  @override
  ConsumerState<_CustomerPaymentSheet> createState() =>
      _CustomerPaymentSheetState();
}

class _CustomerPaymentSheetState extends ConsumerState<_CustomerPaymentSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  String? _openMonthDaily;
  String? _openMonthEvent;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _tc.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final dangerC  = AppColors.dangerColor(isDark);
    final okC      = AppColors.successColor(isDark);
    final customer = widget.customer;

    final allTxns  = ref.watch(transactionsProvider);
    final custTxns = allTxns
        .where((t) => t.customerId == customer.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final dailyTxns = custTxns.where((t) => t.deliveryType != 'event').toList();
    final eventTxns = custTxns.where((t) => t.deliveryType == 'event').toList();

    final activeTxns  = _tc.index == 0 ? dailyTxns : eventTxns;
    final openMonthKey = _tc.index == 0 ? _openMonthDaily : _openMonthEvent;

    // Group active tab's transactions by month
    final monthGroups  = _groupByMonth(activeTxns);
    final sortedMonths = monthGroups.keys.toList()..sort((a, b) => b.compareTo(a));

    final paymentTxns = activeTxns
        .where((t) => t.amountCollected > 0 && t.billedAmount == 0)
        .toList();

    // ── Single outer scroll — eliminates the nested-scroll hang completely ──
    // The old pattern (Column → Flexible → SingleChildScrollView → Column → map)
    // caused Flutter to deadlock measuring unbounded height inside the sheet.
    // Now everything lives in ONE SingleChildScrollView with no Flexible child.
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Customer header ──────────────────────────────────────────────────
        _CustomerHeaderCard(
            customer: customer, isDark: isDark,
            dangerC: dangerC, okC: okC),
        const SizedBox(height: 12),

        // ── Action buttons ───────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _ActionBtn(
            label: 'Add Advance', color: okC, filled: false,
            onTap: () => showMrSheet(context,
                title: '💳 Add Advance — ${customer.name}',
                builder: (_) => _PaymentForm(customer: customer, type: 'advance')),
          )),
          if (customer.hasDues) ...[
            const SizedBox(width: 10),
            Expanded(child: _ActionBtn(
              label: 'Settle Dues', color: okC, filled: true,
              onTap: () => showMrSheet(context,
                  title: '💰 Settle Dues — ${customer.name}',
                  builder: (_) => _PaymentForm(customer: customer, type: 'settle')),
            )),
          ],
        ]),
        const SizedBox(height: 16),

        // ── Daily / Event tab bar ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? AppColors.separatorDark : AppColors.separator),
          ),
          child: TabBar(
            controller: _tc,
            indicator: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07), blurRadius: 4)],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500),
            labelColor: primary,
            unselectedLabelColor: AppColors.inkMuted,
            tabs: [
              Tab(text: '📅 Daily (${dailyTxns.length})'),
              Tab(text: '🎉 Event (${eventTxns.length})'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Tab content (rendered inline — no nested scroll) ─────────────────
        if (activeTxns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Column(children: [
              Icon(Icons.receipt_long_rounded, size: 44,
                  color: AppColors.inkMuted.withValues(alpha: 0.30)),
              const SizedBox(height: 10),
              Text('No transactions',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted)),
              const SizedBox(height: 4),
              Text('No records in this category',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.inkMuted)),
            ])),
          )
        else ...[
          // Last Paid Bill
          Text('Last Paid Bill',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w800, color: primary)),
          const SizedBox(height: 8),
          _LastPaidTable(
              txns: paymentTxns, isDark: isDark, primary: primary),
          const SizedBox(height: 20),

          // Monthly accordions
          ...sortedMonths.map((key) {
            final isOpen = openMonthKey == key;
            return _MonthAccordion(
              monthKey: key,
              txns: monthGroups[key]!,
              isDark: isDark, primary: primary,
              dangerC: dangerC, okC: okC,
              isOpen: isOpen, customer: customer,
              onToggle: () {
                if (_tc.index == 0) {
                  setState(() => _openMonthDaily = isOpen ? null : key);
                } else {
                  setState(() => _openMonthEvent = isOpen ? null : key);
                }
              },
            );
          }),
        ],

        const SizedBox(height: 24),
      ]),
    );
  }

  Map<String, List<JarTransaction>> _groupByMonth(List<JarTransaction> list) {
    final map = <String, List<JarTransaction>>{};
    for (final t in list) {
      try {
        final d   = DateTime.parse(t.date);
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        map.putIfAbsent(key, () => []).add(t);
      } catch (_) {}
    }
    return map;
  }
}


// ── Customer header card ───────────────────────────────────────────────────────
class _CustomerHeaderCard extends StatelessWidget {
  final Customer customer;
  final bool isDark;
  final Color dangerC, okC;
  const _CustomerHeaderCard(
      {required this.customer,
      required this.isDark,
      required this.dangerC,
      required this.okC});

  @override
  Widget build(BuildContext context) {
    final coolC = AppColors.coolColor(isDark);
    final petC  = AppColors.petColor(isDark);
    final color = customer.hasDues
        ? dangerC
        : customer.hasCredit
            ? okC
            : AppColors.inkMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CustomerAvatar(initials: customer.initials, size: 42),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.name,
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            Text(customer.phone,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.inkMuted)),
            if (customer.area.isNotEmpty)
              Text(customer.area,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.inkMuted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              customer.hasDues
                  ? 'Due'
                  : customer.hasCredit
                      ? 'Credit'
                      : 'Clear',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.4),
            ),
            if (customer.balance != 0)
              Text('₹${customer.balance.abs().toInt()}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color)),
          ]),
        ]),
        if (customer.coolOut > 0 || customer.petOut > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            CoolJarIcon(size: 13, color: coolC),
            const SizedBox(width: 4),
            Text('${customer.coolOut} Cool',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: coolC,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 14),
            PetJarIcon(size: 13, color: petC),
            const SizedBox(width: 4),
            Text('${customer.petOut} PET',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: petC,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('with customer',
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.inkMuted)),
          ]),
        ],
      ]),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label,
      required this.color,
      required this.filled,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            gradient: filled
                ? LinearGradient(
                    colors: [color.withValues(alpha: 0.85), color])
                : null,
            color: filled ? null : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: filled
                ? null
                : Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.white : color)),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// LAST PAID BILL TABLE  — Date | Collected By | Amount (Rs)
// ══════════════════════════════════════════════════════════════════════════════
class _LastPaidTable extends StatelessWidget {
  final List<JarTransaction> txns;
  final bool isDark;
  final Color primary;
  const _LastPaidTable(
      {required this.txns, required this.isDark, required this.primary});

  String _fmtDate(String d) {
    try { return DateFormat('dd-MMM-yyyy').format(DateTime.parse(d)); }
    catch (_) { return d; }
  }

  String _fmtTime(String iso) {
    try {
      return DateFormat('hh:mm a')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final okC = AppColors.successColor(isDark);

    if (txns.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(child: Text('No payments recorded yet',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.inkMuted))),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(children: [
        // ── Header ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFD6EAF8),
          child: Row(children: [
            Expanded(flex: 3,
              child: Text('Date',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87))),
            Expanded(flex: 4,
              child: Text('Collected by',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87))),
            Text('Amount (Rs)',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87)),
          ]),
        ),

        // ── Rows ───────────────────────────────────────────────────────────
        ...txns.asMap().entries.map((e) {
          final i  = e.key;
          final t  = e.value;
          final bg = i.isEven
              ? (isDark ? AppColors.cardDark : Colors.white)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : const Color(0xFFF5FBFF));

          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            color: bg,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Expanded(flex: 3,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_fmtDate(t.date),
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87)),
                  Text(_fmtTime(t.createdAt),
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.inkMuted)),
                ])),
              Expanded(flex: 4,
                child: Text(
                  t.createdBy.isNotEmpty ? t.createdBy : 'Admin',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87),
                )),
              Text(
                t.amountCollected.toInt().toString(),
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: okC),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MONTHLY BILL ACCORDION
// ══════════════════════════════════════════════════════════════════════════════
class _MonthAccordion extends StatelessWidget {
  final String monthKey;
  final List<JarTransaction> txns;
  final bool isDark, isOpen;
  final Color primary, dangerC, okC;
  final VoidCallback onToggle;
  final Customer customer;

  const _MonthAccordion({
    required this.monthKey,
    required this.txns,
    required this.isDark,
    required this.isOpen,
    required this.primary,
    required this.dangerC,
    required this.okC,
    required this.onToggle,
    required this.customer,
  });

  String get _monthLabel {
    try {
      final p  = monthKey.split('-');
      final dt = DateTime(int.parse(p[0]), int.parse(p[1]));
      return DateFormat('MMMM yyyy').format(dt);
    } catch (_) { return monthKey; }
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = txns
        .where((t) =>
            t.billedAmount > 0 ||
            t.coolDelivered > 0 ||
            t.petDelivered > 0)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalBilled = txns.fold(0.0, (s, t) => s + t.billedAmount);
    final totalPaid   = txns.fold(0.0, (s, t) => s + t.amountCollected);
    final paymentsAmt = txns
        .where((t) => t.amountCollected > 0 && t.billedAmount == 0)
        .fold(0.0, (s, t) => s + t.amountCollected);

    String billingDate = '';
    if (deliveries.isNotEmpty) {
      try {
        billingDate = DateFormat('d MMMM, yyyy \'at\' hh:mm a')
            .format(DateTime.parse(deliveries.first.createdAt).toLocal());
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? AppColors.separatorDark : AppColors.separator),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [

        // ── Header ──────────────────────────────────────────────────────────
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: isDark
                ? const Color(0xFF1E3A5F)
                : const Color(0xFFD6EAF8),
            child: Row(children: [
              Expanded(
                child: Text(_monthLabel,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87)),
              ),
              // PDF download button only (WhatsApp removed per screenshot)
              GestureDetector(
                onTap: () => showToast(context, 'PDF export coming soon'),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        size: 14,
                        color: isDark ? Colors.white : Colors.black54),
                    const SizedBox(width: 4),
                    Text('PDF',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black54)),
                  ]),
                ),
              ),
              Icon(
                isOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ]),
          ),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        if (isOpen)
          Container(
            color: isDark ? AppColors.cardDark : Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Billing Date row
              if (billingDate.isNotEmpty) ...[
                _BillingLabelRow('Billing Date', ':', billingDate, isDark),
                const SizedBox(height: 12),
                Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.separatorDark
                        : AppColors.separator),
                const SizedBox(height: 12),
              ],

              // Line items — one per delivery
              ...deliveries.map((t) => _BillLineItem(
                  txn: t, isDark: isDark, customer: customer)),

              const SizedBox(height: 8),
              Divider(
                  height: 1,
                  color: isDark
                      ? AppColors.separatorDark
                      : AppColors.separator),
              const SizedBox(height: 8),

              // Past due
              if (totalBilled > totalPaid)
                _AmtRow('Past Month Due Amount',
                    totalBilled - totalPaid, dangerC, isDark),

              // Total paid in month
              _AmtRow('Total Month Paid Amount',
                  paymentsAmt, okC, isDark),

              const SizedBox(height: 4),
              Divider(
                  height: 1,
                  color: isDark
                      ? AppColors.separatorDark
                      : AppColors.separator),
              const SizedBox(height: 4),

              // Grand total
              _AmtRow('Total Amount', totalBilled, primary, isDark,
                  bold: true),
            ]),
          ),
      ]),
    );
  }
}

// ── Billing label : value row ──────────────────────────────────────────────────
class _BillingLabelRow extends StatelessWidget {
  final String label, colon, value;
  final bool isDark;
  const _BillingLabelRow(this.label, this.colon, this.value, this.isDark);

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87),
                overflow: TextOverflow.ellipsis),
          ),
          Text('$colon  ',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.inkMuted)),
          Expanded(
            flex: 3,
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

// ── Bill line item ─────────────────────────────────────────────────────────────
class _BillLineItem extends StatelessWidget {
  final JarTransaction txn;
  final bool isDark;
  final Customer customer;
  const _BillLineItem(
      {required this.txn, required this.isDark, required this.customer});

  @override
  Widget build(BuildContext context) {
    final coolC = AppColors.coolColor(isDark);
    final petC  = AppColors.petColor(isDark);

    final lines = <_LD>[];
    if (txn.coolDelivered > 0) {
      final p = customer.coolPriceOverride ??
          (txn.billedAmount > 0 && txn.petDelivered == 0
              ? txn.billedAmount / txn.coolDelivered
              : 0.0);
      lines.add(_LD(
          label: 'Total Cool Jar',
          qty: txn.coolDelivered,
          price: p,
          color: coolC));
    }
    if (txn.petDelivered > 0) {
      final p = customer.petPriceOverride ??
          (txn.billedAmount > 0 && txn.coolDelivered == 0
              ? txn.billedAmount / txn.petDelivered
              : 0.0);
      lines.add(_LD(
          label: 'Total PET Jar',
          qty: txn.petDelivered,
          price: p,
          color: petC));
    }
    if (lines.isEmpty && txn.billedAmount > 0) {
      lines.add(_LD(
          label: 'Delivery',
          qty: 1,
          price: txn.billedAmount,
          color: AppColors.inkMuted));
    }

    return Column(
      children: lines.map((l) {
        final amt = l.qty * l.price;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            // Product label
            Expanded(flex: 4,
              child: Text(l.label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87))),
            // X Price formula
            Text('X',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 5),
            Text('Price',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.inkMuted)),
            const SizedBox(width: 4),
            Text('( ${l.qty}  X  ${l.price.toInt()} )',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.inkMuted)),
            const SizedBox(width: 8),
            // Amount
            Text('₹ ${amt.toInt()}',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: l.color)),
          ]),
        );
      }).toList(),
    );
  }
}

class _LD {
  final String label;
  final int qty;
  final double price;
  final Color color;
  const _LD(
      {required this.label,
      required this.qty,
      required this.price,
      required this.color});
}

// ── Amount row ────────────────────────────────────────────────────────────────
Widget _AmtRow(String label, double amount, Color color, bool isDark,
    {bool bold = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87)),
        ),
        Text(
          amount.toInt().toString(),
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color),
        ),
      ]),
    );

// ══════════════════════════════════════════════════════════════════════════════
// PAYMENT FORM
// ══════════════════════════════════════════════════════════════════════════════
class _PaymentForm extends ConsumerStatefulWidget {
  final Customer customer;
  final String type; // 'settle' | 'advance'
  const _PaymentForm({required this.customer, required this.type});
  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  final _amt  = TextEditingController();
  final _note = TextEditingController();
  String _mode = 'cash';

  @override
  void initState() {
    super.initState();
    if (widget.type == 'settle') {
      _amt.text = widget.customer.balance.abs().toInt().toString();
    }
  }

  @override
  void dispose() { _amt.dispose(); _note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final dangerC = AppColors.dangerColor(isDark);
    final okC     = AppColors.successColor(isDark);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          CustomerAvatar(initials: widget.customer.initials, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.customer.name,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            if (widget.customer.hasDues)
              Text(
                  'Outstanding: ₹${widget.customer.balance.abs().toInt()}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: dangerC,
                      fontWeight: FontWeight.w600)),
            if (widget.customer.hasCredit)
              Text('Credit: ₹${widget.customer.balance.toInt()}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: okC,
                      fontWeight: FontWeight.w600)),
          ])),
        ]),
      ),
      const SizedBox(height: 20),

      FieldLabel('Amount *'),
      TextFormField(
        controller: _amt,
        keyboardType: TextInputType.number,
        autofocus: true,
        style: GoogleFonts.jetBrainsMono(
            fontSize: 26, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(hintText: '0', prefixText: '₹ '),
      ),
      const SizedBox(height: 16),

      if (widget.type != 'advance') ...[
        FieldLabel('Payment Mode'),
        PaymentModePicker(
            selected: _mode,
            onSelect: (m) => setState(() => _mode = m)),
        const SizedBox(height: 16),
      ],

      FieldLabel('Note (optional)'),
      TextFormField(
        controller: _note,
        decoration: const InputDecoration(
            hintText: 'Reference, cheque no...'),
      ),
      const SizedBox(height: 24),

      GradientButton(
        label: widget.type == 'advance'
            ? '💳 Add Advance'
            : '💰 Record Payment',
        onTap: () {
          final val = double.tryParse(_amt.text) ?? 0;
          if (val <= 0) {
            showToast(context, 'Enter a valid amount', error: true);
            return;
          }
          final sessionUser = ref.read(sessionUserProvider);
          final tx = JarTransaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            customerId: widget.customer.id,
            customerName: widget.customer.name,
            date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            createdAt: DateTime.now().toIso8601String(),
            billedAmount: 0,
            amountCollected: val,
            paymentMode:
                widget.type == 'advance' ? 'advance' : _mode,
            note: _note.text.trim(),
            createdBy: sessionUser?.name ?? 'Admin',
            deliveryType: 'daily',
          );
          ref.read(transactionsProvider.notifier).add(tx);
          Navigator.pop(context);
          showToast(context, '✅ Payment recorded', success: true);
        },
        gradient:
            LinearGradient(colors: [okC.withValues(alpha: 0.85), okC]),
      ),
    ]);
  }
}
