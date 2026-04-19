// ════════════════════════════════════════════════════════════════════════════
// notifications_screen.dart
// FIX v2:
//   • Every alert card is now tappable and deep-links to the relevant screen.
//     - Low stock  → Inventory tab (auto-opens Stock IN sheet)
//     - Jars out   → Customer's ledger screen
//     - Due payment → Payments tab filtered to that customer
//   • Added selectedNotifCustomerProvider so PaymentsScreen can auto-scroll
//     to the tapped customer.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/shared_widgets.dart';
import 'main_scaffold.dart' show kTabInventory, kTabPayments;
import 'ledger_screen.dart';

// Provider to pass a pre-selected customer ID to PaymentsScreen
final selectedNotifCustomerProvider = StateProvider<String?>((ref) => null);

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(inventoryProvider);
    final custs = ref.watch(customersProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final alerts = <_AlertItem>[];

    if (inv.coolStock < settings.lowStockThreshold) {
      alerts.add(_AlertItem(
        icon: Icons.warning_amber_rounded,
        title: 'Low Cool Stock',
        body: 'Only ${inv.coolStock} jars left · Threshold: ${settings.lowStockThreshold}',
        color: AppColors.dangerColor(isDark),
        tag: 'stock',
        actionLabel: 'Stock IN',
        onTap: () {
          ref.read(tabProvider.notifier).state = kTabInventory;
          // Small delay so IndexedStack renders InventoryScreen before sheet opens
          Future.delayed(const Duration(milliseconds: 200), () {
            if (context.mounted) {
              showMrSheet(context,
                  title: '📥 Stock IN — Receive Jars',
                  builder: (_) => const _QuickStockInForm(type: 'cool'));
            }
          });
        },
      ));
    }

    if (inv.petStock < settings.lowStockThreshold) {
      alerts.add(_AlertItem(
        icon: Icons.warning_amber_rounded,
        title: 'Low PET Stock',
        body: 'Only ${inv.petStock} jars remaining',
        color: AppColors.warningColor(isDark),
        tag: 'stock',
        actionLabel: 'Stock IN',
        onTap: () {
          ref.read(tabProvider.notifier).state = kTabInventory;
          Future.delayed(const Duration(milliseconds: 200), () {
            if (context.mounted) {
              showMrSheet(context,
                  title: '📥 Stock IN — Receive Jars',
                  builder: (_) => const _QuickStockInForm(type: 'pet'));
            }
          });
        },
      ));
    }

    for (final c in custs.where((c) => c.hasJarsOut)) {
      alerts.add(_AlertItem(
        icon: Icons.inventory_2_rounded,
        title: 'Jars with ${c.name}',
        body: '${c.coolOut} Cool + ${c.petOut} PET outstanding',
        color: AppColors.coolColor(isDark),
        tag: 'jars',
        actionLabel: 'View Ledger',
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LedgerScreen(customerId: c.id),
          ));
        },
      ));
    }

    for (final c in custs.where((c) => c.hasDues)) {
      alerts.add(_AlertItem(
        icon: Icons.payments_rounded,
        title: 'Due — ${c.name}',
        body: '₹${c.ledgerBalance.abs().toInt()} outstanding',
        color: AppColors.dangerColor(isDark),
        tag: 'payment',
        actionLabel: 'Collect',
        onTap: () {
          // Deep-link to PaymentsScreen and pre-select this customer
          ref.read(selectedNotifCustomerProvider.notifier).state = c.id;
          ref.read(tabProvider.notifier).state = kTabPayments;
        },
      ));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Screen header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Alerts', style: Theme.of(context).textTheme.headlineLarge),
                Text(
                  '${alerts.length} notification${alerts.length == 1 ? '' : 's'}',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkMuted),
                ),
              ]),
            ),
            if (alerts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.dangerColor(isDark).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${alerts.length} active',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dangerColor(isDark)),
                ),
              ),
          ]),
        ),

        Expanded(
          child: alerts.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.successColor(isDark).withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_outline_rounded,
                          size: 36, color: AppColors.successColor(isDark)),
                    ),
                    const SizedBox(height: 16),
                    Text('All clear!',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text('No alerts right now',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, color: AppColors.inkMuted)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: alerts.length,
                  itemBuilder: (_, i) =>
                      _AlertCard(item: alerts[i], isDark: isDark),
                ),
        ),
      ]),
    );
  }
}

// ── Quick Stock-IN form (opened from notification tap) ─────────────────────
class _QuickStockInForm extends ConsumerStatefulWidget {
  final String type; // 'cool' or 'pet'
  const _QuickStockInForm({required this.type});

  @override
  ConsumerState<_QuickStockInForm> createState() => _QuickStockInFormState();
}

class _QuickStockInFormState extends ConsumerState<_QuickStockInForm> {
  final _ctrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCool = widget.type == 'cool';
    final c = isCool ? AppColors.coolColor(isDark) : AppColors.petColor(isDark);
    final label = isCool ? 'Cool Jars' : 'PET Jars';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('How many $label are arriving?',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
      const SizedBox(height: 12),
      TextFormField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '0',
          suffixText: 'jars IN',
          prefixIcon: Icon(Icons.add_box_rounded, color: c),
        ),
      ),
      const SizedBox(height: 20),
      GradientButton(
        label: '📥 Confirm Stock IN',
        onTap: () {
          final count = int.tryParse(_ctrl.text) ?? 0;
          if (count <= 0) {
            showToast(context, 'Enter a valid count');
            return;
          }
          if (isCool) {
            ref.read(inventoryProvider.notifier).addStock(count, 0);
          } else {
            ref.read(inventoryProvider.notifier).addStock(0, count);
          }
          Navigator.pop(context);
          showToast(context, '✅ $count $label added to stock', success: true);
        },
      ),
    ]);
  }
}

// ── Alert item model ──────────────────────────────────────────────────────────
class _AlertItem {
  final IconData icon;
  final String title, body, tag;
  final Color color;
  final String actionLabel;
  final VoidCallback onTap;

  const _AlertItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    required this.tag,
    required this.actionLabel,
    required this.onTap,
  });
}

// ── Alert card — now tappable ─────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final _AlertItem item;
  final bool isDark;
  const _AlertCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: item.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.color.withValues(alpha: 0.18)),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title,
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(item.body,
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                        height: 1.4)),
              ]),
            ),
            const SizedBox(width: 8),
            // FIX: actionable CTA chip showing what will happen on tap
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: item.color.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(item.actionLabel,
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: item.color)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 9, color: item.color),
              ]),
            ),
          ]),
        ),
      );
}
