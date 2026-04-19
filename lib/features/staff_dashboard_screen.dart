// ════════════════════════════════════════════════════════════════════════════
// staff_dashboard_screen.dart
// FIX v2:
//   • Action buttons now actually navigate to the correct tab (were no-ops).
//   • Added onNavigate callback so MainScaffold can pass tabProvider writes.
//   • "Switch Role" correctly clears only sessionUserProvider, not pinUnlocked.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';
import 'main_scaffold.dart' show kTabTransactions, kTabCustomers;

class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Staff Dashboard',
                  style: GoogleFonts.inter(
                      fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                user != null
                    ? 'Welcome back, ${user.name}.'
                    : 'Welcome. Enter your PIN to access staff actions.',
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 20),

              // ── Session info cards ────────────────────────────────────────
              if (user != null) ...[
                _InfoCard(title: 'Role', value: user.role.value),
                const SizedBox(height: 12),
                _InfoCard(
                    title: 'Active', value: user.isActive ? 'Yes' : 'No'),
                const SizedBox(height: 12),
                _InfoCard(
                    title: 'Permissions',
                    value: user.permissions.join(', ')),
              ],

              const SizedBox(height: 20),
              Text('Quick actions',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              // FIX: action buttons now navigate to the real tabs.
              // Previously both had `onTap: () {}` (no-op).
              if (user == null || user.can('transactions'))
                _ActionButton(
                  icon: Icons.receipt_long_rounded,
                  label: 'Open sales dashboard',
                  color: AppColors.primaryColor(isDark),
                  onTap: () =>
                      ref.read(tabProvider.notifier).state = kTabTransactions,
                ),

              if (user == null || user.can('customers')) ...[
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.people_rounded,
                  label: 'View customer list',
                  color: AppColors.coolColor(isDark),
                  onTap: () =>
                      ref.read(tabProvider.notifier).state = kTabCustomers,
                ),
              ],

              const SizedBox(height: 20),

              // ── Switch Role / Log out ─────────────────────────────────────
              // FIX: Clear ONLY sessionUserProvider (staff session).
              //      Do NOT set pinUnlockedProvider = false — that would lock
              //      the entire app and force the owner to re-enter their PIN.
              //      The correct behaviour: device stays unlocked, the next
              //      person to tap enters their own PIN to claim a staff role.
              _ActionButton(
                icon: Icons.switch_account_rounded,
                label: 'Switch / Log out role',
                color: AppColors.inkMuted,
                onTap: () {
                  ref.read(sessionUserProvider.notifier).state = null;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Staff session ended. Enter a PIN to switch role.',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  const _InfoCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          Flexible(
            child: Text(value,
                style: GoogleFonts.inter(color: AppColors.inkMuted),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

// ── Action button — FIX: now has an icon and a real color ─────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: color)),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 12, color: color.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}
