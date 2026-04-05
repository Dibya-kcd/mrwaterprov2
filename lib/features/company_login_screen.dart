import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/company_session.dart';
import '../core/services/rtdb_user_datasource.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/pin_hash_util.dart';
import 'mr_water_logo.dart';

// ══════════════════════════════════════════════════════════════════════════════
// company_login_screen.dart — HIDDEN admin portal
//
// Access: long-press logo on PIN screen for 2 seconds. Staff never see this.
//
// Flow:
//   • Default view = Sign In only (clean, no tab bar)
//   • "Forgot password?" → subtle link below button → inline forgot-pw form
//   • "New business? Create an account →" → subtle bottom link → sign-up form
//   • On success → bottom sheet: "Enter App" or "Use PIN Screen"
//   • "Not you? Sign out" in success sheet → Firebase sign-out (with confirm)
//   • Inside-app logout clears ROLE session only, not Firebase
// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════
enum _View { signIn, signUp, forgotPw, verifyEmail }

class CompanyLoginScreen extends StatefulWidget {
  /// goDirectly=true  → owner enters app directly (skip PIN)
  /// goDirectly=false → return to PIN screen for role selection
  final void Function({required bool goDirectly}) onAuthenticated;
  /// Called when back arrow tapped (only shown when provided)
  final VoidCallback? onBack;
  const CompanyLoginScreen({
    super.key,
    required this.onAuthenticated,
    this.onBack,
  });

  @override
  State<CompanyLoginScreen> createState() => _CompanyLoginScreenState();
}

class _CompanyLoginScreenState extends State<CompanyLoginScreen>
    with TickerProviderStateMixin {

  _View   _view    = _View.signIn;
  bool    _loading = false;
  bool    _obscure = true;
  String? _error;
  String? _info;
  String? _verifyEmail;  // Email being verified
  Timer?  _verifyTimer;  // Auto-check timer

  final _emailCtrl = TextEditingController();
  final _pwCtrl    = TextEditingController();
  final _pw2Ctrl   = TextEditingController();
  final _bizCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _pwCtrl.dispose();
    _pw2Ctrl.dispose();   _bizCtrl.dispose();
    _fadeCtrl.dispose();
    _verifyTimer?.cancel();
    super.dispose();
  }

  // ── No auto-login — Owner must always provide fresh credentials ───────────────────────────
  // Removed auto-login logic to enforce fresh authentication for Owner access

  // ── Switch between form views ─────────────────────────────────────────────
  void _switchView(_View v) {
    if (_view == v) return;
    setState(() { _view = v; _error = null; _info = null; });
    _fadeCtrl.forward(from: 0);
  }

  // ── Firebase auth ─────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      debugPrint('FirebaseAuth: Attempting sign in for ${_emailCtrl.text.trim()}...');
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _pwCtrl.text);
      debugPrint('FirebaseAuth: Sign in successful for ${c.user?.email}');
      if (!c.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _loading = false;
          _error = 'email-not-verified';
        });
        return;
      }
      CompanySession.init(c.user!.uid,
          name: c.user!.displayName ?? c.user!.email ?? '');
      await _ensureOwnerRecord(c.user!);
      if (mounted) _showSuccess();
    } on FirebaseAuthException catch (e) { 
      debugPrint('FirebaseAuth error (code: ${e.code}): ${e.message}');
      debugPrint('FirebaseAuth full details: $e');
      _fail(e.code); 
    } catch (e) {
      debugPrint('FirebaseAuth UNKNOWN error: $e');
      _fail('unknown');
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pwCtrl.text != _pw2Ctrl.text) { _fail('passwords-mismatch'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _pwCtrl.text);
      await c.user!.updateDisplayName(_bizCtrl.text.trim());
      await c.user!.sendEmailVerification();
      await _ensureOwnerRecord(c.user!);
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _loading = false;
          _view = _View.verifyEmail;
          _verifyEmail = c.user!.email;
          _error = null;
          _info = null;
        });
        _startVerificationCheck();
      }
    } on FirebaseAuthException catch (e) { _fail(e.code); }
  }

  void _startVerificationCheck() {
    _verifyTimer?.cancel();
    _verifyTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_verifyEmail == null) return;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.reload();
          if (user.emailVerified) {
            _verifyTimer?.cancel();
            if (mounted) {
              setState(() => _loading = true);
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                _showVerificationSuccess();
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Email verification check error: $e');
      }
    });
  }

  Future<void> _manualVerificationCheck() async {
    if (_verifyEmail == null) return;
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          _verifyTimer?.cancel();
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) _showVerificationSuccess();
        } else {
          setState(() {
            _loading = false;
            _error = 'Email not verified yet. Please check your inbox.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error checking verification status. Please try again.';
      });
    }
  }

  void _showVerificationSuccess() {
    _verifyTimer?.cancel();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final okC = AppColors.successColor(isDark);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: okC.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.check_circle_rounded, size: 36, color: okC),
          ),
          const SizedBox(height: 16),
          Text('Email Verified!',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Your account is ready. You can now sign in.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.4),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) {
                setState(() {
                  _view = _View.signIn;
                  _loading = false;
                  _verifyEmail = null;
                  _emailCtrl.clear();
                  _pwCtrl.clear();
                  _pw2Ctrl.clear();
                  _bizCtrl.clear();
                });
              }
            },
            child: Text('Go to Sign In',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: okC)),
          ),
        ],
      ),
    );
  }

  void _showForgotUsernameHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot username?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'This portal uses your registered email address as the username.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'If you do not remember it, check the email account you used to sign up, or open the welcome email from Firebase.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'If you still cannot access the portal, use the forgot password flow with the same email address, or contact support for help.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.4),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _sendReset() async {
    if (_emailCtrl.text.trim().isEmpty) { _fail('missing-email'); return; }
    setState(() { _loading = true; _error = null; _info = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailCtrl.text.trim());
      setState(() {
        _loading = false;
        _info = 'Reset link sent to ${_emailCtrl.text.trim()}. Check your inbox and spam folder.';
      });
    } on FirebaseAuthException catch (e) { _fail(e.code); }
  }

  Future<void> _ensureOwnerRecord(User user) async {
    final data = await RTDBUserDataSource.instance.getUser(user.uid, user.uid);
    if (data == null) {
      await RTDBUserDataSource.instance.setUser(user.uid, user.uid, {
        'id': user.uid,
        'name': user.displayName ?? user.email ?? 'Owner',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'pin': '',
        'pinHash': '',
        'pinSalt': user.uid,
        'role': 'OWNER',
        'isActive': true,
        'permissions': [
          'dashboard', 'transactions', 'customers', 'inventory',
          'load_unload', 'payments', 'reports', 'notifications',
          'settings', 'expenses', 'smart_entry',
        ],
      });
      await _promptOwnerPinSetup(user);
      return;
    }

    final hasPin = (data['pinHash'] as String?)?.isNotEmpty ?? false;
    if (!hasPin) {
      await _promptOwnerPinSetup(user);
    }
  }

  Future<void> _promptOwnerPinSetup(User user) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? formError;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Owner PIN'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Create a 4–6 digit PIN to unlock the app on shared devices.\nDo not share this PIN.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Owner PIN', counterText: ''),
              maxLength: 6,
            ),
            TextField(
              controller: confirmCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
              maxLength: 6,
            ),
            if (formError != null) ...[
              const SizedBox(height: 12),
              Text(formError!, style: TextStyle(color: AppColors.dangerColor(false), fontSize: 13)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final pin = pinCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();
                final validation = PinHashUtil.validate(pin);
                if (validation != null) {
                  setState(() => formError = validation);
                  return;
                }
                if (pin != confirm) {
                  setState(() => formError = 'PINs must match.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );

    if (created == true && pinCtrl.text.trim().isNotEmpty) {
      final pin = pinCtrl.text.trim();
      final hash = PinHashUtil.hash(pin: pin, salt: user.uid);
      await RTDBUserDataSource.instance.updateUser(user.uid, user.uid, {
        'pin': '',
        'pinHash': hash,
        'pinSalt': user.uid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner PIN created successfully. Use the PIN screen next time.')),
        );
      }
    }
  }

  void _fail(String code) {
    HapticFeedback.heavyImpact();
    setState(() {
      _loading = false;
      _error = switch (code) {
        'user-not-found'       => 'No account found for this email.',
        'wrong-password'       => 'Incorrect password.',
        'invalid-credential'   => 'Incorrect email or password.',
        'invalid-email'        => 'Please enter a valid email address.',
        'email-already-in-use' => 'An account already exists for this email.',
        'weak-password'        => 'Password must be at least 6 characters.',
        'passwords-mismatch'   => 'Passwords do not match.',
        'user-disabled'        => 'This account has been disabled.',
        'too-many-requests'    => 'Too many attempts — please wait.',
        'missing-email'        => 'Enter your email address first.',
        'email-not-verified'   => 'Email not verified. Check your inbox for the verification email.',
        _                      => 'Something went wrong. Please try again.',
      };
    });
  }

  // ── Firebase sign-out (only from admin portal, with confirm) ─────────────
  Future<void> _confirmFirebaseSignOut(BuildContext sheetCtx) async {
    Navigator.of(sheetCtx).pop(); // close success sheet
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out of Firebase?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          'This will sign out your Firebase account. '
          'Staff and app data remain safe. '
          'You will need to sign in again to access the admin portal.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.5,
              color: AppColors.inkMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Sign Out',
                  style: GoogleFonts.inter(
                      color: AppColors.dangerColor(false),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    ) ?? false;

    if (!ok || !mounted) return;
    await CompanySession.firebaseSignOut();
    // Pop this screen entirely after Firebase sign-out
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  // ── Success bottom sheet (shown after login) ──────────────────────────────
  void _showSuccess() {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final okC     = AppColors.successColor(isDark);
    final name    = CompanySession.companyName.isNotEmpty
        ? CompanySession.companyName : 'your account';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,   // lets sheet grow taller if needed
      builder: (sheetCtx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2035) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 24, offset: const Offset(0, -6))],
          ),
          // SingleChildScrollView prevents overflow on small screens
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Drag handle
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.inkMuted.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),

              // Success icon — smaller on small screens
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                    color: okC.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded, size: 36, color: okC),
              ),
              const SizedBox(height: 12),
              Text('Signed In!', style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Welcome, $name',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.inkMuted)),
              const SizedBox(height: 22),

              // ── Open Admin Panel (owner access) ──
              SizedBox(width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 17),
                  label: Text('Open Admin Panel', style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    widget.onAuthenticated(goDirectly: true);
                  },
                ),
              ),
              const SizedBox(height: 10),

              // ── Use PIN Screen ──
              SizedBox(width: double.infinity, height: 50,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.pin_rounded, size: 17, color: primary),
                  label: Text('Use PIN Screen', style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primary.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    widget.onAuthenticated(goDirectly: false);
                  },
                ),
              ),
              const SizedBox(height: 14),

              // ── Firebase sign-out ──
              GestureDetector(
                onTap: () => _confirmFirebaseSignOut(sheetCtx),
                child: Text('Not you? Sign out',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.inkMuted,
                        decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: 4),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final bg      = isDark ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA);

    return Scaffold(
      backgroundColor: bg,
      // Back button shown when opened from _AppGate as a screen (not a push)
      appBar: widget.onBack != null
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: isDark ? Colors.white70 : Colors.black54),
                onPressed: widget.onBack,
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(children: [

              // Logo
              MrWaterLogo(height: 56, onDark: isDark),
              const SizedBox(height: 12),

              // Subtle portal badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primary.withValues(alpha: 0.15)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.admin_panel_settings_rounded,
                      size: 13, color: primary),
                  const SizedBox(width: 6),
                  Text('Business Owner Portal', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600, color: primary)),
                ]),
              ),
              const SizedBox(height: 32),

              // Form card
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2035) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(
                          alpha: isDark ? 0.28 : 0.07),
                      blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Form(key: _formKey,
                      child: _buildForm(isDark, primary)),
                ),
              ),

              // Bottom links — outside the card
              const SizedBox(height: 20),
              if (_view == _View.signIn)
                GestureDetector(
                  onTap: () => _switchView(_View.signUp),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'New business? ',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.inkMuted)),
                    TextSpan(
                        text: 'Create an account →',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: primary)),
                  ])),
                )
              else if (_view != _View.verifyEmail)
                GestureDetector(
                  onTap: () => _switchView(_View.signIn),
                  child: Text('← Back to Sign In',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: primary,
                          fontWeight: FontWeight.w600)),
                ),

              const SizedBox(height: 12),
              Text('Authorised business owners only',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.inkMuted)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark, Color primary) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Title + subtitle
      Text(_title, style: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(_subtitle, style: GoogleFonts.inter(
          fontSize: 13, color: AppColors.inkMuted)),
      const SizedBox(height: 24),

      // Email verification waiting state
      if (_view == _View.verifyEmail) ...[  Text('Verification email sent to:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primary.withValues(alpha: 0.15)),
          ),
          child: Text(_verifyEmail ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primary.withValues(alpha: 0.16)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: primary),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'We\'re automatically checking for verification. This usually takes seconds.',
                style: GoogleFonts.inter(fontSize: 12, color: primary, height: 1.4),
              )),
            ]),
            const SizedBox(height: 10),
            Text('If you don\'t receive the email, check your spam folder or request a new verification link.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 16),
      ] else ...[  

        // Business name — sign up only
        if (_view == _View.signUp) ...[
        _lbl('Business Name'),
        _TF(ctrl: _bizCtrl, hint: 'My Water Supply Co.',
            icon: Icons.business_rounded,
            validator: (v) =>
                v?.trim().isEmpty == true ? 'Enter business name' : null),
        const SizedBox(height: 16),
      ],

      // Email — all views
      _lbl('Email Address'),
      _TF(ctrl: _emailCtrl, hint: 'owner@example.com',
          icon: Icons.email_outlined,
          type: TextInputType.emailAddress,
          validator: (v) => v?.trim().isEmpty == true ? 'Enter email' : null),
      const SizedBox(height: 16),

      // Password — sign in + sign up
      if (_view != _View.forgotPw) ...[
        _lbl('Password'),
        _TF(
          ctrl: _pwCtrl, hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          onObscure: () => setState(() => _obscure = !_obscure),
          action: _view == _View.signIn
              ? TextInputAction.done : TextInputAction.next,
          onSubmit: _view == _View.signIn ? (_) => _signIn() : null,
          validator: (v) => v?.isEmpty == true ? 'Enter password' : null,
        ),
        const SizedBox(height: 16),
      ],

      // Confirm password — sign up
      if (_view == _View.signUp) ...[
        _lbl('Confirm Password'),
        _TF(ctrl: _pw2Ctrl, hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            action: TextInputAction.done,
            validator: (v) =>
                v?.isEmpty == true ? 'Confirm your password' : null),
        const SizedBox(height: 16),
      ],
      ],  // Close else spread for non-verifyEmail views

      // Error / success banner
      if (_error != null) ...[
        _Banner(text: _error!, isError: true, isDark: isDark),
        const SizedBox(height: 14),
      ],
      if (_info != null) ...[
        _Banner(text: _info!, isError: false, isDark: isDark),
        const SizedBox(height: 14),
      ],

      // Primary action button
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: _loading ? null : _action,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary, foregroundColor: Colors.white,
            disabledBackgroundColor: primary.withValues(alpha: 0.40),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(_btnLabel, style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),

      // Forgot password — subtle link, sign in view only
      if (_view == _View.signIn) ...[
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: () => _switchView(_View.forgotPw),
            child: Text('Forgot password?',
                style: GoogleFonts.inter(
                    fontSize: 13, color: primary,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 18),
          GestureDetector(
            onTap: _showForgotUsernameHelp,
            child: Text('Forgot username?',
                style: GoogleFonts.inter(
                    fontSize: 13, color: primary,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      ],

      // Hint text for forgot pw view
      if (_view == _View.forgotPw && _info == null) ...[
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Enter your email above and tap Send Reset Link.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.inkMuted),
          ),
        ),
      ],
    ]);
  }

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w600)),
  );

  String get _title => switch (_view) {
    _View.signIn    => 'Welcome back',
    _View.signUp    => 'Create account',
    _View.forgotPw  => 'Reset password',
    _View.verifyEmail => 'Verify Your Email',
  };
  String get _subtitle => switch (_view) {
    _View.signIn    => 'Sign in to your business account',
    _View.signUp    => 'Register your water delivery business',
    _View.forgotPw  => 'We\'ll email you a reset link',
    _View.verifyEmail => 'Check your inbox for a verification link',
  };
  String get _btnLabel => switch (_view) {
    _View.signIn    => 'Sign In',
    _View.signUp    => 'Create Account',
    _View.forgotPw  => 'Send Reset Link',
    _View.verifyEmail => 'I\'ve Verified My Email',
  };
  VoidCallback get _action => switch (_view) {
    _View.signIn    => _signIn,
    _View.signUp    => _signUp,
    _View.forgotPw  => _sendReset,
    _View.verifyEmail => _manualVerificationCheck,
  };
}

// ── Text field helper ─────────────────────────────────────────────────────────
class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType type;
  final TextInputAction action;
  final bool obscure;
  final VoidCallback? onObscure;
  final ValueChanged<String>? onSubmit;
  final FormFieldValidator<String>? validator;

  const _TF({required this.ctrl, required this.hint, required this.icon,
      this.type = TextInputType.text,
      this.action = TextInputAction.next,
      this.obscure = false, this.onObscure,
      this.onSubmit, this.validator});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, keyboardType: type,
    textInputAction: action, obscureText: obscure,
    onFieldSubmitted: onSubmit, validator: validator,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: AppColors.inkMuted),
      suffixIcon: onObscure != null
          ? GestureDetector(
              onTap: onObscure,
              child: Icon(obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
                  size: 18, color: AppColors.inkMuted))
          : null,
    ),
  );
}

// ── Info / error banner ───────────────────────────────────────────────────────
class _Banner extends StatelessWidget {
  final String text;
  final bool isError, isDark;
  const _Banner({required this.text, required this.isError, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = isError
        ? AppColors.dangerColor(isDark)
        : AppColors.successColor(isDark);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline_rounded
                     : Icons.check_circle_outline_rounded,
            size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: GoogleFonts.inter(fontSize: 12, color: c))),
      ]),
    );
  }
}
