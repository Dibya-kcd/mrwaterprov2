import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv    = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => ref.read(inventoryProvider.notifier).refresh(),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Text('Inventory', style: Theme.of(context).textTheme.headlineLarge),
          Text('Stock in your warehouse',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
          const SizedBox(height: 20),

          // ── Summary strip (3 KPIs) ───────────────────────────────────────────
          Row(children: [
            _SummaryKpi('Total Cool', '${inv.coolTotal}', AppColors.coolColor(isDark), isDark),
            const SizedBox(width: 8),
            _SummaryKpi('Total PET', '${inv.petTotal}', AppColors.petColor(isDark), isDark),
            const SizedBox(width: 8),
            _SummaryKpi('In Warehouse', '${inv.coolStock + inv.petStock}', primary, isDark),
          ]),
          const SizedBox(height: 20),

          // ── Cool jar card ────────────────────────────────────────────────────
          _StockCard(
            label: 'Cool Jars',
            stock: inv.coolStock,
            total: inv.coolTotal,
            color: AppColors.coolColor(isDark),
            icon: CoolJarIcon(size: 22, color: AppColors.coolColor(isDark)),
            isDark: isDark,
            onAdd:  () => _showStockSheet(context, ref, 'cool', 'add'),
            onLoss: () => _showStockSheet(context, ref, 'cool', 'loss'),
          ),
          const SizedBox(height: 16),

          // ── PET jar card ─────────────────────────────────────────────────────
          _StockCard(
            label: 'PET Jars',
            stock: inv.petStock,
            total: inv.petTotal,
            color: AppColors.petColor(isDark),
            icon: PetJarIcon(size: 22, color: AppColors.petColor(isDark)),
            isDark: isDark,
            onAdd:  () => _showStockSheet(context, ref, 'pet', 'add'),
            onLoss: () => _showStockSheet(context, ref, 'pet', 'loss'),
          ),
          const SizedBox(height: 24),
        ],
        ), // ListView
      ), // RefreshIndicator
    );
  }

  void _showStockSheet(BuildContext context, WidgetRef ref, String type, String action) {
    showMrSheet(
      context,
      title: action == 'add' ? '📥 Stock IN — Receive Jars' : '📤 Stock OUT — Record Loss',
      builder: (_) => _StockActionForm(type: type, action: action),
    );
  }
}

// ── Summary KPI - Modern Design ───────────────────────────────────────────────────────
class _SummaryKpi extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _SummaryKpi(this.label, this.value, this.color, this.isDark);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: isDark ? 0.12 : 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: isDark ? 0.25 : 0.15), width: 1),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(value, style: GoogleFonts.inter(fontSize: 24,
            fontWeight: FontWeight.w800, color: color))),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 11,
          fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
    ]),
  ));
}

// ── Stock card ────────────────────────────────────────────────────────────────
class _StockCard extends StatelessWidget {
  final String label;
  final int stock, total;
  final Color color;
  final Widget icon;
  final bool isDark;
  final VoidCallback onAdd, onLoss;

  const _StockCard({
    required this.label, required this.stock, required this.total,
    required this.color, required this.icon, required this.isDark,
    required this.onAdd, required this.onLoss,
  });

  @override
  Widget build(BuildContext context) {
    final pct    = total > 0 ? stock / total : 0.0;
    final out    = total - stock;
    final lowStk = pct < 0.20;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.separatorDark : AppColors.separator),
        boxShadow: [BoxShadow(
          color: color.withValues(alpha: isDark ? 0.08 : 0.06),
          blurRadius: 16, offset: const Offset(0, 4),
        )],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (lowStk ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark))
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              lowStk ? '⚠ LOW' : '✓ OK',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800,
                  color: lowStk ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark)),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Three stats in a row — no overflow possible
        Row(children: [
          Expanded(child: _stat('In Warehouse', '$stock', color)),
          Expanded(child: _stat('With Customers', '$out', AppColors.inkMuted)),
          Expanded(child: _stat('Total Owned', '$total', AppColors.inkMuted)),
        ]),
        const SizedBox(height: 14),

        // Progress bar
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Stock level',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
            const Spacer(),
            Text('${(pct * 100).round()}%',
                style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700,
                    color: color)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: isDark ? AppColors.surface2Dark : AppColors.surface2,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Action buttons — full width row
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onLoss,
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
            label: const Text('Stock OUT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dangerColor(isDark),
              side: BorderSide(color: AppColors.dangerColor(isDark).withValues(alpha: 0.35)),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: const Text('Stock IN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _stat(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: GoogleFonts.inter(fontSize: 10, color: AppColors.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 2),
    Text(v, style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w700, color: c)),
  ]);
}

// ── Stock action form ─────────────────────────────────────────────────────────
class _StockActionForm extends ConsumerStatefulWidget {
  final String type, action;
  const _StockActionForm({required this.type, required this.action});

  @override
  ConsumerState<_StockActionForm> createState() => _StockActionFormState();
}

class _StockActionFormState extends ConsumerState<_StockActionForm> {
  final _cool = TextEditingController(text: '0');
  final _pet  = TextEditingController(text: '0');

  @override
  void dispose() { _cool.dispose(); _pet.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isAdd  = widget.action == 'add';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c      = isAdd ? AppColors.successColor(isDark) : AppColors.dangerColor(isDark);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Banner
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.20)),
        ),
        child: Row(children: [
          Icon(isAdd ? Icons.move_to_inbox_rounded : Icons.output_rounded, color: c, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            isAdd
                ? 'These jars are arriving at your warehouse — stock will increase.'
                : 'These jars are being written off — stock will decrease permanently.',
            style: GoogleFonts.inter(fontSize: 12, color: c, height: 1.4),
          )),
        ]),
      ),
      const SizedBox(height: 20),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('Cool Jars'),
          TextFormField(
            controller: _cool,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '0',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: CoolJarIcon(size: 18, color: AppColors.coolColor(isDark)),
              ),
              suffixText: isAdd ? 'IN' : 'OUT',
            ),
          ),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('PET Jars'),
          TextFormField(
            controller: _pet,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '0',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: PetJarIcon(size: 18, color: AppColors.petColor(isDark)),
              ),
              suffixText: isAdd ? 'IN' : 'OUT',
            ),
          ),
        ])),
      ]),
      const SizedBox(height: 24),

      GradientButton(
        label: isAdd ? '📥 Confirm Stock IN' : '📤 Confirm Stock OUT',
        onTap: () {
          final cool = int.tryParse(_cool.text) ?? 0;
          final pet  = int.tryParse(_pet.text)  ?? 0;
          if (cool == 0 && pet == 0) {
            showToast(context, 'Enter at least one jar count'); return;
          }
          if (isAdd) {
            ref.read(inventoryProvider.notifier).addStock(cool, pet);
          } else {
            ref.read(inventoryProvider.notifier).recordLoss(cool, pet);
          }
          Navigator.pop(context);
          showToast(context, isAdd ? '✅ Stock IN recorded' : '✅ Stock OUT recorded', success: true);
        },
      ),
    ]);
  }
}

