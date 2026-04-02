import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';
import 'transactions_screen.dart';
import 'customers_screen.dart';
import 'expenses_screen.dart';
import 'voice_assistant.dart';
import 'voice_form_helper.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DASHBOARD SCREEN — 2 tabs: Dashboard + Analytics
// ══════════════════════════════════════════════════════════════════════════════
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashState();
}

class _DashState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    // Tab count depends on role — set in build() but init with 2 as default
    _tc = TabController(length: 2, vsync: this);
    _tc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final primary     = Theme.of(context).colorScheme.primary;
    // null = owner (full access), non-null = staff (limited)
    final sessionUser = ref.watch(sessionUserProvider);
    final isOwner     = sessionUser == null;

    // Staff only see the Dashboard tab — Analytics is owner-only
    final tabCount = isOwner ? 2 : 1;

    // Rebuild TabController if tab count changes (owner ↔ staff switch)
    if (_tc.length != tabCount) {
      _tc.dispose();
      _tc = TabController(length: tabCount, vsync: this);
      _tc.addListener(() => setState(() {}));
    }

    return Column(children: [
      // Tab bar — hide if only one tab (staff view)
      if (isOwner)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.card,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.separatorDark : AppColors.separator,
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tc,
            indicatorColor: primary,
            indicatorWeight: 2.5,
            dividerColor: Colors.transparent,
            labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
            labelColor: primary,
            unselectedLabelColor: AppColors.inkMuted,
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Analytics'),
            ],
          ),
        ),

      Expanded(
        child: isOwner
            ? TabBarView(controller: _tc, children: [
                _DashTab(isDark: isDark),
                _AnalyticsTab(isDark: isDark),
              ])
            // Staff: show only Dashboard tab directly (no TabBarView overhead)
            : _DashTab(isDark: isDark),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1: DASHBOARD — Quick Actions + Nav Grid
// ══════════════════════════════════════════════════════════════════════════════
class _DashTab extends ConsumerWidget {
  final bool isDark;
  const _DashTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _QuickActionsCard(isDark: isDark),
        ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _NavGrid(isDark: isDark),
        ),

        const SizedBox(height: 24),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS CARD — label + 4 coloured tiles, all inside one shadow card
// ══════════════════════════════════════════════════════════════════════════════
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  const _QuickAction(this.icon, this.label, this.color);
}

class _QuickActionsCard extends ConsumerWidget {
  final bool isDark;
  const _QuickActionsCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _QuickAction(Icons.local_shipping_rounded,    'Create\nDelivery',    const Color(0xFF0096C7)),
      _QuickAction(Icons.group_add_rounded,         'Create\nCustomer',    const Color(0xFF7B61FF)),
      _QuickAction(Icons.payments_rounded,          'Create\nPayment',     const Color(0xFF06D6A0)),
      _QuickAction(Icons.money_off_rounded,          'Create\nExpense',     const Color(0xFFFF8C42)),
      _QuickAction(Icons.document_scanner_rounded,  'Smart\nEntry',        AppColors.purple),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.12),
            blurRadius: 16, spreadRadius: 0, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Actions',
            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 12),

        // 5 tiles — first row 4, second row 1 centered
        Row(
          children: actions.sublist(0, 4).asMap().entries.map((e) {
            final i = e.key;
            final a = e.value;
            return Expanded(child: Padding(
              padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
              child: _QuickTile(a: a, isDark: isDark,
                onTap: () {
                  if (i == 0) {
                    showMrSheet(context, title: '🚚 Create Delivery',
                        builder: (_) => _QuickDeliverySheet(isDark: isDark));
                  } else if (i == 1) {
                    showMrSheet(context, title: '👤 Add Customer',
                        builder: (_) => const AddCustForm());
                  } else if (i == 2) {
                    showMrSheet(context, title: '💳 Record Payment',
                        builder: (_) => _QuickPaymentForm(isDark: isDark));
                  } else if (i == 3) {
                    showMrSheet(context, title: '🧾 Record Expense',
                        builder: (_) => const ExpenseForm());
                  }
                }),
            ));
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Smart Entry — full-width tile in second row
        _QuickTile(
          a: actions[4], isDark: isDark, fullWidth: true,
          onTap: () => ref.read(tabProvider.notifier).state = 10,
        ),
        const SizedBox(height: 8),
        // Voice Assistant — full-width gradient button in third row
        GestureDetector(
          onTap: () => openVoiceAssistant(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 10, offset: const Offset(0, 4),
              )],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('🎙 Voice Assistant',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 11),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final _QuickAction a;
  final bool isDark;
  final bool fullWidth;
  final VoidCallback onTap;
  const _QuickTile({required this.a, required this.isDark,
      required this.onTap, this.fullWidth = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: fullWidth
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: a.color.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: a.color.withValues(alpha: isDark ? 0.35 : 0.22), width: 1),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(a.icon, size: 22, color: a.color),
              const SizedBox(width: 10),
              Text(a.label.replaceAll('\n', ' '),
                  style: GoogleFonts.dmSans(fontSize: 13,
                      fontWeight: FontWeight.w700, color: a.color)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: a.color),
            ]),
          )
        : Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 62, width: double.infinity,
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: a.color.withValues(alpha: isDark ? 0.35 : 0.22), width: 1),
              ),
              child: Stack(alignment: Alignment.center, children: [
                Icon(a.icon, size: 28, color: a.color),
                Positioned(
                  right: 5, bottom: 5,
                  child: Container(
                    width: 17, height: 17,
                    decoration: BoxDecoration(
                      color: a.color, shape: BoxShape.circle,
                      border: Border.all(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          width: 1.5),
                    ),
                    child: const Icon(Icons.add, size: 10, color: Colors.white),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(a.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: Theme.of(context).colorScheme.onSurface)),
          ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// NAV GRID — 3 per row, consistent shadow cards
// ══════════════════════════════════════════════════════════════════════════════
class _NavItem2 {
  final int tab;
  final IconData icon;
  final String label;
  final Color Function(bool) color;
  const _NavItem2(this.tab, this.icon, this.label, this.color);
}

final _navItems2 = <_NavItem2>[
  _NavItem2(3, Icons.inventory_2_rounded,   'Products',    (d) => AppColors.coolColor(d)),
  _NavItem2(2, Icons.people_alt_rounded,     'Customers',   (d) => AppColors.coolColor(d)),
  _NavItem2(8, Icons.move_to_inbox_rounded,  'Load/Unload', (d) => AppColors.petColor(d)),
  _NavItem2(1, Icons.local_shipping_rounded, 'Deliveries',  (d) => AppColors.coolColor(d)),
  _NavItem2(5, Icons.assessment_rounded,     'Reports',     (d) => AppColors.warningColor(d)),
  _NavItem2(4, Icons.payments_rounded,       'Payments',    (d) => AppColors.successColor(d)),
  _NavItem2(9,  Icons.money_off_rounded,          'Expenses',     (d) => AppColors.dangerColor(d)),
  _NavItem2(10, Icons.document_scanner_rounded,   'Smart Entry',  (d) => AppColors.purple),
  _NavItem2(6,  Icons.notifications_rounded,       'Alerts',       (d) => AppColors.dangerColor(d)),
];

class _NavGrid extends ConsumerWidget {
  final bool isDark;
  const _NavGrid({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: _navItems2.length,
      itemBuilder: (ctx, i) {
        final item = _navItems2[i];
        final c    = item.color(isDark);
        return GestureDetector(
          onTap: () => ref.read(tabProvider.notifier).state = item.tab,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
                  blurRadius: 8, spreadRadius: 0, offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(item.icon, size: 34, color: c),
              const SizedBox(height: 8),
              Text(item.label,
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2: ANALYTICS
// ══════════════════════════════════════════════════════════════════════════════
class _AnalyticsTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _AnalyticsTab({required this.isDark});
  @override
  ConsumerState<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<_AnalyticsTab> {
  static const _filters = [
    'Today', 'This Week', 'This Month',
    'Last 7 Days', 'Last 15 Days', 'Financial Year',
  ];
  String _plFilter  = 'Today';
  String _expFilter = 'This Month';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<JarTransaction> _applyFilter(List<JarTransaction> txns, String f) {
    final now = DateTime.now();
    return txns.where((t) {
      try {
        final d = DateTime.parse(t.date);
        switch (f) {
          case 'Today':         return _sameDay(d, now);
          case 'This Week':     return d.isAfter(now.subtract(Duration(days: now.weekday - 1)));
          case 'This Month':    return d.month == now.month && d.year == now.year;
          case 'Last 7 Days':   return d.isAfter(now.subtract(const Duration(days: 7)));
          case 'Last 15 Days':  return d.isAfter(now.subtract(const Duration(days: 15)));
          case 'Financial Year':
            final fy = now.month >= 4 ? now.year : now.year - 1;
            return !d.isBefore(DateTime(fy, 4, 1));
          default: return true;
        }
      } catch (_) { return false; }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = widget.isDark;
    final txns    = ref.watch(transactionsProvider);
    final custs   = ref.watch(customersProvider);
    final now     = DateTime.now();
    final today   = DateFormat('yyyy-MM-dd').format(now);
    final primary = Theme.of(context).colorScheme.primary;

    // ── Today's summary ────────────────────────────────────────────────────
    final todayTx   = txns.where((t) => t.date == today).toList();
    final todayRev  = todayTx.fold(0.0, (s, t) => s + t.billedAmount);
    final todayColl = todayTx.fold(0.0, (s, t) => s + t.amountCollected);
    final todayDue  = todayTx.fold(0.0, (s, t) => s + t.balance);

    // ── Invoices ───────────────────────────────────────────────────────────
    final totalBilled  = txns.fold(0.0, (s, t) => s + t.billedAmount);
    final totalUnpaid  = txns.fold(0.0, (s, t) => s + t.balance);
    final totalPaid    = totalBilled - totalUnpaid;
    final unpaidCount  = txns.where((t) => t.balance > 0).length;

    // ── P&L ────────────────────────────────────────────────────────────────
    final plTxns   = _applyFilter(txns, _plFilter);
    final plRev    = plTxns.fold(0.0, (s, t) => s + t.billedAmount);
    final plExp    = plTxns.fold(0.0, (s, t) => s + t.damageCharge);
    final plNet    = plRev - plExp;
    final plMax    = math.max(plRev, plExp).clamp(1.0, double.infinity);

    // ── Expenses pie ───────────────────────────────────────────────────────
    final expTxns = _applyFilter(txns, _expFilter);
    final expMap  = <String, double>{};
    for (final t in expTxns) {
      if (t.damageCharge > 0) {
        expMap['Damage Charges'] = (expMap['Damage Charges'] ?? 0) + t.damageCharge;
      }
    }
    if (expMap.isEmpty) expMap['No Expenses'] = 0;
    final expTotal  = expMap.values.fold(0.0, (a, b) => a + b);
    final expColors = [
      primary,
      AppColors.successColor(isDark),
      const Color(0xFFFF8C42),
      const Color(0xFF7B61FF),
      AppColors.dangerColor(isDark),
      AppColors.warningColor(isDark),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ════════════════════════════════════════════════════════════════
        // TODAY'S SUMMARY
        // ════════════════════════════════════════════════════════════════
        _ACard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardHeader(title: "TODAY'S SUMMARY"),
          const SizedBox(height: 12),
          Row(children: [
            _StatTile(label: 'Revenue',      value: '₹${todayRev.toInt()}',  color: primary,                        isDark: isDark),
            const SizedBox(width: 8),
            _StatTile(label: 'Collected',    value: '₹${todayColl.toInt()}', color: AppColors.successColor(isDark), isDark: isDark),
            const SizedBox(width: 8),
            _StatTile(label: 'Pending',      value: '₹${todayDue.toInt()}',  color: AppColors.dangerColor(isDark),  isDark: isDark),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _StatTile(label: 'Transactions', value: '${todayTx.length}',     color: AppColors.warningColor(isDark), isDark: isDark),
            const SizedBox(width: 8),
            _StatTile(label: 'Customers',    value: '${custs.length}',       color: const Color(0xFF7B61FF),        isDark: isDark),
            const SizedBox(width: 8),
            _StatTile(label: 'Active',       value: '${custs.where((c) => c.isActive).length}',
                color: AppColors.coolColor(isDark), isDark: isDark),
          ]),
        ])),

        const SizedBox(height: 14),

        // ════════════════════════════════════════════════════════════════
        // INVOICES
        // ════════════════════════════════════════════════════════════════
        _ACard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardHeader(title: 'INVOICES'),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: _InvoiceStat(
              label: 'Total Invoices', value: '${txns.length}',
              sub: '₹${totalBilled.toInt()} billed',
              color: primary, isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _InvoiceStat(
              label: 'Unpaid', value: '$unpaidCount',
              sub: '₹${totalUnpaid.toInt()} overdue',
              color: AppColors.dangerColor(isDark), isDark: isDark,
            )),
          ]),

          const SizedBox(height: 14),

          // Stacked horizontal bar — overdue (red) + not due yet (amber)
          Builder(builder: (_) {
            final paidFrac   = totalBilled > 0 ? (totalPaid   / totalBilled).clamp(0.0, 1.0) : 0.0;
            final unpaidFrac = totalBilled > 0 ? (totalUnpaid / totalBilled).clamp(0.0, 1.0) : 0.0;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // amounts row
              Row(children: [
                Text('₹${totalUnpaid.toInt()}',
                    style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800,
                        color: AppColors.dangerColor(isDark))),
                const Spacer(),
                Text('₹${totalPaid.toInt()}',
                    style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800,
                        color: AppColors.warningColor(isDark))),
              ]),
              Row(children: [
                Text('Overdue',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.inkMuted)),
                const Spacer(),
                Text('Not due yet',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.inkMuted)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(children: [
                    if (unpaidFrac > 0)
                      Expanded(flex: (unpaidFrac * 100).round().clamp(1, 99),
                          child: Container(color: AppColors.dangerColor(isDark))),
                    if (paidFrac > 0)
                      Expanded(flex: (paidFrac * 100).round().clamp(1, 99),
                          child: Container(color: AppColors.warningColor(isDark))),
                  ]),
                ),
              ),
            ]);
          }),
        ])),

        const SizedBox(height: 14),

        // ════════════════════════════════════════════════════════════════
        // PROFIT & LOSS
        // ════════════════════════════════════════════════════════════════
        _ACard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: _CardHeader(title: 'PROFIT & LOSS')),
            _FilterDropdown(
              value: _plFilter, options: _filters, isDark: isDark,
              onChanged: (v) => setState(() => _plFilter = v),
            ),
          ]),
          const SizedBox(height: 10),

          Text('₹${plNet.toInt()}',
              style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w800,
                  color: plNet >= 0 ? AppColors.successColor(isDark) : AppColors.dangerColor(isDark))),
          Text('Net income for $_plFilter',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.inkMuted)),

          const SizedBox(height: 16),

          _PLBar(label: '₹${plRev.toInt()}', value: plRev, max: plMax,
              color: AppColors.successColor(isDark), isDark: isDark),
          const SizedBox(height: 10),
          _PLBar(label: '₹${plExp.toInt()}', value: plExp, max: plMax,
              color: AppColors.dangerColor(isDark), isDark: isDark),

          const SizedBox(height: 12),
          Row(children: [
            _LegendDot(color: AppColors.successColor(isDark)),
            const SizedBox(width: 5),
            Text('Revenue', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.inkMuted)),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.dangerColor(isDark)),
            const SizedBox(width: 5),
            Text('Expenses', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.inkMuted)),
          ]),
        ])),

        const SizedBox(height: 14),

        // ════════════════════════════════════════════════════════════════
        // EXPENSES PIE CHART
        // ════════════════════════════════════════════════════════════════
        _ACard(isDark: isDark, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: _CardHeader(title: 'EXPENSES')),
            _FilterDropdown(
              value: _expFilter, options: _filters, isDark: isDark,
              onChanged: (v) => setState(() => _expFilter = v),
            ),
          ]),
          const SizedBox(height: 16),

          // Donut
          Center(child: SizedBox(
            width: 180, height: 180,
            child: CustomPaint(
              painter: _DonutPainter(
                data: expMap.values.toList(),
                colors: expColors,
                isDark: isDark,
                bgColor: isDark ? AppColors.cardDark : Colors.white,
              ),
            ),
          )),

          const SizedBox(height: 16),

          // Legend rows
          ...expMap.entries.toList().asMap().entries.map((e) {
            final idx   = e.key;
            final entry = e.value;
            final col   = expColors[idx % expColors.length];
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  _LegendDot(color: col, size: 10),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.key,
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500))),
                  Text('₹${entry.value.toInt()}',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
              if (idx < expMap.length - 1)
                Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
            ]);
          }),

          Divider(height: 20, color: isDark ? AppColors.separatorDark : AppColors.separator),
          Row(children: [
            Text('Total Expense',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface)),
            const Spacer(),
            Text('₹${expTotal.toInt()}',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800,
                    color: AppColors.dangerColor(isDark))),
          ]),
        ])),
      ]),
    );
  }
}

// ── Shared analytics card ─────────────────────────────────────────────────────
class _ACard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _ACard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
          blurRadius: 12, spreadRadius: 0, offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

// ── Card header ───────────────────────────────────────────────────────────────
class _CardHeader extends StatelessWidget {
  final String title;
  const _CardHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface));
}

// ── Stat tile ─────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _StatTile({required this.label, required this.value,
      required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(value, style: GoogleFonts.syne(
            fontSize: 15, fontWeight: FontWeight.w800, color: color))),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.dmSans(
          fontSize: 9, fontWeight: FontWeight.w600, color: color),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  ));
}

// ── Invoice stat box ──────────────────────────────────────────────────────────
class _InvoiceStat extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final bool isDark;
  const _InvoiceStat({required this.label, required this.value,
      required this.sub, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(
          fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.syne(
          fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(sub, style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.inkMuted)),
    ]),
  );
}

// ── Filter dropdown pill ──────────────────────────────────────────────────────
class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final bool isDark;
  final ValueChanged<String> onChanged;
  const _FilterDropdown({required this.value, required this.options,
      required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () async {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final offset = box.localToGlobal(Offset.zero);
        final result = await showMenu<String>(
          context: context,
          color: isDark ? AppColors.cardDark : Colors.white,
          position: RelativeRect.fromLTRB(
              offset.dx, offset.dy + box.size.height + 4,
              offset.dx + box.size.width, 0),
          items: options.map((o) => PopupMenuItem(
            value: o,
            child: Text(o, style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: o == value ? FontWeight.w700 : FontWeight.w400,
                color: o == value ? primary : Theme.of(context).colorScheme.onSurface)),
          )).toList(),
        );
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.20)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w700, color: primary)),
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: primary),
        ]),
      ),
    );
  }
}

// ── P&L horizontal bar ────────────────────────────────────────────────────────
class _PLBar extends StatelessWidget {
  final String label;
  final double value, max;
  final Color color;
  final bool isDark;
  const _PLBar({required this.label, required this.value,
      required this.max, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    final filled = (pct * 100).round().clamp(1, 100);
    final empty  = (100 - filled).clamp(0, 99);
    return Row(children: [
      Flexible(
        flex: 2,
        child: Text(label, style: GoogleFonts.dmSans(
            fontSize: 13, fontWeight: FontWeight.w700, color: color),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(width: 8),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          height: 14,
          child: Row(children: [
            Expanded(flex: filled, child: Container(color: color)),
            if (empty > 0)
              Expanded(flex: empty,
                  child: Container(
                    color: isDark ? AppColors.surface2Dark : AppColors.surface2)),
          ]),
        ),
      )),
    ]);
  }
}

// ── Legend dot ────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final double size;
  const _LegendDot({required this.color, this.size = 8});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ── Donut chart painter ────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;
  final bool isDark;
  final Color bgColor;
  const _DonutPainter({required this.data, required this.colors,
      required this.isDark, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold(0.0, (a, b) => a + b);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy);
    final strokeW = r * 0.40;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2);

    if (total <= 0) {
      // draw empty grey ring
      canvas.drawArc(rect, 0, 2 * math.pi, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..color = (isDark ? AppColors.surface2Dark : AppColors.surface2));
      return;
    }

    double start = -math.pi / 2;
    for (var i = 0; i < data.length; i++) {
      if (data[i] <= 0) continue;
      final sweep = (data[i] / total) * 2 * math.pi;
      canvas.drawArc(rect, start, sweep - 0.05, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..color = colors[i % colors.length]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.data != data || old.isDark != isDark;
}

// ══════════════════════════════════════════════════════════════════════════════
// QUICK DELIVERY SHEET — Daily or Event tab, opens the right form
// ══════════════════════════════════════════════════════════════════════════════
class _QuickDeliverySheet extends ConsumerStatefulWidget {
  final bool isDark;
  const _QuickDeliverySheet({required this.isDark});
  @override
  ConsumerState<_QuickDeliverySheet> createState() => _QuickDeliverySheetState();
}

class _QuickDeliverySheetState extends ConsumerState<_QuickDeliverySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

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
    final isDark  = widget.isDark;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Tab selector
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tc,
          indicator: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _tc.index == 0
                  ? primary.withValues(alpha: 0.35)
                  : AppColors.purple.withValues(alpha: 0.35),
            ),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 5)],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: _tc.index == 0 ? primary : AppColors.purple,
          unselectedLabelColor: AppColors.inkMuted,
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping_rounded, size: 16), text: 'Daily'),
            Tab(icon: Icon(Icons.celebration_rounded, size: 16), text: 'Event'),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Forms — rendered directly (not scrollable TabBarView, so the sheet
      // can scroll naturally around the form content)
      if (_tc.index == 0)
        DeliveryForm()
      else
        EventForm(),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// QUICK PAYMENT FORM — pick customer then record payment
// ══════════════════════════════════════════════════════════════════════════════
class _QuickPaymentForm extends ConsumerStatefulWidget {
  final bool isDark;
  const _QuickPaymentForm({required this.isDark});
  @override
  ConsumerState<_QuickPaymentForm> createState() => _QuickPaymentFormState();
}

class _QuickPaymentFormState extends ConsumerState<_QuickPaymentForm> {
  Customer? _selected;
  final _amt  = TextEditingController();
  final _note = TextEditingController();
  String _mode = 'cash';
  String _search = '';

  @override
  void dispose() { _amt.dispose(); _note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark    = widget.isDark;
    final primary   = Theme.of(context).colorScheme.primary;
    final customers = ref.watch(customersProvider);
    final filtered  = customers.where((c) =>
        c.name.toLowerCase().contains(_search.toLowerCase()) ||
        c.phone.contains(_search)).toList();

    // ── Step 1: pick customer ────────────────────────────────────────────
    if (_selected == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Voice fill button
        Row(children: [
          VoiceMicButton(
            formType: VoiceFormType.payment,
            onResult: (r) {
              if (r.customer != null) {
                setState(() {
                  _selected = r.customer;
                  _amt.text = r.payment.toInt().toString();
                });
              }
            },
          ),
          const SizedBox(width: 8),
          Text('Fill by voice',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.inkMuted)),
        ]),
        const SizedBox(height: 12),
        Text('Select Customer', style: GoogleFonts.dmSans(
            fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        // Search
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
          ),
          child: Row(children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.search_rounded, color: AppColors.inkMuted, size: 18)),
            Expanded(child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
                hintStyle: GoogleFonts.dmSans(color: AppColors.inkMuted, fontSize: 13),
              ),
            )),
          ]),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: filtered.length,
            separatorBuilder: (_, __) => Divider(height: 1,
                color: isDark ? AppColors.separatorDark : AppColors.separator),
            itemBuilder: (ctx, i) {
              final c = filtered[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CustomerAvatar(initials: c.initials, size: 36),
                title: Text(c.name, style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(c.hasDues
                    ? '₹${c.ledgerBalance.abs().toInt()} due'
                    : c.hasCredit ? '+₹${c.creditBalance.toInt()} credit' : 'Clear',
                  style: GoogleFonts.dmSans(fontSize: 11,
                      color: c.hasDues ? AppColors.dangerColor(isDark)
                           : c.hasCredit ? AppColors.successColor(isDark)
                           : AppColors.inkMuted)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted, size: 18),
                onTap: () => setState(() => _selected = c),
              );
            },
          ),
        ),
      ]);
    }

    // ── Step 2: enter amount ─────────────────────────────────────────────
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Customer header
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          CustomerAvatar(initials: _selected!.initials, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selected!.name, style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w700)),
            if (_selected!.hasDues)
              Text('Due: ₹${_selected!.ledgerBalance.abs().toInt()}',
                  style: GoogleFonts.dmSans(fontSize: 12,
                      color: AppColors.dangerColor(isDark))),
          ])),
          GestureDetector(
            onTap: () => setState(() { _selected = null; _amt.clear(); }),
            child: Text('Change', style: GoogleFonts.dmSans(
                fontSize: 12, color: primary, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),

      const SizedBox(height: 16),
      FieldLabel('Amount'),
      TextFormField(
        controller: _amt,
        keyboardType: TextInputType.number,
        autofocus: true,
        style: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w800),
        decoration: const InputDecoration(hintText: '0', prefixText: '₹ '),
      ),

      const SizedBox(height: 16),
      FieldLabel('Payment Mode'),
      Row(children: ['cash', 'upi', 'bank'].map((m) {
        final active = _mode == m;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _mode = m),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? primary.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? primary : Theme.of(context).dividerColor),
            ),
            child: Center(child: Text(m.toUpperCase(),
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? primary : AppColors.inkMuted))),
          ),
        ));
      }).toList()),

      const SizedBox(height: 16),
      FieldLabel('Note (optional)'),
      TextFormField(controller: _note,
          decoration: const InputDecoration(hintText: 'Reference, cheque no...')),

      const SizedBox(height: 24),
      GradientButton(
        label: 'Record Payment',
        onTap: () {
          final val = double.tryParse(_amt.text) ?? 0;
          if (val <= 0) { showToast(context, 'Enter a valid amount', error: true); return; }
          final tx = JarTransaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            customerId: _selected!.id,
            customerName: _selected!.name,
            date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            createdAt: DateTime.now().toIso8601String(),
            billedAmount: 0,
            amountCollected: val,
            paymentMode: _mode,
            note: _note.text,
            createdBy: 'Admin',
          );
          ref.read(transactionsProvider.notifier).add(tx);
          Navigator.pop(context);
          showToast(context, '✅ Payment recorded', success: true);
        },
      ),
    ]);
  }
}

// Expense form and categories live in expenses/expenses_screen.dart

