// ════════════════════════════════════════════════════════════════════════════
// expenses_screen.dart  — Expense history + Add expense form
// Layout: Month picker | Staff filter | Grouped daily history | FAB to add
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';
import 'voice_form_helper.dart';

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE CATEGORIES
// ══════════════════════════════════════════════════════════════════════════════
class ExpenseCat {
  final String label;
  final IconData icon;
  final Color color;
  const ExpenseCat(this.label, this.icon, this.color);
}

const expenseCategories = [
  ExpenseCat('Electricity Bill',          Icons.electric_bolt_rounded,           Color(0xFFFFD166)),
  ExpenseCat('Staff Salary',              Icons.people_rounded,                  Color(0xFF7B61FF)),
  ExpenseCat('Food & Refreshments',       Icons.restaurant_rounded,              Color(0xFFFF8C42)),
  ExpenseCat('Petrol / Diesel',           Icons.local_gas_station_rounded,       Color(0xFF0096C7)),
  ExpenseCat('Machine Maintenance',       Icons.build_rounded,                   Color(0xFF06D6A0)),
  ExpenseCat('Buying Jars',               Icons.inventory_2_rounded,             Color(0xFF52B788)),
  ExpenseCat('Vehicle Maintenance',       Icons.car_repair_rounded,              Color(0xFFEF476F)),
  ExpenseCat('Vehicle Rent',              Icons.directions_car_rounded,          Color(0xFF388BFD)),
  ExpenseCat('New Vehicle',               Icons.local_shipping_rounded,          Color(0xFF1A3A8F)),
  ExpenseCat('New Machinery',             Icons.precision_manufacturing_rounded, Color(0xFF3A9B6B)),
  ExpenseCat('Rent / Office',             Icons.home_work_rounded,               Color(0xFFFF6B6B)),
  ExpenseCat('Water Treatment Supplies',  Icons.water_drop_rounded,              Color(0xFF48CAE4)),
  ExpenseCat('Other',                     Icons.more_horiz_rounded,              Color(0xFF8892AB)),
];

ExpenseCat _catFor(String label) => expenseCategories.firstWhere(
      (c) => c.label == label,
      orElse: () => expenseCategories.last,
    );

// ══════════════════════════════════════════════════════════════════════════════
// HELPER — build list of month options (current month + 23 previous)
// ══════════════════════════════════════════════════════════════════════════════
class _MonthOption {
  final DateTime date; // first day of the month
  _MonthOption(this.date);
  String get label => DateFormat('MMMM yyyy').format(date);
}

List<_MonthOption> _buildMonthOptions() {
  final now = DateTime.now();
  return List.generate(24, (i) {
    final d = DateTime(now.year, now.month - i, 1);
    return _MonthOption(d);
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSES SCREEN  — two tabs: History | Add Expense
// ══════════════════════════════════════════════════════════════════════════════
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  late List<_MonthOption> _months;
  late _MonthOption _selectedMonth;
  String   _selectedStaffId = 'all';
  DateTime? _selectedDate;          // null = all dates in month

  @override
  void initState() {
    super.initState();
    _tc     = TabController(length: 2, vsync: this);
    _tc.addListener(() => setState(() {}));
    _months        = _buildMonthOptions();
    _selectedMonth = _months.first;
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  // ── Filter helpers ──────────────────────────────────────────────────────────
  List<JarTransaction> _filtered(List<JarTransaction> all) {
    return all.where((t) {
      if (t.customerId != 'EXPENSE') return false;
      try {
        final d = DateTime.parse(t.date);
        if (d.year != _selectedMonth.date.year ||
            d.month != _selectedMonth.date.month) {
          return false;
        }
        if (_selectedDate != null &&
            !(d.year == _selectedDate!.year &&
              d.month == _selectedDate!.month &&
              d.day == _selectedDate!.day)) {
          return false;
        }
        if (_selectedStaffId != 'all' && t.createdBy != _selectedStaffId) {
          return false;
        }
        return true;
      } catch (_) { return false; }
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Map<String, List<JarTransaction>> _groupByDate(List<JarTransaction> list) {
    final map = <String, List<JarTransaction>>{};
    for (final t in list) { map.putIfAbsent(t.date, () => []).add(t); }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final allTxns  = ref.watch(transactionsProvider);
    final allStaff = ref.watch(staffProvider).where((s) => s.isActive).toList();

    final expenses    = _filtered(allTxns);
    final totalMonth  = expenses.fold(0.0, (s, t) => s + t.damageCharge);
    final grouped     = _groupByDate(expenses);
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    // Resolve staff display label
    String staffLabel = 'All Employees';
    if (_selectedStaffId != 'all') {
      try { staffLabel = allStaff.firstWhere((s) => s.id == _selectedStaffId).name; }
      catch (_) { _selectedStaffId = 'all'; }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [

        // ── Tab bar ──────────────────────────────────────────────────────────
        Container(
          color: isDark ? AppColors.cardDark : Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Container(
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
              tabs: const [
                Tab(text: '📋 History'),
                Tab(text: '➕ Add Expense'),
              ],
            ),
          ),
        ),

        // ── Tab content ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(controller: _tc, children: [

            // ════════════════════════════════════════════════════════════════
            // TAB 1 — HISTORY
            // ════════════════════════════════════════════════════════════════
            Column(children: [

              // ── Top filter row: Month | Date | Staff | PDF ───────────────
              Container(
                color: isDark ? AppColors.cardDark : Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(children: [

                  // Month dropdown
                  Expanded(child: _DropdownPill(
                    icon: Icons.calendar_month_rounded,
                    label: _selectedMonth.label,
                    isDark: isDark, primary: primary,
                    onTap: () => _showMonthPicker(context, isDark, primary),
                  )),
                  const SizedBox(width: 8),

                  // Date filter
                  Expanded(child: _DropdownPill(
                    icon: Icons.event_rounded,
                    label: _selectedDate != null
                        ? DateFormat('d MMM').format(_selectedDate!)
                        : 'Select Date',
                    isDark: isDark, primary: primary,
                    onTap: () => _pickDate(context),
                  )),
                  const SizedBox(width: 8),

                  // Staff dropdown
                  Expanded(child: _DropdownPill(
                    icon: Icons.person_rounded,
                    label: staffLabel,
                    isDark: isDark, primary: primary,
                    onTap: () => _showStaffPicker(context, isDark, primary, allStaff),
                  )),
                  const SizedBox(width: 8),

                  // PDF button
                  _PdfButton(isDark: isDark, primary: primary),
                ]),
              ),

              // ── Monthly total banner ─────────────────────────────────────
              Container(
                width: double.infinity,
                color: isDark ? AppColors.surface2Dark : const Color(0xFFE8F4FD),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      'Total expenses in ${DateFormat('MMMM').format(_selectedMonth.date)}',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : const Color(0xFF1A6BFF)),
                    ),
                  ),
                  Icon(Icons.currency_rupee_rounded, size: 14,
                      color: AppColors.dangerColor(isDark)),
                  Text(totalMonth.toInt().toString(),
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: AppColors.dangerColor(isDark))),
                ]),
              ),

              // ── Section heading ──────────────────────────────────────────
              if (expenses.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text(
                    'Total Expenses - $staffLabel'
                    ' ${DateFormat('MMMM yyyy').format(_selectedMonth.date)}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF1A3A8F)),
                  ),
                ),

              // ── Expense history list ─────────────────────────────────────
              Expanded(
                child: expenses.isEmpty
                    ? _EmptyState(staffLabel: staffLabel, month: _selectedMonth.label)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 40),
                        itemCount: sortedDates.length,
                        itemBuilder: (ctx, i) {
                          final dateKey    = sortedDates[i];
                          final dayExpenses = grouped[dateKey]!;
                          final dayTotal   = dayExpenses.fold(
                              0.0, (s, t) => s + t.damageCharge);
                          return _DayGroup(
                            dateKey: dateKey,
                            dayExpenses: dayExpenses,
                            dayTotal: dayTotal,
                            isDark: isDark,
                            onDelete: (txn) => _confirmDelete(ctx, txn),
                          );
                        },
                      ),
              ),
            ]),

            // ════════════════════════════════════════════════════════════════
            // TAB 2 — ADD EXPENSE FORM
            // ════════════════════════════════════════════════════════════════
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: ExpenseForm(
                defaultDate: DateTime(
                    _selectedMonth.date.year,
                    _selectedMonth.date.month,
                    DateTime.now().day),
                onSaved: () => _tc.animateTo(0), // jump to History after save
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Month picker ────────────────────────────────────────────────────────────
  void _showMonthPicker(BuildContext context, bool isDark, Color primary) {
    showMrSheet(context, title: '📅 Select Month',
      builder: (_) => SizedBox(
        height: 320,
        child: ListView.builder(
          itemCount: _months.length,
          itemBuilder: (ctx, i) {
            final m      = _months[i];
            final active = m.date.year  == _selectedMonth.date.year &&
                           m.date.month == _selectedMonth.date.month;
            return ListTile(
              title: Text(m.label,
                  style: GoogleFonts.inter(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? primary
                          : (isDark ? Colors.white : Colors.black87))),
              trailing: active
                  ? Icon(Icons.check_circle_rounded, color: primary) : null,
              onTap: () {
                setState(() { _selectedMonth = m; _selectedDate = null; });
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  // ── Date picker ─────────────────────────────────────────────────────────────
  void _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          DateTime(_selectedMonth.date.year, _selectedMonth.date.month, 1),
      firstDate: DateTime(_selectedMonth.date.year, _selectedMonth.date.month, 1),
      lastDate: DateTime(_selectedMonth.date.year, _selectedMonth.date.month + 1, 0),
    );
    if (picked != null) setState(() => _selectedDate = picked);
    // Tap again on same date = clear
    if (picked != null && _selectedDate == picked) {
      setState(() => _selectedDate = null);
    }
  }

  // ── Staff picker ─────────────────────────────────────────────────────────────
  void _showStaffPicker(BuildContext context, bool isDark, Color primary,
      List<StaffMember> staff) {
    showMrSheet(context, title: '👤 Filter by Employee',
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: primary.withValues(alpha: 0.12),
            child: Icon(Icons.people_rounded, color: primary, size: 18),
          ),
          title: Text('All Employees',
              style: GoogleFonts.inter(
                  fontWeight: _selectedStaffId == 'all'
                      ? FontWeight.w700 : FontWeight.w400)),
          trailing: _selectedStaffId == 'all'
              ? Icon(Icons.check_circle_rounded, color: primary) : null,
          onTap: () {
            setState(() => _selectedStaffId = 'all');
            Navigator.pop(context);
          },
        ),
        const Divider(height: 1),
        ...staff.map((s) {
          final active = _selectedStaffId == s.id;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: primary.withValues(alpha: 0.12),
              child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, color: primary)),
            ),
            title: Text(s.name,
                style: GoogleFonts.inter(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
            trailing: active
                ? Icon(Icons.check_circle_rounded, color: primary) : null,
            onTap: () {
              setState(() => _selectedStaffId = s.id);
              Navigator.pop(context);
            },
          );
        }),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ── Confirm delete ──────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, JarTransaction txn) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await confirmDialog(context,
      title: 'Delete Expense?',
      message: '${txn.customerName} · ₹${txn.damageCharge.toInt()} on ${txn.date}',
      confirmLabel: 'Delete',
      color: AppColors.dangerColor(isDark),
    );
    if (ok && mounted) {
      ref.read(transactionsProvider.notifier).delete(txn);
      if (mounted) {
        showToast(context, 'Expense deleted', error: true);
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DAY GROUP — Date header + list of expenses for that day
// ══════════════════════════════════════════════════════════════════════════════
class _DayGroup extends StatelessWidget {
  final String dateKey;
  final List<JarTransaction> dayExpenses;
  final double dayTotal;
  final bool isDark;
  final void Function(JarTransaction) onDelete;

  const _DayGroup({
    required this.dateKey,
    required this.dayExpenses,
    required this.dayTotal,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    DateTime? parsed;
    try { parsed = DateTime.parse(dateKey); } catch (_) {}

    final dateLabel = parsed != null
        ? DateFormat('d MMM yyyy').format(parsed)
        : dateKey;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Day header ────────────────────────────────────────────────────────
      Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2A3A) : const Color(0xFFDDEEFB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Text(
            dateLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF1A6BFF),
            ),
          ),
          const Spacer(),
          Text(
            'Total Expenses  ',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54),
          ),
          Icon(Icons.currency_rupee_rounded, size: 13,
              color: AppColors.dangerColor(isDark)),
          Text(
            dayTotal.toInt().toString(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.dangerColor(isDark),
            ),
          ),
        ]),
      ),

      // ── Expense items for the day ─────────────────────────────────────────
      ...dayExpenses.map((txn) => _ExpenseRow(
            txn: txn,
            isDark: isDark,
            onDelete: () => onDelete(txn),
          )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE ROW — Single expense item
// ══════════════════════════════════════════════════════════════════════════════
class _ExpenseRow extends StatelessWidget {
  final JarTransaction txn;
  final bool isDark;
  final VoidCallback onDelete;

  const _ExpenseRow(
      {required this.txn, required this.isDark, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final ec  = _catFor(txn.customerName);
    final raw = txn.note.replaceFirst('[${txn.customerName}] ', '').trim();

    // Time from createdAt
    String timeStr = '';
    try {
      final dt = DateTime.parse(txn.createdAt);
      timeStr = DateFormat('hh:mm a').format(dt).toLowerCase();
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [

          // Time column (left)
          if (timeStr.isNotEmpty) ...[
            SizedBox(
              width: 54,
              child: Text(
                timeStr,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.inkMuted,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Category icon bubble
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: ec.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(ec.icon, size: 20, color: ec.color),
          ),
          const SizedBox(width: 12),

          // Name + note
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                txn.createdBy.isNotEmpty && txn.createdBy != 'Admin'
                    ? txn.createdBy
                    : txn.customerName,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                raw.isNotEmpty ? raw : txn.customerName,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )),

          const SizedBox(width: 8),

          // Amount + delete
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              Icon(Icons.currency_rupee_rounded, size: 13,
                  color: AppColors.dangerColor(isDark)),
              Text(
                txn.damageCharge.toInt().toString(),
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dangerColor(isDark)),
              ),
            ]),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline_rounded, size: 17,
                  color: AppColors.inkMuted.withValues(alpha: 0.55)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DROPDOWN PILL — Month / Staff selector pill
// ══════════════════════════════════════════════════════════════════════════════
class _DropdownPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _DropdownPill({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark
                    ? AppColors.separatorDark
                    : const Color(0xFFBDD5F8)),
          ),
          child: Row(children: [
            Icon(icon, size: 15, color: primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: primary),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// PDF BUTTON
// ══════════════════════════════════════════════════════════════════════════════
class _PdfButton extends StatelessWidget {
  final bool isDark;
  final Color primary;

  const _PdfButton({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showToast(context, 'PDF export coming soon'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark
                    ? AppColors.separatorDark
                    : const Color(0xFFBDD5F8)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.picture_as_pdf_rounded, size: 15,
                color: AppColors.dangerColor(isDark)),
            const SizedBox(width: 5),
            Text(
              'Download',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dangerColor(isDark)),
            ),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String staffLabel;
  final String month;
  const _EmptyState({required this.staffLabel, required this.month});

  @override
  Widget build(BuildContext context) =>
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_rounded, size: 52,
            color: AppColors.inkMuted.withValues(alpha: 0.35)),
        const SizedBox(height: 14),
        Text(
          'No expenses in $month',
          style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted),
        ),
        const SizedBox(height: 4),
        Text(
          staffLabel == 'All Employees'
              ? 'Tap + to record the first expense'
              : 'No expenses for $staffLabel',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted),
        ),
      ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE FORM — Add new expense (used from FAB + dashboard shortcut)
// ══════════════════════════════════════════════════════════════════════════════
class ExpenseForm extends ConsumerStatefulWidget {
  /// Pre-fill the date (e.g. when opened from a specific month view)
  final DateTime? defaultDate;
  /// Called after the expense is saved — used to switch tab in ExpensesScreen
  final VoidCallback? onSaved;
  const ExpenseForm({super.key, this.defaultDate, this.onSaved});

  @override
  ConsumerState<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseForm> {
  String? _category;
  final _typeCtrl = TextEditingController();
  final _amtCtrl  = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _mode    = 'cash';
  late DateTime _date;
  String? _selectedPersonId; // null = owner/admin
  bool _showCategorySuggestions = false;

  // Filtered suggestions based on what the user has typed
  List<ExpenseCat> get _suggestions {
    if (_typeCtrl.text.isEmpty) return expenseCategories;
    final q = _typeCtrl.text.toLowerCase();
    return expenseCategories
        .where((c) => c.label.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _date = widget.defaultDate ?? DateTime.now();
    _typeCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final allStaff = ref.watch(staffProvider).where((s) => s.isActive).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Voice fill button ──────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          VoiceMicButton(
            formType: VoiceFormType.expense,
            onResult: (r) {
              setState(() {
                if (r.expenseCategory.isNotEmpty) {
                  _typeCtrl.text = r.expenseCategory;
                  _category = r.expenseCategory;
                }
                if (r.expenseAmount > 0) {
                  _amtCtrl.text = r.expenseAmount.toInt().toString();
                }
              });
            },
          ),
          const SizedBox(width: 8),
          Text('Fill fields by voice',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
        ]),
      ),

      // ── Date picker ────────────────────────────────────────────────────────
      Center(
        child: GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(DateTime.now().year - 2),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _date = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface2Dark : const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: isDark
                      ? AppColors.separatorDark
                      : const Color(0xFFBDD5F8)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today_rounded, size: 15, color: primary),
              const SizedBox(width: 8),
              Text(
                DateFormat('d MMM yyyy').format(_date),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primary),
              ),
            ]),
          ),
        ),
      ),

      const SizedBox(height: 20),

      // ── Expense type (type or pick from list) ──────────────────────────────
      FieldLabel('Expenses Type *'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _typeCtrl,
        onTap: () => setState(() => _showCategorySuggestions = true),
        onChanged: (_) => setState(() => _showCategorySuggestions = true),
        decoration: InputDecoration(
          hintText: 'Type your own or select from list',
          prefixIcon: _category != null
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(_catFor(_category!).icon,
                      size: 20, color: _catFor(_category!).color))
              : null,
          suffixIcon: _typeCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    setState(() {
                      _typeCtrl.clear();
                      _category = null;
                      _showCategorySuggestions = false;
                    });
                  },
                )
              : null,
        ),
      ),

      // Category suggestion list
      if (_showCategorySuggestions && _suggestions.isNotEmpty) ...[
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark
                    ? AppColors.separatorDark
                    : AppColors.separator),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: isDark ? 0.20 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? AppColors.separatorDark
                    : AppColors.separator,
              ),
              itemBuilder: (ctx, i) {
                final cat = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(cat.icon, size: 16, color: cat.color),
                  ),
                  title: Text(cat.label,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  onTap: () {
                    setState(() {
                      _category = cat.label;
                      _typeCtrl.text = cat.label;
                      _showCategorySuggestions = false;
                    });
                    FocusScope.of(context).unfocus();
                  },
                );
              },
            ),
          ),
        ),
      ],

      const SizedBox(height: 16),

      // ── Amount ─────────────────────────────────────────────────────────────
      FieldLabel('Amount Spent *'),
      TextFormField(
        controller: _amtCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.jetBrainsMono(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.dangerColor(isDark)),
        decoration: InputDecoration(
          hintText: '0',
          prefixIcon: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
            child: Icon(Icons.currency_rupee_rounded,
                size: 20, color: AppColors.dangerColor(isDark)),
          ),
          prefixIconConstraints: const BoxConstraints(),
        ),
      ),

      const SizedBox(height: 16),

      // ── Select Person (staff) ──────────────────────────────────────────────
      FieldLabel('Select Person'),
      const SizedBox(height: 6),
      _StaffDropdown(
        staff: allStaff,
        selectedId: _selectedPersonId,
        isDark: isDark,
        primary: primary,
        onChanged: (id) => setState(() => _selectedPersonId = id),
      ),

      const SizedBox(height: 16),

      // ── Note (comment) ─────────────────────────────────────────────────────
      GestureDetector(
        onTap: () {
          showMrSheet(
            context,
            title: '💬 Add Comment',
            builder: (ctx) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                      hintText: 'Vendor, reference, bill number...'),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Comment',
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2Dark : const Color(0xFFF5F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark
                    ? AppColors.separatorDark
                    : const Color(0xFFBDD5F8)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                _noteCtrl.text.isNotEmpty
                    ? _noteCtrl.text
                    : 'Comment (optional)',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _noteCtrl.text.isNotEmpty
                        ? (isDark ? Colors.white : Colors.black87)
                        : AppColors.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: primary, size: 20),
          ]),
        ),
      ),

      const SizedBox(height: 24),

      // ── Submit ─────────────────────────────────────────────────────────────
      GradientButton(
        label: 'Submit',
        onTap: _submit,
      ),

      const SizedBox(height: 8),
    ]);
  }

  void _submit() {
    final typeText = _typeCtrl.text.trim();
    if (typeText.isEmpty) {
      showToast(context, 'Please enter or select expense type', error: true);
      return;
    }
    final val = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (val <= 0) {
      showToast(context, 'Enter a valid amount', error: true);
      return;
    }

    // Use typed text as category; if it matches a preset, use that label
    final categoryLabel = _category ?? typeText;

    // Resolve who recorded this expense
    final sessionUser = ref.read(sessionUserProvider);
    // personId intentionally not stored — personName is used directly below
    final personName  = _selectedPersonId != null
        ? ref
            .read(staffProvider)
            .firstWhere((s) => s.id == _selectedPersonId,
                orElse: () => const StaffMember(
                    id: 'admin', name: 'Admin', phone: '', pin: ''))
            .name
        : (sessionUser?.name ?? 'Admin');

    final tx = JarTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: 'EXPENSE',
      customerName: categoryLabel,
      date: DateFormat('yyyy-MM-dd').format(_date),
      createdAt: DateTime.now().toIso8601String(),
      billedAmount: 0,
      amountCollected: 0,
      damageCharge: val,
      paymentMode: _mode,
      note: '[$categoryLabel] ${_noteCtrl.text}'.trim(),
      createdBy: personName,
    );

    ref.read(transactionsProvider.notifier).add(tx);
    // If used inside the tab (onSaved provided), switch to History tab.
    // If opened from a sheet (no onSaved), just pop the sheet.
    if (widget.onSaved != null) {
      // Reset form
      setState(() {
        _category = null;
        _typeCtrl.clear();
        _amtCtrl.clear();
        _noteCtrl.clear();
        _mode = 'cash';
        _date = widget.defaultDate ?? DateTime.now();
        _selectedPersonId = null;
        _showCategorySuggestions = false;
      });
      widget.onSaved!();
    } else {
      Navigator.pop(context);
    }
    showToast(context, '✅ Expense recorded', success: true);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STAFF DROPDOWN — inline dropdown widget for Select Person field
// ══════════════════════════════════════════════════════════════════════════════
class _StaffDropdown extends StatelessWidget {
  final List<StaffMember> staff;
  final String? selectedId;
  final bool isDark;
  final Color primary;
  final ValueChanged<String?> onChanged;

  const _StaffDropdown({
    required this.staff,
    required this.selectedId,
    required this.isDark,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedName = selectedId != null
        ? staff
            .firstWhere((s) => s.id == selectedId,
                orElse: () =>
                    const StaffMember(id: '', name: '', phone: '', pin: ''))
            .name
        : null;

    return GestureDetector(
      onTap: () {
        showMrSheet(
          context,
          title: '👤 Select Person',
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...staff.map((s) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primary.withValues(alpha: 0.12),
                      child: Text(
                        s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, color: primary),
                      ),
                    ),
                    title: Text(s.name,
                        style: GoogleFonts.inter(
                            fontWeight: selectedId == s.id
                                ? FontWeight.w700
                                : FontWeight.w400)),
                    trailing: selectedId == s.id
                        ? Icon(Icons.check_circle_rounded, color: primary)
                        : null,
                    onTap: () {
                      onChanged(s.id);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2Dark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        child: Row(children: [
          Icon(Icons.person_rounded,
              size: 20,
              color: selectedName != null ? primary : AppColors.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedName ?? '',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selectedName != null
                      ? (isDark ? Colors.white : Colors.black87)
                      : AppColors.inkMuted),
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.inkMuted),
        ]),
      ),
    );
  }
}
