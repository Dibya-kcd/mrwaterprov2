import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';
import 'voice_assistant.dart';
import 'voice_form_helper.dart';

const _uuid = Uuid();

// ══════════════════════════════════════════════════════════════════════════════
// TRANSACTIONS SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TxnScreenState();
}

class _TxnScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'All';
  String _search = '';
  late DateTime _from;
  late DateTime _to;
  bool _datePickerOpen = false;
  bool _headerExpanded = true;

  @override
  void initState() {
    super.initState();
    _resetToToday(); // default = today
  }

  String _fmtDate(DateTime d) => DateFormat('dd MMM').format(d);
  String _fmtFull(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  bool get _isToday {
    final n = DateTime.now();
    return _from.year==n.year && _from.month==n.month && _from.day==n.day &&
           _to.year  ==n.year && _to.month  ==n.month && _to.day  ==n.day;
  }
  bool get _isCustomRange => !_isToday;

  void _resetToToday() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month, now.day);
      _to   = DateTime(now.year, now.month, now.day, 23, 59, 59);
      _datePickerOpen = false;
    });
  }

  List<JarTransaction> _buildList(List<JarTransaction> all) {
    return all.where((t) {
      // ── Always exclude expense entries — they live in the Expenses screen only
      if (t.customerId == 'EXPENSE') return false;

      DateTime? txDate;
      try { txDate = DateTime.parse(t.date); } catch (_) {}
      final inRange = txDate != null && !txDate.isBefore(_from) && !txDate.isAfter(_to);
      if (!inRange) return false;
      if (_search.isNotEmpty &&
          !t.customerName.toLowerCase().contains(_search.toLowerCase())) return false;

      final isEvent = t.deliveryType == 'event';

      return switch (_filter) {
        // Daily = daily deliveries + daily payments (excl. event txns)
        // This ensures collected/due totals in summary strip are accurate for daily
        'Daily' => !isEvent,
        // Event = event deliveries + event payments only
        'Event' => isEvent,
        // All = everything (no Unpaid filter — removed per requirement)
        _ => true,
      };
    }).toList()..sort((a, b) {
      // Sort by date desc, then createdAt desc — latest always on top
      final dc = b.date.compareTo(a.date);
      if (dc != 0) return dc;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  @override
  Widget build(BuildContext context) {
    final all   = ref.watch(transactionsProvider);
    final custs = ref.watch(customersProvider);
    // Build a fast lookup: customerId → Customer
    final custMap = { for (final c in custs) c.id: c };

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final list = _buildList(all);

    // Collapsed header summary label
    final String collapsedLabel = _isToday
        ? 'Today, ${_fmtDate(_from)}'
        : '${_fmtDate(_from)} – ${_fmtDate(_to)}';
    final bool hasActiveFilter = _filter != 'All' || _search.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: VoiceFab(isDark: isDark, primary: primary),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(children: [

        // ── Sticky collapsed bar (always visible) ──────────────────────────
        GestureDetector(
          onTap: () => setState(() => _headerExpanded = !_headerExpanded),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Transactions', style: Theme.of(context).textTheme.headlineLarge),
                if (!_headerExpanded)
                  Row(children: [
                    Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.inkMuted),
                    const SizedBox(width: 4),
                    Text(collapsedLabel,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
                    if (hasActiveFilter) ...[ 
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_filter != 'All' ? _filter : _search,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                                color: primary)),
                      ),
                    ],
                  ])
                else
                  Text('All jar movements & payments',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
              ])),
              // Count badge
              if (list.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${list.length}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: primary)),
                ),
              AnimatedRotation(
                turns: _headerExpanded ? 0 : 0.5,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_up_rounded,
                    size: 22, color: AppColors.inkMuted),
              ),
            ]),
          ),
        ),

        // ── Collapsible panel ─────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _headerExpanded
              ? _HeaderPanel(
                  search: _search,
                  from: _from,
                  to: _to,
                  filter: _filter,
                  isCustomRange: _isCustomRange,
                  datePickerOpen: _datePickerOpen,
                  isDark: isDark,
                  primary: primary,
                  onSearch: (v) => setState(() => _search = v),
                  onTogglePicker: () => setState(() => _datePickerOpen = !_datePickerOpen),
                  onFromPicked: (d) => setState(() {
                    _from = d;
                    if (_from.isAfter(_to)) _to = DateTime(_from.year, _from.month, _from.day, 23, 59, 59);
                  }),
                  onToPicked: (d) => setState(() {
                    _to = DateTime(d.year, d.month, d.day, 23, 59, 59);
                    if (_to.isBefore(_from)) _from = DateTime(_to.year, _to.month, _to.day);
                  }),
                  onResetToday: _isToday ? null : _resetToToday,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  fmtDate: _fmtDate,
                  fmtFull: _fmtFull,
                  list: list,
                )
              : const SizedBox.shrink(),
        ),

        // Summary strip — here it has access to custMap and _search
        if (list.isNotEmpty) _SummaryStrip(
          list: list,
          custMap: custMap,
          searchName: _search,
        ),

        const SizedBox(height: 6),

        // ── List ──────────────────────────────────────────────────────────
        Expanded(
          child: list.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => ref.read(transactionsProvider.notifier).refreshAll(ref),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 400,
                      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 60, width: 60, child: CoolJarIcon()),
                  const SizedBox(height: 16),
                  Text('No transactions', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    all.isEmpty
                      ? 'Tap + to record a delivery or return'
                      : 'No transactions in this date range — try expanding the range',
                    style: GoogleFonts.inter(color: AppColors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                  if (all.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${all.length} total in database',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
                  ],
                ])),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(transactionsProvider.notifier).refreshAll(ref),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => _TxnCard(
                      tx: list[i],
                      custMap: custMap,
                      onTap: () => _openForm(ctx, list[i]),
                      onDelete: () => _delete(ctx, list[i]),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  Future<void> _openForm(BuildContext ctx, JarTransaction? tx) async {
    if (tx == null) {
      await showMrSheet(ctx, title: '🚚 New Delivery',
          builder: (_) => DeliveryForm());
      return;
    }
    final type = _detectTxType(tx);
    switch (type) {
      case 'payment':
        await showMrSheet(ctx, title: '💰 Edit Payment',
            builder: (_) => PaymentForm(existing: tx));
      case 'return':
        await showMrSheet(ctx, title: '📦 Edit Return',
            builder: (_) => ReturnJarForm(existing: tx));
      case 'event':
        await showMrSheet(ctx, title: '🎉 Edit Event',
            builder: (_) => EventForm(existing: tx));
      default:
        await showMrSheet(ctx, title: '🚚 Edit Delivery',
            builder: (_) => DeliveryForm(existing: tx));
    }
  }

  /// Detect transaction type purely from field values.
  static String _detectTxType(JarTransaction tx) {
    // Pure payment: no jar movement, has collected amount
    if (tx.billedAmount == 0 && tx.amountCollected > 0) return 'payment';
    // Pure return: no deliveries, only returns
    final hasDelivery = tx.coolDelivered > 0 || tx.petDelivered > 0;
    final hasReturn   = tx.coolReturned  > 0 || tx.petReturned  > 0;
    if (!hasDelivery && hasReturn) return 'return';
    if (tx.deliveryType == 'event') return 'event';
    return 'delivery';
  }

  Future<void> _delete(BuildContext ctx, JarTransaction tx) async {
    final ok = await confirmDialog(ctx,
      title: 'Delete Transaction?',
      message: 'Inventory and payments for ${tx.customerName} will be reversed. Cannot be undone.',
    );
    if (ok && mounted) {
      ref.read(transactionsProvider.notifier).delete(tx);
      if (mounted) {
        showToast(ctx, 'Transaction deleted & inventory reversed', error: true);
      }
    }
  }
}

// ── Collapsible header panel ──────────────────────────────────────────────────
class _HeaderPanel extends StatelessWidget {
  final String search, filter;
  final DateTime from, to;
  final bool isCustomRange, datePickerOpen, isDark;
  final Color primary;
  final ValueChanged<String> onSearch, onFilterChanged;
  final VoidCallback onTogglePicker;
  final ValueChanged<DateTime> onFromPicked, onToPicked;
  final VoidCallback? onResetToday;
  final String Function(DateTime) fmtDate, fmtFull;
  final List<JarTransaction> list;

  const _HeaderPanel({
    required this.search, required this.filter,
    required this.from, required this.to,
    required this.isCustomRange, required this.datePickerOpen,
    required this.isDark, required this.primary,
    required this.onSearch, required this.onFilterChanged,
    required this.onTogglePicker,
    required this.onFromPicked, required this.onToPicked,
    required this.onResetToday,
    required this.fmtDate, required this.fmtFull,
    required this.list,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Search
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
          ),
          child: Row(children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.search_rounded, color: AppColors.inkMuted, size: 18)),
            Expanded(child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search customer...',
                border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
                hintStyle: GoogleFonts.inter(color: AppColors.inkMuted),
              ),
            )),
          ]),
        ),
        const SizedBox(height: 8),
        // ── Date range pill + inline expandable picker ────────────────────
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onTogglePicker,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isCustomRange ? primary.withValues(alpha: 0.08)
                      : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: datePickerOpen ? primary
                        : isCustomRange ? primary.withValues(alpha: 0.4)
                        : (isDark ? AppColors.separatorDark : AppColors.separator),
                    width: datePickerOpen ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 14,
                      color: isCustomRange || datePickerOpen ? primary : AppColors.inkMuted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    isCustomRange
                        ? '${fmtDate(from)} – ${fmtDate(to)}'
                        : 'Today, ${fmtDate(from)}',
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isCustomRange ? primary
                          : (isDark ? AppColors.inkDark : AppColors.ink),
                    ),
                    overflow: TextOverflow.ellipsis,
                  )),
                  AnimatedRotation(
                    turns: datePickerOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 18,
                        color: isCustomRange || datePickerOpen ? primary : AppColors.inkMuted),
                  ),
                ]),
              ),
            ),
          ),
          if (onResetToday != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onResetToday,
              child: Container(
                height: 38, width: 38,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
                ),
                child: Icon(Icons.today_rounded, size: 16, color: AppColors.inkMuted),
              ),
            ),
          ],
        ]),
        // ── Inline date picker panel (no modal, no save button) ───────────
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: datePickerOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surface2Dark : AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary.withValues(alpha: 0.25)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: _InlineDateField(
                          label: 'FROM',
                          date: from, isDark: isDark, primary: primary,
                          onPicked: onFromPicked,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          fmtFull: fmtFull,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _InlineDateField(
                          label: 'TO',
                          date: to, isDark: isDark, primary: primary,
                          onPicked: onToPicked,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          fmtFull: fmtFull,
                        )),
                      ]),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _QuickPick(label: 'Today',        onTap: onResetToday ?? () {}),
                          _QuickPick(label: 'Yesterday',    onTap: () {
                            final y = DateTime.now().subtract(const Duration(days: 1));
                            onFromPicked(DateTime(y.year, y.month, y.day));
                            onToPicked(DateTime(y.year, y.month, y.day));
                          }),
                          _QuickPick(label: 'Last 7 days',  onTap: () {
                            final n = DateTime.now();
                            onFromPicked(DateTime(n.year, n.month, n.day).subtract(const Duration(days: 6)));
                            onToPicked(n);
                          }),
                          _QuickPick(label: 'This month',   onTap: () {
                            final n = DateTime.now();
                            onFromPicked(DateTime(n.year, n.month, 1));
                            onToPicked(n);
                          }),
                          _QuickPick(label: 'Last 30 days', onTap: () {
                            final n = DateTime.now();
                            onFromPicked(DateTime(n.year, n.month, n.day).subtract(const Duration(days: 29)));
                            onToPicked(n);
                          }),
                        ]),
                      ),
                    ]),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        // Filter chips — All | Daily | Event  (Unpaid removed)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Daily', 'Event'].map((f) {
              final active = f == filter;
              final chipColor = f == 'Event' ? AppColors.purple : primary;
              return GestureDetector(
                onTap: () => onFilterChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active
                        ? chipColor.withValues(alpha: 0.1)
                        : (isDark ? AppColors.surface2Dark : AppColors.surface2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? chipColor
                          : (isDark ? AppColors.separatorDark : AppColors.separator),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (f == 'Daily') ...[
                      Icon(Icons.local_shipping_rounded, size: 12,
                          color: active ? chipColor : AppColors.inkMuted),
                      const SizedBox(width: 4),
                    ] else if (f == 'Event') ...[
                      Icon(Icons.celebration_rounded, size: 12,
                          color: active ? chipColor : AppColors.inkMuted),
                      const SizedBox(width: 4),
                    ],
                    Text(f, style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: active ? chipColor : AppColors.inkMuted)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 4),
      ]),
    );
  }
}


// ── Inline date field (From / To) ────────────────────────────────────────────
class _InlineDateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isDark;
  final Color primary;
  final ValueChanged<DateTime> onPicked;
  final DateTime firstDate, lastDate;
  final String Function(DateTime) fmtFull;

  const _InlineDateField({
    required this.label, required this.date, required this.isDark,
    required this.primary, required this.onPicked,
    required this.firstDate, required this.lastDate, required this.fmtFull,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                  color: primary, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.calendar_month_rounded, size: 13, color: primary),
            const SizedBox(width: 5),
            Expanded(child: Text(
              fmtFull(date),
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.inkDark : AppColors.ink),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
        ]),
      ),
    );
  }
}

// ── Quick-pick shortcut chip ─────────────────────────────────────────────────
class _QuickPick extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickPick({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        child: Text(label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.inkDark : AppColors.ink)),
      ),
    );
  }
}

// ── Summary Strip ─────────────────────────────────────────────────────────────
// ── Summary Strip ─────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final List<JarTransaction> list;
  final Map<String, Customer> custMap;
  final String searchName;

  const _SummaryStrip({
    required this.list,
    required this.custMap,
    required this.searchName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final successC = AppColors.successColor(isDark);
    final dangerC  = AppColors.dangerColor(isDark);
    final coolC    = AppColors.coolColor(isDark);
    final petC     = AppColors.petColor(isDark);

    final billed    = list.fold(0.0, (s, t) => s + t.billedAmount);
    final collected = list.fold(0.0, (s, t) => s + t.amountCollected);
    final cd = list.fold(0, (s, t) => s + t.coolDelivered);
    final pd = list.fold(0, (s, t) => s + t.petDelivered);
    final cr = list.fold(0, (s, t) => s + t.coolReturned);
    final pr = list.fold(0, (s, t) => s + t.petReturned);

    // When a single customer is searched, show their TOTAL ledger balance
    // instead of the period net — prevents misleading "Advance" label
    // when customer still has overall dues
    Customer? singleCust;
    if (searchName.isNotEmpty) {
      final q = searchName.toLowerCase();
      final matches = custMap.values.where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.phone.contains(q)).toList();
      if (matches.length == 1) singleCust = matches.first;
    }

    final String thirdLabel;
    final String thirdValue;
    final Color  thirdColor;
    if (singleCust != null) {
      final bal = singleCust.ledgerBalance;
      thirdLabel = bal < 0 ? 'Total Due' : bal > 0 ? 'Total Adv' : 'Settled';
      thirdValue = bal != 0 ? '₹${bal.abs().toInt()}' : '—';
      thirdColor = bal < 0 ? dangerC : bal > 0 ? successC : AppColors.inkMuted;
    } else {
      final net = collected - billed;
      thirdLabel = net < 0 ? 'Net Due' : net > 0 ? 'Net Adv' : 'Settled';
      thirdValue = net != 0 ? '₹${net.abs().toInt()}' : '—';
      thirdColor = net < 0 ? dangerC : net > 0 ? successC : AppColors.inkMuted;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2Dark : AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.separatorDark : AppColors.separator),
      ),
      child: Column(children: [
        IntrinsicHeight(
          child: Row(children: [
            _SC('Billed',    '₹${billed.toInt()}',    primary,   isDark),
            _div(isDark),
            _SC('Collected', '₹${collected.toInt()}', successC,  isDark),
            _div(isDark),
            _SC(thirdLabel,  thirdValue,              thirdColor, isDark),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1,
              color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        Row(children: [
          Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            CoolJarIcon(size: 13, color: coolC),
            const SizedBox(width: 5),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('COOL', style: GoogleFonts.inter(fontSize: 9,
                  fontWeight: FontWeight.w700, color: coolC, letterSpacing: 0.4)),
              Text('↓$cd  ↑$cr', style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w700, color: coolC)),
            ]),
          ])),
          Container(width: 1, height: 28,
              color: isDark ? AppColors.separatorDark : AppColors.separator),
          Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            PetJarIcon(size: 13, color: petC),
            const SizedBox(width: 5),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PET', style: GoogleFonts.inter(fontSize: 9,
                  fontWeight: FontWeight.w700, color: petC, letterSpacing: 0.4)),
              Text('↓$pd  ↑$pr', style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w700, color: petC)),
            ]),
          ])),
          Container(width: 1, height: 28,
              color: isDark ? AppColors.separatorDark : AppColors.separator),
          Expanded(child: Column(children: [
            Text('TXN', style: GoogleFonts.inter(fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.inkMuted, letterSpacing: 0.4)),
            Text('${list.length}', style: GoogleFonts.jetBrainsMono(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.inkDark : AppColors.ink)),
          ])),
        ]),
      ]),
    );
  }

  Widget _div(bool dark) => Container(
      width: 1, margin: const EdgeInsets.symmetric(horizontal: 6),
      color: dark ? AppColors.separatorDark : AppColors.separator);
}


class _SC extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _SC(this.label, this.value, this.color, this.isDark);

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
          color: AppColors.inkMuted, letterSpacing: 0.5)),
      const SizedBox(height: 3),
      FittedBox(fit: BoxFit.scaleDown, child:
        Text(value, style: GoogleFonts.jetBrainsMono(
            fontSize: 14, fontWeight: FontWeight.w700, color: color))),
    ],
  ));
}

// ── Event Status Badge ───────────────────────────────────────────────────────
class _EventStatusBadge extends StatelessWidget {
  final String status;
  final bool isDark;
  const _EventStatusBadge({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      'scheduled' => ('Scheduled', Icons.schedule_rounded,    AppColors.warningColor(isDark)),
      'active'    => ('Active',    Icons.play_circle_rounded, AppColors.primaryColor(isDark)),
      'completed' => ('Done',      Icons.check_circle_rounded,AppColors.successColor(isDark)),
      _           => ('Unknown',   Icons.circle_outlined,     AppColors.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.inter(
            fontSize: 9, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

// ── Transaction Card ──────────────────────────────────────────────────────────
class _TxnCard extends StatelessWidget {
  final JarTransaction tx;
  final Map<String, Customer> custMap;   // for real ledger balance
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _TxnCard({required this.tx, required this.custMap,
      required this.onTap, required this.onDelete});

  // ── Type detection ────────────────────────────────────────────────────────
  bool get _isPurePayment => tx.billedAmount == 0 && tx.amountCollected > 0;
  bool get _isPureReturn  => tx.coolDelivered == 0 && tx.petDelivered == 0
                           && (tx.coolReturned > 0 || tx.petReturned > 0);
  bool get _isEvent       => tx.deliveryType == 'event';
  // everything else = daily delivery

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final coolC   = AppColors.coolColor(isDark);
    final petC    = AppColors.petColor(isDark);
    final okC     = AppColors.successColor(isDark);
    final primary = Theme.of(context).colorScheme.primary;

    // ── Badge config per type ─────────────────────────────────────────────
    final bool isAdvance     = _isPurePayment && tx.paymentMode == 'advance';
    final bool isEventPayment = _isPurePayment && tx.deliveryType == 'event';
    final (badgeLabel, badgeIcon, badgeColor) = isAdvance
        ? ('Advance',  Icons.savings_rounded,          AppColors.purple)
        : isEventPayment
            ? ('Evt Pay', Icons.celebration_rounded,   okC)
            : _isPurePayment
                ? ('Payment',  Icons.payments_rounded, okC)
                : _isPureReturn
                    ? ('Return',   Icons.undo_rounded,         AppColors.inkMuted)
                    : _isEvent
                        ? ('Event',    Icons.celebration_rounded, AppColors.purple)
                        : ('Delivery', Icons.local_shipping_rounded, primary);

    // ── Amount display ────────────────────────────────────────────────────
    // Payment txn → show collected amount (billed is 0, meaningless)
    // Delivery/Event → show billed amount
    // Return → show damage charge if any, else 0
    final displayAmount = _isPurePayment
        ? tx.amountCollected
        : tx.billedAmount;

    // ── Status chip: dynamic due / advance / paid — never show for ₹0 entries ──
    // Per-transaction balance: positive = customer owes on THIS tx
    final txBalance = tx.balance; // billedAmount - amountCollected

    // For pure payments, returns with ₹0 billed/collected, never show a chip
    // For deliveries: show due, advance, or paid based on per-tx balance
    String? statusLabel;
    Color? statusColor;

    if (_isPurePayment) {
      // Pure payment — no status chip needed (amount speaks for itself)
      statusLabel = null;
    } else if (txBalance == 0 && displayAmount == 0) {
      // ₹0 transaction (e.g. pure return with no damage) — nothing to show
      statusLabel = null;
    } else if (txBalance > 0) {
      // This tx has unpaid balance
      statusLabel = '₹${txBalance.toInt()} due';
      statusColor = AppColors.dangerColor(isDark);
    } else if (txBalance < 0) {
      // Overpaid on this tx → advance applied
      statusLabel = '₹${txBalance.abs().toInt()} adv';
      statusColor = okC;
    } else {
      // txBalance == 0 and something was billed/collected → fully paid
      statusLabel = '✓ Paid';
      statusColor = okC;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Top row: avatar | name + badges | amount ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(children: [
                CustomerAvatar(initials: _initials(tx.customerName), size: 38),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: Text(tx.customerName,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis, maxLines: 1)),
                    const SizedBox(width: 6),
                    // ── Type badge ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(badgeIcon, size: 10, color: badgeColor),
                        const SizedBox(width: 3),
                        Text(badgeLabel, style: GoogleFonts.inter(fontSize: 9,
                            fontWeight: FontWeight.w800, color: badgeColor)),
                      ]),
                    ),
                    if (_isEvent && tx.eventStatus != null) ...[
                      const SizedBox(width: 4),
                      _EventStatusBadge(status: tx.eventStatus!, isDark: isDark),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  // Date + time + event name + edited tag
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 11, color: AppColors.inkMuted),
                    const SizedBox(width: 3),
                    Text(_fmtDate(tx.date),
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
                    const SizedBox(width: 4),
                    Text(_fmtTime(tx.createdAt),
                        style: GoogleFonts.inter(fontSize: 11,
                            color: AppColors.inkMuted.withValues(alpha: 0.7))),
                    if (_isEvent && tx.eventName != null && tx.eventName!.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Flexible(child: Text('· ${tx.eventName}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.purple,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis)),
                    ],
                    if (tx.updatedAt != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warningColor(isDark).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('edited', style: GoogleFonts.inter(fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningColor(isDark))),
                      ),
                    ],
                  ]),
                ])),
                // ── Amount + status chip ───────────────────────────────────
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (displayAmount > 0)
                    Text('₹${displayAmount.toInt()}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                  if (statusLabel != null && statusColor != null)
                    StatusChip(label: statusLabel, color: statusColor),
                ]),
              ]),
            ),

            // ── Detail grid (COOL | PET | PAY) ───────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark ? AppColors.separatorDark : AppColors.separator),
              ),
              child: IntrinsicHeight(child: Row(children: [
                // Cool
                Expanded(child: _JarDetail(
                  icon: CoolJarIcon(size: 16, color: coolC), label: 'COOL', color: coolC,
                  delivered: tx.coolDelivered, returned: tx.coolReturned,
                  damaged: tx.coolDamaged, isDark: isDark, okColor: okC,
                )),
                VerticalDivider(width: 1, thickness: 1,
                    color: isDark ? AppColors.separatorDark : AppColors.separator),
                // PET
                Expanded(child: _JarDetail(
                  icon: PetJarIcon(size: 16, color: petC), label: 'PET', color: petC,
                  delivered: tx.petDelivered, returned: tx.petReturned,
                  damaged: tx.petDamaged, isDark: isDark, okColor: okC,
                )),
                VerticalDivider(width: 1, thickness: 1,
                    color: isDark ? AppColors.separatorDark : AppColors.separator),
                // Payment cell
                Expanded(child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_modeIcon(tx.paymentMode), size: 16, color: primary),
                    const SizedBox(height: 3),
                    Text('PAY', style: GoogleFonts.inter(fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted, letterSpacing: 0.4)),
                    const SizedBox(height: 5),
                    if (tx.amountCollected <= 0)
                      Text('—', style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.inkMuted))
                    else
                      // Mode pill + amount pill side by side
                      Wrap(alignment: WrapAlignment.center,
                          spacing: 3, runSpacing: 3, children: [
                        _payPill(_modeLabel(tx.paymentMode), primary),
                        _payPill('₹${tx.amountCollected.toInt()}', okC, mono: true),
                      ]),
                  ]),
                )),
              ])),
            ),

            // Note
            if (tx.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(children: [
                  const Icon(Icons.notes_rounded, size: 12, color: AppColors.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(tx.note,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted))),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  String _initials(String name) {
    final p = name.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : name.substring(0, math.min(2, name.length)).toUpperCase();
  }

  static Widget _payPill(String label, Color c, {bool mono = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: mono
        ? GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: c)
        : GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
  );

  String _fmtDate(String d) {
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(d)); }
    catch (_) { return d; }
  }

  String _fmtTime(String iso) {
    try { return DateFormat('h:mm a').format(DateTime.parse(iso).toLocal()); }
    catch (_) { return ''; }
  }

  IconData _modeIcon(String m) => switch (m) {
    'cash' => Icons.payments_rounded,
    'upi'  => Icons.phone_android_rounded,
    'bank' => Icons.account_balance_rounded,
    _      => Icons.attach_money_rounded,
  };
  String _modeLabel(String m) => switch (m) {
    'cash' => 'Cash', 'upi' => 'UPI', 'bank' => 'Bank', _ => m,
  };
}


class _JarDetail extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color, okColor;
  final int delivered, returned, damaged;
  final bool isDark;
  const _JarDetail({required this.icon, required this.label, required this.color,
      required this.delivered, required this.returned, required this.damaged,
      required this.isDark, required this.okColor});

  @override
  Widget build(BuildContext context) {
    final empty = delivered == 0 && returned == 0 && damaged == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        icon,
        const SizedBox(height: 3),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700,
            color: empty ? AppColors.inkMuted : color, letterSpacing: 0.4)),
        const SizedBox(height: 5),
        if (empty)
          Text('—', style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted))
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (delivered > 0) _pill('↓$delivered', color),
              if (delivered > 0 && returned > 0) const SizedBox(width: 3),
              if (returned > 0)  _pill('↑$returned', okColor),
              if ((delivered > 0 || returned > 0) && damaged > 0) const SizedBox(width: 3),
              if (damaged > 0)   _pill('⚠$damaged', AppColors.dangerColor(isDark)),
            ]),
          ),
      ]),
    );
  }

  Widget _pill(String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label, style: GoogleFonts.jetBrainsMono(
        fontSize: 10, fontWeight: FontWeight.w700, color: c)),
  );
}

// _ActBtn removed — card tap opens edit sheet

// ══════════════════════════════════════════════════════════════════════════════
// TRANSACTION FORM  (Daily + Event)
// ══════════════════════════════════════════════════════════════════════════════
class TxnForm extends ConsumerStatefulWidget {
  final JarTransaction? existing;
  /// Pre-select delivery type: 'daily', 'event'. null = show toggle.
  final String? initialDeliveryType;
  const TxnForm({super.key, this.existing, this.initialDeliveryType});

  @override
  ConsumerState<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends ConsumerState<TxnForm> {
  final _formKey = GlobalKey<FormState>();
  Customer? _cust;
  int _cd = 0, _pd = 0, _cr = 0, _pr = 0, _cdmg = 0, _pdmg = 0;
  double _collected = 0;
  String _mode = 'cash';
  String _deliveryType = 'daily'; // 'daily' | 'event'
  final _noteCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _eventNameCtrl = TextEditingController();
  final _transportCtrl = TextEditingController();
  DateTime? _eventDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _cd = e.coolDelivered; _pd = e.petDelivered;
      _cr = e.coolReturned; _pr = e.petReturned;
      _cdmg = e.coolDamaged; _pdmg = e.petDamaged;
      _collected = e.amountCollected;
      _amtCtrl.text = e.amountCollected.toInt().toString();
      _mode = e.paymentMode;
      _noteCtrl.text = e.note;
      _deliveryType = e.deliveryType ?? 'daily';
      _eventNameCtrl.text = e.eventName ?? '';
      if ((e.transportFee) > 0) _transportCtrl.text = e.transportFee.toInt().toString();
      _eventStatus = e.eventStatus ?? _autoEventStatus(e.date);
    } else {
      if (widget.initialDeliveryType != null) {
        _deliveryType = widget.initialDeliveryType!;
      }
      final preSelected = ref.read(selectedCustomerForTxnProvider);
      if (preSelected != null) {
        _cust = preSelected;
        Future.microtask(() => ref.read(selectedCustomerForTxnProvider.notifier).state = null);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existing != null && _cust == null) {
      final custs = ref.read(customersProvider);
      try { _cust = custs.firstWhere((c) => c.id == widget.existing!.customerId); } catch (_) {}
    }
  }

  // ── inline price override state ─────────────────────────────────────────────
  bool _showPriceOverride = false;
  final _coolOverrideCtrl = TextEditingController();
  final _petOverrideCtrl = TextEditingController();
  // ── event status ──────────────────────────────────────────────────────────
  String _eventStatus = 'scheduled'; // scheduled | active | completed

  @override
  void dispose() {
    _noteCtrl.dispose(); _amtCtrl.dispose(); _eventNameCtrl.dispose();
    _transportCtrl.dispose(); _coolOverrideCtrl.dispose(); _petOverrideCtrl.dispose();
    super.dispose();
  }

  static String _autoEventStatus(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eventDay = DateTime(d.year, d.month, d.day);
      if (eventDay.isAfter(today)) return 'scheduled';
      if (eventDay == today) return 'active';
      return 'active';
    } catch (_) { return 'active'; }
  }

  AppSettings get _s => ref.read(settingsProvider);
  double get _effectiveCoolPrice {
    // inline override takes priority, then customer override, then settings
    final inline = double.tryParse(_coolOverrideCtrl.text);
    if (inline != null && inline > 0) return inline;
    return _cust?.coolPriceOverride ?? _s.coolPrice;
  }
  double get _effectivePetPrice {
    final inline = double.tryParse(_petOverrideCtrl.text);
    if (inline != null && inline > 0) return inline;
    return _cust?.petPriceOverride ?? _s.petPrice;
  }
  double get _eventTransportFee  => double.tryParse(_transportCtrl.text) ?? 0;
  double get _billed => (_cd * _effectiveCoolPrice) + (_pd * _effectivePetPrice)
      + ((_cdmg + _pdmg) * _s.damageChargePerJar)
      + (_deliveryType == 'event' ? _eventTransportFee : 0);
  bool get _hasAny => _cd > 0 || _pd > 0 || _cr > 0 || _pr > 0;

  void _onCustomerSelected(Customer c) {
    setState(() {
      _cust = c;
      // Pre-fill override fields with customer's existing override if set
      _coolOverrideCtrl.text = c.coolPriceOverride != null ? c.coolPriceOverride!.toStringAsFixed(0) : '';
      _petOverrideCtrl.text  = c.petPriceOverride  != null ? c.petPriceOverride!.toStringAsFixed(0)  : '';
    });
  }

  Future<void> _save() async {
    if (_cust == null) { showToast(context, 'Select a customer', error: true); return; }
    if (!_hasAny) { showToast(context, 'Add at least one jar entry', error: true); return; }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 250));
    final now = DateTime.now().toIso8601String();
    // Persist inline price overrides back to customer if changed
    final inlineCool = double.tryParse(_coolOverrideCtrl.text);
    final inlinePet  = double.tryParse(_petOverrideCtrl.text);
    final updatedCust = _cust!.copyWith(
      coolPriceOverride: inlineCool != null && inlineCool > 0 ? inlineCool : _cust!.coolPriceOverride,
      petPriceOverride:  inlinePet  != null && inlinePet  > 0 ? inlinePet  : _cust!.petPriceOverride,
    );
    if (inlineCool != _cust!.coolPriceOverride || inlinePet != _cust!.petPriceOverride) {
      ref.read(customersProvider.notifier).update(updatedCust);
    }

    final tx = JarTransaction(
      id: widget.existing?.id ?? _uuid.v4(),
      customerId: _cust!.id, customerName: _cust!.name,
      date: widget.existing?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      coolDelivered: _cd, petDelivered: _pd, coolReturned: _cr, petReturned: _pr,
      coolDamaged: _cdmg, petDamaged: _pdmg,
      coolPrice: _effectiveCoolPrice,
      petPrice: _effectivePetPrice,
      billedAmount: _billed, amountCollected: _collected, paymentMode: _mode,
      damageCharge: (_cdmg + _pdmg) * _s.damageChargePerJar,
      transportFee: _deliveryType == 'event' ? _eventTransportFee : 0,
      note: _noteCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: widget.existing != null ? now : null,
      createdBy: 'Admin',
      deliveryType: _deliveryType,
      eventName: _deliveryType == 'event' ? _eventNameCtrl.text.trim() : null,
      eventStatus: _deliveryType == 'event' ? _eventStatus : null,
    );
    if (widget.existing != null) {
      // Awaited — Navigator.pop only fires after Firebase write confirms.
      // This prevents the race where the screen pops before the tx is saved.
      await ref.read(transactionsProvider.notifier).edit(widget.existing!, tx);
    } else {
      await ref.read(transactionsProvider.notifier).add(tx);
    }
    if (mounted) {
      Navigator.pop(context);
      showToast(context, widget.existing != null ? '✅ Updated & synced' : '✅ Saved & inventory updated', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = ref.watch(inventoryProvider);
    final custs = ref.watch(customersProvider).where((c) => c.isActive).toList();
    final s = ref.watch(settingsProvider);
    final coolC = AppColors.coolColor(isDark);
    final petC = AppColors.petColor(isDark);
    final isEvent = _deliveryType == 'event';

    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Delivery Type Toggle — hidden when type pre-set from quick action ──
        if (widget.initialDeliveryType == null) ...[
          _DeliveryTypeToggle(
            selected: _deliveryType,
            onSelect: (t) => setState(() => _deliveryType = t),
            isDark: isDark,
          ),
          const SizedBox(height: 20),
        ],

        // ── Event Details (only for events) ──────────────────────────────────
        if (isEvent) ...[
          _EventDetailsSection(
            nameCtrl: _eventNameCtrl,
            transportCtrl: _transportCtrl,
            eventDate: _eventDate,
            isDark: isDark,
            onDatePicked: (d) => setState(() => _eventDate = d),
            onTransportChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
        ],

        // ── Customer Picker ───────────────────────────────────────────────────
        FieldLabel('Customer *'),
        _CustPicker(
          selected: _cust,
          customers: custs,
          onSelect: _onCustomerSelected,
        ),
        // ── Inline Price Override ───────────────────────────────────────────
        if (_cust != null) _InlinePriceOverride(
          cust: _cust!,
          coolCtrl: _coolOverrideCtrl,
          petCtrl: _petOverrideCtrl,
          defaultCoolPrice: _s.coolPrice,
          defaultPetPrice: _s.petPrice,
          showOverride: _showPriceOverride,
          onToggle: () => setState(() => _showPriceOverride = !_showPriceOverride),
          onChanged: () => setState(() {}),
          isDark: isDark,
        ),
        const SizedBox(height: 20),

        // ── Jar Table ─────────────────────────────────────────────────────────
        FieldLabel(isEvent ? 'Jars — Event Delivery' : 'Jars — Send & Collect'),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgDark : AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: LayoutBuilder(builder: (ctx, bc) {
                final labelW = (bc.maxWidth * 0.22).clamp(56.0, 80.0);
                return Row(children: [
                  SizedBox(width: labelW),
                  Expanded(child: _ColHeader(
                    icon: Icons.arrow_downward_rounded,
                    label: 'IN',
                    sub: isEvent ? 'jars to event' : 'delivered to customer',
                    color: Theme.of(context).colorScheme.primary,
                  )),
                  if (!isEvent)
                    Expanded(child: _ColHeader(
                      icon: Icons.arrow_upward_rounded,
                      label: 'OUT',
                      sub: 'collected from customer',
                      color: AppColors.successColor(isDark),
                    )),
                ]);
              }),
            ),
            Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
            _JarInputRow(
              jarIcon: CoolJarIcon(size: 22, color: coolC),
              label: 'Cool', color: coolC,
              stockInfo: 'Stock: ${inv.coolStock}',
              priceInfo: _effectiveCoolPrice != _s.coolPrice
                  ? '₹${_effectiveCoolPrice.toInt()}/jar ★'
                  : '₹${s.coolPrice.toInt()}/jar',
              unitPrice: _effectiveCoolPrice,
              delivered: _cd, returned: isEvent ? 0 : _cr,
              showReturn: !isEvent,
              maxDeliver: inv.coolStock + (widget.existing?.coolDelivered ?? 0),
              maxReturn: (_cust?.coolOut ?? 99) + (widget.existing?.coolReturned ?? 0),
              onDeliverChanged: (v) => setState(() => _cd = v),
              onReturnChanged: (v) => setState(() => _cr = v),
            ),
            Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
            _JarInputRow(
              jarIcon: PetJarIcon(size: 22, color: petC),
              label: 'PET', color: petC,
              stockInfo: 'Stock: ${inv.petStock}',
              priceInfo: _effectivePetPrice != _s.petPrice
                  ? '₹${_effectivePetPrice.toInt()}/jar ★'
                  : '₹${s.petPrice.toInt()}/jar',
              unitPrice: _effectivePetPrice,
              delivered: _pd, returned: isEvent ? 0 : _pr,
              showReturn: !isEvent,
              maxDeliver: inv.petStock + (widget.existing?.petDelivered ?? 0),
              maxReturn: (_cust?.petOut ?? 99) + (widget.existing?.petReturned ?? 0),
              onDeliverChanged: (v) => setState(() => _pd = v),
              onReturnChanged: (v) => setState(() => _pr = v),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Event Status & Return Jars ────────────────────────────────────────
        if (isEvent) ...[
          const SizedBox(height: 12),
          _EventStatusSection(
            status: _eventStatus,
            eventDate: _eventDate,
            coolDelivered: _cd,
            petDelivered: _pd,
            coolReturned: _cr,
            petReturned: _pr,
            coolReturnDmg: _cdmg,
            petReturnDmg: _pdmg,
            isDark: isDark,
            onStatusChange: (s) => setState(() => _eventStatus = s),
            onCoolReturnChanged: (v) => setState(() => _cr = v),
            onPetReturnChanged: (v) => setState(() => _pr = v),
            onCoolDmgChanged: (v) => setState(() => _cdmg = v),
            onPetDmgChanged: (v) => setState(() => _pdmg = v),
            maxCoolReturn: _cd,
            maxPetReturn: _pd,
          ),
        ],

        // ── Damaged Jars (daily only, when returns exist) ─────────────────────
        if (!isEvent && (_cr > 0 || _pr > 0))
          _DamagedSection(
            coolReturned: _cr, petReturned: _pr,
            coolDmg: _cdmg, petDmg: _pdmg,
            coolColor: coolC, petColor: petC, isDark: isDark,
            onCoolChanged: (v) => setState(() => _cdmg = v),
            onPetChanged: (v) => setState(() => _pdmg = v),
            damagePerJar: s.damageChargePerJar,
          ),

        // ── Bill Summary ──────────────────────────────────────────────────────
        if (_billed > 0) ...[
          const SizedBox(height: 12),
          _BillCard(
            cd: _cd, pd: _pd, cdmg: isEvent ? 0 : _cdmg, pdmg: isEvent ? 0 : _pdmg,
            coolPrice: _effectiveCoolPrice, petPrice: _effectivePetPrice,
            dmgPrice: s.damageChargePerJar, total: _billed,
            advance: _cust?.advanceBalance ?? 0,
            transportFee: isEvent ? _eventTransportFee : 0,
          ),
        ],
        const SizedBox(height: 16),

        // ── Amount Collected ──────────────────────────────────────────────────
        FieldLabel('Amount Collected', hint: '(leave 0 = unpaid)'),
        _AmountField(
          ctrl: _amtCtrl,
          hint: _billed.toInt().toString(),
          advance: _cust?.advanceBalance ?? 0,
          onChanged: (v) => setState(() => _collected = v),
          onUseAdvance: () => setState(() {
            _collected = _billed;
            _amtCtrl.text = _billed.toInt().toString();
            // Advance is deducted from their balance — payment mode stays cash/upi
          }),
        ),
        const SizedBox(height: 16),

        // ── Payment Mode ──────────────────────────────────────────────────────
        FieldLabel('Payment Mode'),
        PaymentModePicker(selected: _mode, onSelect: (m) => setState(() => _mode = m)),
        const SizedBox(height: 16),

        // ── Note ──────────────────────────────────────────────────────────────
        FieldLabel('Note (optional)'),
        TextFormField(
          controller: _noteCtrl,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Any notes...'),
        ),
        const SizedBox(height: 24),

        // ── Save / Delete buttons ─────────────────────────────────────────
        if (widget.existing != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.dangerColor(isDark).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.dangerColor(isDark).withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.dangerColor(isDark)),
                const SizedBox(width: 8),
                Text('Delete Transaction', style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.dangerColor(isDark))),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        GradientButton(
          label: widget.existing != null ? 'Update Transaction' : 'Save & Sync',
          loading: _saving,
          onTap: _hasAny && _cust != null ? _save : null,
          gradient: (!_hasAny || _cust == null)
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
              : (isEvent
                  ? const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFFB388FF)],
                      begin: Alignment.centerLeft, end: Alignment.centerRight)
                  : AppColors.primaryGradient),
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await confirmDialog(context,
      title: 'Delete Transaction?',
      message: 'Inventory and payments for ${_cust?.name ?? ''} will be reversed. Cannot be undone.',
    );
    if (ok && mounted) {
      ref.read(transactionsProvider.notifier).delete(widget.existing!);
      Navigator.pop(context);
      if (mounted) {
        showToast(context, 'Transaction deleted & inventory reversed', error: true);
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED helpers used by all 4 focused forms
// ══════════════════════════════════════════════════════════════════════════════

/// Reusable delete button strip shown at the bottom of edit forms.
class _DeleteBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _DeleteBtn({required this.onTap, required this.isDark});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.dangerColor(isDark).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dangerColor(isDark).withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.dangerColor(isDark)),
        const SizedBox(width: 8),
        Text('Delete Transaction', style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.dangerColor(isDark))),
      ]),
    ),
  );
}

Future<void> _confirmDeleteTx(BuildContext context, WidgetRef ref,
    JarTransaction tx, String custName) async {
  final ok = await confirmDialog(context,
    title: 'Delete Transaction?',
    message: 'Records for $custName will be reversed. Cannot be undone.',
  );
  if (ok && context.mounted) {
    ref.read(transactionsProvider.notifier).delete(tx);
    Navigator.pop(context);
    showToast(context, 'Transaction deleted & reversed', error: true);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 1. DELIVERY FORM
// ══════════════════════════════════════════════════════════════════════════════
class DeliveryForm extends ConsumerStatefulWidget {
  final JarTransaction? existing;
  const DeliveryForm({super.key, this.existing});
  @override
  ConsumerState<DeliveryForm> createState() => _DeliveryFormState();
}

class _DeliveryFormState extends ConsumerState<DeliveryForm> {
  final _formKey = GlobalKey<FormState>();
  Customer? _cust;
  int _cd = 0, _pd = 0, _cr = 0, _pr = 0, _cdmg = 0, _pdmg = 0;
  double _collected = 0;
  String _mode = 'cash';
  bool _showPriceOverride = false;
  bool _saving = false;
  final _noteCtrl         = TextEditingController();
  final _amtCtrl          = TextEditingController();
  final _coolOverrideCtrl = TextEditingController();
  final _petOverrideCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _cd = e.coolDelivered; _pd = e.petDelivered;
      _cr = e.coolReturned;  _pr = e.petReturned;
      _cdmg = e.coolDamaged; _pdmg = e.petDamaged;
      _collected = e.amountCollected;
      _amtCtrl.text = e.amountCollected.toInt().toString();
      _mode = e.paymentMode;
      _noteCtrl.text = e.note;
    } else {
      final pre = ref.read(selectedCustomerForTxnProvider);
      if (pre != null) {
        _cust = pre;
        Future.microtask(() => ref.read(selectedCustomerForTxnProvider.notifier).state = null);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existing != null && _cust == null) {
      try { _cust = ref.read(customersProvider).firstWhere((c) => c.id == widget.existing!.customerId); }
      catch (_) {}
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose(); _amtCtrl.dispose();
    _coolOverrideCtrl.dispose(); _petOverrideCtrl.dispose();
    super.dispose();
  }

  AppSettings get _s => ref.read(settingsProvider);
  double get _effectiveCoolPrice {
    final v = double.tryParse(_coolOverrideCtrl.text);
    return (v != null && v > 0) ? v : (_cust?.coolPriceOverride ?? _s.coolPrice);
  }
  double get _effectivePetPrice {
    final v = double.tryParse(_petOverrideCtrl.text);
    return (v != null && v > 0) ? v : (_cust?.petPriceOverride ?? _s.petPrice);
  }
  double get _billed => (_cd * _effectiveCoolPrice) + (_pd * _effectivePetPrice)
      + ((_cdmg + _pdmg) * _s.damageChargePerJar);
  bool get _hasAny => _cd > 0 || _pd > 0;

  void _onCustSelected(Customer c) => setState(() {
    _cust = c;
    _coolOverrideCtrl.text = c.coolPriceOverride?.toStringAsFixed(0) ?? '';
    _petOverrideCtrl.text  = c.petPriceOverride?.toStringAsFixed(0)  ?? '';
  });

  Future<void> _save() async {
    if (_cust == null) { showToast(context, 'Select a customer', error: true); return; }
    if (!_hasAny)      { showToast(context, 'Add at least one jar to deliver', error: true); return; }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now().toIso8601String();
    final inlineCool = double.tryParse(_coolOverrideCtrl.text);
    final inlinePet  = double.tryParse(_petOverrideCtrl.text);
    if (inlineCool != _cust!.coolPriceOverride || inlinePet != _cust!.petPriceOverride) {
      ref.read(customersProvider.notifier).update(_cust!.copyWith(
        coolPriceOverride: (inlineCool != null && inlineCool > 0) ? inlineCool : _cust!.coolPriceOverride,
        petPriceOverride:  (inlinePet  != null && inlinePet  > 0) ? inlinePet  : _cust!.petPriceOverride,
      ));
    }
    final tx = JarTransaction(
      id: widget.existing?.id ?? _uuid.v4(),
      customerId: _cust!.id, customerName: _cust!.name,
      date: widget.existing?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      coolDelivered: _cd, petDelivered: _pd,
      coolReturned: _cr, petReturned: _pr,
      coolDamaged: _cdmg, petDamaged: _pdmg,
      coolPrice: _effectiveCoolPrice, petPrice: _effectivePetPrice,
      billedAmount: _billed, amountCollected: _collected, paymentMode: _mode,
      damageCharge: (_cdmg + _pdmg) * _s.damageChargePerJar,
      note: _noteCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: widget.existing != null ? now : null,
      createdBy: 'Admin', deliveryType: 'daily',
    );
    widget.existing != null
        ? await ref.read(transactionsProvider.notifier).edit(widget.existing!, tx)
        : await ref.read(transactionsProvider.notifier).add(tx);
    if (mounted) {
      Navigator.pop(context);
      showToast(context, widget.existing != null ? '✅ Updated' : '✅ Delivery saved', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv    = ref.watch(inventoryProvider);
    final custs  = ref.watch(customersProvider).where((c) => c.isActive).toList();
    final s      = ref.watch(settingsProvider);
    final coolC  = AppColors.coolColor(isDark);
    final petC   = AppColors.petColor(isDark);
    final primary = Theme.of(context).colorScheme.primary;

    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Voice fill button ──────────────────────────────────────────────────
      if (widget.existing == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            VoiceMicButton(
              formType: VoiceFormType.delivery,
              preselectedCustomer: _cust,
              onResult: (r) {
                setState(() {
                  if (r.customer != null) { _cust = r.customer; _onCustSelected(r.customer!); }
                  _cd = r.coolDelivered; _pd = r.petDelivered;
                  _cr = r.coolReturned;  _pr = r.petReturned;
                  _collected = r.payment;
                  _amtCtrl.text = r.payment.toInt().toString();
                });
              },
            ),
            const SizedBox(width: 8),
            Text('Fill fields by voice',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
          ]),
        ),
      FieldLabel('Customer *'),
      _CustPicker(selected: _cust, customers: custs, onSelect: _onCustSelected),
      if (_cust != null) _InlinePriceOverride(
        cust: _cust!, coolCtrl: _coolOverrideCtrl, petCtrl: _petOverrideCtrl,
        defaultCoolPrice: s.coolPrice, defaultPetPrice: s.petPrice,
        showOverride: _showPriceOverride,
        onToggle: () => setState(() => _showPriceOverride = !_showPriceOverride),
        onChanged: () => setState(() {}), isDark: isDark),
      const SizedBox(height: 20),

      FieldLabel('Jars — Deliver & Collect'),
      Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDark : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 0), child: LayoutBuilder(builder: (ctx, bc) {
            final labelW = (bc.maxWidth * 0.22).clamp(56.0, 80.0);
            return Row(children: [
              SizedBox(width: labelW),
              Expanded(child: _ColHeader(icon: Icons.arrow_downward_rounded, label: 'IN',
                  sub: 'delivered to customer', color: primary)),
              Expanded(child: _ColHeader(icon: Icons.arrow_upward_rounded, label: 'OUT',
                  sub: 'collected from customer', color: AppColors.successColor(isDark))),
            ]);
          })),
          Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
          _JarInputRow(jarIcon: CoolJarIcon(size: 22, color: coolC), label: 'Cool', color: coolC,
            stockInfo: 'Stock: ${inv.coolStock}',
            priceInfo: _effectiveCoolPrice != s.coolPrice ? '₹${_effectiveCoolPrice.toInt()}/jar ★' : '₹${s.coolPrice.toInt()}/jar',
            unitPrice: _effectiveCoolPrice, delivered: _cd, returned: _cr, showReturn: true,
            maxDeliver: inv.coolStock + (widget.existing?.coolDelivered ?? 0),
            maxReturn: (_cust?.coolOut ?? 99) + (widget.existing?.coolReturned ?? 0),
            onDeliverChanged: (v) => setState(() => _cd = v),
            onReturnChanged:  (v) => setState(() => _cr = v)),
          Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
          _JarInputRow(jarIcon: PetJarIcon(size: 22, color: petC), label: 'PET', color: petC,
            stockInfo: 'Stock: ${inv.petStock}',
            priceInfo: _effectivePetPrice != s.petPrice ? '₹${_effectivePetPrice.toInt()}/jar ★' : '₹${s.petPrice.toInt()}/jar',
            unitPrice: _effectivePetPrice, delivered: _pd, returned: _pr, showReturn: true,
            maxDeliver: inv.petStock + (widget.existing?.petDelivered ?? 0),
            maxReturn: (_cust?.petOut ?? 99) + (widget.existing?.petReturned ?? 0),
            onDeliverChanged: (v) => setState(() => _pd = v),
            onReturnChanged:  (v) => setState(() => _pr = v)),
        ]),
      ),
      const SizedBox(height: 12),

      if (_cr > 0 || _pr > 0) _DamagedSection(
        coolReturned: _cr, petReturned: _pr, coolDmg: _cdmg, petDmg: _pdmg,
        coolColor: coolC, petColor: petC, isDark: isDark,
        onCoolChanged: (v) => setState(() => _cdmg = v),
        onPetChanged:  (v) => setState(() => _pdmg = v),
        damagePerJar: s.damageChargePerJar),

      if (_billed > 0) ...[
        const SizedBox(height: 12),
        _BillCard(cd: _cd, pd: _pd, cdmg: _cdmg, pdmg: _pdmg,
          coolPrice: _effectiveCoolPrice, petPrice: _effectivePetPrice,
          dmgPrice: s.damageChargePerJar, total: _billed,
          advance: _cust?.advanceBalance ?? 0),
      ],
      const SizedBox(height: 16),

      FieldLabel('Amount Collected', hint: '(leave 0 = unpaid)'),
      _AmountField(ctrl: _amtCtrl, hint: _billed.toInt().toString(),
        advance: _cust?.advanceBalance ?? 0,
        onChanged: (v) => setState(() => _collected = v),
        onUseAdvance: () => setState(() { _collected = _billed; _amtCtrl.text = _billed.toInt().toString(); })),
      const SizedBox(height: 16),

      FieldLabel('Payment Mode'),
      PaymentModePicker(selected: _mode, onSelect: (m) => setState(() => _mode = m)),
      const SizedBox(height: 16),

      FieldLabel('Note (optional)'),
      TextFormField(controller: _noteCtrl, maxLines: 2,
          decoration: const InputDecoration(hintText: 'Any notes...')),
      const SizedBox(height: 24),

      if (widget.existing != null) ...[
        _DeleteBtn(isDark: isDark,
            onTap: () => _confirmDeleteTx(context, ref, widget.existing!, _cust?.name ?? '')),
        const SizedBox(height: 12),
      ],
      GradientButton(
        label: widget.existing != null ? 'Update Delivery' : '🚚 Save Delivery',
        loading: _saving,
        onTap: _hasAny && _cust != null ? _save : null,
        gradient: (!_hasAny || _cust == null)
            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
            : AppColors.primaryGradient,
      ),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. EVENT FORM
// ══════════════════════════════════════════════════════════════════════════════
class EventForm extends ConsumerStatefulWidget {
  final JarTransaction? existing;
  const EventForm({super.key, this.existing});
  @override
  ConsumerState<EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventForm> {
  final _formKey = GlobalKey<FormState>();
  Customer? _cust;
  int _cd = 0, _pd = 0, _cr = 0, _pr = 0, _cdmg = 0, _pdmg = 0;
  double _collected = 0;
  String _mode = 'cash';
  String _eventStatus = 'scheduled';
  bool _showPriceOverride = false;
  bool _saving = false;
  DateTime? _eventDate;
  final _noteCtrl         = TextEditingController();
  final _amtCtrl          = TextEditingController();
  final _eventNameCtrl    = TextEditingController();
  final _transportCtrl    = TextEditingController();
  final _coolOverrideCtrl = TextEditingController();
  final _petOverrideCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _cd = e.coolDelivered; _pd = e.petDelivered;
      _cr = e.coolReturned;  _pr = e.petReturned;
      _cdmg = e.coolDamaged; _pdmg = e.petDamaged;
      _collected = e.amountCollected;
      _amtCtrl.text = e.amountCollected.toInt().toString();
      _mode = e.paymentMode; _noteCtrl.text = e.note;
      _eventNameCtrl.text = e.eventName ?? '';
      if (e.transportFee > 0) _transportCtrl.text = e.transportFee.toInt().toString();
      _eventStatus = e.eventStatus ?? _autoStatus(e.date);
    } else {
      final pre = ref.read(selectedCustomerForTxnProvider);
      if (pre != null) {
        _cust = pre;
        Future.microtask(() => ref.read(selectedCustomerForTxnProvider.notifier).state = null);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existing != null && _cust == null) {
      try { _cust = ref.read(customersProvider).firstWhere((c) => c.id == widget.existing!.customerId); }
      catch (_) {}
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose(); _amtCtrl.dispose(); _eventNameCtrl.dispose();
    _transportCtrl.dispose(); _coolOverrideCtrl.dispose(); _petOverrideCtrl.dispose();
    super.dispose();
  }

  static String _autoStatus(String d) {
    try {
      final day   = DateTime.parse(d);
      final today = DateTime.now();
      return day.isAfter(DateTime(today.year, today.month, today.day)) ? 'scheduled' : 'active';
    } catch (_) { return 'active'; }
  }

  AppSettings get _s => ref.read(settingsProvider);
  double get _effectiveCoolPrice {
    final v = double.tryParse(_coolOverrideCtrl.text);
    return (v != null && v > 0) ? v : (_cust?.coolPriceOverride ?? _s.coolPrice);
  }
  double get _effectivePetPrice {
    final v = double.tryParse(_petOverrideCtrl.text);
    return (v != null && v > 0) ? v : (_cust?.petPriceOverride ?? _s.petPrice);
  }
  double get _transport => double.tryParse(_transportCtrl.text) ?? 0;
  double get _billed    => (_cd * _effectiveCoolPrice) + (_pd * _effectivePetPrice) + _transport;
  bool   get _hasAny    => _cd > 0 || _pd > 0;

  void _onCustSelected(Customer c) => setState(() {
    _cust = c;
    _coolOverrideCtrl.text = c.coolPriceOverride?.toStringAsFixed(0) ?? '';
    _petOverrideCtrl.text  = c.petPriceOverride?.toStringAsFixed(0)  ?? '';
  });

  Future<void> _save() async {
    if (_cust == null) { showToast(context, 'Select a customer', error: true); return; }
    if (!_hasAny)      { showToast(context, 'Add at least one jar', error: true); return; }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now().toIso8601String();
    final tx = JarTransaction(
      id: widget.existing?.id ?? _uuid.v4(),
      customerId: _cust!.id, customerName: _cust!.name,
      date: widget.existing?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      coolDelivered: _cd, petDelivered: _pd,
      coolReturned: _cr, petReturned: _pr,
      coolDamaged: _cdmg, petDamaged: _pdmg,
      coolPrice: _effectiveCoolPrice, petPrice: _effectivePetPrice,
      billedAmount: _billed, amountCollected: _collected, paymentMode: _mode,
      transportFee: _transport, note: _noteCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: widget.existing != null ? now : null,
      createdBy: 'Admin', deliveryType: 'event',
      eventName: _eventNameCtrl.text.trim(), eventStatus: _eventStatus,
    );
    widget.existing != null
        ? await ref.read(transactionsProvider.notifier).edit(widget.existing!, tx)
        : await ref.read(transactionsProvider.notifier).add(tx);
    if (mounted) {
      Navigator.pop(context);
      showToast(context, widget.existing != null ? '✅ Event updated' : '✅ Event saved', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final inv     = ref.watch(inventoryProvider);
    final custs   = ref.watch(customersProvider).where((c) => c.isActive).toList();
    final s       = ref.watch(settingsProvider);
    final coolC   = AppColors.coolColor(isDark);
    final petC    = AppColors.petColor(isDark);
    const eventGrad = LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFFB388FF)],
        begin: Alignment.centerLeft, end: Alignment.centerRight);

    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Voice fill button ──────────────────────────────────────────────────
      if (widget.existing == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            VoiceMicButton(
              formType: VoiceFormType.event,
              preselectedCustomer: _cust,
              onResult: (r) {
                setState(() {
                  if (r.customer != null) { _cust = r.customer; _onCustSelected(r.customer!); }
                  _cd = r.coolDelivered; _pd = r.petDelivered;
                  _cr = r.coolReturned;  _pr = r.petReturned;
                  _collected = r.payment;
                  _amtCtrl.text = r.payment.toInt().toString();
                });
              },
            ),
            const SizedBox(width: 8),
            Text('Fill fields by voice',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
          ]),
        ),
      _EventDetailsSection(nameCtrl: _eventNameCtrl, transportCtrl: _transportCtrl,
        eventDate: _eventDate, isDark: isDark,
        onDatePicked: (d) => setState(() => _eventDate = d),
        onTransportChanged: (_) => setState(() {})),
      const SizedBox(height: 20),

      FieldLabel('Customer / Organisation *'),
      _CustPicker(selected: _cust, customers: custs, onSelect: _onCustSelected),
      if (_cust != null) _InlinePriceOverride(
        cust: _cust!, coolCtrl: _coolOverrideCtrl, petCtrl: _petOverrideCtrl,
        defaultCoolPrice: s.coolPrice, defaultPetPrice: s.petPrice,
        showOverride: _showPriceOverride,
        onToggle: () => setState(() => _showPriceOverride = !_showPriceOverride),
        onChanged: () => setState(() {}), isDark: isDark),
      const SizedBox(height: 20),

      FieldLabel('Jars — Event Delivery'),
      Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDark : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 0), child: LayoutBuilder(builder: (ctx, bc) {
            final labelW = (bc.maxWidth * 0.22).clamp(56.0, 80.0);
            return Row(children: [
              SizedBox(width: labelW),
              Expanded(child: _ColHeader(icon: Icons.arrow_downward_rounded, label: 'IN',
                  sub: 'jars to event', color: AppColors.purple)),
            ]);
          })),
          Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
          _JarInputRow(jarIcon: CoolJarIcon(size: 22, color: coolC), label: 'Cool', color: coolC,
            stockInfo: 'Stock: ${inv.coolStock}',
            priceInfo: _effectiveCoolPrice != s.coolPrice ? '₹${_effectiveCoolPrice.toInt()}/jar ★' : '₹${s.coolPrice.toInt()}/jar',
            unitPrice: _effectiveCoolPrice, delivered: _cd, returned: 0, showReturn: false,
            maxDeliver: inv.coolStock + (widget.existing?.coolDelivered ?? 0),
            maxReturn: 99,
            onDeliverChanged: (v) => setState(() => _cd = v),
            onReturnChanged: (_) {}),
          Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
          _JarInputRow(jarIcon: PetJarIcon(size: 22, color: petC), label: 'PET', color: petC,
            stockInfo: 'Stock: ${inv.petStock}',
            priceInfo: _effectivePetPrice != s.petPrice ? '₹${_effectivePetPrice.toInt()}/jar ★' : '₹${s.petPrice.toInt()}/jar',
            unitPrice: _effectivePetPrice, delivered: _pd, returned: 0, showReturn: false,
            maxDeliver: inv.petStock + (widget.existing?.petDelivered ?? 0),
            maxReturn: 99,
            onDeliverChanged: (v) => setState(() => _pd = v),
            onReturnChanged: (_) {}),
        ]),
      ),
      const SizedBox(height: 16),

      _EventStatusSection(
        status: _eventStatus, eventDate: _eventDate,
        coolDelivered: _cd, petDelivered: _pd,
        coolReturned: _cr, petReturned: _pr,
        coolReturnDmg: _cdmg, petReturnDmg: _pdmg, isDark: isDark,
        onStatusChange: (s) => setState(() => _eventStatus = s),
        onCoolReturnChanged: (v) => setState(() => _cr = v),
        onPetReturnChanged:  (v) => setState(() => _pr = v),
        onCoolDmgChanged:    (v) => setState(() => _cdmg = v),
        onPetDmgChanged:     (v) => setState(() => _pdmg = v),
        maxCoolReturn: _cd, maxPetReturn: _pd),

      if (_billed > 0) ...[
        const SizedBox(height: 12),
        _BillCard(cd: _cd, pd: _pd, cdmg: 0, pdmg: 0,
          coolPrice: _effectiveCoolPrice, petPrice: _effectivePetPrice,
          dmgPrice: s.damageChargePerJar, total: _billed,
          advance: _cust?.advanceBalance ?? 0, transportFee: _transport),
      ],
      const SizedBox(height: 16),

      FieldLabel('Amount Collected', hint: '(leave 0 = unpaid)'),
      _AmountField(ctrl: _amtCtrl, hint: _billed.toInt().toString(),
        advance: _cust?.advanceBalance ?? 0,
        onChanged: (v) => setState(() => _collected = v),
        onUseAdvance: () => setState(() { _collected = _billed; _amtCtrl.text = _billed.toInt().toString(); })),
      const SizedBox(height: 16),

      FieldLabel('Payment Mode'),
      PaymentModePicker(selected: _mode, onSelect: (m) => setState(() => _mode = m)),
      const SizedBox(height: 16),

      FieldLabel('Note (optional)'),
      TextFormField(controller: _noteCtrl, maxLines: 2,
          decoration: const InputDecoration(hintText: 'Any notes...')),
      const SizedBox(height: 24),

      if (widget.existing != null) ...[
        _DeleteBtn(isDark: isDark,
            onTap: () => _confirmDeleteTx(context, ref, widget.existing!, _cust?.name ?? '')),
        const SizedBox(height: 12),
      ],
      GradientButton(
        label: widget.existing != null ? 'Update Event' : '🎉 Save Event',
        loading: _saving,
        onTap: _hasAny && _cust != null ? _save : null,
        gradient: (!_hasAny || _cust == null)
            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
            : eventGrad,
      ),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. RETURN JAR FORM  — pure return/collection with delivery-type context
//    The owner picks whether jars came back from a Normal delivery or an Event,
//    so the transaction is tagged correctly and inventory is reversed properly.
// ══════════════════════════════════════════════════════════════════════════════
class ReturnJarForm extends ConsumerStatefulWidget {
  final JarTransaction? existing;
  const ReturnJarForm({super.key, this.existing});
  @override
  ConsumerState<ReturnJarForm> createState() => _ReturnJarFormState();
}

class _ReturnJarFormState extends ConsumerState<ReturnJarForm> {
  Customer? _cust;
  int  _cr = 0, _pr = 0, _cdmg = 0, _pdmg = 0;
  bool _saving = false;
  /// 'daily' = jars came back from a regular delivery
  /// 'event' = jars came back from an event
  String _returnContext = 'daily';
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _cr = e.coolReturned; _pr = e.petReturned;
      _cdmg = e.coolDamaged; _pdmg = e.petDamaged;
      _noteCtrl.text  = e.note;
      _returnContext  = e.deliveryType == 'event' ? 'event' : 'daily';
    } else {
      final pre = ref.read(selectedCustomerForTxnProvider);
      if (pre != null) {
        _cust = pre;
        Future.microtask(() => ref.read(selectedCustomerForTxnProvider.notifier).state = null);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existing != null && _cust == null) {
      try { _cust = ref.read(customersProvider).firstWhere((c) => c.id == widget.existing!.customerId); }
      catch (_) {}
    }
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  AppSettings get _s  => ref.read(settingsProvider);
  double get _dmgCharge => (_cdmg + _pdmg) * _s.damageChargePerJar;
  bool   get _hasAny    => _cr > 0 || _pr > 0;

  Future<void> _save() async {
    if (_cust == null) { showToast(context, 'Select a customer', error: true); return; }
    if (!_hasAny)      { showToast(context, 'Enter jars being returned', error: true); return; }
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now().toIso8601String();
    final tx = JarTransaction(
      id: widget.existing?.id ?? _uuid.v4(),
      customerId: _cust!.id, customerName: _cust!.name,
      date: widget.existing?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      coolDelivered: 0, petDelivered: 0,
      coolReturned: _cr, petReturned: _pr,
      coolDamaged: _cdmg, petDamaged: _pdmg,
      coolPrice: 0, petPrice: 0,
      billedAmount: _dmgCharge, amountCollected: 0, paymentMode: 'cash',
      damageCharge: _dmgCharge,
      note: _noteCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: widget.existing != null ? now : null,
      createdBy: 'Admin',
      deliveryType: _returnContext,   // keeps event/daily context for ledger accuracy
    );
    widget.existing != null
        ? await ref.read(transactionsProvider.notifier).edit(widget.existing!, tx)
        : await ref.read(transactionsProvider.notifier).add(tx);
    if (mounted) {
      Navigator.pop(context);
      showToast(context, widget.existing != null ? '✅ Return updated' : '✅ Return recorded', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final custs   = ref.watch(customersProvider).where((c) => c.isActive).toList();
    final s       = ref.watch(settingsProvider);
    final coolC   = AppColors.coolColor(isDark);
    final petC    = AppColors.petColor(isDark);
    final okC     = AppColors.successColor(isDark);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Voice fill button ──────────────────────────────────────────────────
      if (widget.existing == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            VoiceMicButton(
              formType: VoiceFormType.returnJars,
              preselectedCustomer: _cust,
              onResult: (r) {
                setState(() {
                  if (r.customer != null) _cust = r.customer;
                  _cr = r.coolReturned;
                  _pr = r.petReturned;
                });
              },
            ),
            const SizedBox(width: 8),
            Text('Fill fields by voice',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
          ]),
        ),

      // ── Return context toggle: Normal or Event ───────────────────────────
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          _ReturnCtxBtn(
            icon: Icons.local_shipping_rounded,
            label: 'Normal Delivery',
            sublabel: 'Jars from regular delivery',
            value: 'daily', selected: _returnContext,
            color: primary, isDark: isDark,
            onTap: () => setState(() => _returnContext = 'daily'),
          ),
          const SizedBox(width: 4),
          _ReturnCtxBtn(
            icon: Icons.celebration_rounded,
            label: 'Event',
            sublabel: 'Jars from an event order',
            value: 'event', selected: _returnContext,
            color: AppColors.purple, isDark: isDark,
            onTap: () => setState(() => _returnContext = 'event'),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // ── Customer picker ──────────────────────────────────────────────────
      FieldLabel('Customer *'),
      _CustPicker(selected: _cust, customers: custs,
          onSelect: (c) => setState(() => _cust = c)),
      const SizedBox(height: 20),

      // ── Jar return steppers ──────────────────────────────────────────────
      FieldLabel('Jars Being Returned'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDark : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        child: Row(children: [
          Expanded(child: Column(children: [
            CoolJarIcon(size: 28, color: coolC),
            const SizedBox(height: 6),
            Text('Cool', style: GoogleFonts.inter(fontSize: 12,
                fontWeight: FontWeight.w700, color: coolC)),
            Text('Out: ${_cust?.coolOut ?? 0}',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted)),
            const SizedBox(height: 10),
            _EditableStepper(
              value: _cr,
              max: (_cust?.coolOut ?? 99) + (widget.existing?.coolReturned ?? 0),
              color: coolC, onChanged: (v) => setState(() => _cr = v)),
          ])),
          Container(width: 1, height: 80,
              color: isDark ? AppColors.separatorDark : AppColors.separator),
          Expanded(child: Column(children: [
            PetJarIcon(size: 28, color: petC),
            const SizedBox(height: 6),
            Text('PET', style: GoogleFonts.inter(fontSize: 12,
                fontWeight: FontWeight.w700, color: petC)),
            Text('Out: ${_cust?.petOut ?? 0}',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted)),
            const SizedBox(height: 10),
            _EditableStepper(
              value: _pr,
              max: (_cust?.petOut ?? 99) + (widget.existing?.petReturned ?? 0),
              color: petC, onChanged: (v) => setState(() => _pr = v)),
          ])),
        ]),
      ),
      const SizedBox(height: 12),

      if (_cr > 0 || _pr > 0) _DamagedSection(
        coolReturned: _cr, petReturned: _pr, coolDmg: _cdmg, petDmg: _pdmg,
        coolColor: coolC, petColor: petC, isDark: isDark,
        onCoolChanged: (v) => setState(() => _cdmg = v),
        onPetChanged:  (v) => setState(() => _pdmg = v),
        damagePerJar: s.damageChargePerJar),

      const SizedBox(height: 16),
      FieldLabel('Note (optional)'),
      TextFormField(controller: _noteCtrl, maxLines: 2,
          decoration: const InputDecoration(hintText: 'Any notes...')),
      const SizedBox(height: 24),

      if (widget.existing != null) ...[
        _DeleteBtn(isDark: isDark,
            onTap: () => _confirmDeleteTx(context, ref, widget.existing!, _cust?.name ?? '')),
        const SizedBox(height: 12),
      ],
      GradientButton(
        label: widget.existing != null ? 'Update Return' : '📦 Save Return',
        loading: _saving,
        onTap: _hasAny && _cust != null ? _save : null,
        gradient: (!_hasAny || _cust == null)
            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
            : LinearGradient(
                colors: [okC, okC.withValues(alpha: 0.75)],
                begin: Alignment.centerLeft, end: Alignment.centerRight),
      ),
    ]);
  }
}

/// Toggle button used inside ReturnJarForm to pick context (normal vs event).
class _ReturnCtxBtn extends StatelessWidget {
  final IconData icon;
  final String label, sublabel, value, selected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _ReturnCtxBtn({required this.icon, required this.label,
      required this.sublabel, required this.value, required this.selected,
      required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? (isDark ? AppColors.cardDark : AppColors.card) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: color.withValues(alpha: 0.35)) : null,
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
              : [],
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: active ? color : AppColors.inkMuted),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? color : AppColors.inkMuted)),
            Text(sublabel, style: GoogleFonts.inter(fontSize: 9, color: AppColors.inkMuted)),
          ])),
          if (active)
            Icon(Icons.check_circle_rounded, size: 14, color: color),
        ]),
      ),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 4. PAYMENT FORM  — standalone payment with Daily / Event / Advance context
//
//   Daily    → deliveryType: 'daily',  paymentMode: cash/upi/bank
//              Appears in Daily filter; reduces daily dues
//   Event    → deliveryType: 'event',  paymentMode: cash/upi/bank
//              Appears in Event filter; reduces event dues
//   Advance  → deliveryType: 'daily',  paymentMode: 'advance'
//              Acts as credit on the customer ledger
// ══════════════════════════════════════════════════════════════════════════════
class PaymentForm extends ConsumerStatefulWidget {
  final JarTransaction? existing;
  const PaymentForm({super.key, this.existing});
  @override
  ConsumerState<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<PaymentForm> {
  Customer? _cust;
  /// 'daily' | 'event' | 'advance'
  String _payType = 'daily';
  String _mode    = 'cash';
  bool   _saving  = false;
  final _amtCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amtCtrl.text  = e.amountCollected.toInt().toString();
      _noteCtrl.text = e.note;
      // Detect original pay type from saved fields
      if (e.paymentMode == 'advance') {
        _payType = 'advance';
        _mode    = 'cash';
      } else {
        _payType = e.deliveryType == 'event' ? 'event' : 'daily';
        _mode    = e.paymentMode;
      }
    } else {
      final pre = ref.read(selectedCustomerForTxnProvider);
      if (pre != null) {
        _cust = pre;
        if (_cust!.hasDues) _amtCtrl.text = _cust!.ledgerBalance.abs().toInt().toString();
        Future.microtask(() => ref.read(selectedCustomerForTxnProvider.notifier).state = null);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.existing != null && _cust == null) {
      try { _cust = ref.read(customersProvider).firstWhere((c) => c.id == widget.existing!.customerId); }
      catch (_) {}
    }
  }

  @override
  void dispose() { _amtCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  void _onCustSelected(Customer c) {
    setState(() {
      _cust = c;
      if (c.hasDues) _amtCtrl.text = c.ledgerBalance.abs().toInt().toString();
    });
  }

  Future<void> _save() async {
    if (_cust == null) { showToast(context, 'Select a customer', error: true); return; }
    final val = double.tryParse(_amtCtrl.text) ?? 0;
    if (val <= 0) { showToast(context, 'Enter a valid amount', error: true); return; }
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now().toIso8601String();
    // Map _payType → deliveryType + paymentMode
    final delivType   = _payType == 'event' ? 'event' : 'daily';
    final payModeOut  = _payType == 'advance' ? 'advance' : _mode;
    final tx = JarTransaction(
      id: widget.existing?.id ?? _uuid.v4(),
      customerId: _cust!.id, customerName: _cust!.name,
      date: widget.existing?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      coolDelivered: 0, petDelivered: 0, coolReturned: 0, petReturned: 0,
      coolDamaged: 0, petDamaged: 0, coolPrice: 0, petPrice: 0,
      billedAmount: 0, amountCollected: val, paymentMode: payModeOut,
      note: _noteCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: widget.existing != null ? now : null,
      createdBy: 'Admin', deliveryType: delivType,
    );
    widget.existing != null
        ? await ref.read(transactionsProvider.notifier).edit(widget.existing!, tx)
        : await ref.read(transactionsProvider.notifier).add(tx);
    if (mounted) {
      Navigator.pop(context);
      showToast(context, widget.existing != null ? '✅ Payment updated' : '✅ Payment recorded', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final custs   = ref.watch(customersProvider).where((c) => c.isActive).toList();
    final primary = Theme.of(context).colorScheme.primary;
    final okC     = AppColors.successColor(isDark);
    final dangerC = AppColors.dangerColor(isDark);
    final isAdvance = _payType == 'advance';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Voice fill button ──────────────────────────────────────────────────
      if (widget.existing == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            VoiceMicButton(
              formType: VoiceFormType.payment,
              preselectedCustomer: _cust,
              onResult: (r) {
                setState(() {
                  if (r.customer != null) { _cust = r.customer; _onCustSelected(r.customer!); }
                  _amtCtrl.text = r.payment.toInt().toString();
                });
              },
            ),
            const SizedBox(width: 8),
            Text('Fill fields by voice',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
          ]),
        ),

      // ── Payment type toggle: Daily | Event | Advance ─────────────────────
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          _PayTypeBtn(label: 'Daily',   icon: Icons.local_shipping_rounded,
              value: 'daily',   selected: _payType, color: primary,
              isDark: isDark, onTap: () => setState(() => _payType = 'daily')),
          const SizedBox(width: 4),
          _PayTypeBtn(label: 'Event',   icon: Icons.celebration_rounded,
              value: 'event',   selected: _payType, color: AppColors.purple,
              isDark: isDark, onTap: () => setState(() => _payType = 'event')),
          const SizedBox(width: 4),
          _PayTypeBtn(label: 'Advance', icon: Icons.savings_rounded,
              value: 'advance', selected: _payType, color: okC,
              isDark: isDark, onTap: () => setState(() => _payType = 'advance')),
        ]),
      ),

      // Context hint for each type
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
        child: Text(
          _payType == 'daily'
              ? 'Settles dues from regular daily deliveries'
              : _payType == 'event'
                  ? 'Settles dues from an event order'
                  : 'Adds credit to customer\'s advance balance',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted),
        ),
      ),
      const SizedBox(height: 20),

      // ── Customer picker ──────────────────────────────────────────────────
      FieldLabel('Customer *'),
      _CustPicker(selected: _cust, customers: custs, onSelect: _onCustSelected),

      // Balance info chip
      if (_cust != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (_cust!.hasDues ? dangerC : okC).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (_cust!.hasDues ? dangerC : okC).withValues(alpha: 0.20)),
          ),
          child: Row(children: [
            Icon(_cust!.hasDues ? Icons.receipt_long_rounded : Icons.check_circle_outline_rounded,
                size: 14, color: _cust!.hasDues ? dangerC : okC),
            const SizedBox(width: 8),
            Expanded(child: Text(
              _cust!.hasDues
                  ? 'Outstanding due: ₹${_cust!.ledgerBalance.abs().toInt()}'
                  : _cust!.hasAdvance
                      ? 'Advance balance: ₹${_cust!.advanceBalance.toInt()}'
                      : 'No outstanding dues',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _cust!.hasDues ? dangerC : okC),
            )),
            if (_cust!.hasDues && !isAdvance)
              GestureDetector(
                onTap: () => setState(() =>
                    _amtCtrl.text = _cust!.ledgerBalance.abs().toInt().toString()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: okC.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text('Fill due', style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700, color: okC)),
                ),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 20),

      // ── Amount ───────────────────────────────────────────────────────────
      FieldLabel(isAdvance ? 'Advance Amount *' : 'Payment Amount *'),
      TextFormField(
        controller: _amtCtrl,
        keyboardType: TextInputType.number,
        style: GoogleFonts.jetBrainsMono(fontSize: 26, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(hintText: '0', prefixText: '₹ '),
      ),
      const SizedBox(height: 16),

      // ── Payment mode (hidden for Advance — mode is forced to 'advance') ──
      if (!isAdvance) ...[
        FieldLabel('Payment Mode'),
        PaymentModePicker(selected: _mode, onSelect: (m) => setState(() => _mode = m)),
        const SizedBox(height: 16),
      ],

      FieldLabel('Note (optional)'),
      TextFormField(controller: _noteCtrl, maxLines: 2,
          decoration: InputDecoration(
              hintText: isAdvance ? 'Advance deposit reference...' : 'Reference, cheque no...')),
      const SizedBox(height: 24),

      if (widget.existing != null) ...[
        _DeleteBtn(isDark: isDark,
            onTap: () => _confirmDeleteTx(context, ref, widget.existing!, _cust?.name ?? '')),
        const SizedBox(height: 12),
      ],
      GradientButton(
        label: widget.existing != null
            ? 'Update Payment'
            : isAdvance ? '💳 Add Advance' : '💰 Record Payment',
        loading: _saving,
        onTap: _cust != null ? _save : null,
        gradient: _cust == null
            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
            : isAdvance
                ? LinearGradient(colors: [AppColors.purple, AppColors.purple.withValues(alpha: 0.75)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight)
                : LinearGradient(colors: [okC, okC.withValues(alpha: 0.75)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
      ),
    ]);
  }
}

/// Compact toggle button for PaymentForm type selection.
class _PayTypeBtn extends StatelessWidget {
  final String label, value, selected;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _PayTypeBtn({required this.label, required this.icon, required this.value,
      required this.selected, required this.color, required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? (isDark ? AppColors.cardDark : AppColors.card) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: color.withValues(alpha: 0.35)) : null,
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 5)]
              : [],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: active ? color : AppColors.inkMuted),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? color : AppColors.inkMuted)),
        ]),
      ),
    ));
  }
}

// ── Legacy wrapper — routes to the correct focused form ───────────────────────
// Keeps backward-compat for any screen still calling TxnForm directly.
class TxnFormRouter extends StatelessWidget {
  final JarTransaction? existing;
  final String? initialDeliveryType;
  const TxnFormRouter({super.key, this.existing, this.initialDeliveryType});

  @override
  Widget build(BuildContext context) {
    if (existing != null) {
      return switch (_TxnScreenState._detectTxType(existing!)) {
        'payment' => PaymentForm(existing: existing),
        'return'  => ReturnJarForm(existing: existing),
        'event'   => EventForm(existing: existing),
        _         => DeliveryForm(existing: existing),
      };
    }
    if (initialDeliveryType == 'event') return EventForm();
    return DeliveryForm();
  }
}

// ── Delivery Type Toggle ───────────────────────────────────────────────────────
class _DeliveryTypeToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isDark;
  const _DeliveryTypeToggle({required this.selected, required this.onSelect, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2Dark : AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _TypeBtn(
          icon: Icons.local_shipping_rounded,
          label: 'Daily Delivery',
          sublabel: 'Regular door-to-door',
          value: 'daily',
          selected: selected,
          color: AppColors.primaryColor(isDark),
          onTap: () => onSelect('daily'),
          isDark: isDark,
        ),
        const SizedBox(width: 4),
        _TypeBtn(
          icon: Icons.celebration_rounded,
          label: 'Event Delivery',
          sublabel: 'Bulk / one-off',
          value: 'event',
          selected: selected,
          color: AppColors.purple,
          onTap: () => onSelect('event'),
          isDark: isDark,
        ),
      ]),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final IconData icon;
  final String label, sublabel, value, selected;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;
  const _TypeBtn({required this.icon, required this.label, required this.sublabel,
      required this.value, required this.selected, required this.color,
      required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? (isDark ? AppColors.cardDark : AppColors.card) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: color.withValues(alpha: 0.3)) : null,
          boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6)] : [],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: active ? color : AppColors.inkMuted),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
                color: active ? color : AppColors.inkMuted)),
            Text(sublabel, style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted)),
          ])),
          if (active)
            Icon(Icons.check_circle_rounded, size: 16, color: color),
        ]),
      ),
    ));
  }
}

// ── Event Details Section ─────────────────────────────────────────────────────
class _EventDetailsSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController transportCtrl;
  final DateTime? eventDate;
  final bool isDark;
  final ValueChanged<DateTime?> onDatePicked;
  final ValueChanged<String> onTransportChanged;
  const _EventDetailsSection({required this.nameCtrl, required this.transportCtrl,
      required this.eventDate, required this.isDark,
      required this.onDatePicked, required this.onTransportChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.celebration_rounded, size: 16, color: AppColors.purple),
          const SizedBox(width: 8),
          Text('Event Details', style: GoogleFonts.inter(fontSize: 13,
              fontWeight: FontWeight.w700, color: AppColors.purple)),
        ]),
        const SizedBox(height: 12),
        FieldLabel('Event Name'),
        TextFormField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'e.g. Annual Conference, Wedding, Seminar'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the event name' : null,
        ),
        const SizedBox(height: 12),
        FieldLabel('Transport / Logistics Fee (optional)'),
        TextFormField(
          controller: transportCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onTransportChanged,
          decoration: InputDecoration(
            hintText: '0',
            prefixText: '₹ ',
            prefixStyle: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700,
                color: AppColors.purple),
            suffixIcon: const Icon(Icons.local_shipping_rounded, size: 18, color: AppColors.purple),
          ),
        ),
        const SizedBox(height: 12),
        FieldLabel('Event Date (optional)'),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: eventDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            onDatePicked(picked);
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface2Dark : AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.inkMuted),
              const SizedBox(width: 10),
              Expanded(child: Text(
                eventDate != null
                    ? DateFormat('dd MMM yyyy').format(eventDate!)
                    : 'Tap to select event date',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: eventDate != null
                        ? (isDark ? AppColors.inkDark : AppColors.ink)
                        : AppColors.inkMuted),
              )),
              if (eventDate != null)
                const Icon(Icons.check_rounded, size: 16, color: AppColors.purple),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Column Header ─────────────────────────────────────────────────────────────
class _ColHeader extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  const _ColHeader({required this.icon, required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(height: 3),
    Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
        color: color, letterSpacing: 0.5)),
    Text(sub, style: GoogleFonts.inter(fontSize: 9, color: AppColors.inkMuted)),
    const SizedBox(height: 10),
  ]);
}

// ── Jar Input Row ─────────────────────────────────────────────────────────────
class _JarInputRow extends StatelessWidget {
  final Widget jarIcon;
  final String label, stockInfo, priceInfo;
  final Color color;
  final double unitPrice;
  final int delivered, returned, maxDeliver, maxReturn;
  final bool showReturn;
  final ValueChanged<int> onDeliverChanged, onReturnChanged;

  const _JarInputRow({required this.jarIcon, required this.label, required this.color,
      required this.stockInfo, required this.priceInfo, required this.unitPrice,
      required this.delivered, required this.returned,
      required this.maxDeliver, required this.maxReturn,
      required this.onDeliverChanged, required this.onReturnChanged,
      this.showReturn = true});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Responsive breakpoints: shrink label column on very narrow screens
      final totalWidth = constraints.maxWidth;
      final labelWidth = (totalWidth * 0.22).clamp(56.0, 80.0);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // ── Jar label column ─────────────────────────────────
          SizedBox(width: labelWidth, child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              jarIcon,
              const SizedBox(height: 3),
              Text(label,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  overflow: TextOverflow.ellipsis),
              Text(stockInfo,
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted),
                  overflow: TextOverflow.ellipsis),
              Text(priceInfo,
                  style: GoogleFonts.inter(fontSize: 10,
                      color: priceInfo.contains('★') ? AppColors.warningColor(false) : AppColors.inkMuted,
                      fontWeight: priceInfo.contains('★') ? FontWeight.w700 : FontWeight.w400),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
          // ── IN stepper ───────────────────────────────────────
          Expanded(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EditableStepper(value: delivered, max: maxDeliver, onChanged: onDeliverChanged,
                  color: color),
              if (delivered > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('₹${(delivered * unitPrice).toInt()} billed',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, color: color, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
          )),
          // ── OUT stepper ──────────────────────────────────────
          if (showReturn)
            Expanded(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EditableStepper(value: returned, max: maxReturn, onChanged: onReturnChanged,
                    color: AppColors.success),
                if (returned > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('$returned back',
                        style: GoogleFonts.inter(fontSize: 9, color: AppColors.inkMuted),
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
            )),
        ]),
      );
    });
  }
}

// ── Editable stepper — tap number to type directly, or use +/- buttons ────────
class _EditableStepper extends StatefulWidget {
  final int value, max;
  final Color color;
  final ValueChanged<int> onChanged;
  const _EditableStepper({required this.value, required this.max,
      required this.color, required this.onChanged});

  @override
  State<_EditableStepper> createState() => _EditableStepperState();
}

class _EditableStepperState extends State<_EditableStepper> {
  late TextEditingController _ctrl;
  bool _editing = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_EditableStepper old) {
    super.didUpdateWidget(old);
    if (!_editing && old.value != widget.value) {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  void _commit() {
    final v = (int.tryParse(_ctrl.text) ?? widget.value).clamp(0, widget.max);
    setState(() { _editing = false; _ctrl.text = '$v'; });
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    // LayoutBuilder lets the stepper measure its actual available width
    // and scale every dimension proportionally — no fixed pixel overflows.
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final btnSize  = (w * 0.24).clamp(24.0, 34.0);
      final gap      = (w * 0.03).clamp(2.0,  6.0);
      final dispW    = (w - btnSize * 2 - gap * 2).clamp(28.0, 56.0);
      final dispH    = btnSize.clamp(28.0, 40.0);
      final fs       = (dispW * 0.34).clamp(12.0, 18.0);
      final iconSize = (btnSize * 0.50).clamp(10.0, 16.0);

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── minus ──
          _StepBtn(
            icon: Icons.remove_rounded, color: c,
            size: btnSize, iconSize: iconSize,
            enabled: widget.value > 0,
            onTap: () { _editing = false; widget.onChanged((widget.value - 1).clamp(0, widget.max)); },
          ),
          SizedBox(width: gap),
          // ── tappable number / inline text field ──
          GestureDetector(
            onTap: () {
              setState(() { _editing = true; _ctrl.text = '${widget.value}'; });
              Future.microtask(() {
                _focus.requestFocus();
                _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: dispW, height: dispH,
              decoration: BoxDecoration(
                color: _editing ? c.withValues(alpha: 0.10) : c.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _editing ? c : c.withValues(alpha: 0.25),
                  width: _editing ? 1.5 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: _editing
                  ? TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: fs, fontWeight: FontWeight.w800, color: c),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _commit(),
                    )
                  : Text('${widget.value}',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: fs, fontWeight: FontWeight.w800, color: c)),
            ),
          ),
          SizedBox(width: gap),
          // ── plus ──
          _StepBtn(
            icon: Icons.add_rounded, color: c,
            size: btnSize, iconSize: iconSize,
            enabled: widget.value < widget.max,
            onTap: () { _editing = false; widget.onChanged((widget.value + 1).clamp(0, widget.max)); },
          ),
        ],
      );
    });
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  // Responsive sizing passed in from parent LayoutBuilder
  final double size;
  final double iconSize;
  const _StepBtn({required this.icon, required this.color,
      required this.enabled, required this.onTap,
      this.size = 34, this.iconSize = 16});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: enabled ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: color.withValues(alpha: enabled ? 0.30 : 0.12)),
      ),
      child: Icon(icon, size: iconSize, color: enabled ? color : AppColors.inkMuted),
    ),
  );
}

// ── Damaged Section ────────────────────────────────────────────────────────────
class _DamagedSection extends StatefulWidget {
  final int coolReturned, petReturned, coolDmg, petDmg;
  final Color coolColor, petColor;
  final bool isDark;
  final ValueChanged<int> onCoolChanged, onPetChanged;
  final double damagePerJar;
  const _DamagedSection({required this.coolReturned, required this.petReturned,
      required this.coolDmg, required this.petDmg,
      required this.coolColor, required this.petColor, required this.isDark,
      required this.onCoolChanged, required this.onPetChanged, required this.damagePerJar});

  @override
  State<_DamagedSection> createState() => _DamagedSectionState();
}

class _DamagedSectionState extends State<_DamagedSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final dangerC = AppColors.dangerColor(widget.isDark);
    return Container(
      decoration: BoxDecoration(
        color: dangerC.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dangerC.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        ListTile(
          dense: true,
          leading: Icon(Icons.warning_amber_rounded, color: dangerC, size: 18),
          title: Text('Damaged jars?', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: dangerC)),
          subtitle: Text('₹${widget.damagePerJar.toInt()} per jar charge',
              style: GoogleFonts.inter(fontSize: 11, color: dangerC.withValues(alpha: 0.7))),
          trailing: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: dangerC),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Expanded(child: Column(children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  CoolJarIcon(size: 14, color: widget.coolColor), const SizedBox(width: 4),
                  Text('Cool dmg', style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
                ]),
                const SizedBox(height: 6),
                _EditableStepper(value: widget.coolDmg, max: widget.coolReturned,
                    onChanged: widget.onCoolChanged, color: dangerC),
              ])),
              const SizedBox(width: 20),
              Expanded(child: Column(children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  PetJarIcon(size: 14, color: widget.petColor), const SizedBox(width: 4),
                  Text('PET dmg', style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
                ]),
                const SizedBox(height: 6),
                _EditableStepper(value: widget.petDmg, max: widget.petReturned,
                    onChanged: widget.onPetChanged, color: dangerC),
              ])),
            ]),
          ),
      ]),
    );
  }
}

// ── Bill Card ─────────────────────────────────────────────────────────────────
class _BillCard extends StatelessWidget {
  final int cd, pd, cdmg, pdmg;
  final double coolPrice, petPrice, dmgPrice, total, advance, transportFee;
  const _BillCard({required this.cd, required this.pd, required this.cdmg, required this.pdmg,
      required this.coolPrice, required this.petPrice, required this.dmgPrice,
      required this.total, required this.advance, this.transportFee = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0A1F6E), Color(0xFF1A6BFF)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        if (cd > 0) _rIcon(
          leading: Row(mainAxisSize: MainAxisSize.min, children: [
            CoolJarIcon(size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text('Cool ×$cd', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
          ]),
          value: '₹${(cd * coolPrice).toInt()}',
        ),
        if (pd > 0) _rIcon(
          leading: Row(mainAxisSize: MainAxisSize.min, children: [
            PetJarIcon(size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text('PET ×$pd', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
          ]),
          value: '₹${(pd * petPrice).toInt()}',
        ),
        if ((cdmg + pdmg) > 0) _r('⚠ Damage ×${cdmg + pdmg}', '₹${((cdmg + pdmg) * dmgPrice).toInt()}'),
        if (transportFee > 0) _r('🚚 Transport', '₹${transportFee.toInt()}'),
        const Divider(color: Colors.white24, height: 16),
        _r('Total', '₹${total.toInt()}', bold: true),
        if (advance > 0) _r('Advance avail', '₹${advance.toInt()}', sub: true),
      ]),
    );
  }

  Widget _rIcon({required Widget leading, required String value}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      leading,
      const Spacer(),
      Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 15,
          fontWeight: FontWeight.w600, color: Colors.white)),
    ]),
  );

  Widget _r(String l, String v, {bool bold = false, bool sub = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(l, style: GoogleFonts.inter(fontSize: sub ? 12 : 13, color: sub ? Colors.white54 : Colors.white70,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
      const Spacer(),
      Text(v, style: GoogleFonts.jetBrainsMono(fontSize: sub ? 12 : 15,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: sub ? Colors.white54 : Colors.white)),
    ]),
  );
}

// ── Amount Field ──────────────────────────────────────────────────────────────
class _AmountField extends StatelessWidget {
  final TextEditingController ctrl;
  final double advance;
  final String hint;
  final ValueChanged<double> onChanged;
  final VoidCallback onUseAdvance;
  const _AmountField({required this.ctrl, required this.hint, required this.advance,
      required this.onChanged, required this.onUseAdvance});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2Dark : AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
      ),
      child: Row(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('₹', style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w700,
              color: AppColors.inkMuted))),
        Expanded(child: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
          style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint, border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
            hintStyle: GoogleFonts.jetBrainsMono(color: AppColors.inkMuted, fontSize: 20),
          ),
        )),
        if (advance > 0)
          GestureDetector(
            onTap: onUseAdvance,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Use ₹${advance.toInt()} adv',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary)),
            ),
          ),
      ]),
    );
  }
}

// ── Customer Picker — FIXED: RangeError + Add New Customer ────────────────────
class _CustPicker extends StatelessWidget {
  final Customer? selected;
  final List<Customer> customers;
  final ValueChanged<Customer> onSelect;
  const _CustPicker({required this.selected, required this.customers, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        height: 58, padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        child: Row(children: [
          if (selected != null) ...[
            CustomerAvatar(initials: selected!.initials, size: 34),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(selected!.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
              Row(children: [
                CoolJarIcon(size: 12, color: AppColors.coolColor(isDark)),
                Text(' ${selected!.coolOut} with them  ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
                PetJarIcon(size: 12, color: AppColors.petColor(isDark)),
                Text(' ${selected!.petOut} with them  ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
                if (selected!.advanceBalance > 0)
                  Text('₹${selected!.advanceBalance.toInt()} adv',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.successColor(isDark), fontWeight: FontWeight.w600)),
              ]),
            ])),
          ] else
            Expanded(child: Text('Tap to select customer...',
                style: GoogleFonts.inter(color: AppColors.inkMuted, fontSize: 14))),
          const Icon(Icons.expand_more_rounded, color: AppColors.inkMuted),
        ]),
      ),
    );
  }

  Future<void> _pick(BuildContext ctx) async {
    final result = await showModalBottomSheet<Customer>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _CustPickerSheet(
        customers: customers,
        onSelect: (c) => Navigator.pop(sheetCtx, c),
      ),
    );
    if (result != null) onSelect(result);
  }
}

/// Separate stateful sheet widget — avoids the RangeError by using
/// a properly constrained ListView with its own search state.
class _CustPickerSheet extends ConsumerStatefulWidget {
  final List<Customer> customers;
  final ValueChanged<Customer> onSelect;
  const _CustPickerSheet({required this.customers, required this.onSelect});

  @override
  ConsumerState<_CustPickerSheet> createState() => _CustPickerSheetState();
}

class _CustPickerSheetState extends ConsumerState<_CustPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.customers
        .where((c) => c.name.toLowerCase().contains(_search.toLowerCase()) ||
            c.phone.contains(_search) ||
            c.area.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.80),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: isDark ? AppColors.separatorDark : AppColors.separator,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(child: Text('Select Customer',
                style: Theme.of(context).textTheme.headlineMedium)),
            IconButton(icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface2Dark : AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
            ),
            child: Row(children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.search_rounded, color: AppColors.inkMuted, size: 17)),
              Expanded(child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search name, phone, area...',
                  border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
                  hintStyle: GoogleFonts.inter(color: AppColors.inkMuted, fontSize: 13),
                ),
              )),
            ]),
          ),
        ),
        // Customer list — properly constrained with Flexible
        Flexible(
          child: filtered.isEmpty
              ? _NoCustomerFound(
                  search: _search,
                  onAdd: () async {
                    // Close picker, open add customer form
                    Navigator.pop(context);
                    final newCust = await showMrSheet<Customer>(context,
                      title: '👤 Add New Customer',
                      builder: (_) => _QuickAddCustomerForm(),
                    );
                    if (newCust != null) widget.onSelect(newCust);
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return ListTile(
                      onTap: () => widget.onSelect(c),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: CustomerAvatar(initials: c.initials, size: 38),
                      title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      subtitle: Row(children: [
                        CoolJarIcon(size: 12, color: AppColors.coolColor(isDark)),
                        Text(' ${c.coolOut}  ', style: GoogleFonts.inter(fontSize: 12,
                            color: AppColors.coolColor(isDark))),
                        PetJarIcon(size: 12, color: AppColors.petColor(isDark)),
                        Text(' ${c.petOut}  ', style: GoogleFonts.inter(fontSize: 12,
                            color: AppColors.petColor(isDark))),
                        Text('· ${c.area}', style: GoogleFonts.inter(fontSize: 11,
                            color: AppColors.inkMuted)),
                      ]),
                      trailing: c.advanceBalance > 0
                          ? Text('+₹${c.advanceBalance.toInt()}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 12,
                                  fontWeight: FontWeight.w700, color: AppColors.success))
                          : c.ledgerBalance < 0
                              ? Text('-₹${c.ledgerBalance.abs().toInt()}',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12,
                                      fontWeight: FontWeight.w700, color: AppColors.dangerColor(isDark)))
                              : null,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

/// Shown when no customers match the search — gives an inline "Add" option
class _NoCustomerFound extends StatelessWidget {
  final String search;
  final VoidCallback onAdd;
  const _NoCustomerFound({required this.search, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_search_rounded, size: 48, color: AppColors.inkMuted),
        const SizedBox(height: 12),
        Text(
          search.isNotEmpty ? 'No customer found for "$search"' : 'No customers yet',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: '+ Add ${search.isNotEmpty ? '"$search"' : 'New Customer'}',
          onTap: onAdd,
          height: 46,
        ),
      ]),
    );
  }
}

/// Quick add customer form — used inline from transaction picker
class _QuickAddCustomerForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_QuickAddCustomerForm> createState() => _QuickAddCustomerFormState();
}

class _QuickAddCustomerFormState extends ConsumerState<_QuickAddCustomerForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _area.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('New customer will be saved and selected automatically.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
      const SizedBox(height: 16),
      FieldLabel('Full Name *'),
      TextFormField(
        controller: _name,
        decoration: const InputDecoration(hintText: 'Priya Mehta'),
        validator: (v) => (v == null || v.trim().length < 3) ? 'At least 3 characters' : null,
      ),
      const SizedBox(height: 12),
      FieldLabel('Mobile Number *'),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(hintText: '9876543210', prefixText: '+91 '),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) return 'Enter valid 10-digit number';
          return null;
        },
      ),
      const SizedBox(height: 12),
      FieldLabel('Area / Route'),
      TextFormField(controller: _area, decoration: const InputDecoration(hintText: 'Koregaon Park')),
      const SizedBox(height: 24),
      GradientButton(
        label: 'Save & Select Customer',
        onTap: () {
          if (_formKey.currentState!.validate()) {
            final newCust = Customer(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _name.text.trim(), phone: _phone.text.trim(),
              area: _area.text.trim(), createdAt: DateTime.now().toIso8601String(),
            );
            ref.read(customersProvider.notifier).add(newCust);
            Navigator.pop(context, newCust);
            showToast(context, '✅ Customer added & selected', success: true);
          }
        },
      ),
    ]),
  );
}

// ── Inline Price Override ─────────────────────────────────────────────────────
/// Shows current effective price for a selected customer.
/// Tapping opens editable Cool + PET fields that update live and persist on save.
class _InlinePriceOverride extends StatelessWidget {
  final Customer cust;
  final TextEditingController coolCtrl, petCtrl;
  final double defaultCoolPrice, defaultPetPrice;
  final bool showOverride, isDark;
  final VoidCallback onToggle, onChanged;

  const _InlinePriceOverride({
    required this.cust, required this.coolCtrl, required this.petCtrl,
    required this.defaultCoolPrice, required this.defaultPetPrice,
    required this.showOverride, required this.isDark,
    required this.onToggle, required this.onChanged,
  });

  double get _effectiveCool {
    final v = double.tryParse(coolCtrl.text);
    return (v != null && v > 0) ? v : (cust.coolPriceOverride ?? defaultCoolPrice);
  }
  double get _effectivePet {
    final v = double.tryParse(petCtrl.text);
    return (v != null && v > 0) ? v : (cust.petPriceOverride ?? defaultPetPrice);
  }

  bool get _coolCustom => _effectiveCool != defaultCoolPrice;
  bool get _petCustom  => _effectivePet  != defaultPetPrice;
  bool get _anyCustom  => _coolCustom || _petCustom;

  @override
  Widget build(BuildContext context) {
    final coolC = AppColors.coolColor(isDark);
    final petC  = AppColors.petColor(isDark);
    final warningC = AppColors.warningColor(isDark);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _anyCustom
            ? warningC.withValues(alpha: 0.07)
            : (isDark ? AppColors.surface2Dark : AppColors.surface2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _anyCustom ? warningC.withValues(alpha: 0.35) : (isDark ? AppColors.separatorDark : AppColors.separator),
          width: _anyCustom ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row — always visible
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Icon(Icons.sell_rounded, size: 14,
                color: _anyCustom ? warningC : AppColors.inkMuted),
            const SizedBox(width: 8),
            Expanded(child: Wrap(spacing: 8, children: [
              _PriceChip(
                icon: CoolJarIcon(size: 12, color: coolC),
                label: '₹${_effectiveCool.toInt()}',
                isCustom: _coolCustom,
                color: coolC, warningC: warningC, isDark: isDark,
              ),
              _PriceChip(
                icon: PetJarIcon(size: 12, color: petC),
                label: '₹${_effectivePet.toInt()}',
                isCustom: _petCustom,
                color: petC, warningC: warningC, isDark: isDark,
              ),
              if (_anyCustom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: warningC.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Custom ★', style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w800, color: warningC)),
                ),
            ])),
            Icon(showOverride ? Icons.keyboard_arrow_up_rounded : Icons.edit_rounded,
                size: 16, color: AppColors.inkMuted),
          ]),
        ),

        // Expandable edit fields
        if (showOverride) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
          const SizedBox(height: 12),
          Text('Override price for this transaction (saves to customer)',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CoolJarIcon(size: 14, color: coolC),
                const SizedBox(width: 6),
                Text('Cool /jar', style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w700, color: coolC)),
                if (_coolCustom) ...[
                  const SizedBox(width: 4),
                  Text('★', style: GoogleFonts.inter(fontSize: 10, color: warningC)),
                ],
              ]),
              const SizedBox(height: 6),
              _PriceField(
                ctrl: coolCtrl,
                hint: defaultCoolPrice.toStringAsFixed(0),
                color: coolC, isDark: isDark,
                onChanged: (_) => onChanged(),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PetJarIcon(size: 14, color: petC),
                const SizedBox(width: 6),
                Text('PET /jar', style: GoogleFonts.inter(fontSize: 12,
                    fontWeight: FontWeight.w700, color: petC)),
                if (_petCustom) ...[
                  const SizedBox(width: 4),
                  Text('★', style: GoogleFonts.inter(fontSize: 10, color: warningC)),
                ],
              ]),
              const SizedBox(height: 6),
              _PriceField(
                ctrl: petCtrl,
                hint: defaultPetPrice.toStringAsFixed(0),
                color: petC, isDark: isDark,
                onChanged: (_) => onChanged(),
              ),
            ])),
          ]),
          if (_anyCustom)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'ℹ️ Custom price applies to this transaction only. Previous transactions are unaffected.',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted, height: 1.4),
              ),
            ),
        ],
      ]),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isCustom, isDark;
  final Color color, warningC;
  const _PriceChip({required this.icon, required this.label, required this.isCustom,
      required this.color, required this.warningC, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isCustom ? warningC.withValues(alpha: 0.1) : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: isCustom ? warningC.withValues(alpha: 0.3) : color.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      icon,
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700,
          color: isCustom ? warningC : color)),
    ]),
  );
}

class _PriceField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final Color color;
  final bool isDark;
  final ValueChanged<String> onChanged;
  const _PriceField({required this.ctrl, required this.hint, required this.color,
      required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(
      color: isDark ? AppColors.bgDark : AppColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
    ),
    child: Row(children: [
      Padding(padding: const EdgeInsets.only(left: 10),
        child: Text('₹', style: GoogleFonts.jetBrainsMono(
            fontSize: 14, fontWeight: FontWeight.w700, color: color))),
      Expanded(child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: color),
        decoration: InputDecoration(
          hintText: hint, border: InputBorder.none, filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          hintStyle: GoogleFonts.jetBrainsMono(fontSize: 15, color: color.withValues(alpha: 0.35)),
        ),
      )),
    ]),
  );
}

// ── Event Status & Return Section ─────────────────────────────────────────────
class _EventStatusSection extends StatelessWidget {
  final String status;
  final DateTime? eventDate;
  final int coolDelivered, petDelivered, coolReturned, petReturned;
  final int coolReturnDmg, petReturnDmg;
  final int maxCoolReturn, maxPetReturn;
  final bool isDark;
  final ValueChanged<String> onStatusChange;
  final ValueChanged<int> onCoolReturnChanged, onPetReturnChanged;
  final ValueChanged<int> onCoolDmgChanged, onPetDmgChanged;

  const _EventStatusSection({
    required this.status, required this.eventDate,
    required this.coolDelivered, required this.petDelivered,
    required this.coolReturned, required this.petReturned,
    required this.coolReturnDmg, required this.petReturnDmg,
    required this.maxCoolReturn, required this.maxPetReturn,
    required this.isDark, required this.onStatusChange,
    required this.onCoolReturnChanged, required this.onPetReturnChanged,
    required this.onCoolDmgChanged, required this.onPetDmgChanged,
  });

  bool get _isScheduled => status == 'scheduled';

  String get _daysLabel {
    if (eventDate == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(eventDate!.year, eventDate!.month, eventDate!.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1) return 'In $diff days';
    if (diff == -1) return 'Yesterday';
    return '${-diff} days ago';
  }

  Color _statusColor(bool isDark) => switch (status) {
    'scheduled' => AppColors.warningColor(isDark),
    'active'    => AppColors.primaryColor(isDark),
    'completed' => AppColors.successColor(isDark),
    _ => AppColors.inkMuted,
  };

  IconData get _statusIcon => switch (status) {
    'scheduled' => Icons.schedule_rounded,
    'active'    => Icons.play_circle_rounded,
    'completed' => Icons.check_circle_rounded,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final statusC = _statusColor(isDark);
    final coolC = AppColors.coolColor(isDark);
    final petC  = AppColors.petColor(isDark);
    final dangerC = AppColors.dangerColor(isDark);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusC.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusC.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Status Header ────────────────────────────────────────────────────
        Row(children: [
          Icon(_statusIcon, size: 16, color: statusC),
          const SizedBox(width: 8),
          Text('Event Status', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: statusC)),
          const Spacer(),
          if (eventDate != null && _isScheduled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusC.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_rounded, size: 11, color: statusC),
                const SizedBox(width: 4),
                Text(_daysLabel, style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w800, color: statusC)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),

        // ── Status Toggle Buttons ────────────────────────────────────────────
        Row(children: [
          _StatusBtn(label: 'Scheduled', icon: Icons.schedule_rounded,
              value: 'scheduled', current: status,
              color: AppColors.warningColor(isDark), onTap: () => onStatusChange('scheduled')),
          const SizedBox(width: 8),
          _StatusBtn(label: 'Active', icon: Icons.play_circle_rounded,
              value: 'active', current: status,
              color: AppColors.primaryColor(isDark), onTap: () => onStatusChange('active')),
          const SizedBox(width: 8),
          _StatusBtn(label: 'Done', icon: Icons.check_circle_rounded,
              value: 'completed', current: status,
              color: AppColors.successColor(isDark), onTap: () => onStatusChange('completed')),
        ]),

        // ── Jar Return Section (only when active or completed) ───────────────
        if (!_isScheduled) ...[
          const SizedBox(height: 16),
          Divider(height: 1, color: statusC.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.swap_vert_rounded, size: 15, color: statusC),
            const SizedBox(width: 6),
            Text('Collect Jars Back', style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (coolDelivered > 0 || petDelivered > 0)
              Text('${coolDelivered + petDelivered} sent out',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
          ]),
          const SizedBox(height: 12),

          // Cool return row
          if (coolDelivered > 0)
            _ReturnRow(
              icon: CoolJarIcon(size: 18, color: coolC),
              label: 'Cool', color: coolC, dangerC: dangerC,
              delivered: coolDelivered, returned: coolReturned,
              damaged: coolReturnDmg, maxReturn: maxCoolReturn,
              isDark: isDark,
              onReturnChanged: onCoolReturnChanged,
              onDmgChanged: onCoolDmgChanged,
            ),

          if (coolDelivered > 0 && petDelivered > 0) const SizedBox(height: 10),

          // PET return row
          if (petDelivered > 0)
            _ReturnRow(
              icon: PetJarIcon(size: 18, color: petC),
              label: 'PET', color: petC, dangerC: dangerC,
              delivered: petDelivered, returned: petReturned,
              damaged: petReturnDmg, maxReturn: maxPetReturn,
              isDark: isDark,
              onReturnChanged: onPetReturnChanged,
              onDmgChanged: onPetDmgChanged,
            ),

          // Return summary
          if (coolReturned > 0 || petReturned > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successColor(isDark).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  '${coolReturned + petReturned} jar${(coolReturned + petReturned) > 1 ? 's' : ''} collected back'
                  '${(coolReturnDmg + petReturnDmg) > 0 ? '  ·  ${coolReturnDmg + petReturnDmg} damaged' : ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.successColor(isDark),
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],
        ],
      ]),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label, value, current;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StatusBtn({required this.label, required this.icon, required this.value,
      required this.current, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.2), width: active ? 1.5 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 16, color: active ? color : AppColors.inkMuted),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.inter(
              fontSize: 10, fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active ? color : AppColors.inkMuted)),
        ]),
      ),
    ));
  }
}

class _ReturnRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color, dangerC;
  final int delivered, returned, damaged, maxReturn;
  final bool isDark;
  final ValueChanged<int> onReturnChanged, onDmgChanged;

  const _ReturnRow({required this.icon, required this.label, required this.color,
      required this.dangerC, required this.delivered, required this.returned,
      required this.damaged, required this.maxReturn, required this.isDark,
      required this.onReturnChanged, required this.onDmgChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          icon, const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          Text('$delivered sent', style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(children: [
            Text('Collected Back', style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.successColor(isDark))),
            const SizedBox(height: 6),
            _EditableStepper(value: returned, max: maxReturn,
                onChanged: onReturnChanged, color: AppColors.success),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [
            Text('Damaged', style: GoogleFonts.inter(
                fontSize: 10, color: dangerC)),
            const SizedBox(height: 6),
            _EditableStepper(value: damaged, max: returned,
                onChanged: onDmgChanged, color: dangerC),
          ])),
        ]),
        if (returned > 0 && delivered > returned)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${delivered - returned} jars still at event',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.warningColor(isDark))),
          ),
      ]),
    );
  }
}


// VoiceFab is now defined in voice_assistant.dart (public class).
// It calls openVoiceAssistant(context) which uses Navigator.push
// instead of showMrSheet — fixes the bottom sheet height hang.
