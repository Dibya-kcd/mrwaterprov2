import 'package:firebase_auth/firebase_auth.dart';
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
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // FIX 10: owner session = Firebase authenticated AND no staff member active.
    // sessionUserProvider == null alone is insufficient because the app starts
    // with sessionUserProvider = null before anyone logs in.
    final firebaseUser  = FirebaseAuth.instance.currentUser;
    final staffSession  = ref.watch(sessionUserProvider);
    final isOwnerSession = firebaseUser != null && staffSession == null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Hero / Welcome card ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withValues(alpha: 0.72)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: primary.withValues(alpha: 0.32),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Row: icon + spacer + badge + × button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded,
                              color: Colors.white, size: 28),
                        ),

                        const Spacer(),

                        // FIX 10: badge only shows "Owner" when genuinely
                        // owner-authenticated (Firebase user + no staff session)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOwnerSession
                                    ? Icons.verified_user_rounded
                                    : Icons.person_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isOwnerSession ? 'Owner' : 'Staff',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // ✕ Close button
                        GestureDetector(
                          onTap: onBack ?? () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Text('Admin Panel',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Manage your business settings',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.78))),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Section label ────────────────────────────────────────────
              Text('MANAGEMENT',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                      letterSpacing: 1.2)),
              const SizedBox(height: 12),

              // ── Action cards ─────────────────────────────────────────────
              _ActionCard(
                icon: Icons.person_add_rounded,
                title: 'Staff Management',
                subtitle: 'Add staff, set PINs and manage permissions.',
                color: primary,
                isDark: isDark,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen())),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.lock_reset_rounded,
                title: 'Reset Owner PIN',
                subtitle: 'Change the owner PIN used to unlock the app.',
                color: AppColors.warningColor(isDark),
                isDark: isDark,
                onTap: () => _showResetOwnerPin(context),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.history_rounded,
                title: 'Access Logs',
                subtitle: 'Review staff access and PIN unlock events.',
                color: AppColors.coolColor(isDark),
                isDark: isDark,
                onTap: () => _showLogsDialog(context),
              ),
              const SizedBox(height: 28),

              // ── Section label ────────────────────────────────────────────
              Text('NAVIGATION',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkMuted,
                      letterSpacing: 1.2)),
              const SizedBox(height: 12),

              // Go to App
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onBack ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.apps_rounded, size: 18),
                  label: Text('Go to App',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Sign out
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context, ref),
                  icon: Icon(Icons.logout_rounded,
                      size: 18, color: AppColors.dangerColor(isDark)),
                  label: Text('Sign out of Firebase',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dangerColor(isDark))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.dangerColor(isDark)
                            .withValues(alpha: 0.40)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              // FIX 10: warning shown when accessed without owner session
              if (!isOwnerSession) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        AppColors.dangerColor(isDark).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.dangerColor(isDark)
                            .withValues(alpha: 0.22)),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: AppColors.dangerColor(isDark)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This screen is only valid when unlocked as owner.',
                        style: GoogleFonts.inter(
                            color: AppColors.dangerColor(isDark), fontSize: 12),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetOwnerPin(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset owner PIN',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
            'Owner PIN reset will be available in the next update.',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.inkMuted, height: 1.4)),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }

  void _showLogsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Access Logs',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
            'Log viewing will be available after integrating access-event storage.',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.inkMuted, height: 1.4)),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text('Sign out?',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
            content: Text(
              'Your app data stays safe. You\'ll need to sign in again to access the admin portal.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.inkMuted, height: 1.5),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Sign Out',
                    style: GoogleFonts.inter(
                        color: AppColors.dangerColor(isDark),
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    // FIX 8: Sign out Firebase FIRST so that when _AppGate re-evaluates after
    // lock(), FirebaseAuth.currentUser is already null and the PIN screen
    // correctly routes to the company login screen — no race condition.
    await CompanySession.firebaseSignOut();

    // Now lock the app (clears pinUnlockedProvider + sessionUserProvider)
    await SessionManager.instance.lock(ref);

    if (onSignOut != null) {
      onSignOut!();
    } else if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

// ── Action card ───────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
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
          color: isDark ? const Color(0xFF1A2035) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isDark
                  ? AppColors.separatorDark
                  : AppColors.separator),
          boxShadow: [
            BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.12 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                        height: 1.3)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.inkMuted, size: 20),
        ]),
      ),
    );
  }
}
