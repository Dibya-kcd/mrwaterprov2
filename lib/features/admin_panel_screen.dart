// ✅ UPDATED — admin_panel_screen.dart
// Changes: AppBar removed. X close button + Owner badge embedded in hero card.
// Title lives inside the gradient card (not in a system AppBar).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/app_state.dart';
import '../core/services/company_session.dart';
import '../core/services/session_manager.dart';
import '../core/theme/app_colors.dart';
import '../features/settings_screen.dart';
import 'app_logo.dart';

class AdminPanelScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSignOut;
  const AdminPanelScreen({super.key, this.onBack, this.onSignOut});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final owner   = ref.watch(sessionUserProvider) == null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header: Logo only (Redundant title removed) ───────────────
              const Center(
                child: AppLogo(
                  height: 52,
                ),
              ),
              const SizedBox(height: 24),

              // ── Welcome Card (Welcome Box) ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withValues(alpha: 0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.32),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon + Badge row
                        Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white, size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Owner / Staff badge
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
                                    owner
                                        ? Icons.verified_user_rounded
                                        : Icons.person_rounded,
                                    size: 13, color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    owner ? 'Owner' : 'Staff',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Title + subtitle
                        Text(
                          'Admin Portal',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your business settings and staff access',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),

                    // ✕ Close button in the top-right corner of the box
                    Positioned(
                      top: 0, right: 0,
                      child: GestureDetector(
                        onTap: onSignOut ?? () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white, size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── MANAGEMENT section label ──────────────────────────────────
              Text(
                'MANAGEMENT',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted, letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // ── Action cards ──────────────────────────────────────────────
              _ActionCard(
                icon: Icons.person_add_rounded,
                title: 'Staff Management',
                desc: 'Add staff, set PINs and manage permissions.',
                color: primary,
                isDark: isDark,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.lock_reset_rounded,
                title: 'Reset Owner PIN',
                desc: 'Change the owner PIN used to unlock the app.',
                color: AppColors.warningColor(isDark),
                isDark: isDark,
                onTap: () => _showResetOwnerPin(context),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.history_rounded,
                title: 'Access Logs',
                desc: 'Review staff access and PIN unlock events.',
                color: AppColors.coolColor(isDark),
                isDark: isDark,
                onTap: () => _showLogsDialog(context),
              ),

              const SizedBox(height: 28),

              // ── NAVIGATION ──────────────────────────────────────────────────
              const _Section(title: 'SYSTEM NAVIGATION'),
              const SizedBox(height: 12),
              _NavCard(
                icon: Icons.dashboard_rounded,
                title: 'Go to Dashboard',
                desc: 'Back to daily operations & deliveries',
                color: primary,
                onTap: onBack ?? () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              _NavCard(
                icon: Icons.logout_rounded,
                title: 'Lock & Return',
                desc: 'Sign out of owner session and return to PIN screen',
                color: AppColors.dangerColor(isDark),
                onTap: () => _signOut(context, ref),
              ),

              // ── Warning banner if not owner ───────────────────────────────
              if (!owner) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerColor(isDark).withValues(alpha: 0.08),
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

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  void _showResetOwnerPin(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset owner PIN',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          'Owner PIN reset will be available in the next update.',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.inkMuted, height: 1.4),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Access Logs',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          'Log viewing will be available after integrating access-event storage.',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.inkMuted, height: 1.4),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                  color: AppColors.dangerColor(isDark),
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    await SessionManager.instance.lock(ref);
    ref.read(pinUnlockedProvider.notifier).state = false;
    await CompanySession.firebaseSignOut();
    if (context.mounted) {
      if (onSignOut != null) {
        onSignOut!();
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.inkMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2035) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.inkMuted.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
