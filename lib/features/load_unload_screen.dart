// ════════════════════════════════════════════════════════════════════════════
// load_unload_screen.dart  — Daily jar load/unload tracking
// Simple cumulative model: one DayLog per day, additive entries.
// Wire diagram shows totals. History tab shows past days.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';

// ════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ════════════════════════════════════════════════════════════════════════════
class LoadUnloadScreen extends ConsumerStatefulWidget {
  const LoadUnloadScreen({super.key});
  @override
  ConsumerState<LoadUnloadScreen> createState() => _LoadUnloadScreenState();
}

class _LoadUnloadScreenState extends ConsumerState<LoadUnloadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final logs    = ref.watch(dayLogProvider);
    final today   = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log     = logs.firstWhere((d) => d.date == today,
        orElse: () => DayLog(date: today));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        _ScreenHeader(log: log, isDark: isDark, primary: primary),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface2Dark : AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
            ),
            child: TabBar(
              controller: _tab,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
              labelColor: primary,
              unselectedLabelColor: AppColors.inkMuted,
              indicator: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [Tab(text: '📅 Today'), Tab(text: '📋 Logbook')],
            ),
          ),
        ),
        Expanded(child: TabBarView(controller: _tab, children: [
          _TodayTab(log: log, isDark: isDark, primary: primary),
          _HistoryTab(
              logs: logs.where((d) => d.date != today).toList(),
              isDark: isDark, primary: primary),
        ])),
      ]),
      bottomNavigationBar: _tab.index == 0
          ? _BottomBar(log: log, isDark: isDark, primary: primary)
          : null,
    );
  }
}

// ── Screen header ─────────────────────────────────────────────────────────────
class _ScreenHeader extends StatelessWidget {
  final DayLog log;
  final bool isDark;
  final Color primary;
  const _ScreenHeader({required this.log, required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEE, dd MMM yyyy').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Load / Unload', style: Theme.of(context).textTheme.headlineLarge),
          Text(today, style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
        ])),
        GestureDetector(
          onTap: () => showMrSheet(context, title: "✏️ Edit Today's Totals",
              builder: (_) => _EditTotalsForm(log: log)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface2Dark : AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.edit_rounded, size: 14, color: AppColors.inkMuted),
              const SizedBox(width: 5),
              Text('Edit', style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TODAY TAB
// ════════════════════════════════════════════════════════════════════════════
class _TodayTab extends ConsumerWidget {
  final DayLog log;
  final bool isDark;
  final Color primary;
  const _TodayTab({required this.log, required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coolC   = AppColors.coolColor(isDark);
    final petC    = AppColors.petColor(isDark);
    final allTx   = ref.watch(transactionsProvider);
    final todayTx = allTx.where((t) => t.date == log.date).toList();

    // Auto-computed from transaction records
    final txCoolDelivered = todayTx.fold(0, (s, t) => s + t.coolDelivered);
    final txPetDelivered  = todayTx.fold(0, (s, t) => s + t.petDelivered);
    final txCoolEmpty     = todayTx.fold(0, (s, t) => s + t.coolReturned);
    final txPetEmpty      = todayTx.fold(0, (s, t) => s + t.petReturned);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        // ── Flow simulation diagram (only — cards removed per requirement) ──
        _FlowDiagram(
          log: log,
          txCoolDelivered: txCoolDelivered,
          txPetDelivered: txPetDelivered,
          txCoolEmpty: txCoolEmpty,
          txPetEmpty: txPetEmpty,
          isDark: isDark,
          coolC: coolC,
          petC: petC,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FLOW SIMULATION  — matches the screenshot layout exactly:
//
//   [Truck →]   [Total Loaded]  →  [Delivered]  →  [Filled Returned]
//                                                          ↓
//   [Truck ←]  [Actual Unloaded] ← [Calculated]  ←  [Empty Collected]
//
// Each cell shows: label on top, big bold number, formula hint below.
// ════════════════════════════════════════════════════════════════════════════
class _FlowDiagram extends StatelessWidget {
  final DayLog log;
  final int txCoolDelivered, txPetDelivered, txCoolEmpty, txPetEmpty;
  final bool isDark;
  final Color coolC, petC;
  const _FlowDiagram({
    required this.log,
    required this.txCoolDelivered, required this.txPetDelivered,
    required this.txCoolEmpty, required this.txPetEmpty,
    required this.isDark, required this.coolC, required this.petC,
  });

  @override
  Widget build(BuildContext context) {
    final okC     = AppColors.successColor(isDark);
    final warnC   = AppColors.warningColor(isDark);
    final dangerC = AppColors.dangerColor(isDark);
    final bg      = isDark ? AppColors.cardDark : Colors.white;
    const textDim = AppColors.inkMuted;

    // ── Computed values ──────────────────────────────────────────────────────
    final loaded    = log.coolLoaded + log.petLoaded;
    final delivered = txCoolDelivered + txPetDelivered;

    // filledBack = filled jars manually entered by driver (Unload form, DayLog)
    // These are full jars brought back — NOT delivered to any customer
    final filledBack = log.coolFilledReturned + log.petFilledReturned;

    // txEmptyBack = empty jars collected from customers per delivery tx records (auto)
    final txEmptyBack = txCoolEmpty + txPetEmpty;

    // emptyBack = empty jars physically unloaded from vehicle (DayLog, driver entry)
    final emptyBack = log.coolEmptyReturned + log.petEmptyReturned;

    // Returned Filled = manual entry from DayLog (driver records filled-back jars)
    // NOT derived from loaded - delivered (that was wrong)
    final returnedFilled = filledBack;

    // Calculated Unload = jars that SHOULD come back as empties:
    //   loaded - filledBack (those came back full, not as empties)
    //         - delivered   (those went to customers as full jars)
    //         + txEmptyBack (empties already collected from customers via deliveries)
    // Simplifies to: (loaded - filledBack - delivered) + txEmptyBack
    final calcUnload = (loaded - filledBack - delivered) + txEmptyBack;

    // Actual Unload = empty jars physically returned on vehicle (driver's manual count)
    final actualUnload = emptyBack;

    // Balance: what driver actually brought back should match what was calculated
    final balanced = actualUnload == calcUnload;
    final diff     = actualUnload - calcUnload;

    // ── Arrow color ──────────────────────────────────────────────────────────
    final arrowC = isDark
        ? const Color(0xFF4A90D9)
        : const Color(0xFF1A6BFF);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.07),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Column(children: [

        // ── Header ────────────────────────────────────────────────────────────
        Row(children: [
          Text('JAR FLOW SIMULATION',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800,
                  color: textDim, letterSpacing: 0.8)),
          const Spacer(),
          _StatusPill(
            label: balanced ? 'BALANCED ✓' : (diff > 0 ? 'SURPLUS +$diff' : 'SHORT ${diff.abs()}'),
            color: balanced ? okC : dangerC,
          ),
        ]),
        const SizedBox(height: 16),

        // ════════════════════════════════════════════════════════════════════
        // TOP ROW: truck → | Loaded | → | Delivered | → | Filled Returned |
        // ════════════════════════════════════════════════════════════════════
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

            // Truck icon (going right / loading)
            _TruckIcon(goingRight: true, color: warnC),
            const SizedBox(width: 6),

            // [1] Total Product Loaded
            _SimCell(
              label: 'Total Product\nLoaded',
              value: loaded,
              subLabel: '${log.coolLoaded}C + ${log.petLoaded}P',
              color: warnC,
              isDark: isDark,
            ),

            // →
            _HArrow(right: true, color: arrowC),

            // [2] Delivered Product
            _SimCell(
              label: 'Delivered\nProduct',
              value: delivered,
              subLabel: '${txCoolDelivered}C + ${txPetDelivered}P',
              color: okC,
              isDark: isDark,
            ),

            // →
            _HArrow(right: true, color: arrowC),

            // [3] Returned Filled Product — MANUAL entry from driver (DayLog)
            _SimCell(
              label: 'Returned\nFilled Product',
              value: returnedFilled,
              subLabel: '${log.coolFilledReturned}C + ${log.petFilledReturned}P',
              subIsFormula: false,
              color: coolC,
              isDark: isDark,
            ),
          ]),
        ),

        // ── Vertical down-arrow on right (between rows) ────────────────────
        Row(children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                size: 22, color: arrowC),
          ),
        ]),

        // ════════════════════════════════════════════════════════════════════
        // BOTTOM ROW: | Actual Unloaded | ← | Calculated | ← | Empty Coll. | ← truck
        // ════════════════════════════════════════════════════════════════════
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

            // Truck icon (going left / unloading)
            _TruckIcon(goingRight: false, color: petC),
            const SizedBox(width: 6),

            // [4] Actual Product Unloaded
            _SimCell(
              label: 'Actual\nProduct Unloaded',
              value: actualUnload,
              subLabel: '${log.coolEmptyReturned}C + ${log.petEmptyReturned}P',
              color: petC,
              isDark: isDark,
              highlightMismatch: !balanced,
              mismatchColor: dangerC,
            ),

            // ←
            _HArrow(right: false, color: arrowC),

            // [5] Calculated Product Unloaded — derived from tx + manual data
            _SimCell(
              label: 'Calculated\nProduct Unloaded',
              value: calcUnload,
              subLabel: '($loaded-$filledBack-$delivered+$txEmptyBack)',
              subIsFormula: true,
              color: isDark ? const Color(0xFF8892AB) : const Color(0xFF6C7A9C),
              isDark: isDark,
            ),

            // ←
            _HArrow(right: false, color: arrowC),

            // [6] Collected Empty Product (from customer delivery tx records)
            _SimCell(
              label: 'Collected\nEmpty Product',
              value: txEmptyBack,
              subLabel: '${txCoolEmpty}C + ${txPetEmpty}P',
              color: isDark ? const Color(0xFF5BB3D0) : const Color(0xFF0096C7),
              isDark: isDark,
            ),
          ]),
        ),

        // ── Balance note if mismatched ─────────────────────────────────────
        if (!balanced) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: dangerC.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dangerC.withValues(alpha: 0.22)),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: dangerC),
              const SizedBox(width: 8),
              Expanded(child: Text(
                diff > 0
                    ? 'Actual unloaded is $diff more than calculated. Please verify.'
                    : 'Actual unloaded is ${diff.abs()} less than calculated. Please verify.',
                style: GoogleFonts.inter(
                    fontSize: 11, color: dangerC, fontWeight: FontWeight.w500),
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Simulation cell ────────────────────────────────────────────────────────────
class _SimCell extends StatelessWidget {
  final String label;
  final int value;
  final String subLabel;
  final bool subIsFormula;
  final Color color;
  final bool isDark;
  final bool highlightMismatch;
  final Color? mismatchColor;

  const _SimCell({
    required this.label,
    required this.value,
    required this.subLabel,
    this.subIsFormula = false,
    required this.color,
    required this.isDark,
    this.highlightMismatch = false,
    this.mismatchColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = highlightMismatch ? (mismatchColor ?? color) : color;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Label
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
                height: 1.3,
              )),
          const SizedBox(height: 6),
          // Big number
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$value',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: effectiveColor,
                  height: 1.0,
                )),
          ),
          const SizedBox(height: 4),
          // Sub-label (formula or breakdown)
          Text(subLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: subIsFormula
                    ? AppColors.inkMuted.withValues(alpha: 0.7)
                    : color.withValues(alpha: 0.75),
                fontWeight: subIsFormula ? FontWeight.w400 : FontWeight.w600,
                fontStyle: subIsFormula ? FontStyle.italic : FontStyle.normal,
              )),
        ],
      ),
    );
  }
}

// ── Horizontal arrow ───────────────────────────────────────────────────────────
class _HArrow extends StatelessWidget {
  final bool right;
  final Color color;
  const _HArrow({required this.right, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Icon(
      right ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
      size: 18,
      color: color.withValues(alpha: 0.6),
    ),
  );
}

// ── Truck icon (loading / unloading direction) ─────────────────────────────────
class _TruckIcon extends StatelessWidget {
  final bool goingRight;
  final Color color;
  const _TruckIcon({required this.goingRight, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: goingRight ? 1.0 : -1.0,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(Icons.local_shipping_rounded, size: 20, color: color),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
// BOTTOM ACTION BAR  — Load & Unload buttons side by side
// ════════════════════════════════════════════════════════════════════════════
class _BottomBar extends ConsumerWidget {
  final DayLog log;
  final bool isDark;
  final Color primary;
  const _BottomBar({required this.log, required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final warnC = AppColors.warningColor(isDark);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + safeBottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 16, offset: const Offset(0, -4),
        )],
      ),
      child: Row(children: [
        // Load button
        Expanded(child: GestureDetector(
          onTap: () => showMrSheet(context,
              title: '📤 Load Jars',
              builder: (_) => _LoadForm(log: log)),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [warnC.withValues(alpha: 0.85), warnC],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.upload_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text('Load', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        )),
        const SizedBox(width: 12),
        // Unload button
        Expanded(child: GestureDetector(
          onTap: () => showMrSheet(context,
              title: '📥 Unload Jars',
              builder: (_) => _UnloadForm(log: log)),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary.withValues(alpha: 0.85), primary],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.download_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text('Unload', style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOAD FORM  — enter jars being loaded onto vehicle (additive)
// ════════════════════════════════════════════════════════════════════════════
class _LoadForm extends ConsumerStatefulWidget {
  final DayLog log;
  const _LoadForm({required this.log});
  @override
  ConsumerState<_LoadForm> createState() => _LoadFormState();
}

class _LoadFormState extends ConsumerState<_LoadForm> {
  int _cl = 0, _pl = 0;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final coolC   = AppColors.coolColor(isDark);
    final petC    = AppColors.petColor(isDark);
    final warnC   = AppColors.warningColor(isDark);
    final hasAny  = _cl > 0 || _pl > 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Context banner — shows current loaded total
      Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: warnC.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: warnC.withValues(alpha: 0.22)),
        ),
        child: Row(children: [
          Icon(Icons.warehouse_rounded, size: 16, color: warnC),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Currently loaded today',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
            Text('${widget.log.coolLoaded}C  ${widget.log.petLoaded}P',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 14, fontWeight: FontWeight.w800, color: warnC)),
          ])),
          Icon(Icons.add_circle_outline_rounded, size: 16, color: warnC),
          const SizedBox(width: 4),
          Text('Adding more', style: GoogleFonts.inter(fontSize: 10, color: warnC,
              fontWeight: FontWeight.w600)),
        ]),
      ),

      _fieldGroup('Enter Jars Being Loaded',
          'New jars being put onto the vehicle now', warnC, isDark),
      const SizedBox(height: 14),

      Row(children: [
        Expanded(child: _NumEntry(label: 'Cool', color: coolC, isDark: isDark,
            value: _cl, onChanged: (v) => setState(() => _cl = v))),
        const SizedBox(width: 12),
        Expanded(child: _NumEntry(label: 'PET', color: petC, isDark: isDark,
            value: _pl, onChanged: (v) => setState(() => _pl = v))),
      ]),
      const SizedBox(height: 24),

      GradientButton(
        label: _saving ? 'Saving...' : '📤  Submit Load',
        loading: _saving,
        onTap: (hasAny && !_saving) ? () async {
          setState(() => _saving = true);
          try {
            // Additive: add to existing loaded totals
            await ref.read(dayLogProvider.notifier).setExact(
              coolLoaded:  widget.log.coolLoaded  + _cl,
              petLoaded:   widget.log.petLoaded   + _pl,
              coolEmpty:   widget.log.coolEmptyReturned,
              petEmpty:    widget.log.petEmptyReturned,
              coolFilled:  widget.log.coolFilledReturned,
              petFilled:   widget.log.petFilledReturned,
            );
            if (context.mounted) {
              Navigator.pop(context);
              showToast(context, '✅ ${_cl}C + ${_pl}P loaded', success: true);
            }
          } catch (e) {
            if (context.mounted) {
              showToast(context, '❌ Save failed: ${e.toString().replaceAll('StateError: ', '')}', success: false);
            }
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        } : null,
        gradient: hasAny
            ? LinearGradient(colors: [warnC.withValues(alpha: 0.85), warnC])
            : LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400]),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// UNLOAD FORM  — enter jars being returned from vehicle (additive)
//   Empty Returned  = empty jars physically collected back from customers
//   Filled Returned = full jars brought back (not delivered / rejected)
// ════════════════════════════════════════════════════════════════════════════
class _UnloadForm extends ConsumerStatefulWidget {
  final DayLog log;
  const _UnloadForm({required this.log});
  @override
  ConsumerState<_UnloadForm> createState() => _UnloadFormState();
}

class _UnloadFormState extends ConsumerState<_UnloadForm> {
  int _ce = 0, _pe = 0;   // empty returned
  int _cf = 0, _pf = 0;   // filled returned (not delivered)
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final coolC   = AppColors.coolColor(isDark);
    final petC    = AppColors.petColor(isDark);
    final primary = Theme.of(context).colorScheme.primary;
    final okC     = AppColors.successColor(isDark);
    final hasAny  = _ce > 0 || _pe > 0 || _cf > 0 || _pf > 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Context banner — shows current unload totals
      Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.22)),
        ),
        child: Row(children: [
          Icon(Icons.local_shipping_rounded, size: 16, color: primary),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Returned today so far',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
            Text('Empty: ${widget.log.coolEmptyReturned}C ${widget.log.petEmptyReturned}P  '
                'Filled: ${widget.log.coolFilledReturned}C ${widget.log.petFilledReturned}P',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                    color: primary)),
          ])),
        ]),
      ),

      // ── Section 1: Empty Returned ──────────────────────────────────────────
      _fieldGroup('📦  Empty Jars Collected',
          'Empty jars physically brought back from customers', AppColors.inkMuted, isDark),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _NumEntry(label: 'Cool', color: coolC, isDark: isDark,
            value: _ce, onChanged: (v) => setState(() => _ce = v))),
        const SizedBox(width: 12),
        Expanded(child: _NumEntry(label: 'PET', color: petC, isDark: isDark,
            value: _pe, onChanged: (v) => setState(() => _pe = v))),
      ]),
      const SizedBox(height: 22),

      // ── Section 2: Filled Returned (not delivered) ─────────────────────────
      _fieldGroup('🔵  Filled Jars Returned',
          'Full jars brought back — not delivered to any customer', okC, isDark),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _NumEntry(label: 'Cool', color: coolC, isDark: isDark,
            value: _cf, onChanged: (v) => setState(() => _cf = v))),
        const SizedBox(width: 12),
        Expanded(child: _NumEntry(label: 'PET', color: petC, isDark: isDark,
            value: _pf, onChanged: (v) => setState(() => _pf = v))),
      ]),
      const SizedBox(height: 24),

      GradientButton(
        label: _saving ? 'Saving...' : '📥  Submit Unload',
        loading: _saving,
        onTap: (hasAny && !_saving) ? () async {
          setState(() => _saving = true);
          try {
            // Additive: add to existing return totals
            await ref.read(dayLogProvider.notifier).setExact(
              coolLoaded:  widget.log.coolLoaded,
              petLoaded:   widget.log.petLoaded,
              coolEmpty:   widget.log.coolEmptyReturned  + _ce,
              petEmpty:    widget.log.petEmptyReturned   + _pe,
              coolFilled:  widget.log.coolFilledReturned + _cf,
              petFilled:   widget.log.petFilledReturned  + _pf,
            );
            if (context.mounted) {
              Navigator.pop(context);
              showToast(context,
                  '✅ ${_ce + _pe} empty  ${_cf + _pf} filled returned', success: true);
            }
          } catch (e) {
            if (context.mounted) {
              showToast(context, '❌ Save failed: ${e.toString().replaceAll('StateError: ', '')}', success: false);
            }
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        } : null,
        gradient: hasAny
            ? AppColors.primaryGradient
            : LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400]),
      ),
    ]);
  }
}


// ════════════════════════════════════════════════════════════════════════════
// EDIT TOTALS FORM — owner direct override
// ════════════════════════════════════════════════════════════════════════════
class _EditTotalsForm extends ConsumerStatefulWidget {
  final DayLog log;
  const _EditTotalsForm({required this.log});
  @override
  ConsumerState<_EditTotalsForm> createState() => _EditTotalsFormState();
}
class _EditTotalsFormState extends ConsumerState<_EditTotalsForm> {
  late int _cl, _pl, _ce, _pe, _cf, _pf;
  String _note = '';
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _cl = widget.log.coolLoaded;     _pl = widget.log.petLoaded;
    _ce = widget.log.coolEmptyReturned; _pe = widget.log.petEmptyReturned;
    _cf = widget.log.coolFilledReturned; _pf = widget.log.petFilledReturned;
    _note = widget.log.note ?? '';
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coolC  = AppColors.coolColor(isDark);
    final petC   = AppColors.petColor(isDark);
    final warnC  = AppColors.warningColor(isDark);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: warnC.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: warnC.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(Icons.warning_rounded, size: 14, color: warnC),
          const SizedBox(width: 8),
          Expanded(child: Text('Owner edit — sets exact values. Use to fix mistakes only.',
              style: GoogleFonts.inter(fontSize: 12, color: warnC, height: 1.4))),
        ]),
      ),
      Text('📤  Loaded', style: GoogleFonts.inter(fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.inkDark : AppColors.ink)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _NumEntry(label: 'Cool', color: coolC, isDark: isDark,
            value: _cl, onChanged: (v) => setState(() => _cl = v))),
        const SizedBox(width: 12),
        Expanded(child: _NumEntry(label: 'PET', color: petC, isDark: isDark,
            value: _pl, onChanged: (v) => setState(() => _pl = v))),
      ]),
      const SizedBox(height: 14),
      Text('📦  Empty Returned', style: GoogleFonts.inter(fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.inkDark : AppColors.ink)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _NumEntry(label: 'Cool', color: coolC, isDark: isDark,
            value: _ce, onChanged: (v) => setState(() => _ce = v))),
        const SizedBox(width: 12),
        Expanded(child: _NumEntry(label: 'PET', color: petC, isDark: isDark,
            value: _pe, onChanged: (v) => setState(() => _pe = v))),
      ]),
      const SizedBox(height: 14),
      Text('🔵  Filled Returned', style: GoogleFonts.inter(fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.inkDark : AppColors.ink)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _NumEntry(label: 'Cool', color: coolC, isDark: isDark,
            value: _cf, onChanged: (v) => setState(() => _cf = v))),
        const SizedBox(width: 12),
        Expanded(child: _NumEntry(label: 'PET', color: petC, isDark: isDark,
            value: _pf, onChanged: (v) => setState(() => _pf = v))),
      ]),
      const SizedBox(height: 14),
      TextFormField(
        initialValue: _note,
        decoration: InputDecoration(
          labelText: 'Reason for edit',
          hintText: 'e.g. corrected miscounted jars',
          labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted),
          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted),
        ),
        onChanged: (v) => _note = v,
      ),
      const SizedBox(height: 24),
      GradientButton(
        label: _saving ? 'Saving...' : '✏️ Save Correction',
        onTap: !_saving ? () async {
          setState(() => _saving = true);
          try {
            await ref.read(dayLogProvider.notifier).setExact(
              coolLoaded: _cl, petLoaded: _pl,
              coolEmpty: _ce, petEmpty: _pe,
              coolFilled: _cf, petFilled: _pf,
              note: _note.trim().isEmpty ? null : _note.trim(),
            );
            if (context.mounted) {
              Navigator.pop(context);
              showToast(context, '✅ Totals corrected', success: true);
            }
          } catch (e) {
            if (context.mounted) {
              showToast(context, '❌ Save failed: ${e.toString().replaceAll('StateError: ', '')}', success: false);
            }
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        } : null,
      ),
    ]);
  }
}

// ── Shared form widgets ───────────────────────────────────────────────────────
// _NumEntry — editable jar counter:
//   • Tap [ - ] / [ + ] to decrement / increment by 1
//   • Long-press OR tap the number itself to type any value directly
class _NumEntry extends StatefulWidget {
  final String label;
  final Color color;
  final bool isDark;
  final int value;
  final ValueChanged<int> onChanged;
  const _NumEntry({required this.label, required this.color,
      required this.isDark, required this.value, required this.onChanged});

  @override
  State<_NumEntry> createState() => _NumEntryState();
}

class _NumEntryState extends State<_NumEntry> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_NumEntry old) {
    super.didUpdateWidget(old);
    // Keep display in sync when parent rebuilds (but don't fight active editor)
    if (!_editing && old.value != widget.value) {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _ctrl.text = '${widget.value}';
      _ctrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    });
  }

  void _commitEdit() {
    final parsed = int.tryParse(_ctrl.text.trim()) ?? widget.value;
    final clamped = parsed < 0 ? 0 : parsed;
    setState(() => _editing = false);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final color  = widget.color;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _editing ? color : color.withValues(alpha: 0.22),
          width: _editing ? 1.8 : 1.0,
        ),
      ),
      child: Column(children: [
        Text(widget.label, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [

          // ── [ - ] button ────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.value > 0
                ? () {
                    if (_editing) _commitEdit();
                    widget.onChanged(widget.value - 1);
                  }
                : null,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: widget.value > 0
                    ? color.withValues(alpha: 0.14)
                    : color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.remove_rounded, size: 18,
                  color: widget.value > 0
                      ? color
                      : color.withValues(alpha: 0.30)),
            ),
          ),

          const SizedBox(width: 10),

          // ── Editable value area ──────────────────────────────────────────
          // Tap to activate inline text field; otherwise shows bold number.
          GestureDetector(
            onTap: _startEditing,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 52,
              height: 36,
              decoration: BoxDecoration(
                color: _editing
                    ? color.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _editing
                  ? Center(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: color),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _commitEdit(),
                        onTapOutside: (_) => _commitEdit(),
                      ),
                    )
                  : Center(
                      child: Text(
                        '${widget.value}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: color),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 10),

          // ── [ + ] button ────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              if (_editing) _commitEdit();
              widget.onChanged(widget.value + 1);
            },
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_rounded, size: 18, color: color),
            ),
          ),
        ]),

        // Hint shown only while editing
        if (_editing)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('Tap ✓ or press Enter',
                style: GoogleFonts.inter(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.65),
                    fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }
}

// ignore: unused_element
class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool isDark;
  const _InfoRow(this.label, this.value, this.isDark);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
      const SizedBox(width: 8),
      Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
          color: isDark ? AppColors.inkDark : AppColors.ink)),
    ]),
  );
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

Widget _fieldGroup(String title, String subtitle, Color color, bool isDark) =>
  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800,
        color: isDark ? AppColors.inkDark : AppColors.ink)),
    const SizedBox(height: 2),
    Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
  ]);

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 160),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w800, color: color),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}


class _HistoryTab extends StatelessWidget {
  final List<DayLog> logs;
  final bool isDark;
  final Color primary;
  const _HistoryTab({required this.logs, required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history_rounded, size: 48,
            color: AppColors.inkMuted.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text('No entries yet', style: GoogleFonts.inter(fontSize: 15, color: AppColors.inkMuted)),
        const SizedBox(height: 4),
        Text('Past day logs will appear here',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: logs.length,
      itemBuilder: (_, i) => _HistoryCard(log: logs[i], isDark: isDark),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final DayLog log;
  final bool isDark;
  const _HistoryCard({required this.log, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final coolC = AppColors.coolColor(isDark);
    final petC  = AppColors.petColor(isDark);
    final okC   = AppColors.successColor(isDark);
    String fmt;
    try { fmt = DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(log.date)); }
    catch (_) { fmt = log.date; }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.inkMuted),
          const SizedBox(width: 6),
          Text(fmt, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
              color: isDark ? AppColors.inkDark : AppColors.ink)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _HC('Loaded',
              '${log.coolLoaded}C + ${log.petLoaded}P', coolC)),
          Expanded(child: _HC('Empty Ret.',
              '${log.coolEmptyReturned}C + ${log.petEmptyReturned}P', AppColors.inkMuted)),
          Expanded(child: _HC('Filled Ret.',
              '${log.coolFilledReturned}C + ${log.petFilledReturned}P', okC)),
          Expanded(child: _HC('Net Del.',
              '${log.coolNetDelivered}C + ${log.petNetDelivered}P', petC)),
        ]),
        if (log.note != null && log.note!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(log.note!, style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.inkMuted, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _HC extends StatelessWidget {
  final String l, v;
  final Color c;
  const _HC(this.l, this.v, this.c);
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: GoogleFonts.inter(fontSize: 9, color: AppColors.inkMuted,
        fontWeight: FontWeight.w600)),
    const SizedBox(height: 2),
    Text(v, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
  ]);
}
