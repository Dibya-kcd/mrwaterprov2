import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv      = ref.watch(inventoryProvider);
    final custs    = ref.watch(customersProvider);
    final settings = ref.watch(settingsProvider);
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    final alerts = <_AlertItem>[];

    if (inv.coolStock < settings.lowStockThreshold) {
      alerts.add(_AlertItem(
        icon: Icons.warning_amber_rounded,
        title: 'Low Cool Stock',
        body: 'Only ${inv.coolStock} jars left · Threshold: ${settings.lowStockThreshold}',
        color: AppColors.dangerColor(isDark),
        tag: 'stock',
      ));
    }
    if (inv.petStock < settings.lowStockThreshold) {
      alerts.add(_AlertItem(
        icon: Icons.warning_amber_rounded,
        title: 'Low PET Stock',
        body: 'Only ${inv.petStock} jars remaining',
        color: AppColors.warningColor(isDark),
        tag: 'stock',
      ));
    }
    for (final c in custs.where((c) => c.hasJarsOut)) {
      alerts.add(_AlertItem(
        icon: Icons.inventory_2_rounded,
        title: 'Jars with ${c.name}',
        body: '${c.coolOut} Cool + ${c.petOut} PET outstanding',
        color: AppColors.coolColor(isDark),
        tag: 'jars',
      ));
    }
    for (final c in custs.where((c) => c.hasDues)) {
      alerts.add(_AlertItem(
        icon: Icons.payments_rounded,
        title: 'Due — ${c.name}',
        body: '₹${c.ledgerBalance.abs().toInt()} outstanding',
        color: AppColors.dangerColor(isDark),
        tag: 'payment',
      ));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Screen header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Alerts', style: Theme.of(context).textTheme.headlineLarge),
              Text('${alerts.length} notification${alerts.length == 1 ? '' : 's'}',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkMuted)),
            ])),
            if (alerts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.dangerColor(isDark).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${alerts.length} active',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.dangerColor(isDark)),
                ),
              ),
          ]),
        ),

        Expanded(
          child: alerts.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 72, height: 72,
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
                      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkMuted)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: alerts.length,
                  itemBuilder: (_, i) => _AlertCard(item: alerts[i], isDark: isDark),
                ),
        ),
      ]),
    );
  }
}

class _AlertItem {
  final IconData icon;
  final String title, body, tag;
  final Color color;
  const _AlertItem({required this.icon, required this.title, required this.body,
      required this.color, required this.tag});
}

class _AlertCard extends StatelessWidget {
  final _AlertItem item;
  final bool isDark;
  const _AlertCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: item.color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: item.color.withValues(alpha: 0.18)),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icon, color: item.color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.title,
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text(item.body,
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.inkMuted, height: 1.4)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(item.tag,
            style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: item.color)),
      ),
    ]),
  );
}
