import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';

class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionUserProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
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

              // ── Session info cards ──────────────────────────────────────
              if (user != null) ...[
                _InfoCard(title: 'Role', value: user.role.value),
                const SizedBox(height: 12),
                _InfoCard(title: 'Active', value: user.isActive ? 'Yes' : 'No'),
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

              // ── Permission-gated action buttons ─────────────────────────
              // FIX 6: wrap every action in a can() guard so only permitted
              // staff see and can tap the corresponding feature button.
              if (user == null || user.can('transactions'))
                _ActionButton(
                    label: 'Open sales dashboard', onTap: () {}),
              if (user == null || user.can('customers')) ...[
                const SizedBox(height: 10),
                _ActionButton(
                    label: 'View customer queue', onTap: () {}),
              ],

              const SizedBox(height: 10),

              // ── Switch Role / Log out ────────────────────────────────────
              // FIX 2: Do NOT set pinUnlockedProvider = false here.
              // That would lock the entire app and force the owner to re-enter
              // their PIN. The correct behaviour is to clear only the staff
              // session (sessionUserProvider = null) so the app stays open
              // and the owner can hand the device to another staff member who
              // then enters their own PIN, or the owner continues as-is.
              _ActionButton(
                label: 'Switch / Log out role',
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

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
