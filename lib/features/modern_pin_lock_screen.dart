import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/staff_provider.dart';
import '../core/services/rtdb_user_datasource.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/pin_hash_util.dart';

class ModernPinLockScreen extends ConsumerStatefulWidget {
  final ValueChanged<bool> onUnlocked;
  final VoidCallback? onOpenAdminPortal;

  const ModernPinLockScreen({
    super.key,
    required this.onUnlocked,
    this.onOpenAdminPortal,
  });

  @override
  ConsumerState<ModernPinLockScreen> createState() => _ModernPinLockScreenState();
}

class _ModernPinLockScreenState extends ConsumerState<ModernPinLockScreen>
    with TickerProviderStateMixin {

  String  _pin   = '';
  String? _error;
  bool    _shake = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    
    // Shake animation for errors
    _shakeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    _shakeAnim = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut));
    
    // Pulse animation for logo
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.repeat(reverse: true);
    
    // Fade animation for entrance
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Glow animation
    _glowCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3000));
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _glowCtrl.repeat(reverse: true);
  }

  @override
  void dispose() { 
    _shakeCtrl.dispose(); 
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose(); 
  }

  void _append(String d) {
    if (_pin.length >= 4) return;
    setState(() { _pin += d; _error = null; });
    HapticFeedback.lightImpact();
    if (_pin.length == 4) _verify();
  }

  void _delete() => setState(() {
    if (_pin.isNotEmpty) {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
      HapticFeedback.selectionClick();
    }
  });

  Future<void> _verify() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final allStaff = ref.read(staffProvider);
    StaffMember? matched;

    // Check staff PINs
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
        }
      }

      if (pinMatch) {
        matched = s;
        break;
      }
    }

    // Check owner PIN if Firebase user is authenticated
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
              if (pinMatch) matched = owner;
            }
          }
        } catch (e) {
          debugPrint('Error checking owner PIN: $e');
        }
      }
    }

    if (matched != null) {
      HapticFeedback.heavyImpact();
      ref.read(sessionUserProvider.notifier).state = matched;
      widget.onUnlocked(matched.isOwner);
    } else {
      _wrongPin('Invalid PIN - try again');
    }
  }

  void _wrongPin(String msg) {
    HapticFeedback.heavyImpact();
    setState(() { _shake = true; _error = msg; _pin = ''; });
    _shakeCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _shake = false);
    });
  }

  void _ownerLogin() {
    if (!mounted) return;
    widget.onOpenAdminPortal?.call();
  }

  void _openAdminPortal() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    widget.onOpenAdminPortal?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = Theme.of(context).colorScheme.primary;
    final isFirebaseAuthed = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA),
      body: AnimatedBuilder(
        animation: _fadeAnim,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF000000),
                          const Color(0xFF1A1A1A),
                          primary.withValues(alpha: 0.1),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFAFAFA),
                          const Color(0xFFF5F5F5),
                          primary.withValues(alpha: 0.05),
                        ],
                      ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    final w = constraints.maxWidth;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // ── Top Section (Logo) ─────────────────────────────
                            Column(
                              children: [
                                SizedBox(height: h * 0.06),
                                // Animated Logo with glow effect
                                AnimatedBuilder(
                                  animation: Listenable.merge([_pulseAnim, _glowAnim]),
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _pulseAnim.value,
                                      child: GestureDetector(
                                        onLongPress: _openAdminPortal,
                                        child: Column(
                                          children: [
                                            // Stack for Logo and Glow
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // Glow effect
                                                Container(
                                                  width: 120,
                                                  height: 120,
                                                  decoration: BoxDecoration(
                                                    gradient: RadialGradient(
                                                      colors: [
                                                        primary.withValues(alpha: _glowAnim.value * 0.3),
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                // Main logo container
                                                Container(
                                                  width: 120,
                                                  height: 120,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        primary,
                                                        primary.withValues(alpha: 0.8),
                                                        primary.withValues(alpha: 0.6),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(30),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: primary.withValues(alpha: 0.4),
                                                        blurRadius: 30,
                                                        offset: const Offset(0, 8),
                                                      ),
                                                      BoxShadow(
                                                        color: primary.withValues(alpha: 0.2),
                                                        blurRadius: 60,
                                                        offset: const Offset(0, 16),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.water_drop_rounded,
                                                      size: 50,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 24),
                                            Text(
                                              'MrWater Pro',
                                              style: GoogleFonts.inter(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                                letterSpacing: -1,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Water Delivery Management',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                            // ── Middle Section (PIN Display) ───────────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: AnimatedBuilder(
                                animation: _shakeAnim,
                                builder: (ctx, child) {
                                  final dx = _shake
                                      ? 15 * (_shakeAnim.value < 0.5
                                          ? -_shakeAnim.value * 2
                                          : (_shakeAnim.value - 0.5) * 2)
                                      : 0.0;
                                  return Transform.translate(
                                    offset: Offset(dx, 0),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Enter Your PIN',
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1C1C1E),
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(4, (i) {
                                            final filled = i < _pin.length;
                                            return AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              margin: const EdgeInsets.symmetric(horizontal: 14),
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: filled ? primary : Colors.transparent,
                                                border: Border.all(
                                                  color: _error != null
                                                      ? AppColors.dangerColor(isDark)
                                                      : filled
                                                          ? primary
                                                          : isDark
                                                              ? Colors.white.withValues(alpha: 0.3)
                                                              : const Color(0xFFD1D1D6),
                                                  width: filled ? 3 : 2,
                                                ),
                                                boxShadow: filled
                                                    ? [
                                                        BoxShadow(
                                                          color: primary.withValues(alpha: 0.5),
                                                          blurRadius: 12,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            );
                                          }),
                                        ),
                                        const SizedBox(height: 20),
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 400),
                                          child: _error != null
                                              ? Container(
                                                  key: const ValueKey('error'),
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.dangerColor(isDark).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(
                                                      color: AppColors.dangerColor(isDark).withValues(alpha: 0.3),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.error_outline_rounded,
                                                        size: 16,
                                                        color: AppColors.dangerColor(isDark),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        _error!,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppColors.dangerColor(isDark),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : const SizedBox(key: ValueKey('empty'), height: 40),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            // ── Bottom Section (Keypad) ────────────────────────
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: w * 0.08),
                              child: Column(
                                children: [
                                  for (final row in [
                                    ['1', '2', '3'],
                                    ['4', '5', '6'],
                                    ['7', '8', '9'],
                                    ['*', '0', '#'],
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Row(
                                        children: row.map((digit) {
                                          return Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: _ModernKeyButton(
                                                text: digit,
                                                onTap: () => _append(digit),
                                                isDark: isDark,
                                                primary: primary,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Action buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ModernActionButton(
                                          text: 'Clear',
                                          onTap: () => setState(() {
                                            _pin = '';
                                            _error = null;
                                            HapticFeedback.selectionClick();
                                          }),
                                          isDark: isDark,
                                          isSecondary: true,
                                          primary: primary,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: _ModernActionButton(
                                          text: 'Delete',
                                          onTap: _delete,
                                          isDark: isDark,
                                          icon: Icons.backspace_rounded,
                                          primary: primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),

                                  // Owner login button
                                  if (isFirebaseAuthed)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: GestureDetector(
                                        onTap: _ownerLogin,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFD1D1D6),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.shield_rounded,
                                                size: 16,
                                                color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Login as Owner',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Hidden admin hint
                                  if (!isFirebaseAuthed)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Text(
                                        'Admin? Hold logo for 2 seconds',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFFC7C7CC),
                                        ),
                                      ),
                                    ),
                                  
                                  SizedBox(height: h * 0.04),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Modern key button component
class _ModernKeyButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isDark;
  final Color primary;

  const _ModernKeyButton({
    required this.text,
    required this.onTap,
    required this.isDark,
    required this.primary,
  });

  @override
  State<_ModernKeyButton> createState() => _ModernKeyButtonState();
}

class _ModernKeyButtonState extends State<_ModernKeyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _colorAnimation = ColorTween(
      begin: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
      end: widget.primary.withValues(alpha: 0.1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _colorAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: _colorAnimation.value,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                boxShadow: _controller.isAnimating
                    ? [
                        BoxShadow(
                          color: widget.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  widget.text,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Modern action button component
class _ModernActionButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isDark;
  final bool isSecondary;
  final IconData? icon;
  final Color primary;

  const _ModernActionButton({
    required this.text,
    required this.onTap,
    required this.isDark,
    this.isSecondary = false,
    this.icon,
    required this.primary,
  });

  @override
  State<_ModernActionButton> createState() => _ModernActionButtonState();
}

class _ModernActionButtonState extends State<_ModernActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: widget.isSecondary
                    ? Colors.transparent
                    : widget.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isSecondary
                      ? (widget.isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.1))
                      : widget.primary.withValues(alpha: 0.3),
                  width: widget.isSecondary ? 1 : 1.5,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: 18,
                        color: widget.isDark ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.text,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
