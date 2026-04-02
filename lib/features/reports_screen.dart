import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// REPORT DEFINITIONS  — grouped by category
// ══════════════════════════════════════════════════════════════════════════════
class _RDef {
  final String id, title, desc, icon;
  final Color Function(bool) color;
  const _RDef({required this.id, required this.title,
      required this.desc, required this.icon, required this.color});
}

class _RGroup {
  final String name;
  final List<_RDef> items;
  const _RGroup(this.name, this.items);
}

final _groups = <_RGroup>[
  _RGroup('Customer & Invoice', [
    _RDef(id:'invoice', title:'Customer Invoice', icon:'🧾',
      desc:'Itemised per-customer invoice with activity type — printable & shareable',
      color:(d)=>AppColors.primaryColor(d)),
    _RDef(id:'ledger',  title:'Customer Ledger',  icon:'📒',
      desc:'Full transaction history with jar movements, timestamps & running balance',
      color:(d)=>AppColors.warningColor(d)),
  ]),
  _RGroup('Delivery & Stock', [
    _RDef(id:'delivery', title:'Delivery Report', icon:'🚚',
      desc:'All deliveries & returns with jar counts, type and timestamp per day',
      color:(d)=>AppColors.coolColor(d)),
    _RDef(id:'stock',    title:'Stock Report',    icon:'🏭',
      desc:'Warehouse in/out movements and current inventory levels',
      color:(d)=>AppColors.petColor(d)),
  ]),
  _RGroup('Payments & Finance', [
    _RDef(id:'outstanding', title:'Outstanding Dues', icon:'⏳',
      desc:'All customers with pending balance or advance credit',
      color:(d)=>AppColors.dangerColor(d)),
    _RDef(id:'payment',  title:'Payment Collection', icon:'💵',
      desc:'Collections by mode: Cash, UPI, Bank — with totals and timestamps',
      color:(d)=>AppColors.successColor(d)),
    _RDef(id:'sales',    title:'Sales Report',       icon:'📈',
      desc:'Revenue breakdown by product, customer and period',
      color:(d)=>AppColors.primaryColor(d)),
    _RDef(id:'expense',  title:'Expense Report',     icon:'📉',
      desc:'Operational expenses recorded in the Expenses screen by category',
      color:(d)=>AppColors.dangerColor(d)),
    _RDef(id:'pnl',      title:'Profit & Loss',      icon:'💹',
      desc:'Net revenue vs operational expenses with margin percentage',
      color:(d)=>AppColors.successColor(d)),
  ]),
  _RGroup('Events', [
    _RDef(id:'event',     title:'Event Report',    icon:'🎉',
      desc:'All event deliveries with status, jar summary and timestamps',
      color:(d)=>AppColors.purple),
    _RDef(id:'event_pay', title:'Event Payments',  icon:'🎪',
      desc:'Billed vs collected vs pending for all events',
      color:(d)=>AppColors.purple),
  ]),
  _RGroup('Inventory & Jars', [
    _RDef(id:'jar_balance', title:'Jar Balance', icon:'🫙',
      desc:'How many Cool & PET jars each customer currently holds',
      color:(d)=>AppColors.coolColor(d)),
  ]),
];

// ══════════════════════════════════════════════════════════════════════════════
// MAIN REPORTS SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<ReportsScreen> {
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_openId != null) {
      final def = _groups.expand((g) => g.items).firstWhere((r) => r.id == _openId);
      return _ReportPage(def: def, onBack: () => setState(() => _openId = null));
    }

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text('Reports', style: Theme.of(context).textTheme.headlineLarge)),
          const SizedBox(height: 4),
          Text('Select a report, set date range, choose format & export',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
        ]),
      )),
      SliverList(delegate: SliverChildBuilderDelegate((ctx, gi) {
        final group = _groups[gi];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(group.name, style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8,
                color: AppColors.inkMuted)),
          ),
          ...group.items.map((def) => _ReportRow(
            def: def, isDark: isDark,
            onTap: () => setState(() => _openId = def.id),
          )),
        ]);
      }, childCount: _groups.length)),
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ]);
  }
}

// ── Row-style report entry ─────────────────────────────────────────────────────
class _ReportRow extends StatelessWidget {
  final _RDef def;
  final bool isDark;
  final VoidCallback onTap;
  const _ReportRow({required this.def, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = def.color(isDark);
    final w = MediaQuery.of(context).size.width;
    final compact = w < 360;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        child: Row(children: [
          Container(
            width: compact ? 38 : 44, height: compact ? 38 : 44,
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(def.icon,
                style: TextStyle(fontSize: compact ? 18 : 20))),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(def.title, style: GoogleFonts.inter(
                fontSize: compact ? 13 : 14, fontWeight: FontWeight.w700, color: c),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(def.desc, style: GoogleFonts.inter(
                fontSize: compact ? 10 : 11, color: AppColors.inkMuted, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkMuted),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REPORT PAGE  — date picker, format, generate, share
// ══════════════════════════════════════════════════════════════════════════════
class _ReportPage extends ConsumerStatefulWidget {
  final _RDef def;
  final VoidCallback onBack;
  const _ReportPage({required this.def, required this.onBack});
  @override
  ConsumerState<_ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<_ReportPage> {
  // ── Date ────────────────────────────────────────────────────────────────────
  String   _preset = 'Today';
  DateTime _from   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to     = DateTime.now();

  // ── Customer ────────────────────────────────────────────────────────────────
  String  _custSearch = '';
  String? _customerId;          // null = All Customers

  // ── Other filters ───────────────────────────────────────────────────────────
  String _format     = 'pdf';
  String _ledgerType = 'all';

  // ── State ───────────────────────────────────────────────────────────────────
  bool _generating = false;
  bool _generated  = false;

  static const _presets = ['Today', 'This Week', 'This Month', 'Custom'];

  Color get _c => widget.def.color(Theme.of(context).brightness == Brightness.dark);

  void _applyPreset(String p) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _preset    = p;
      _generated = false;
      switch (p) {
        case 'Today':
          _from = today; _to = today; break;
        case 'This Week':
          _from = today.subtract(Duration(days: today.weekday - 1));
          _to   = today; break;
        case 'This Month':
          _from = DateTime(now.year, now.month, 1);
          _to   = today; break;
        case 'Custom':
          break; // keep current range, user will pick
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _applyPreset('Today');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c      = _c;

    // ── Invoice → dedicated smart screen ────────────────────────────────────
    if (widget.def.id == 'invoice') {
      return _InvoiceFilterScreen(def: widget.def, onBack: widget.onBack);
    }

    // ── Customer data ────────────────────────────────────────────────────────
    final allCusts = ref.watch(customersProvider)
        .where((cu) => cu.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final filteredCusts = _custSearch.isEmpty
        ? allCusts
        : allCusts.where((cu) =>
            cu.name.toLowerCase().contains(_custSearch.toLowerCase()) ||
            cu.phone.contains(_custSearch)).toList();

    Customer? selCust;
    if (_customerId != null) {
      try { selCust = allCusts.firstWhere((cu) => cu.id == _customerId); }
      catch (_) { _customerId = null; }
    }

    // Last txn date per customer
    final txns = ref.watch(transactionsProvider);
    final Map<String, String> lastTxnDate = {};
    for (final t in txns) {
      if (!lastTxnDate.containsKey(t.customerId) ||
          t.date.compareTo(lastTxnDate[t.customerId]!) > 0) {
        lastTxnDate[t.customerId] = t.date;
      }
    }

    final needsCustomer = !['stock','expense','pnl','outstanding'].contains(widget.def.id);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [

        // ── Header ────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.card,
            border: Border(bottom: BorderSide(
                color: isDark ? AppColors.separatorDark : AppColors.separator)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark ? AppColors.separatorDark : AppColors.separator),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.def.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: FittedBox(
              fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(widget.def.title, style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w700, color: c)))),
          ]),
        ),

        // ── Scrollable body ───────────────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ══════════════════════════════════════════════════════════════════
            // 1. DATE RANGE — quick presets + compact row
            // ══════════════════════════════════════════════════════════════════
            _IFSection(label: '📅 Date Range', isDark: isDark, child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Quick preset row
                Row(children: _presets.map((p) {
                  final active = _preset == p;
                  return Expanded(child: Padding(
                    padding: EdgeInsets.only(right: p != _presets.last ? 6 : 0),
                    child: GestureDetector(
                      onTap: () => _applyPreset(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: active
                              ? c.withValues(alpha: 0.12)
                              : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: active ? c
                                  : (isDark ? AppColors.separatorDark : AppColors.separator),
                              width: active ? 1.5 : 1),
                        ),
                        child: Center(child: Text(p,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? c : AppColors.inkMuted))),
                      ),
                    ),
                  ));
                }).toList()),

                const SizedBox(height: 10),

                // Compact date display / Custom picker trigger
                GestureDetector(
                  onTap: _preset == 'Custom'
                      ? () => _pickCustomRange(context, c) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _preset == 'Custom'
                              ? c.withValues(alpha: 0.50)
                              : (isDark ? AppColors.separatorDark : AppColors.separator)),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: c),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('d MMM yyyy').format(_from)}'
                        '  →  '
                        '${DateFormat('d MMM yyyy').format(_to)}',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      if (_preset == 'Custom') ...[
                        const Spacer(),
                        Text('Change', style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700, color: c)),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ══════════════════════════════════════════════════════════════════
            // 2. CUSTOMER — inline search (for applicable reports)
            // ══════════════════════════════════════════════════════════════════
            if (needsCustomer) ...[
              _IFSection(label: '👤 Customer', isDark: isDark, child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Selected chip
                  if (selCust != null) ...[
                    GestureDetector(
                      onTap: () => setState(() {
                        _customerId = null; _custSearch = ''; _generated = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.withValues(alpha: 0.30)),
                        ),
                        child: Row(children: [
                          CustomerAvatar(initials: selCust.initials, size: 32),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(selCust.name, style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(selCust.phone, style: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.inkMuted)),
                          ])),
                          Icon(Icons.check_circle_rounded, size: 16, color: c),
                          const SizedBox(width: 6),
                          Icon(Icons.close_rounded, size: 15,
                              color: AppColors.inkMuted),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() {
                        _customerId = null; _custSearch = ''; _generated = false;
                      }),
                      child: Text('Change customer', style: GoogleFonts.inter(
                          fontSize: 12, color: c, fontWeight: FontWeight.w600)),
                    ),
                  ] else ...[

                    // "All Customers" option pill
                    GestureDetector(
                      onTap: () => setState(() {
                        _customerId = null; _generated = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _customerId == null
                              ? c.withValues(alpha: 0.10)
                              : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _customerId == null
                                  ? c
                                  : (isDark ? AppColors.separatorDark : AppColors.separator),
                              width: _customerId == null ? 1.5 : 1),
                        ),
                        child: Row(children: [
                          Icon(Icons.people_rounded, size: 16,
                              color: _customerId == null ? c : AppColors.inkMuted),
                          const SizedBox(width: 8),
                          Text('All Customers', style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: _customerId == null
                                  ? FontWeight.w700 : FontWeight.w500,
                              color: _customerId == null ? c : AppColors.inkMuted)),
                          if (_customerId == null) ...[
                            const Spacer(),
                            Icon(Icons.check_circle_rounded, size: 15, color: c),
                          ],
                        ]),
                      ),
                    ),

                    // Search bar
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDark ? AppColors.separatorDark : AppColors.separator),
                      ),
                      child: Row(children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.search_rounded,
                              color: AppColors.inkMuted, size: 16),
                        ),
                        Expanded(child: TextField(
                          onChanged: (v) => setState(() => _custSearch = v),
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by name or phone...',
                            border: InputBorder.none, filled: false,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: GoogleFonts.inter(
                                color: AppColors.inkMuted, fontSize: 13),
                          ),
                        )),
                      ]),
                    ),

                    // Customer list (constrained height)
                    if (filteredCusts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isDark ? AppColors.separatorDark : AppColors.separator),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withValues(
                                  alpha: isDark ? 0.14 : 0.06),
                              blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: filteredCusts.length,
                            separatorBuilder: (_, __) => Divider(height: 1,
                                color: isDark
                                    ? AppColors.separatorDark : AppColors.separator),
                            itemBuilder: (ctx, i) {
                              final cu       = filteredCusts[i];
                              final lastDate = lastTxnDate[cu.id];
                              return InkWell(
                                onTap: () => setState(() {
                                  _customerId = cu.id;
                                  _custSearch = '';
                                  _generated  = false;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 9),
                                  child: Row(children: [
                                    CustomerAvatar(
                                        initials: cu.initials, size: 32),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                      Text(cu.name, style: GoogleFonts.inter(
                                          fontSize: 13, fontWeight: FontWeight.w700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Row(children: [
                                        Text(cu.phone, style: GoogleFonts.inter(
                                            fontSize: 10, color: AppColors.inkMuted)),
                                        if (lastDate != null)
                                          Text(
                                            '  ·  ${() { try { return DateFormat('dd MMM yy').format(DateTime.parse(lastDate)); } catch (_) { return ''; } }()}',
                                            style: GoogleFonts.inter(
                                                fontSize: 10, color: AppColors.inkMuted),
                                          ),
                                      ]),
                                    ])),
                                    if (cu.hasDues)
                                      _StatusBadge(
                                          label: '₹${cu.balance.abs().toInt()} Due',
                                          color: AppColors.dangerColor(isDark))
                                    else if (cu.hasCredit)
                                      _StatusBadge(
                                          label: '₹${cu.balance.toInt()} Cr',
                                          color: AppColors.successColor(isDark)),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // ══════════════════════════════════════════════════════════════════
            // 3. LEDGER TYPE FILTER (All / Daily / Event)
            // ══════════════════════════════════════════════════════════════════
            if (widget.def.id == 'ledger') ...[
              _IFSection(label: '🔀 Transaction Type', isDark: isDark, child:
                Row(children: [
                  for (final entry in [
                    ('All',   'all',   c),
                    ('Daily', 'daily', AppColors.primaryColor(isDark)),
                    ('Event', 'event', AppColors.purple),
                  ]) ...[
                    if (entry != ('All', 'all', c)) const SizedBox(width: 8),
                    Expanded(child: _LedgerTypeBtn(
                        label: entry.$1, value: entry.$2,
                        sel: _ledgerType, c: entry.$3, isDark: isDark,
                        onTap: () => setState(() {
                          _ledgerType = entry.$2; _generated = false;
                        }))),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // ══════════════════════════════════════════════════════════════════
            // 4. EXPORT FORMAT
            // ══════════════════════════════════════════════════════════════════
            _IFSection(label: '📤 Export Format', isDark: isDark, child:
              Row(children: [
                Expanded(child: _FmtBtn(
                    label: 'PDF', icon: Icons.picture_as_pdf_rounded,
                    selected: _format == 'pdf',
                    color: AppColors.dangerColor(isDark), isDark: isDark,
                    onTap: () => setState(() => _format = 'pdf'))),
                const SizedBox(width: 10),
                Expanded(child: _FmtBtn(
                    label: 'Excel', icon: Icons.table_chart_rounded,
                    selected: _format == 'excel',
                    color: AppColors.successColor(isDark), isDark: isDark,
                    onTap: () => setState(() => _format = 'excel'))),
              ]),
            ),

            const SizedBox(height: 20),

            // ══════════════════════════════════════════════════════════════════
            // 5. GENERATE BUTTON
            // ══════════════════════════════════════════════════════════════════
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _generating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: c.withValues(alpha: 0.50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _generating
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 10),
                        Text('Generating…', style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                      ])
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.auto_awesome_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Generate Report', style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),

            // ══════════════════════════════════════════════════════════════════
            // 6. POST-GENERATION: actions + success banner + preview
            // ══════════════════════════════════════════════════════════════════
            if (_generated) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _ActionBtn(
                    icon: Icons.share_rounded, label: 'Share',
                    color: AppColors.primaryColor(isDark), isDark: isDark,
                    onTap: _share)),
                const SizedBox(width: 10),
                Expanded(child: _ActionBtn(
                    icon: Icons.download_rounded, label: 'Download',
                    color: AppColors.successColor(isDark), isDark: isDark,
                    onTap: _download)),
                const SizedBox(width: 10),
                Expanded(child: _ActionBtn(
                    icon: Icons.print_rounded, label: 'Print',
                    color: AppColors.warningColor(isDark), isDark: isDark,
                    onTap: _print)),
              ]),
              const SizedBox(height: 12),
              // Success banner
              _IFSection(label: '', isDark: isDark, child:
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.successColor(isDark).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.check_circle_rounded, size: 20,
                        color: AppColors.successColor(isDark)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Report ready', style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.successColor(isDark))),
                    Text(
                      '${widget.def.title} · '
                      '${DateFormat("dd MMM").format(_from)} – '
                      '${DateFormat("dd MMM yyyy").format(_to)} · '
                      '${_format.toUpperCase()}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.inkMuted),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ])),
                ]),
              ),
              const SizedBox(height: 12),
              _ReportPreview(def: widget.def, from: _from, to: _to,
                  customerId: _customerId, isDark: isDark, c: c,
                  ledgerType: _ledgerType),
            ],
          ]),
        )),
      ]),
    );
  }

  // ── Custom date range picker ─────────────────────────────────────────────────
  Future<void> _pickCustomRange(BuildContext context, Color c) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: c)),
        child: child!,
      ),
    );
    if (range != null) setState(() {
      _from = range.start; _to = range.end; _generated = false;
    });
  }

  // cached data for export
  List<List<String>> _exportRows = [];
  List<String>       _exportHeads = [];
  String             _exportTitle = '';

  Future<void> _generate() async {
    setState(() { _generating = true; _generated = false; });
    // Gather data into exportable rows
    _buildExportData();
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() { _generating = false; _generated = true; });
  }

  void _buildExportData() {
    final txns  = ref.read(transactionsProvider);
    final custs = ref.read(customersProvider);
    final filt  = txns.where((t) {
      try {
        final d = DateTime.parse(t.date);
        return !d.isBefore(_from) && !d.isAfter(_to.add(const Duration(days: 1)));
      } catch (_) { return false; }
    }).toList();
    final byC = _customerId != null
        ? filt.where((t) => t.customerId == _customerId).toList() : filt;

    _exportTitle = widget.def.title;
    switch (widget.def.id) {
      case 'invoice':
        // Invoice = per-customer summary for the period: jar totals + billing
        final custTxns = byC.where((t) =>
            t.customerId != 'EXPENSE' &&
            (t.coolDelivered > 0 || t.petDelivered > 0)).toList();
        if (_customerId != null && custTxns.isNotEmpty) {
          final coolDel  = custTxns.fold(0, (s, t) => s + t.coolDelivered);
          final petDel   = custTxns.fold(0, (s, t) => s + t.petDelivered);
          final coolRet  = custTxns.fold(0, (s, t) => s + t.coolReturned);
          final petRet   = custTxns.fold(0, (s, t) => s + t.petReturned);
          final coolPrice = custTxns.isNotEmpty ? custTxns.first.coolPrice : 0.0;
          final petPrice  = custTxns.isNotEmpty ? custTxns.first.petPrice  : 0.0;
          final billed   = custTxns.fold(0.0, (s, t) => s + t.billedAmount);
          final paid     = custTxns.fold(0.0, (s, t) => s + t.amountCollected);
          _exportHeads = ['Item', 'Detail'];
          _exportRows  = [
            ['Cool Delivered',  '$coolDel jars × ₹${coolPrice.toInt()} = ₹${(coolDel * coolPrice).toInt()}'],
            ['PET Delivered',   '$petDel jars × ₹${petPrice.toInt()} = ₹${(petDel * petPrice).toInt()}'],
            ['Cool Returned',   '$coolRet jars'],
            ['PET Returned',    '$petRet jars'],
            ['Cool With Customer', '${coolDel - coolRet} jars'],
            ['PET With Customer',  '${petDel - petRet} jars'],
            ['---', '---'],
            ['Total Billed',  '₹${billed.toInt()}'],
            ['Amount Paid',   '₹${paid.toInt()}'],
            ['Balance Due',   '₹${(billed - paid).toInt()}'],
          ];
        } else {
          _exportHeads = ['Customer','Cool Del','PET Del','Billed','Paid','Due'];
          final byCust = <String, List<JarTransaction>>{};
          for (final t in custTxns) byCust.putIfAbsent(t.customerId, () => []).add(t);
          _exportRows = byCust.entries.map((e) {
            final cd = e.value.fold(0, (s, t) => s + t.coolDelivered);
            final pd = e.value.fold(0, (s, t) => s + t.petDelivered);
            final b  = e.value.fold(0.0, (s, t) => s + t.billedAmount);
            final p  = e.value.fold(0.0, (s, t) => s + t.amountCollected);
            return [e.value.first.customerName,'$cd','$pd','₹${b.toInt()}','₹${p.toInt()}','₹${(b-p).toInt()}'];
          }).toList();
        }
      case 'ledger':
        final custTxns = byC.where((t) => t.customerId != 'EXPENSE').toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // oldest-first for balance calc
        final filtered = _ledgerType == 'all' ? custTxns
            : _ledgerType == 'event'
                ? custTxns.where((t) => t.deliveryType == 'event').toList()
                : custTxns.where((t) => t.deliveryType != 'event').toList();
        _exportHeads = ['Date & Time','Customer','Type','Jars','Billed','Paid','Balance'];
        // Pre-compute balance per tx oldest→newest
        double running = 0;
        final Map<String, String> rbMap = {};
        for (final t in filtered) {
          running += (t.billedAmount - t.amountCollected);
          rbMap[t.id] = running == 0 ? 'Settled'
              : running > 0 ? '₹${running.toInt()} due'
              : '₹${running.abs().toInt()} advance';
        }
        // Display newest-first
        _exportRows = filtered.reversed.map((t) {
          final type = t.billedAmount == 0 && t.amountCollected > 0
              ? (t.paymentMode == 'advance' ? 'Advance' : 'Payment')
              : t.deliveryType == 'event' ? 'Event' : 'Daily';
          final jars = [
            if (t.coolDelivered > 0) '↓${t.coolDelivered}C',
            if (t.petDelivered  > 0) '↓${t.petDelivered}P',
            if (t.coolReturned  > 0) '↑${t.coolReturned}C',
            if (t.petReturned   > 0) '↑${t.petReturned}P',
          ].join(' ');
          return [
            _fdt(t.createdAt), t.customerName, type,
            jars.isEmpty ? '—' : jars,
            '₹${t.billedAmount.toInt()}', '₹${t.amountCollected.toInt()}',
            rbMap[t.id] ?? '—',
          ];
        }).toList();
      case 'delivery':
        // Only daily transactions that have actual jar movement (not payment-only, not events)
        final deliveries = byC.where((t) =>
            t.customerId != 'EXPENSE' &&
            t.deliveryType != 'event' &&
            (t.coolDelivered > 0 || t.petDelivered > 0 ||
             t.coolReturned  > 0 || t.petReturned  > 0)).toList();
        _exportHeads = ['Date & Time','Customer','Cool↓','Cool↑','PET↓','PET↑'];
        _exportRows  = deliveries.map((t) => [
          _fdt(t.createdAt), t.customerName,
          '${t.coolDelivered}', '${t.coolReturned}',
          '${t.petDelivered}',  '${t.petReturned}',
        ]).toList();
      case 'payment':
        final payments = byC.where((t) => t.amountCollected > 0 && t.customerId != 'EXPENSE').toList();
        _exportHeads = ['Date & Time','Customer','Mode','Type','Billed','Collected'];
        _exportRows  = payments.map((t) => [
          _fdt(t.createdAt), t.customerName,
          t.paymentMode.toUpperCase(),
          t.deliveryType == 'event' ? 'Event' : 'Daily',
          '₹${t.billedAmount.toInt()}', '₹${t.amountCollected.toInt()}',
        ]).toList();
      case 'outstanding':
        _exportHeads = ['Customer', 'Phone', 'Area', 'Balance'];
        _exportRows  = custs.where((c) => c.balance != 0).map((c) => [
          c.name, c.phone, c.area,
          c.balance < 0 ? '₹${c.balance.abs().toInt()} due' : '₹${c.balance.toInt()} adv',
        ]).toList();
      case 'jar_balance':
        _exportHeads = ['Customer', 'Phone', 'Cool Out', 'PET Out'];
        _exportRows  = custs.where((c) => c.hasJarsOut).map((c) => [
          c.name, c.phone, '${c.coolOut}', '${c.petOut}',
        ]).toList();
      case 'sales':
        final rev = byC.fold(0.0, (s, t) => s + t.billedAmount);
        final col = byC.fold(0.0, (s, t) => s + t.amountCollected);
        _exportHeads = ['Line', 'Amount'];
        _exportRows  = [
          ['Cool Revenue', '₹${byC.fold(0.0,(s,t)=>s+t.coolDelivered*t.coolPrice).toInt()}'],
          ['PET Revenue',  '₹${byC.fold(0.0,(s,t)=>s+t.petDelivered*t.petPrice).toInt()}'],
          ['Transport',    '₹${byC.fold(0.0,(s,t)=>s+t.transportFee).toInt()}'],
          ['Damage Charges','₹${byC.fold(0.0,(s,t)=>s+t.damageCharge).toInt()}'],
          ['TOTAL',        '₹${rev.toInt()}'],
          ['Collected',    '₹${col.toInt()}'],
          ['Pending',      '₹${(rev-col).toInt()}'],
        ];
      case 'expense':
        final expOnly = filt.where((t) => t.customerId == 'EXPENSE').toList();
        _exportHeads = ['Date', 'Category', 'Payment Mode', 'Amount'];
        _exportRows  = expOnly.map((t) => [
          _fd(t.date), t.customerName, t.paymentMode.toUpperCase(), _fm(t.damageCharge),
        ]).toList();
      case 'event':
        // Group transactions into logical events — one row per event
        final eventGroups = _groupEventTxns(filt);
        _exportHeads = ['Date', 'Customer', 'Event', 'Cool↓', 'PET↓',
                        'Cool↑', 'PET↑', 'Billed', 'Paid', 'Pending', 'Status'];
        _exportRows  = eventGroups.map((g) => [
          _fd(g.date),
          g.customerName,
          g.eventName,
          '${g.coolDelivered}',
          '${g.petDelivered}',
          '${g.coolReturned}',
          '${g.petReturned}',
          _fm(g.billed),
          _fm(g.collected),
          _fm(g.pending),
          g.status?.toUpperCase() ?? '—',
        ]).toList();
      case 'event_pay':
        // Event payments — one row per logical event (grouped)
        final evPayGroups = _groupEventTxns(filt);
        _exportHeads = ['Date', 'Customer', 'Event', 'Jars',
                        'Billed', 'Paid', 'Pending'];
        _exportRows  = evPayGroups.map((g) {
          final jars = [
            if (g.coolDelivered > 0) '↓${g.coolDelivered}C',
            if (g.petDelivered  > 0) '↓${g.petDelivered}P',
            if (g.coolReturned  > 0) '↑${g.coolReturned}C',
            if (g.petReturned   > 0) '↑${g.petReturned}P',
          ].join(' ');
          return [
            _fd(g.date),
            g.customerName,
            g.eventName,
            jars.isEmpty ? '—' : jars,
            _fm(g.billed),
            _fm(g.collected),
            _fm(g.pending),
          ];
        }).toList();
      default:
        _exportHeads = ['Date & Time', 'Customer', 'Billed', 'Collected'];
        _exportRows  = byC.map((t) => [
          _fdt(t.createdAt), t.customerName,
          '₹${t.billedAmount.toInt()}', '₹${t.amountCollected.toInt()}',
        ]).toList();
    }
  }

  Future<pw.Document> _buildPdf() async {
    final pdf = pw.Document();
    final dateRange = '${DateFormat('dd MMM yyyy').format(_from)} – ${DateFormat('dd MMM yyyy').format(_to)}';
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text(_exportTitle,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Period: $dateRange',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.SizedBox(height: 16),
        if (_exportRows.isEmpty)
          pw.Text('No data for this period.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: _exportHeads.map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.Text(h, style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
                )).toList(),
              ),
              ..._exportRows.map((row) => pw.TableRow(
                children: row.map((cell) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
                )).toList(),
              )),
            ],
          ),
        pw.SizedBox(height: 20),
        pw.Text('Generated by MrWater · ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ],
    ));
    return pdf;
  }

  String _buildCsv() {
    final buf = StringBuffer();
    buf.writeln(_exportHeads.map((h) => '"$h"').join(','));
    for (final row in _exportRows) {
      buf.writeln(row.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }
    return buf.toString();
  }

  Future<void> _download() async {
    try {
      if (_format == 'pdf') {
        final pdf = await _buildPdf();
        final bytes = await pdf.save();
        final dir  = await getApplicationDocumentsDirectory();
        final name = '${_exportTitle.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}';
        final file = File('${dir.path}/$name.pdf');
        await file.writeAsBytes(bytes);
        if (mounted) showToast(context, '✅ Saved to Documents', success: true);
      } else {
        final csv  = _buildCsv();
        final dir  = await getApplicationDocumentsDirectory();
        final name = '${_exportTitle.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}';
        final file = File('${dir.path}/$name.csv');
        await file.writeAsString(csv);
        if (mounted) showToast(context, '✅ CSV saved to Documents', success: true);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Error: $e', error: true);
    }
  }

  Future<void> _share() async {
    try {
      final dir  = await getTemporaryDirectory();
      final name = '${_exportTitle.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}';
      if (_format == 'pdf') {
        final pdf   = await _buildPdf();
        final bytes = await pdf.save();
        final file  = XFile.fromData(bytes, name: '$name.pdf', mimeType: 'application/pdf');
        await Share.shareXFiles([file], subject: _exportTitle);
      } else {
        final csv  = _buildCsv();
        final file = File('${dir.path}/$name.csv');
        await file.writeAsString(csv);
        await Share.shareXFiles([XFile(file.path)], subject: _exportTitle);
      }
    } catch (e) {
      if (mounted) showToast(context, 'Share error: $e', error: true);
    }
  }

  Future<void> _print() async {
    try {
      if (_format == 'pdf') {
        final pdf = await _buildPdf();
        await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
      } else {
        // For Excel/CSV, convert to PDF first then print
        final pdf = await _buildPdf();
        await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
      }
    } catch (e) {
      if (mounted) showToast(context, 'Print error: $e', error: true);
    }
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
// INVOICE FILTER SCREEN  — smart, minimal-tap invoice report builder
// ══════════════════════════════════════════════════════════════════════════════
class _InvoiceFilterScreen extends ConsumerStatefulWidget {
  final _RDef def;
  final VoidCallback onBack;
  const _InvoiceFilterScreen({required this.def, required this.onBack});
  @override
  ConsumerState<_InvoiceFilterScreen> createState() => _InvoiceFilterScreenState();
}

class _InvoiceFilterScreenState extends ConsumerState<_InvoiceFilterScreen> {
  // Customer
  String _search        = '';
  String? _customerId;
  bool   _showCustError = false;

  // Date
  String   _preset = 'Today'; // Today | This Week | This Month | Custom
  late DateTime _from;
  late DateTime _to;

  // Format
  String _format = 'pdf';

  // State
  bool _generating = false;
  bool _generated  = false;
  List<List<String>> _exportRows  = [];
  List<String>       _exportHeads = [];

  static const _presets = ['Today', 'This Week', 'This Month', 'Custom'];

  @override
  void initState() {
    super.initState();
    _applyPreset('Today');
  }

  void _applyPreset(String p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _preset = p;
      _generated = false;
      switch (p) {
        case 'Today':
          _from = today; _to = today; break;
        case 'This Week':
          _from = today.subtract(Duration(days: today.weekday - 1));
          _to   = today; break;
        case 'This Month':
          _from = DateTime(now.year, now.month, 1);
          _to   = today; break;
        case 'Custom':
          _from = today; _to = today; break;
      }
    });
  }

  Color get _c => widget.def.color(Theme.of(context).brightness == Brightness.dark);

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final c       = _c;

    final allCusts = ref.watch(customersProvider)
        .where((cu) => cu.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Filter by search
    final filtered = _search.isEmpty
        ? allCusts
        : allCusts.where((cu) =>
            cu.name.toLowerCase().contains(_search.toLowerCase()) ||
            cu.phone.contains(_search)).toList();

    // Resolve selected customer
    Customer? selCust;
    if (_customerId != null) {
      try { selCust = allCusts.firstWhere((cu) => cu.id == _customerId); }
      catch (_) { _customerId = null; }
    }

    // Last txn date per customer
    final txns = ref.watch(transactionsProvider);
    Map<String, String> lastTxnDate = {};
    for (final t in txns) {
      if (!lastTxnDate.containsKey(t.customerId) ||
          t.date.compareTo(lastTxnDate[t.customerId]!) > 0) {
        lastTxnDate[t.customerId] = t.date;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [

        // ── Header ────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.card,
            border: Border(bottom: BorderSide(
                color: isDark ? AppColors.separatorDark : AppColors.separator)),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark ? AppColors.separatorDark : AppColors.separator),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.def.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.def.title,
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w700, color: c))),
          ]),
        ),

        // ── Body ─────────────────────────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ════════════════════════════════════════════════════════════════
            // 1. CUSTOMER SEARCH
            // ════════════════════════════════════════════════════════════════
            _IFSection(
              label: '👤 Customer',
              isDark: isDark,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Selected customer chip (if any)
                if (selCust != null) ...[
                  GestureDetector(
                    onTap: () => setState(() { _customerId = null; _generated = false; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.withValues(alpha: 0.30)),
                      ),
                      child: Row(children: [
                        CustomerAvatar(initials: selCust.initials, size: 34),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(selCust.name, style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(selCust.phone, style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.inkMuted)),
                        ])),
                        Icon(Icons.check_circle_rounded, size: 18, color: c),
                        const SizedBox(width: 6),
                        Icon(Icons.close_rounded, size: 16, color: AppColors.inkMuted),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() { _customerId = null; _search = ''; _generated = false; }),
                    child: Text('Change customer',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: c, fontWeight: FontWeight.w600)),
                  ),
                ] else ...[
                  // Search bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _showCustError
                              ? AppColors.dangerColor(isDark)
                              : (isDark ? AppColors.separatorDark : AppColors.separator)),
                    ),
                    child: Row(children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.search_rounded,
                            color: AppColors.inkMuted, size: 18),
                      ),
                      Expanded(child: TextField(
                        onChanged: (v) => setState(() {
                          _search = v;
                          _showCustError = false;
                        }),
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search customer by name or phone...',
                          border: InputBorder.none, filled: false,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: GoogleFonts.inter(
                              color: AppColors.inkMuted, fontSize: 13),
                        ),
                      )),
                    ]),
                  ),

                  // Inline validation error
                  if (_showCustError) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 14,
                          color: AppColors.dangerColor(isDark)),
                      const SizedBox(width: 5),
                      Text('⚠ Please select a customer',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.dangerColor(isDark),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],

                  const SizedBox(height: 8),

                  // Customer list
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? AppColors.separatorDark
                              : AppColors.separator),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(
                              alpha: isDark ? 0.15 : 0.06),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(child: Text('No customers found',
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: AppColors.inkMuted))),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(height: 1,
                                  color: isDark
                                      ? AppColors.separatorDark
                                      : AppColors.separator),
                              itemBuilder: (ctx, i) {
                                final cu = filtered[i];
                                final lastDate = lastTxnDate[cu.id];
                                final hasDue = cu.hasDues;
                                final hasCredit = cu.hasCredit;
                                return InkWell(
                                  onTap: () => setState(() {
                                    _customerId = cu.id;
                                    _search = '';
                                    _showCustError = false;
                                    _generated = false;
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(children: [
                                      CustomerAvatar(
                                          initials: cu.initials, size: 36),
                                      const SizedBox(width: 10),
                                      Expanded(child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(cu.name,
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        Row(children: [
                                          Text(cu.phone,
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: AppColors.inkMuted)),
                                          if (lastDate != null) ...[
                                            Text('  ·  ',
                                                style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color: AppColors.inkMuted)),
                                            Text(
                                              () {
                                                try {
                                                  return DateFormat('dd MMM yy')
                                                      .format(DateTime.parse(lastDate));
                                                } catch (_) { return ''; }
                                              }(),
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: AppColors.inkMuted),
                                            ),
                                          ],
                                        ]),
                                      ])),
                                      if (hasDue)
                                        _StatusBadge(
                                            label: '₹${cu.balance.abs().toInt()} Due',
                                            color: AppColors.dangerColor(isDark))
                                      else if (hasCredit)
                                        _StatusBadge(
                                            label: '₹${cu.balance.toInt()} Cr',
                                            color: AppColors.successColor(isDark))
                                      else
                                        _StatusBadge(
                                            label: 'Clear',
                                            color: AppColors.inkMuted),
                                    ]),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 14),

            // ════════════════════════════════════════════════════════════════
            // 2. QUICK DATE PRESETS
            // ════════════════════════════════════════════════════════════════
            _IFSection(
              label: '📅 Date Range',
              isDark: isDark,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Quick preset buttons
                Row(children: _presets.map((p) {
                  final active = _preset == p;
                  return Expanded(child: Padding(
                    padding: EdgeInsets.only(
                        right: p != _presets.last ? 6 : 0),
                    child: GestureDetector(
                      onTap: () => _applyPreset(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: active
                              ? c.withValues(alpha: 0.12)
                              : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: active
                                  ? c
                                  : (isDark ? AppColors.separatorDark : AppColors.separator),
                              width: active ? 1.5 : 1),
                        ),
                        child: Center(child: Text(p,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: active
                                    ? FontWeight.w700 : FontWeight.w500,
                                color: active ? c : AppColors.inkMuted))),
                      ),
                    ),
                  ));
                }).toList()),

                const SizedBox(height: 10),

                // Compact date row — always visible, full picker only for Custom
                GestureDetector(
                  onTap: _preset == 'Custom'
                      ? () => _pickCustomRange(context, isDark, c)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _preset == 'Custom'
                              ? c.withValues(alpha: 0.50)
                              : (isDark ? AppColors.separatorDark : AppColors.separator)),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: c),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('d MMM yyyy').format(_from)}'
                        '  →  '
                        '${DateFormat('d MMM yyyy').format(_to)}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                      if (_preset == 'Custom') ...[
                        const Spacer(),
                        Text('Change',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c)),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // ════════════════════════════════════════════════════════════════
            // 3. EXPORT FORMAT
            // ════════════════════════════════════════════════════════════════
            _IFSection(
              label: '📤 Export Format',
              isDark: isDark,
              child: Row(children: [
                Expanded(child: _FmtBtn(
                    label: 'PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    selected: _format == 'pdf',
                    color: AppColors.dangerColor(isDark),
                    isDark: isDark,
                    onTap: () => setState(() => _format = 'pdf'))),
                const SizedBox(width: 10),
                Expanded(child: _FmtBtn(
                    label: 'Excel',
                    icon: Icons.table_chart_rounded,
                    selected: _format == 'excel',
                    color: AppColors.successColor(isDark),
                    isDark: isDark,
                    onTap: () => setState(() => _format = 'excel'))),
              ]),
            ),

            const SizedBox(height: 20),

            // ════════════════════════════════════════════════════════════════
            // 4. GENERATE CTA
            // ════════════════════════════════════════════════════════════════
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _generating ? null : _handleGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: c.withValues(alpha: 0.50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _generating
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text('Generating…',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ])
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.auto_awesome_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Generate Report',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),

            // ════════════════════════════════════════════════════════════════
            // 5. SUCCESS + ACTIONS (after generation)
            // ════════════════════════════════════════════════════════════════
            if (_generated) ...[
              const SizedBox(height: 16),
              // Success banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.successColor(isDark).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.successColor(isDark).withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.successColor(isDark).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.check_circle_rounded, size: 20,
                        color: AppColors.successColor(isDark)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Report Ready',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.successColor(isDark))),
                    Text(
                      '${selCust?.name ?? 'All'} · '
                      '${DateFormat('dd MMM').format(_from)} – '
                      '${DateFormat('dd MMM yyyy').format(_to)} · '
                      '${_format.toUpperCase()}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.inkMuted),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ])),
                ]),
              ),
              const SizedBox(height: 10),
              // Share / Download / Print
              Row(children: [
                Expanded(child: _ActionBtn(
                    icon: Icons.share_rounded, label: 'Share',
                    color: AppColors.primaryColor(isDark), isDark: isDark,
                    onTap: () => _share(context))),
                const SizedBox(width: 10),
                Expanded(child: _ActionBtn(
                    icon: Icons.download_rounded, label: 'Download',
                    color: AppColors.successColor(isDark), isDark: isDark,
                    onTap: () => _download(context))),
                const SizedBox(width: 10),
                Expanded(child: _ActionBtn(
                    icon: Icons.print_rounded, label: 'Print',
                    color: AppColors.warningColor(isDark), isDark: isDark,
                    onTap: () => _print(context))),
              ]),
              const SizedBox(height: 16),
              // Preview table
              _ReportPreview(
                  def: widget.def,
                  from: _from, to: _to,
                  customerId: _customerId,
                  isDark: isDark, c: c,
                  ledgerType: 'all'),
            ],
          ]),
        )),
      ]),
    );
  }

  // ── Custom date range picker ────────────────────────────────────────────────
  Future<void> _pickCustomRange(
      BuildContext context, bool isDark, Color c) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: c),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to   = range.end;
        _generated = false;
      });
    }
  }

  // ── Generate ────────────────────────────────────────────────────────────────
  Future<void> _handleGenerate() async {
    if (_customerId == null) {
      setState(() => _showCustError = true);
      return;
    }
    setState(() { _generating = true; _generated = false; });
    _buildExportData();
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() { _generating = false; _generated = true; });
  }

  void _buildExportData() {
    final txns = ref.read(transactionsProvider);
    final filt = txns.where((t) {
      try {
        final d = DateTime.parse(t.date);
        return !d.isBefore(_from) &&
            !d.isAfter(_to.add(const Duration(days: 1)));
      } catch (_) { return false; }
    }).toList();
    final byC = filt.where((t) => t.customerId == _customerId).toList();
    final custTxns = byC.where((t) =>
        t.customerId != 'EXPENSE' &&
        (t.coolDelivered > 0 || t.petDelivered > 0)).toList();

    if (custTxns.isNotEmpty) {
      final coolDel   = custTxns.fold(0, (s, t) => s + t.coolDelivered);
      final petDel    = custTxns.fold(0, (s, t) => s + t.petDelivered);
      final coolRet   = custTxns.fold(0, (s, t) => s + t.coolReturned);
      final petRet    = custTxns.fold(0, (s, t) => s + t.petReturned);
      final coolPrice = custTxns.first.coolPrice;
      final petPrice  = custTxns.first.petPrice;
      final billed    = custTxns.fold(0.0, (s, t) => s + t.billedAmount);
      final paid      = custTxns.fold(0.0, (s, t) => s + t.amountCollected);
      _exportHeads = ['Item', 'Detail'];
      _exportRows  = [
        ['Cool Delivered',     '$coolDel jars × ₹${coolPrice.toInt()} = ₹${(coolDel * coolPrice).toInt()}'],
        ['PET Delivered',      '$petDel jars × ₹${petPrice.toInt()} = ₹${(petDel * petPrice).toInt()}'],
        ['Cool Returned',      '$coolRet jars'],
        ['PET Returned',       '$petRet jars'],
        ['Cool With Customer', '${coolDel - coolRet} jars'],
        ['PET With Customer',  '${petDel - petRet} jars'],
        ['---', '---'],
        ['Total Billed',  '₹${billed.toInt()}'],
        ['Amount Paid',   '₹${paid.toInt()}'],
        ['Balance Due',   '₹${(billed - paid).toInt()}'],
      ];
    } else {
      _exportHeads = ['Customer','Cool Del','PET Del','Billed','Paid','Due'];
      _exportRows  = [];
    }
  }

  Future<void> _share(BuildContext context) async {
    final bytes = await _buildPdf();
    final name  = 'invoice_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final file  = XFile.fromData(bytes, name: name, mimeType: 'application/pdf');
    await Share.shareXFiles([file], subject: 'Customer Invoice Report');
  }

  Future<void> _download(BuildContext context) async {
    final bytes = await _buildPdf();
    final name  = 'invoice_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
    if (mounted) {
      showToast(context, '✅ Sharing for download', success: true);
    }
  }

  Future<void> _print(BuildContext context) async {
    final bytes = await _buildPdf();
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Customer Invoice Report',
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text(
          '${DateFormat('dd MMM yyyy').format(_from)} – ${DateFormat('dd MMM yyyy').format(_to)}',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: _exportHeads,
          data: _exportRows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellPadding: const pw.EdgeInsets.all(6),
        ),
      ]),
    ));
    return Uint8List.fromList(await doc.save());
  }
}

// ── Section wrapper ────────────────────────────────────────────────────────────
class _IFSection extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isDark;
  const _IFSection(
      {required this.label, required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.separatorDark : AppColors.separator),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 8, offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.inkMuted)),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

// ── Status badge ───────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ignore: unused_element
class _Card extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _Card({required this.isDark, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? AppColors.cardDark : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
    ),
    child: child,
  );
}

// ignore: unused_element
class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: AppColors.inkMuted, letterSpacing: 0.5));
}

// ignore: unused_element
class _DateTap extends StatelessWidget {
  final String label;
  final DateTime value;
  final Color color;
  final bool isDark;
  final ValueChanged<DateTime> onPick;
  const _DateTap({required this.label, required this.value, required this.color,
      required this.isDark, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context, initialDate: value,
          firstDate: DateTime(2020), lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
                colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: color)),
            child: child!,
          ),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
              color: color, letterSpacing: 0.6)),
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(DateFormat(w < 360 ? 'dd MMM yy' : 'dd MMM yyyy').format(value),
                style: GoogleFonts.jetBrainsMono(fontSize: 13,
                    fontWeight: FontWeight.w700, color: color))),
        ]),
      ),
    );
  }
}

class _FmtBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected, isDark;
  final Color color;
  final VoidCallback onTap;
  const _FmtBtn({required this.label, required this.icon, required this.selected,
      required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? color : (isDark ? AppColors.separatorDark : AppColors.separator),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: selected ? color : AppColors.inkMuted),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
            color: selected ? color : AppColors.inkMuted)),
        if (selected) ...[
          const SizedBox(width: 6),
          Icon(Icons.check_circle_rounded, size: 14, color: color),
        ],
      ]),
    ),
  );
}

class _LedgerTypeBtn extends StatelessWidget {
  final String label, value, sel;
  final Color c;
  final bool isDark;
  final VoidCallback onTap;
  const _LedgerTypeBtn({required this.label, required this.value, required this.sel,
      required this.c, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == sel;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? c : (isDark ? AppColors.separatorDark : AppColors.separator),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Center(child: Text(label, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? c : AppColors.inkMuted))),
      ),
    ));
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color,
      required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11,
            fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

// ── Customer picker ────────────────────────────────────────────────────────────
// ignore: unused_element
class _CustPicker extends ConsumerWidget {
  final bool isDark;
  final Color color;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  const _CustPicker({required this.isDark, required this.color,
      required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custs = ref.watch(customersProvider);
    final sel = custs.cast<Customer?>().firstWhere(
        (c) => c?.id == selectedId, orElse: () => null);

    return GestureDetector(
      onTap: () => showMrSheet(context, title: '👤 Select Customer',
        builder: (_) => Column(children: [
          // allowAll always true — show All Customers option
          _PickRow(null, 'All Customers', '', null == selectedId, color, isDark,
              () { onSelect(null); Navigator.pop(context); }),
          ...custs.map((c) => _PickRow(c.initials, c.name, c.area.isNotEmpty ? c.area : c.phone,
              c.id == selectedId, color, isDark,
              () { onSelect(c.id); Navigator.pop(context); })),
        ]),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(children: [
          Icon(Icons.person_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CUSTOMER', style: GoogleFonts.inter(fontSize: 9,
                fontWeight: FontWeight.w700, color: AppColors.inkMuted, letterSpacing: 0.4)),
            Text(sel?.name ?? 'All Customers',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Icon(Icons.expand_more_rounded, size: 18, color: color),
        ]),
      ),
    );
  }

  Widget _PickRow(String? initials, String name, String sub,
      bool sel, Color c, bool isDark, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: sel ? c.withValues(alpha: 0.08) : (isDark ? AppColors.surface2Dark : AppColors.surface2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sel ? c : (isDark ? AppColors.separatorDark : AppColors.separator)),
      ),
      child: Row(children: [
        if (initials != null)
          CustomerAvatar(initials: initials, size: 28)
        else
          Icon(Icons.people_rounded, size: 18, color: AppColors.inkMuted),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis, maxLines: 1),
          if (sub.isNotEmpty)
            Text(sub, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted),
                overflow: TextOverflow.ellipsis, maxLines: 1),
        ])),
        if (sel) Icon(Icons.check_circle_rounded, size: 16, color: c),
      ]),
    ));
}

// ══════════════════════════════════════════════════════════════════════════════
// REPORT PREVIEW  — data tables per report type
// ══════════════════════════════════════════════════════════════════════════════
class _ReportPreview extends ConsumerWidget {
  final _RDef def;
  final DateTime from, to;
  final String? customerId;
  final bool isDark;
  final Color c;
  final String ledgerType;
  const _ReportPreview({required this.def, required this.from, required this.to,
      required this.customerId, required this.isDark, required this.c,
      this.ledgerType = 'all'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns  = ref.watch(transactionsProvider);
    final custs = ref.watch(customersProvider);
    final inv   = ref.watch(inventoryProvider);

    final filt = txns.where((t) {
      try {
        final d = DateTime.parse(t.date);
        return !d.isBefore(from) &&
            !d.isAfter(to.add(const Duration(days: 1)));
      } catch (_) { return false; }
    }).toList();

    final byC = customerId != null
        ? filt.where((t) => t.customerId == customerId).toList()
        : filt;

    return switch (def.id) {
      'invoice'     => _InvoicePreview(txns: byC, custs: custs, isDark: isDark, c: c,
                           customerId: customerId),
      'ledger'      => _LedgerPreview(txns: byC, custs: custs, isDark: isDark, c: c,
                           customerId: customerId, ledgerType: ledgerType),
      'outstanding' => _OutstandingPreview(custs: custs, isDark: isDark, c: c),
      'jar_balance' => _JarBalPreview(custs: customerId != null
            ? custs.where((x) => x.id == customerId).toList() : custs,
          isDark: isDark, c: c),
      'delivery'    => _DeliveryPreview(txns: byC, isDark: isDark, c: c),
      'stock'       => _StockPreview(inv: inv, txns: filt, isDark: isDark, c: c),
      'payment'     => _PaymentPreview(txns: byC, isDark: isDark, c: c),
      'sales'       => _SalesPreview(txns: byC, isDark: isDark, c: c),
      'expense'     => _ExpensePreview(txns: filt, isDark: isDark, c: c),
      'pnl'         => _PnLPreview(txns: byC, isDark: isDark, c: c),
      'event'       => _EventPreview(txns: filt.where((t) => t.deliveryType == 'event').toList(), isDark: isDark, c: c),
      'event_pay'   => _EventPayPreview(txns: filt.where((t) => t.deliveryType == 'event').toList(), isDark: isDark, c: c),
      _             => const SizedBox.shrink(),
    };
  }
}

// ── Shared table & KPI widgets ─────────────────────────────────────────────────
class _Table extends StatelessWidget {
  final List<String> heads;
  final List<List<String>> rows;
  final bool isDark;
  final Color c;
  const _Table({required this.heads, required this.rows, required this.isDark, required this.c});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final fs = w < 360 ? 9.5 : 11.0;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(color: c.withValues(alpha: 0.10),
          child: Row(children: heads.asMap().entries.map((e) => Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(e.value, style: GoogleFonts.inter(fontSize: fs,
                fontWeight: FontWeight.w800, color: c, letterSpacing: 0.2),
                textAlign: e.key == 0 ? TextAlign.left : TextAlign.right),
          ))).toList()),
        ),
        if (rows.isEmpty)
          Padding(padding: const EdgeInsets.all(18),
            child: Text('No data', style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.inkMuted)))
        else ...rows.asMap().entries.map((re) => Container(
          color: re.key.isEven ? Colors.transparent
              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.015)),
          child: Row(children: re.value.asMap().entries.map((ce) => Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Text(ce.value, style: GoogleFonts.jetBrainsMono(
                fontSize: fs, fontWeight: FontWeight.w500),
                textAlign: ce.key == 0 ? TextAlign.left : TextAlign.right,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ))).toList()),
        )),
      ]),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  final List<({String label, String value, Color color})> items;
  final bool isDark;
  const _KpiStrip({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final vfs = w < 360 ? 14.0 : 16.0;
    return Row(children: items.asMap().entries.map((e) {
      final k = e.value;
      return Expanded(child: Container(
        margin: EdgeInsets.only(right: e.key < items.length - 1 ? 8 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: k.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: k.color.withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.label, style: GoogleFonts.inter(fontSize: 9,
              fontWeight: FontWeight.w700, color: k.color, letterSpacing: 0.4)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(k.value, style: GoogleFonts.jetBrainsMono(
                fontSize: vfs, fontWeight: FontWeight.w800, color: k.color))),
        ]),
      ));
    }).toList());
  }
}

String _fd(String d)  { try { return DateFormat('dd MMM').format(DateTime.parse(d)); } catch (_) { return d; } }
String _fdt(String iso) { try { return DateFormat('dd MMM  h:mm a').format(DateTime.parse(iso).toLocal()); } catch (_) { return iso; } }
// ignore: unused_element
String _ft(String iso)  { try { return DateFormat('h:mm a').format(DateTime.parse(iso).toLocal()); } catch (_) { return ''; } }
String _fm(double v) => v == 0 ? '—' : '₹${v.toInt()}';

// ── Preview implementations ────────────────────────────────────────────────────

/// Proper customer invoice — summary view per period, not a transaction list.
class _InvoicePreview extends StatelessWidget {
  final List<JarTransaction> txns;
  final List<Customer> custs;
  final String? customerId;
  final bool isDark; final Color c;
  const _InvoicePreview({required this.txns, required this.custs,
      required this.isDark, required this.c, this.customerId});

  @override
  Widget build(BuildContext context) {
    // Only delivery/event txns that actually have jars
    final deliveries = txns.where((t) =>
        t.customerId != 'EXPENSE' &&
        (t.coolDelivered > 0 || t.petDelivered > 0)).toList();
    // All txns for payment info (includes pure payments)
    final allCustTxns = txns.where((t) => t.customerId != 'EXPENSE').toList();

    if (deliveries.isEmpty && allCustTxns.isEmpty) return _empty(isDark);

    // Group by customer
    final custIds = {...deliveries.map((t) => t.customerId),
                     ...allCustTxns.map((t) => t.customerId)}.toList();

    return Column(children: custIds.map((custId) {
      final cust = custs.cast<Customer?>().firstWhere(
          (x) => x?.id == custId, orElse: () => null);
      final custDel  = deliveries.where((t) => t.customerId == custId).toList();
      final custAll  = allCustTxns.where((t) => t.customerId == custId).toList();

      final coolDel   = custDel.fold(0, (s, t) => s + t.coolDelivered);
      final petDel    = custDel.fold(0, (s, t) => s + t.petDelivered);
      final coolRet   = custDel.fold(0, (s, t) => s + t.coolReturned);
      final petRet    = custDel.fold(0, (s, t) => s + t.petReturned);
      final coolPrice = custDel.isNotEmpty ? custDel.first.coolPrice : 0.0;
      final petPrice  = custDel.isNotEmpty ? custDel.first.petPrice  : 0.0;
      final transport = custDel.fold(0.0, (s, t) => s + t.transportFee);
      final damage    = custDel.fold(0.0, (s, t) => s + t.damageCharge);
      final billed    = custAll.fold(0.0, (s, t) => s + t.billedAmount);
      final paid      = custAll.fold(0.0, (s, t) => s + t.amountCollected);
      final due       = billed - paid;

      // Jar balance from Customer object (live — not period-specific)
      final coolOut   = cust?.coolOut ?? 0;
      final petOut    = cust?.petOut  ?? 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Invoice header ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13), topRight: Radius.circular(13)),
            ),
            child: Row(children: [
              if (cust != null) CustomerAvatar(initials: cust.initials, size: 36),
              if (cust != null) const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cust?.name ?? custId, style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w800, color: c)),
                if (cust?.phone.isNotEmpty == true)
                  Text(cust!.phone, style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.inkMuted)),
                if (cust?.area.isNotEmpty == true)
                  Text(cust!.area, style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.inkMuted)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('INVOICE', style: GoogleFonts.inter(fontSize: 9,
                    fontWeight: FontWeight.w800, color: c, letterSpacing: 1)),
                Text(_fm(billed), style: GoogleFonts.jetBrainsMono(
                    fontSize: 18, fontWeight: FontWeight.w800, color: c)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (due > 0 ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    due > 0 ? '₹${due.toInt()} DUE' : '✓ PAID',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800,
                        color: due > 0 ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark)),
                  ),
                ),
              ]),
            ]),
          ),

          Divider(height: 1, color: c.withValues(alpha: 0.15)),

          Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Delivery summary ──────────────────────────────────────────
            _InvSection('Deliveries in Period', isDark: isDark, c: c),
            const SizedBox(height: 8),
            _InvRow2Col('Cool Jars Delivered', '$coolDel × ₹${coolPrice.toInt()}',
                '₹${(coolDel * coolPrice).toInt()}', isDark: isDark, c: c),
            _InvRow2Col('PET Jars Delivered',  '$petDel × ₹${petPrice.toInt()}',
                '₹${(petDel * petPrice).toInt()}', isDark: isDark, c: c),
            if (coolRet > 0) _InvRow2Col('Cool Returned', '$coolRet jars', '', isDark: isDark, c: c),
            if (petRet  > 0) _InvRow2Col('PET Returned',  '$petRet jars',  '', isDark: isDark, c: c),
            if (transport > 0) _InvRow2Col('Transport Fee', '',  '₹${transport.toInt()}', isDark: isDark, c: c),
            if (damage    > 0) _InvRow2Col('Damage Charge', '', '₹${damage.toInt()}',    isDark: isDark, c: c),
            const SizedBox(height: 12),

            // ── Current jar balance ───────────────────────────────────────
            _InvSection('Current Jar Balance (Live)', isDark: isDark, c: c),
            const SizedBox(height: 8),
            Row(children: [
              _JarBalChip(label: 'Cool with Customer',
                  value: '$coolOut', color: AppColors.coolColor(isDark), isDark: isDark),
              const SizedBox(width: 8),
              _JarBalChip(label: 'PET with Customer',
                  value: '$petOut', color: AppColors.petColor(isDark), isDark: isDark),
            ]),
            const SizedBox(height: 12),

            // ── Billing summary ───────────────────────────────────────────
            _InvSection('Billing Summary', isDark: isDark, c: c),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                _BillLine('Total Billed',    _fm(billed),  c,        isDark),
                _BillLine('Amount Paid',     _fm(paid),    AppColors.successColor(isDark), isDark),
                const Divider(height: 16),
                _BillLine('Balance Due',     _fm(due),
                    due > 0 ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark), isDark,
                    bold: true),
              ]),
            ),
          ])),
        ]),
      );
    }).toList());
  }
}

Widget _InvSection(String label, {required bool isDark, required Color c}) =>
  Text(label.toUpperCase(), style: GoogleFonts.inter(
      fontSize: 9, fontWeight: FontWeight.w800, color: c, letterSpacing: 0.6));

Widget _InvRow2Col(String label, String detail, String amount,
    {required bool isDark, required Color c}) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color:
          isDark ? AppColors.inkDark : AppColors.ink))),
      if (detail.isNotEmpty)
        Flexible(child: Text(detail, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted),
            overflow: TextOverflow.ellipsis, maxLines: 1)),
      const SizedBox(width: 8),
      Text(amount, style: GoogleFonts.jetBrainsMono(fontSize: 12,
          fontWeight: FontWeight.w600, color: c),
          overflow: TextOverflow.ellipsis, maxLines: 1),
    ]),
  );

Widget _BillLine(String label, String value, Color color, bool isDark,
    {bool bold = false}) =>
  Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.inter(
          fontSize: bold ? 13 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          color: isDark ? AppColors.inkDark : AppColors.ink))),
      Text(value, style: GoogleFonts.jetBrainsMono(
          fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color)),
    ]),
  );

class _JarBalChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _JarBalChip({required this.label, required this.value,
      required this.color, required this.isDark});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
          color: color, letterSpacing: 0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 18,
          fontWeight: FontWeight.w800, color: color)),
    ]),
  ));
}

class _LedgerPreview extends StatelessWidget {
  final List<JarTransaction> txns;
  final List<Customer> custs;
  final bool isDark; final Color c;
  final String? customerId;
  final String ledgerType; // 'all' | 'daily' | 'event'
  const _LedgerPreview({required this.txns, required this.custs,
      required this.isDark, required this.c, this.customerId,
      this.ledgerType = 'all'});

  String _type(JarTransaction t) {
    if (t.billedAmount == 0 && t.amountCollected > 0)
      return t.paymentMode == 'advance' ? 'Advance' : 'Payment';
    if (t.coolDelivered == 0 && t.petDelivered == 0 &&
        (t.coolReturned > 0 || t.petReturned > 0)) return 'Return';
    return t.deliveryType == 'event' ? 'Event' : 'Daily';
  }

  String _jars(JarTransaction t) {
    final parts = <String>[];
    if (t.coolDelivered > 0) parts.add('↓${t.coolDelivered}C');
    if (t.petDelivered  > 0) parts.add('↓${t.petDelivered}P');
    if (t.coolReturned  > 0) parts.add('↑${t.coolReturned}C');
    if (t.petReturned   > 0) parts.add('↑${t.petReturned}P');
    return parts.isEmpty ? '—' : parts.join(' ');
  }

  /// Apply ledgerType filter.
  /// Payments are shown in the matching type:
  ///   daily-payment (deliveryType='daily') shown in Daily + All
  ///   event-payment  (deliveryType='event') shown in Event + All
  List<JarTransaction> _applyTypeFilter(List<JarTransaction> src) {
    if (ledgerType == 'all') return src;
    return src.where((t) => t.deliveryType == ledgerType).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Sort oldest-first to compute running balance correctly
    final custTxns = txns
        .where((t) => t.customerId != 'EXPENSE')
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Apply Daily / Event filter
    final filtered = _applyTypeFilter(custTxns);
    if (filtered.isEmpty) return _empty(isDark);

    if (customerId != null) {
      final cust = custs.cast<Customer?>().firstWhere(
          (x) => x?.id == customerId, orElse: () => null);

      // Dynamic balance label: Due / Advance — nothing when clear
      final balLabel = cust == null ? null
          : cust.ledgerBalance < 0 ? 'Due'
          : cust.ledgerBalance > 0 ? 'Advance'
          : null; // balance is 0 — no badge needed
      final balColor = cust == null ? AppColors.inkMuted
          : cust.hasDues    ? AppColors.dangerColor(isDark)
          : cust.hasAdvance ? AppColors.successColor(isDark)
          : AppColors.inkMuted;

      // Pre-compute running balance per tx (oldest→newest)
      double running = 0;
      final Map<String, String> rbMap = {};
      for (final t in filtered) {
        running += (t.billedAmount - t.amountCollected);
        rbMap[t.id] = running == 0 ? '—'
            : running > 0
                ? '₹${running.toInt()} due'
                : '₹${running.abs().toInt()} adv';
      }

      // Display newest-first (reverse order) — balance is already precomputed per id
      final displayRows = filtered.reversed.toList();

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (cust != null) Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withValues(alpha: 0.20)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CustomerAvatar(initials: cust.initials, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cust.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(cust.phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
              ])),
              // Dynamic balance badge — only shown when there is a balance
              if (balLabel != null)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(balLabel, style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: balColor, letterSpacing: 0.4)),
                  Text('₹${cust.ledgerBalance.abs().toInt()}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700,
                          color: balColor)),
                ]),
            ]),
            // Jar balance row
            if (cust.coolOut > 0 || cust.petOut > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  CoolJarIcon(size: 13, color: AppColors.coolColor(isDark)),
                  const SizedBox(width: 4),
                  Text('${cust.coolOut}', style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.coolColor(isDark))),
                  Text(' Cool', style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted)),
                  const SizedBox(width: 12),
                  PetJarIcon(size: 13, color: AppColors.petColor(isDark)),
                  const SizedBox(width: 4),
                  Text('${cust.petOut}', style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.petColor(isDark))),
                  Text(' PET', style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted)),
                  const Spacer(),
                  Text('with customer', style: GoogleFonts.inter(fontSize: 9, color: AppColors.inkMuted)),
                ]),
              ),
            ],
          ]),
        ),
        // Type filter hint
        if (ledgerType != 'all') Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (ledgerType == 'event' ? AppColors.purple : c).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(ledgerType == 'event' ? Icons.celebration_rounded : Icons.local_shipping_rounded,
                size: 13, color: ledgerType == 'event' ? AppColors.purple : c),
            const SizedBox(width: 6),
            Text('Showing ${ledgerType == 'event' ? 'Event' : 'Daily'} transactions only',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
          ]),
        ),
        // Table: newest row on top
        _Table(isDark: isDark, c: c,
          heads: ['Date & Time', 'Type', 'Jars', 'Billed', 'Paid', 'Balance'],
          rows: displayRows.map((t) => [
            _fdt(t.createdAt), _type(t), _jars(t),
            _fm(t.billedAmount), _fm(t.amountCollected),
            rbMap[t.id] ?? '—',
          ]).toList()),
      ]);
    }

    // All customers grouped — same fixes: newest-first display, no "Clear" badge
    final byCust = <String, List<JarTransaction>>{};
    for (final t in filtered) byCust.putIfAbsent(t.customerId, () => []).add(t);

    return Column(children: byCust.entries.map((e) {
      final cust   = custs.cast<Customer?>().firstWhere((x) => x?.id == e.key, orElse: () => null);
      final billed = e.value.fold(0.0, (s, t) => s + t.billedAmount);
      final paid   = e.value.fold(0.0, (s, t) => s + t.amountCollected);
      final net    = billed - paid; // positive = customer owes, negative = advance

      // Pre-compute running balance per tx (oldest→newest order, already sorted)
      double running = 0;
      final Map<String, String> rbMap = {};
      for (final t in e.value) {
        running += (t.billedAmount - t.amountCollected);
        rbMap[t.id] = running == 0 ? '—'
            : running > 0
                ? '₹${running.toInt()} due'
                : '₹${running.abs().toInt()} adv';
      }

      // Display newest-first
      final displayRows = e.value.reversed.toList();

      final netLabel = net > 0 ? 'Due' : net < 0 ? 'Advance' : null;
      final netColor = net > 0 ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark);

      return Container(margin: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              if (cust != null) CustomerAvatar(initials: cust.initials, size: 26),
              if (cust != null) const SizedBox(width: 8),
              Expanded(child: Text(cust?.name ?? e.key, style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700))),
              if (netLabel != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: netColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('₹${net.abs().toInt()} $netLabel',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                          color: netColor)),
                ),
              ],
            ])),
          _Table(isDark: isDark, c: c,
            heads: ['Date & Time', 'Type', 'Jars', 'Billed', 'Paid', 'Bal'],
            rows: displayRows.map((t) => [
              _fdt(t.createdAt), _type(t), _jars(t),
              _fm(t.billedAmount), _fm(t.amountCollected),
              rbMap[t.id] ?? '—',
            ]).toList()),
        ]));
    }).toList());
  }
}

class _DeliveryPreview extends StatelessWidget {
  final List<JarTransaction> txns; final bool isDark; final Color c;
  const _DeliveryPreview({required this.txns, required this.isDark, required this.c});
  @override
  Widget build(BuildContext context) {
    // Only daily transactions with actual jar movement — exclude payment-only and events
    final deliveries = txns.where((t) =>
        t.customerId != 'EXPENSE' &&
        t.deliveryType != 'event' &&
        (t.coolDelivered > 0 || t.petDelivered > 0 ||
         t.coolReturned  > 0 || t.petReturned  > 0)).toList();
    final cd = deliveries.fold(0,(s,t)=>s+t.coolDelivered), pd = deliveries.fold(0,(s,t)=>s+t.petDelivered);
    final cr = deliveries.fold(0,(s,t)=>s+t.coolReturned),  pr = deliveries.fold(0,(s,t)=>s+t.petReturned);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _KpiStrip(isDark: isDark, items: [
        (label:'Cool Out', value:'$cd', color:AppColors.coolColor(isDark)),
        (label:'PET Out',  value:'$pd', color:AppColors.petColor(isDark)),
        (label:'Returned', value:'${cr+pr}', color:c),
      ]),
      const SizedBox(height: 10),
      if (deliveries.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('No jar movements in this period',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted))),
        )
      else
        _Table(isDark: isDark, c: c, heads: ['Date & Time','Customer','Cool','PET'],
          rows: deliveries.map((t) {
            final coolParts = [
              if (t.coolDelivered > 0) '↓${t.coolDelivered}',
              if (t.coolReturned  > 0) '↑${t.coolReturned}',
            ];
            final petParts = [
              if (t.petDelivered  > 0) '↓${t.petDelivered}',
              if (t.petReturned   > 0) '↑${t.petReturned}',
            ];
            return [
              _fdt(t.createdAt),
              t.customerName.split(' ').first,
              coolParts.isEmpty ? '—' : coolParts.join(' '),
              petParts.isEmpty  ? '—' : petParts.join(' '),
            ];
          }).toList()),
    ]);
  }
}

class _PaymentPreview extends StatelessWidget {
  final List<JarTransaction> txns; final bool isDark; final Color c;
  const _PaymentPreview({required this.txns, required this.isDark, required this.c});
  @override
  Widget build(BuildContext context) {
    final payments = txns.where((t) => t.amountCollected > 0 && t.customerId != 'EXPENSE').toList();
    final total  = payments.fold(0.0,(s,t)=>s+t.amountCollected);
    final billed = txns.fold(0.0,(s,t)=>s+t.billedAmount);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _KpiStrip(isDark: isDark, items: [
        (label:'Billed',    value:_fm(billed), color:c),
        (label:'Collected', value:_fm(total),  color:AppColors.successColor(isDark)),
        (label:'Pending',   value:_fm(billed-total), color:AppColors.dangerColor(isDark)),
      ]),
      const SizedBox(height: 10),
      _Table(isDark: isDark, c: c, heads: ['Date & Time','Customer','Mode','Type','Amount'],
        rows: payments.map((t)=>[
          _fdt(t.createdAt),
          t.customerName.split(' ').first,
          switch(t.paymentMode){'cash'=>'Cash','upi'=>'UPI','bank'=>'Bank','advance'=>'Advance',_=>t.paymentMode},
          t.deliveryType == 'event' ? 'Event' : 'Daily',
          _fm(t.amountCollected),
        ]).toList()),
    ]);
  }
}

class _OutstandingPreview extends StatelessWidget {
  final List<Customer> custs; final bool isDark; final Color c;
  const _OutstandingPreview({required this.custs, required this.isDark, required this.c});
  @override
  Widget build(BuildContext context) {
    final due = custs.where((c)=>c.balance<0).toList()..sort((a,b)=>a.balance.compareTo(b.balance));
    final adv = custs.where((c)=>c.balance>0).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _KpiStrip(isDark: isDark, items: [
        (label:'Total Due', value:_fm(due.fold(0.0,(s,c)=>s+c.balance.abs())), color:AppColors.dangerColor(isDark)),
        (label:'Credit',   value:_fm(adv.fold(0.0,(s,c)=>s+c.balance)),       color:AppColors.successColor(isDark)),
        (label:'Customers', value:'${due.length}', color:c),
      ]),
      const SizedBox(height: 10),
      _Table(isDark: isDark, c: c, heads: ['Customer','Area','Balance'],
        rows: due.map((c)=>[c.name.split(' ').first, c.area.isNotEmpty?c.area:'—',
            '₹${c.balance.abs().toInt()} due']).toList()),
    ]);
  }
}

class _JarBalPreview extends StatelessWidget {
  final List<Customer> custs; final bool isDark; final Color c;
  const _JarBalPreview({required this.custs, required this.isDark, required this.c});
  @override
  Widget build(BuildContext context) {
    final list = custs.where((x)=>x.hasJarsOut).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _KpiStrip(isDark: isDark, items: [
        (label:'Cool Out',  value:'${list.fold(0,(s,c)=>s+c.coolOut)}', color:AppColors.coolColor(isDark)),
        (label:'PET Out',   value:'${list.fold(0,(s,c)=>s+c.petOut)}',  color:AppColors.petColor(isDark)),
        (label:'Customers', value:'${list.length}', color:c),
      ]),
      const SizedBox(height: 10),
      _Table(isDark: isDark, c: c, heads: ['Customer','Area','Cool','PET'],
        rows: list.map((c)=>[c.name.split(' ').first, c.area.isNotEmpty?c.area:'—',
            '${c.coolOut}', '${c.petOut}']).toList()),
    ]);
  }
}

class _StockPreview extends StatelessWidget {
  final InventoryState inv;
  final List<JarTransaction> txns; final bool isDark; final Color c;
  const _StockPreview({required this.inv, required this.txns, required this.isDark, required this.c});
  @override
  Widget build(BuildContext context) {
    final cd=txns.fold(0,(s,t)=>s+t.coolDelivered), pd=txns.fold(0,(s,t)=>s+t.petDelivered);
    final cr=txns.fold(0,(s,t)=>s+t.coolReturned),  pr=txns.fold(0,(s,t)=>s+t.petReturned);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _KpiStrip(isDark: isDark, items: [
        (label:'Cool Stock', value:'${inv.coolStock}', color:AppColors.coolColor(isDark)),
        (label:'PET Stock',  value:'${inv.petStock}',  color:AppColors.petColor(isDark)),
        (label:'Cool Out',   value:'${inv.coolOut}',   color:c),
      ]),
      const SizedBox(height: 10),
      _Table(isDark: isDark, c: c, heads: ['Type','Out','In','Damaged','Net'],
        rows: [
          ['Cool','$cd','$cr','${txns.fold(0,(s,t)=>s+t.coolDamaged)}','${cd-cr}'],
          ['PET', '$pd','$pr','${txns.fold(0,(s,t)=>s+t.petDamaged)}', '${pd-pr}'],
        ]),
    ]);
  }
}

class _SalesPreview extends StatelessWidget {
  final List<JarTransaction> txns; final bool isDark; final Color c;
  const _SalesPreview({required this.txns, required this.isDark, required this.c});
  @override
  Widget build(BuildContext context) {
    final rev = txns.fold(0.0,(s,t)=>s+t.billedAmount);
    final col = txns.fold(0.0,(s,t)=>s+t.amountCollected);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _KpiStrip(isDark: isDark, items: [
        (label:'Revenue',   value:_fm(rev), color:c),
        (label:'Collected', value:_fm(col), color:AppColors.successColor(isDark)),
        (label:'Pending',   value:_fm(rev-col), color:AppColors.dangerColor(isDark)),
      ]),
      const SizedBox(height: 10),
      _Table(isDark: isDark, c: c, heads: ['Source','Amount'],
        rows: [
          ['Cool Jars',  _fm(txns.fold(0.0,(s,t)=>s+t.coolDelivered*t.coolPrice))],
          ['PET Jars',   _fm(txns.fold(0.0,(s,t)=>s+t.petDelivered*t.petPrice))],
          ['Transport',  _fm(txns.fold(0.0,(s,t)=>s+t.transportFee))],
          ['Damage',     _fm(txns.fold(0.0,(s,t)=>s+t.damageCharge))],
          ['TOTAL', _fm(rev)],
        ]),
    ]);
  }
}

class _ExpensePreview extends StatelessWidget {
  final List<JarTransaction> txns; final bool isDark; final Color c;
  const _ExpensePreview({required this.txns, required this.isDark, required this.c});
  @override
  Widget build(BuildContext context) {
    // Only actual expenses recorded via the Expenses screen
    final expenses = txns.where((t) => t.customerId == 'EXPENSE').toList();
    final total = expenses.fold(0.0, (s, t) => s + t.damageCharge);

    // Group by category (stored in customerName for expense txns)
    final byCategory = <String, double>{};
    for (final t in expenses) {
      byCategory[t.customerName] = (byCategory[t.customerName] ?? 0) + t.damageCharge;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _KpiStrip(isDark: isDark, items: [
        (label:'Total Expenses', value:_fm(total), color:c),
        (label:'Entries',        value:'${expenses.length}', color:AppColors.warningColor(isDark)),
        (label:'Categories',     value:'${byCategory.length}', color:AppColors.inkMuted),
      ]),
      const SizedBox(height: 10),
      if (expenses.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(child: Text('No expenses recorded in this period.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted))),
        )
      else ...[
        // Summary by category
        _Table(isDark: isDark, c: c,
          heads: ['Category', 'Amount'],
          rows: byCategory.entries.map((e) => [e.key, _fm(e.value)]).toList()
            ..add(['TOTAL', _fm(total)])),
        const SizedBox(height: 10),
        // Itemised list
        _Table(isDark: isDark, c: c,
          heads: ['Date', 'Category', 'Mode', 'Amount'],
          rows: expenses.map((t) => [
            _fd(t.date),
            t.customerName,
            t.paymentMode.toUpperCase(),
            _fm(t.damageCharge),
          ]).toList()),
      ],
    ]);
  }
}

class _PnLPreview extends StatelessWidget {
  final List<JarTransaction> txns; final bool isDark; final Color c;
  const _PnLPreview({required this.txns, required this.isDark, required this.c});
  @override
  Widget build(BuildContext context) {
    final rev = txns.fold(0.0,(s,t)=>s+t.billedAmount);
    final col = txns.fold(0.0,(s,t)=>s+t.amountCollected);
    final exp = txns.fold(0.0,(s,t)=>s+t.transportFee+t.damageCharge);
    final net = col - exp;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _KpiStrip(isDark: isDark, items: [
        (label:'Revenue',  value:_fm(rev), color:c),
        (label:'Expenses', value:_fm(exp), color:AppColors.dangerColor(isDark)),
        (label:'Net',      value:_fm(net), color:net>=0?AppColors.successColor(isDark):AppColors.dangerColor(isDark)),
      ]),
      const SizedBox(height: 10),
      _Table(isDark: isDark, c: c, heads: ['Line','Amount'],
        rows: [
          ['(+) Revenue',    _fm(rev)],
          ['(+) Collected',  _fm(col)],
          ['(−) Transport',  _fm(txns.fold(0.0,(s,t)=>s+t.transportFee))],
          ['(−) Damage',     _fm(txns.fold(0.0,(s,t)=>s+t.damageCharge))],
          ['= Net',          _fm(net)],
          ['Margin', col>0 ? '${(net/col*100).toStringAsFixed(1)}%' : '—'],
        ]),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EVENT GROUP MODEL  — all transactions for one logical event
// Grouping key: customerId + date + eventName (normalised)
// ══════════════════════════════════════════════════════════════════════════════
class _EventGroup {
  final String customerId;
  final String customerName;
  final String date;
  final String eventName;
  final List<JarTransaction> txns; // all txns for this event

  _EventGroup({
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.eventName,
    required this.txns,
  });

  // Aggregate fields
  int    get coolDelivered => txns.fold(0,   (s, t) => s + t.coolDelivered);
  int    get petDelivered  => txns.fold(0,   (s, t) => s + t.petDelivered);
  int    get coolReturned  => txns.fold(0,   (s, t) => s + t.coolReturned);
  int    get petReturned   => txns.fold(0,   (s, t) => s + t.petReturned);
  double get billed        => txns.fold(0.0, (s, t) => s + t.billedAmount);
  double get collected     => txns.fold(0.0, (s, t) => s + t.amountCollected);
  double get pending       => billed - collected;

  // Latest status among delivery txns (non-payment)
  String? get status {
    final delivery = txns
        .where((t) => t.billedAmount > 0 || t.coolDelivered > 0 || t.petDelivered > 0)
        .toList();
    if (delivery.isEmpty) return null;
    // Sort by createdAt desc — take the latest status
    delivery.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return delivery.first.eventStatus;
  }

  // Latest createdAt across all txns
  String get latestCreatedAt {
    final sorted = txns.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.createdAt;
  }
}

/// Groups a flat list of event transactions into logical events.
/// Key = customerId + date + normalised-eventName.
List<_EventGroup> _groupEventTxns(List<JarTransaction> all) {
  final eventTxns = all.where((t) =>
      t.customerId != 'EXPENSE' && t.deliveryType == 'event').toList();

  final map = <String, _EventGroup>{};
  for (final t in eventTxns) {
    final name = (t.eventName ?? '').trim().toLowerCase();
    final key  = '${t.customerId}||${t.date}||$name';
    if (map.containsKey(key)) {
      map[key]!.txns.add(t);
    } else {
      map[key] = _EventGroup(
        customerId:   t.customerId,
        customerName: t.customerName,
        date:         t.date,
        eventName:    t.eventName?.isNotEmpty == true ? t.eventName! : 'Event Order',
        txns:         [t],
      );
    }
  }

  // Sort groups: latest-first by most recent transaction timestamp
  final groups = map.values.toList()
    ..sort((a, b) => b.latestCreatedAt.compareTo(a.latestCreatedAt));
  return groups;
}

// ══════════════════════════════════════════════════════════════════════════════
// EVENT REPORT PREVIEW  — one card per logical event (grouped)
// ══════════════════════════════════════════════════════════════════════════════
class _EventPreview extends StatelessWidget {
  final List<JarTransaction> txns; final bool isDark; final Color c;
  const _EventPreview({required this.txns, required this.isDark, required this.c});

  @override
  Widget build(BuildContext context) {
    final groups = _groupEventTxns(txns);

    // Aggregate KPIs across all events
    final totalCoolOut  = groups.fold(0,   (s, g) => s + g.coolDelivered);
    final totalPetOut   = groups.fold(0,   (s, g) => s + g.petDelivered);
    final totalBilled   = groups.fold(0.0, (s, g) => s + g.billed);
    final totalCollected= groups.fold(0.0, (s, g) => s + g.collected);
    final totalPending  = totalBilled - totalCollected;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── KPI strip ──────────────────────────────────────────────────────────
      _KpiStrip(isDark: isDark, items: [
        (label: 'Events',    value: '${groups.length}', color: c),
        (label: 'Cool Out',  value: '$totalCoolOut',    color: AppColors.coolColor(isDark)),
        (label: 'PET Out',   value: '$totalPetOut',     color: AppColors.petColor(isDark)),
      ]),
      const SizedBox(height: 8),
      _KpiStrip(isDark: isDark, items: [
        (label: 'Billed',    value: _fm(totalBilled),    color: AppColors.primaryColor(isDark)),
        (label: 'Collected', value: _fm(totalCollected), color: AppColors.successColor(isDark)),
        (label: 'Pending',   value: _fm(totalPending),   color: AppColors.dangerColor(isDark)),
      ]),
      const SizedBox(height: 10),

      if (groups.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('No events in this period',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted))),
        )
      else
        ...groups.map((g) => _EventGroupCard(group: g, isDark: isDark, c: c)),
    ]);
  }
}

// ── One event card ────────────────────────────────────────────────────────────
class _EventGroupCard extends StatelessWidget {
  final _EventGroup group;
  final bool isDark;
  final Color c;
  const _EventGroupCard(
      {required this.group, required this.isDark, required this.c});

  @override
  Widget build(BuildContext context) {
    final g           = group;
    final status      = g.status;
    final statusColor = status == 'completed'
        ? AppColors.successColor(isDark)
        : status == 'cancelled'
            ? AppColors.dangerColor(isDark)
            : AppColors.warningColor(isDark);

    final jars = [
      if (g.coolDelivered > 0) '↓${g.coolDelivered}C',
      if (g.petDelivered  > 0) '↓${g.petDelivered}P',
      if (g.coolReturned  > 0) '↑${g.coolReturned}C',
      if (g.petReturned   > 0) '↑${g.petReturned}P',
    ].join('  ');

    // Transaction breakdown (delivery txns + payment txns)
    final deliveryTxns = g.txns.where((t) =>
        t.billedAmount > 0 || t.coolDelivered > 0 || t.petDelivered > 0).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final paymentTxns  = g.txns.where((t) =>
        t.amountCollected > 0 && t.billedAmount == 0).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.separatorDark : AppColors.separator),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header: timestamp + customer name + status ──────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11), topRight: Radius.circular(11)),
          ),
          child: Row(children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_fdt(g.latestCreatedAt),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted)),
              const SizedBox(height: 2),
              Text(g.customerName,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w800),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            if (status != null && status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.30)),
                ),
                child: Text(status.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: statusColor)),
              ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Event name + jar summary ───────────────────────────────────
            Row(children: [
              Icon(Icons.celebration_rounded, size: 13, color: c),
              const SizedBox(width: 5),
              Expanded(child: Text(g.eventName,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: c, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (jars.isNotEmpty)
                Text(jars,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.inkDark : AppColors.ink)),
            ]),
            const SizedBox(height: 8),

            // ── Billed / Collected / Pending ───────────────────────────────
            Row(children: [
              _MiniKpi('Billed',    _fm(g.billed),    AppColors.primaryColor(isDark)),
              const SizedBox(width: 16),
              _MiniKpi('Collected', _fm(g.collected), AppColors.successColor(isDark)),
              const SizedBox(width: 16),
              _MiniKpi('Pending',   _fm(g.pending),
                  g.pending > 0
                      ? AppColors.dangerColor(isDark)
                      : AppColors.successColor(isDark)),
            ]),

            // ── Transaction breakdown (if > 1 transaction) ────────────────
            if (g.txns.length > 1) ...[
              const SizedBox(height: 10),
              Divider(height: 1,
                  color: isDark ? AppColors.separatorDark : AppColors.separator),
              const SizedBox(height: 8),
              // Delivery txns
              ...deliveryTxns.map((t) => _TxnLine(
                  label: _typeLabel(t),
                  timestamp: _fdt(t.createdAt),
                  detail: _jarStr(t),
                  amount: t.billedAmount > 0 ? _fm(t.billedAmount) : null,
                  amtColor: AppColors.primaryColor(isDark),
                  isDark: isDark)),
              // Payment txns
              ...paymentTxns.map((t) => _TxnLine(
                  label: 'Payment',
                  timestamp: _fdt(t.createdAt),
                  detail: t.paymentMode.toUpperCase(),
                  amount: '+${_fm(t.amountCollected)}',
                  amtColor: AppColors.successColor(isDark),
                  isDark: isDark)),
            ],
          ]),
        ),
      ]),
    );
  }

  String _typeLabel(JarTransaction t) {
    if (t.coolDelivered > 0 || t.petDelivered > 0) return 'Delivery';
    if (t.coolReturned  > 0 || t.petReturned  > 0) return 'Return';
    return 'Event';
  }

  String _jarStr(JarTransaction t) {
    final parts = <String>[];
    if (t.coolDelivered > 0) parts.add('↓${t.coolDelivered}C');
    if (t.petDelivered  > 0) parts.add('↓${t.petDelivered}P');
    if (t.coolReturned  > 0) parts.add('↑${t.coolReturned}C');
    if (t.petReturned   > 0) parts.add('↑${t.petReturned}P');
    return parts.join(' ');
  }
}

// ── Single transaction line inside event card ─────────────────────────────────
class _TxnLine extends StatelessWidget {
  final String label, timestamp;
  final String? detail, amount;
  final Color amtColor;
  final bool isDark;
  const _TxnLine({
    required this.label, required this.timestamp,
    required this.amtColor, required this.isDark,
    this.detail, this.amount,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Container(
        width: 6, height: 6,
        margin: const EdgeInsets.only(right: 8, top: 1),
        decoration: BoxDecoration(
            color: amtColor.withValues(alpha: 0.6),
            shape: BoxShape.circle),
      ),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.inkDark : AppColors.ink)),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(detail!,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, color: AppColors.inkMuted)),
          ],
        ]),
        Text(timestamp,
            style: GoogleFonts.inter(fontSize: 9, color: AppColors.inkMuted)),
      ])),
      if (amount != null)
        Text(amount!,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11, fontWeight: FontWeight.w700, color: amtColor)),
    ]),
  );
}

// ── Inline mini KPI (value big, label small underneath) ──────────────────────
class _MiniKpi extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniKpi(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: GoogleFonts.jetBrainsMono(
          fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: GoogleFonts.inter(
          fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// EVENT PAYMENTS PREVIEW  — one row per logical event (grouped)
// Consistent with EventPreview grouping — payments rolled into event row
// ══════════════════════════════════════════════════════════════════════════════
class _EventPayPreview extends StatelessWidget {
  final List<JarTransaction> txns; final bool isDark; final Color c;
  const _EventPayPreview({required this.txns, required this.isDark, required this.c});

  @override
  Widget build(BuildContext context) {
    final groups    = _groupEventTxns(txns);
    final billed    = groups.fold(0.0, (s, g) => s + g.billed);
    final collected = groups.fold(0.0, (s, g) => s + g.collected);
    final pending   = billed - collected;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _KpiStrip(isDark: isDark, items: [
        (label: 'Events',    value: '${groups.length}', color: c),
        (label: 'Collected', value: _fm(collected), color: AppColors.successColor(isDark)),
        (label: 'Pending',   value: _fm(pending),   color: AppColors.dangerColor(isDark)),
      ]),
      const SizedBox(height: 8),
      _KpiStrip(isDark: isDark, items: [
        (label: 'Billed', value: _fm(billed), color: c),
        (label: 'Paid %',
         value: billed > 0 ? '${(collected / billed * 100).toStringAsFixed(0)}%' : '—',
         color: AppColors.primaryColor(isDark)),
        (label: 'Balance', value: _fm(pending),
         color: pending > 0 ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark)),
      ]),
      const SizedBox(height: 10),

      if (groups.isEmpty)
        _empty(isDark)
      else
        _Table(isDark: isDark, c: c,
          heads: ['Date', 'Customer', 'Event', 'Jars', 'Billed', 'Paid', 'Pending'],
          rows: groups.map((g) {
            final jars = [
              if (g.coolDelivered > 0) '↓${g.coolDelivered}C',
              if (g.petDelivered  > 0) '↓${g.petDelivered}P',
              if (g.coolReturned  > 0) '↑${g.coolReturned}C',
              if (g.petReturned   > 0) '↑${g.petReturned}P',
            ].join(' ');
            return [
              _fd(g.date),
              g.customerName.split(' ').first,
              g.eventName,
              jars.isEmpty ? '—' : jars,
              _fm(g.billed),
              _fm(g.collected),
              _fm(g.pending),
            ];
          }).toList()),
    ]);
  }
}

Widget _empty(bool isDark) => Padding(
  padding: const EdgeInsets.all(32),
  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.search_off_rounded, size: 44, color: AppColors.inkMuted.withValues(alpha: 0.3)),
    const SizedBox(height: 12),
    Text('No data for this period', style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
  ])),
);

