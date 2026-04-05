import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/app_state.dart';
import '../core/services/company_session.dart';
import '../core/services/session_manager.dart';
import '../core/theme/app_colors.dart';
import '../features/settings_screen.dart';

class AdminPanelScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSignOut;
  const AdminPanelScreen({super.key, this.onBack, this.onSignOut});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(sessionUserProvider) == null;
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null ? null : IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack,
        ),
        title: const Text('Admin Panel'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Owner tools', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'This area is only available to the owner after verifying the owner PIN.',
              style: GoogleFonts.inter(color: AppColors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 22),
            _ActionCard(
              icon: Icons.person_add_rounded,
              title: 'Create staff PIN',
              subtitle: 'Add a team member with role and access limits.',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.lock_clock_rounded,
              title: 'Reset owner PIN',
              subtitle: 'Force the owner to re-enter or change the owner PIN.',
              onTap: () => _showResetOwnerPin(context),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.history_rounded,
              title: 'View access logs',
              subtitle: 'Review staff access and PIN unlock events.',
              onTap: () => _showLogsDialog(context),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onBack ?? () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Go to App'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out of Firebase'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerColor(false)),
              ),
            ),
            if (!owner)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Warning: this screen is only valid when the app is unlocked as owner.',
                  style: GoogleFonts.inter(color: AppColors.dangerColor(false), fontSize: 12),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  void _showResetOwnerPin(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset owner PIN'),
        content: const Text('Owner PIN reset is not yet implemented in this prototype.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showLogsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Access logs'),
        content: const Text('Log viewing is available after integrating access-event storage.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await SessionManager.instance.lock(ref);
    ref.read(pinUnlockedProvider.notifier).state = false;
    await CompanySession.firebaseSignOut();
    if (onSignOut != null) {
      onSignOut!();
    } else if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(subtitle, style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }
}
