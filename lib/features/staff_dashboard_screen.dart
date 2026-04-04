import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models/user_role.dart';
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Staff Dashboard', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              user != null
                  ? 'Welcome back, ${user.name}.'
                  : 'Welcome. Enter your PIN to access staff actions.',
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 20),
            if (user != null) ...[
              _InfoCard(title: 'Role', value: user.role.value),
              const SizedBox(height: 12),
              _InfoCard(title: 'Active', value: user.isActive ? 'Yes' : 'No'),
              const SizedBox(height: 12),
              _InfoCard(title: 'Permissions', value: user.permissions.join(', ')),
            ],
            const SizedBox(height: 20),
            Text('Quick actions', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _ActionButton(label: 'Open sales dashboard', onTap: () {}),
            const SizedBox(height: 10),
            _ActionButton(label: 'View customer queue', onTap: () {}),
            const SizedBox(height: 10),
            _ActionButton(label: 'Log out role', onTap: () {
              ref.read(sessionUserProvider.notifier).state = null;
              ref.read(pinUnlockedProvider.notifier).state = false;
            }),
          ]),
        ),
      ),
    );
  }
}

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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        Text(value, style: GoogleFonts.inter(color: AppColors.inkMuted)),
      ]),
    );
  }
}

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
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
