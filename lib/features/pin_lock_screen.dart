import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/models/staff_member.dart';
import '../core/providers/staff_provider.dart';
import '../core/services/rtdb_user_datasource.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/pin_hash_util.dart';
import 'app_logo.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PIN LOCK SCREEN  — the initial/home screen of the app
//
// FLOW:
//   • Shows every time the app starts OR when a role logs out
//   • Staff enter their 4-digit PIN → app opens with their role
//   • "Login as Owner" button appears ONLY if Firebase is already authenticated
//     (owner has previously signed into the admin portal)
//   • If Firebase NOT authenticated:
//       - No "Login as Owner" button shown
//       - Small hint text: "Admin? Hold logo for 2 seconds"
//   • Long-press logo (2s) → hidden admin portal (CompanyLoginScreen)
//
// LOGOUT RULE:
//   • In-app logout (staff or owner role) → clear sessionUser → back to PIN
//   • Firebase account logout → ONLY from admin portal, never from inside app
// ══════════════════════════════════════════════════════════════════════════════

class PinLockScreen extends ConsumerStatefulWidget {
  /// Called when PIN/owner login succeeds.
  /// isOwner=true → owner bypass; isOwner=false → staff PIN match
  final ValueChanged<bool> onUnlocked;
  /// Called when user long-presses logo to open hidden admin portal
  final VoidCallback? onOpenAdminPortal;

  const PinLockScreen({
    super.key,
    required this.onUnlocked,
    this.onOpenAdminPortal,
  });

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen>
    with SingleTickerProviderStateMixin {

  String  _pin   = '';
  String? _error;
  bool    _shake = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
  }

  @override
  void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  // ── PIN input ─────────────────────────────────────────────────────────────
  void _append(String d) {
    if (_pin.length >= 4) return;
    setState(() { _pin += d; _error = null; });
    if (_pin.length == 4) _verify();
  }

  void _delete() => setState(() {
    if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
    _error = null;
  });

  Future<void> _verify() async {
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    final allStaff = ref.read(staffProvider);
    StaffMember? matched;

    // First check staff PINs
    for (final s in allStaff) {
      if (!s.isActive) continue;

      bool pinMatch;
      if (s.hasPinHash) {
        pinMatch = PinHashUtil.verify(
          pin: _pin,
          salt: s.pinSalt,
          storedHash: s.pinHash,
        );
      } else {
        pinMatch = s.pin == _pin;
        if (pinMatch) {
          final hashed = s.copyWith(
            pinHash: PinHashUtil.hash(pin: _pin, salt: s.id),
            pinSalt: s.id,
          );
          ref.read(staffProvider.notifier).update(hashed);
          debugPrint('[PinLock] Upgraded staff ${s.name} to hashed PIN');
        }
      }

      if (pinMatch) {
        matched = s;
        break;
      }
    }

    // If no staff match, check owner PIN if Firebase user is authenticated
    if (matched == null) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          final ownerData = await RTDBUserDataSource.instance.getUser(currentUser.uid, currentUser.uid);
          if (ownerData != null) {
            final owner = StaffMember.fromJson(ownerData);
            if (owner.isActive && owner.hasPinHash) {
              final pinMatch = PinHashUtil.verify(
                pin: _pin,
                salt: owner.pinSalt,
                storedHash: owner.pinHash,
              );
              if (pinMatch) {
                matched = owner;
              }
            }
          }
        } catch (e) {
          debugPrint('Error checking owner PIN: $e');
        }
      }
    }

    if (matched != null) {
      HapticFeedback.lightImpact();
      ref.read(sessionUserProvider.notifier).state = matched;
      widget.onUnlocked(matched.isOwner);
    } else {
      _wrongPin('Wrong PIN — try again');
    }
  }

  void _wrongPin(String msg) {
    HapticFeedback.heavyImpact();
    setState(() { _shake = true; _error = msg; _pin = ''; });
    _shakeCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _shake = false);
    });
  }

  // ── Owner login — requires fresh email/password authentication ─────────────────────────────
  // Owner must always provide fresh credentials, never auto-login based on Firebase session
  void _ownerLogin() {
    if (!mounted) return;
    // Open the admin portal for fresh email/password login
    widget.onOpenAdminPortal?.call();
  }

  // ── Hidden admin portal — long press logo ─────────────────────────────────
  // Delegates to _AppGate via the onOpenAdminPortal callback.
  // No Navigator.push — _AppGate owns all screen transitions.
  void _openAdminPortal() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    widget.onOpenAdminPortal?.call();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final staff    = ref.watch(staffProvider);
    final isFirebaseAuthed = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      // Spacer to push content to center
                      const Spacer(),

                      // ── Logo + long-press trigger ────────────────────────────────
                      GestureDetector(
                        onLongPress: _openAdminPortal,
                        child: Column(children: [
                          AppLogo.fullWidth(),
                          const SizedBox(height: 14),
                          Text(
                            staff.isEmpty
                                ? 'No staff added yet'
                                : 'Enter your PIN to continue',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.inkMuted),
                          ),
                          // Hint only when Firebase not authed
                          if (!isFirebaseAuthed) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Admin? Hold logo for 2 seconds',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.inkMuted.withValues(alpha: 0.55)),
                            ),
                          ],
                        ]),
                      ),

                      const SizedBox(height: 40),

                      // ── PIN dots ─────────────────────────────────────────────────
                      AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (ctx, child) {
                          final dx = _shake
                              ? 10 * (_shakeAnim.value < 0.5
                                  ? -_shakeAnim.value * 2
                                  : (_shakeAnim.value - 0.5) * 2)
                              : 0.0;
                          return Transform.translate(
                              offset: Offset(dx * 10, 0), child: child);
                        },
                        child: Column(children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (i) {
                              final filled = i < _pin.length;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                margin: const EdgeInsets.symmetric(horizontal: 10),
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: filled ? primary : Colors.transparent,
                                  border: Border.all(
                                    color: _error != null
                                        ? AppColors.dangerColor(isDark)
                                        : filled
                                            ? primary
                                            : AppColors.inkMuted.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          AnimatedOpacity(
                            opacity: _error != null ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Text(_error ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: AppColors.dangerColor(isDark))),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 32),

                      // ── Keypad ───────────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Column(children: [
                          for (final row in [
                            ['1','2','3'],
                            ['4','5','6'],
                            ['7','8','9'],
                            ['','0','⌫'],
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: row.map((k) {
                                  if (k.isEmpty) return const SizedBox(width: 72, height: 72);
                                  return _PinKey(
                                    label: k,
                                    isDark: isDark,
                                    primary: primary,
                                    isDelete: k == '⌫',
                                    onTap: () => k == '⌫' ? _delete() : _append(k),
                                  );
                                }).toList(),
                              ),
                            ),
                        ]),
                      ),

                      const SizedBox(height: 28),

                      // ── Owner login / staff info ─────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(children: [

                          if (isFirebaseAuthed) ...[
                            // Owner bypass button — only when Firebase authed
                            GestureDetector(
                              onTap: _ownerLogin,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: primary.withValues(alpha: 0.22)),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                  Icon(Icons.shield_rounded, size: 16, color: primary),
                                  const SizedBox(width: 8),
                                  Text('Login as Owner',
                                      style: GoogleFonts.inter(
                                          fontSize: 14, fontWeight: FontWeight.w700,
                                          color: primary)),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tap to authenticate as Owner',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.inkMuted.withValues(alpha: 0.6)),
                            ),
                          ] else ...[
                            // Not Firebase authed — show staff count hint
                            if (staff.isNotEmpty)
                              Text(
                                '${staff.length} staff member${staff.length > 1 ? 's' : ''} configured',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.inkMuted),
                              ),
                            if (staff.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: primary.withValues(alpha: 0.15)),
                                ),
                                child: Column(children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 20, color: primary),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No staff added yet.\n'
                                    'Hold the logo above for 2 seconds to access the admin panel and sign in.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: AppColors.inkMuted,
                                        height: 1.5),
                                  ),
                                ]),
                              ),
                          ],

                        ]),
                      ),

                      // Spacer to push content to center
                      const Spacer(),
                    ],
                  ),
                ),
              );
          },
        ),
      ),
    );
  }
}

// ── Keypad button ─────────────────────────────────────────────────────────────
class _PinKey extends StatelessWidget {
  final String label;
  final bool isDark, isDelete;
  final Color primary;
  final VoidCallback onTap;
  const _PinKey({required this.label, required this.isDark,
      required this.primary, required this.isDelete, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: isDelete
            ? AppColors.dangerColor(isDark).withValues(alpha: 0.07)
            : (isDark ? AppColors.cardDark : AppColors.card),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDelete
              ? AppColors.dangerColor(isDark).withValues(alpha: 0.22)
              : (isDark ? AppColors.separatorDark : AppColors.separator),
        ),
        boxShadow: isDelete ? [] : [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: isDelete
            ? Icon(Icons.backspace_outlined, size: 22,
                color: AppColors.dangerColor(isDark))
            : Text(label, style: GoogleFonts.inter(
                fontSize: 26, fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// STAFF GUARD  — wrap screens that need permission control
// Usage: StaffGuard(permission: 'transactions', child: TransactionsScreen())
// ══════════════════════════════════════════════════════════════════════════════
const _kPermNames = <String, String>{
  'dashboard':     '🏠 Dashboard',
  'transactions':  '🚚 Transactions',
  'customers':     '👤 Customers',
  'inventory':     '📦 Inventory',
  'load_unload':   '🔄 Load / Unload',
  'payments':      '💳 Payments',
  'reports':       '📊 Reports',
  'notifications': '🔔 Notifications',
  'expenses':      '💸 Expenses',
};

class StaffGuard extends ConsumerWidget {
  final String permission;
  final Widget child;
  const StaffGuard({super.key, required this.permission, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionUserProvider);
    if (user == null || user.can(permission)) return child; // owner = full access

    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final primary     = Theme.of(context).colorScheme.primary;
    final dangerC     = AppColors.dangerColor(isDark);
    final featureName = _kPermNames[permission] ?? permission;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: dangerC.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.lock_rounded, size: 34, color: dangerC),
          ),
          const SizedBox(height: 20),
          Text('Access Restricted', style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: dangerC.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dangerC.withValues(alpha: 0.20)),
            ),
            child: Text(featureName, style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700, color: dangerC)),
          ),
          const SizedBox(height: 12),
          Text(
            'Your account doesn\'t have access to this feature.\n'
            'Ask the owner to update your permissions in Settings.',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.inkMuted, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Logged in as: ${user.name}',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: primary)),
          ),
        ]),
      )),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SESSION CHIP  — small chip in AppBar showing current staff role
// Tapping it confirms role-logout (back to PIN screen, Firebase stays logged in)
// ══════════════════════════════════════════════════════════════════════════════
class SessionChip extends ConsumerWidget {
  const SessionChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionUserProvider);
    if (user == null) return const SizedBox.shrink(); // owner — no chip shown

    return GestureDetector(
      onTap: () => _confirmRoleLogout(context, ref, user),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(user.name.split(' ').first,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(width: 4),
          const Icon(Icons.swap_horiz_rounded, size: 11, color: Colors.white70),
        ]),
      ),
    );
  }

  /// Role logout — clears staff session and returns to PIN screen.
  /// Firebase remains logged in (owner can bypass again immediately).
  void _confirmRoleLogout(BuildContext context, WidgetRef ref, StaffMember user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Switch Role?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          'Log out ${user.name} and return to the PIN screen?\n'
          'Your Firebase account remains signed in.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.5,
              color: AppColors.inkMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Clear role session → _AppGate rebuilds → PinLockScreen shown
                ref.read(sessionUserProvider.notifier).state = null;
                ref.read(pinUnlockedProvider.notifier).state = false;
              },
              child: Text('Switch Role',
                  style: GoogleFonts.inter(
                      color: AppColors.dangerColor(false),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
