import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/company_session.dart';
import '../core/services/rtdb_user_datasource.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/pin_hash_util.dart';
import 'app_logo.dart';

// ══════════════════════════════════════════════════════════════════════════════
// company_login_screen.dart — HIDDEN admin portal
// Access: long-press logo on PIN screen for 2 seconds.
// ══════════════════════════════════════════════════════════════════════════════

enum _View { signIn, signUp, forgotPw, verifyEmail }

class CompanyLoginScreen extends StatefulWidget {
  final void Function({required bool goDirectly}) onAuthenticated;
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
  String? _verifyEmail;
  Timer?  _verifyTimer;
  // Dots animation for verify screen
  int     _dotCount = 1;
  Timer?  _dotTimer;

  final _emailCtrl = TextEditingController();
  final _pwCtrl    = TextEditingController();
  final _pw2Ctrl   = TextEditingController();
  final _bizCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 280));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 280));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _pwCtrl.dispose();
    _pw2Ctrl.dispose();   _bizCtrl.dispose();
    _fadeCtrl.dispose();  _slideCtrl.dispose();
    _verifyTimer?.cancel();
    _dotTimer?.cancel();
    super.dispose();
  }

  void _switchView(_View v) {
    if (_view == v) return;
    _dotTimer?.cancel();
    setState(() { _view = v; _error = null; _info = null; _loading = false; });
    _fadeCtrl.forward(from: 0);
    _slideCtrl.forward(from: 0);
  }

  // ── Sign In ───────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _pwCtrl.text);
      if (!c.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();
        setState(() { _loading = false; _error = 'email-not-verified'; });
        return;
      }
      CompanySession.init(c.user!.uid,
          name: c.user!.displayName ?? c.user!.email ?? '');
      // ── DO NOT call _ensureOwnerRecord here ──────────────────────────────
      // The owner record is created ONCE during sign-up (_onVerified).
      // Calling it on every sign-in risks creating duplicate records on new
      // devices if the Firebase stream hasn't loaded yet.
      if (mounted) _showSuccess();
    } on FirebaseAuthException catch (e) { _fail(e.code); }
    catch (e) { _fail('unknown'); }
  }

  // ── Sign Up ───────────────────────────────────────────────────────────────
  // ── Sign Up ───────────────────────────────────────────────────────────────
  // Single-owner enforcement: block if a company already exists in Firebase.
  // Owner record creation happens ONCE in _onVerified() after email is confirmed.
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pwCtrl.text != _pw2Ctrl.text) { _fail('passwords-mismatch'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      // Guard: one Firebase project = one business owner
      final alreadyExists = await RTDBUserDataSource.instance.anyCompanyExists();
      if (alreadyExists) {
        if (mounted) setState(() { _loading = false; _error = 'A business account already exists. Please sign in instead.'; });
        return;
      }
      final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _pwCtrl.text);
      await c.user!.updateDisplayName(_bizCtrl.text.trim());
      await c.user!.sendEmailVerification();
      // ⚠️ Do NOT call _ensureOwnerRecord here.
      // CompanySession is not yet initialised — email is unverified.
      // Owner record is created ONCE in _onVerified() after verification + CompanySession.init().
      // ⚠️ Do NOT sign out — keep signed in so timer can call user.reload()
      if (mounted) {
        setState(() {
          _loading     = false;
          _view        = _View.verifyEmail;
          _verifyEmail = c.user!.email;
          _error       = null;
          _info        = null;
        });
        _startDotAnimation();
        _startVerificationCheck();
      }
    } on FirebaseAuthException catch (e) { _fail(e.code); }
  }

  // ── Auto-check every 3 s while user is signed in ─────────────────────────
  void _startVerificationCheck() {
    _verifyTimer?.cancel();
    _verifyTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;           // signed out — stop
        await user.reload();
        final fresh = FirebaseAuth.instance.currentUser;
        if (fresh == null) return;
        if (fresh.emailVerified) {
          _verifyTimer?.cancel();
          _dotTimer?.cancel();
          if (mounted) _onVerified(fresh);
        }
      } catch (e) {
        debugPrint('Verify-check error: $e');
      }
    });
  }

  // ── Manual "I've verified" button ────────────────────────────────────────
  Future<void> _manualVerificationCheck() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // User was signed out — ask them to sign in
        setState(() {
          _loading = false;
          _error   = 'Session expired. Please sign in with your verified email.';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _switchView(_View.signIn);
        });
        return;
      }
      await user.reload();
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh != null && fresh.emailVerified) {
        _verifyTimer?.cancel();
        _dotTimer?.cancel();
        _onVerified(fresh);
      } else {
        setState(() {
          _loading = false;
          _error   = 'Not verified yet — check your inbox (and spam folder).';
        });
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Could not check status. Try again.'; });
    }
  }

  // ── Resend verification email ─────────────────────────────────────────────
  Future<void> _resendVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (mounted) setState(() => _info = 'Verification email resent!');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to resend. Please wait a moment.');
    }
  }

  // ── Called when verification confirmed ───────────────────────────────────
  void _onVerified(User user) {
    if (!mounted) return;
    setState(() => _loading = false);
    _showVerificationSuccess(() async {
      CompanySession.init(user.uid,
          name: user.displayName ?? user.email ?? '');
      await _ensureOwnerRecord(user);
      if (mounted) _showSuccess();
    });
  }

  // ── Animated dots for "checking..." ──────────────────────────────────────
  void _startDotAnimation() {
    _dotTimer?.cancel();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount % 3) + 1);
    });
  }

  // ── Verification success dialog ───────────────────────────────────────────
  void _showVerificationSuccess(VoidCallback onContinue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final okC    = AppColors.successColor(isDark);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: okC.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.verified_rounded, size: 40, color: okC),
          ),
          const SizedBox(height: 16),
          Text('Email Verified! 🎉',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Your account is ready.\nSetting up your workspace…',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton(
                onPressed: () { Navigator.pop(ctx); onContinue(); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: okC, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Continue →', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success bottom sheet ──────────────────────────────────────────────────
  void _showSuccess() {
    if (!mounted) return;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final okC     = AppColors.successColor(isDark);
    final name    = CompanySession.companyName.isNotEmpty
        ? CompanySession.companyName : 'Owner';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2035) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28, offset: const Offset(0, -6))],
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle bar
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.inkMuted.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              // Avatar + name
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(color: okC.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded, size: 38, color: okC),
              ),
              const SizedBox(height: 12),
              Text('Welcome back!',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(name,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 28),
              // Open Admin Panel
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                  label: Text('Open Admin Panel',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    widget.onAuthenticated(goDirectly: true);
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Use PIN Screen
              SizedBox(width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.pin_rounded, size: 18, color: primary),
                  label: Text('Use PIN Screen',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primary.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    widget.onAuthenticated(goDirectly: false);
                  },
                ),
              ),
              const SizedBox(height: 16),
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

  // ── Forgot username dialog ────────────────────────────────────────────────
  void _showForgotUsernameHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Forgot username?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          'Your username is the email address you registered with.\n\n'
          'Check the welcome email you received when signing up, or use "Forgot password?" to regain access.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  // ── Send password reset ───────────────────────────────────────────────────
  Future<void> _sendReset() async {
    if (_emailCtrl.text.trim().isEmpty) { _fail('missing-email'); return; }
    setState(() { _loading = true; _error = null; _info = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailCtrl.text.trim());
      setState(() {
        _loading = false;
        _info = '✅ Reset link sent to ${_emailCtrl.text.trim()}.\nCheck your inbox and spam folder.';
      });
    } on FirebaseAuthException catch (e) { _fail(e.code); }
  }

  // ── Owner record setup ────────────────────────────────────────────────────
  // Called ONCE: only from _onVerified() after email confirmed + CompanySession.init().
  // NEVER called on sign-in — sign-in only reads existing data.
  //
  // DB structure enforced here:
  //   companies/{uid}/users/{uid}   ← owner user record
  //   metadata/owner_registered     ← single-owner guard flag
  Future<void> _ensureOwnerRecord(User user) async {
    // CompanySession must already be initialised before we reach here.
    // Path: companies/{uid}/users/{uid}
    final data = await RTDBUserDataSource.instance.getUser(user.uid, user.uid);

    if (data == null) {
      // First registration on this Firebase account — create ONE company node.
      debugPrint('[Auth] Creating owner record at companies/${user.uid}/users/${user.uid}');
      await RTDBUserDataSource.instance.setUser(user.uid, user.uid, {
        'id':          user.uid,
        'name':        user.displayName ?? user.email ?? 'Owner',
        'email':       user.email ?? '',
        'phone':       user.phoneNumber ?? '',
        'pin':         '',
        'pinHash':     '',
        'pinSalt':     user.uid,
        'role':        'OWNER',
        'isActive':    true,
        'permissions': [
          'dashboard', 'transactions', 'customers', 'inventory',
          'load_unload', 'payments', 'reports', 'notifications',
          'settings', 'expenses', 'smart_entry',
        ],
      });
      // Mark that an owner is registered so future signups are blocked.
      await RTDBUserDataSource.instance.markOwnerRegistered();
      await _promptOwnerPinSetup(user);
      return;
    }

    // Record already exists — only fix role if somehow wrong (defensive).
    final role = (data['role'] ?? '').toString().toUpperCase();
    if (role != 'OWNER') {
      debugPrint('[Auth] Fixing incorrect role for owner ${user.email}: was $role');
      await RTDBUserDataSource.instance.updateUser(user.uid, user.uid, {'role': 'OWNER'});
    }

    // Prompt for PIN if missing (e.g. user skipped on first registration).
    final hasPin = (data['pinHash'] as String?)?.isNotEmpty ?? false;
    if (!hasPin) await _promptOwnerPinSetup(user);
  }

  Future<void> _promptOwnerPinSetup(User user) async {
    final pinCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? formError;
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Create Owner PIN', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Create a 4–6 digit PIN to unlock the app on shared devices.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.4)),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Owner PIN', counterText: ''),
              maxLength: 6,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
              maxLength: 6,
            ),
            if (formError != null) ...[
              const SizedBox(height: 10),
              Text(formError!, style: TextStyle(color: AppColors.dangerColor(false), fontSize: 12)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Skip')),
            ElevatedButton(
              onPressed: () {
                final pin = pinCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();
                final err = PinHashUtil.validate(pin);
                if (err != null) { setS(() => formError = err); return; }
                if (pin != confirm) { setS(() => formError = 'PINs must match.'); return; }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
    if (created == true && pinCtrl.text.trim().isNotEmpty) {
      final pin  = pinCtrl.text.trim();
      final hash = PinHashUtil.hash(pin: pin, salt: user.uid);
      await RTDBUserDataSource.instance.updateUser(user.uid, user.uid,
          {'pin': '', 'pinHash': hash, 'pinSalt': user.uid});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner PIN saved. Use it on the PIN screen next time.')));
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
        'too-many-requests'    => 'Too many attempts — please wait a moment.',
        'missing-email'        => 'Enter your email address first.',
        'email-not-verified'   => 'Please verify your email before signing in.\nCheck your inbox.',
        _                      => 'Something went wrong. Please try again.',
      };
    });
  }

  Future<void> _confirmFirebaseSignOut(BuildContext sheetCtx) async {
    Navigator.of(sheetCtx).pop();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Your app data stays safe. You\'ll need to sign in again to access the admin portal.',
            style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.inkMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Sign Out', style: GoogleFonts.inter(
                  color: AppColors.dangerColor(false), fontWeight: FontWeight.w700))),
        ],
      ),
    ) ?? false;
    if (!ok || !mounted) return;
    await CompanySession.firebaseSignOut();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final bg      = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: widget.onBack != null
          ? AppBar(
              backgroundColor: Colors.transparent, elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18,
                    color: isDark ? Colors.white70 : Colors.black54),
                onPressed: widget.onBack,
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(children: [

              // ── Logo ───────────────────────────────────────────────────────
              const AppLogo(height: 60),
              const SizedBox(height: 10),

              // ── Portal badge ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primary.withValues(alpha: 0.18)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 13, color: primary),
                  const SizedBox(width: 6),
                  Text('Business Owner Portal',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: primary)),
                ]),
              ),
              const SizedBox(height: 28),

              // ── Form card ──────────────────────────────────────────────────
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2035) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                      blurRadius: 28, offset: const Offset(0, 8))],
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Form(key: _formKey, child: _buildForm(isDark, primary)),
                  ),
                ),
              ),

              // ── Bottom links ───────────────────────────────────────────────
              const SizedBox(height: 20),
              if (_view == _View.signIn)
                GestureDetector(
                  onTap: () => _switchView(_View.signUp),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'New business? ',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
                    TextSpan(text: 'Create an account →',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: primary)),
                  ])),
                )
              else if (_view != _View.verifyEmail)
                GestureDetector(
                  onTap: () => _switchView(_View.signIn),
                  child: Text('← Back to Sign In',
                      style: GoogleFonts.inter(fontSize: 13, color: primary, fontWeight: FontWeight.w600)),
                ),

              const SizedBox(height: 12),
              Text('Authorised business owners only',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark, Color primary) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Title + subtitle
      Text(_title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(_subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
      const SizedBox(height: 24),

      // ── Verify Email state ─────────────────────────────────────────────────
      if (_view == _View.verifyEmail) ...[
        // Email chip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.18)),
          ),
          child: Row(children: [
            Icon(Icons.email_outlined, size: 16, color: primary),
            const SizedBox(width: 10),
            Expanded(child: Text(_verifyEmail ?? '',
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 16),

        // Auto-checking indicator
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.14)),
          ),
          child: Row(children: [
            SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary)),
            const SizedBox(width: 12),
            Expanded(child: Text(
              'Waiting for verification${'.' * _dotCount}',
              style: GoogleFonts.inter(fontSize: 13, color: primary, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 12),

        // Steps
        const _VerifyStep(num: '1', text: 'Open the email we sent to your inbox'),
        const SizedBox(height: 8),
        const _VerifyStep(num: '2', text: 'Click the verification link in the email'),
        const SizedBox(height: 8),
        const _VerifyStep(num: '3', text: 'This screen will update automatically'),
        const SizedBox(height: 16),

        // Resend link
        Center(
          child: GestureDetector(
            onTap: _resendVerification,
            child: Text('Didn\'t receive it? Resend email',
                style: GoogleFonts.inter(fontSize: 12, color: primary,
                    decoration: TextDecoration.underline)),
          ),
        ),
        const SizedBox(height: 16),

        // Error / info banners
        if (_error != null) ...[
          _Banner(text: _error!, isError: true, isDark: isDark),
          const SizedBox(height: 12),
        ],
        if (_info != null) ...[
          _Banner(text: _info!, isError: false, isDark: isDark),
          const SizedBox(height: 12),
        ],

        // Manual check button
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _manualVerificationCheck,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary, foregroundColor: Colors.white,
              disabledBackgroundColor: primary.withValues(alpha: 0.40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('I\'ve Verified My Email',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),

      ] else ...[

        // ── Standard form fields ───────────────────────────────────────────
        if (_view == _View.signUp) ...[
          _lbl('Business Name'),
          _TF(ctrl: _bizCtrl, hint: 'My Water Supply Co.',
              icon: Icons.business_rounded,
              validator: (v) => v?.trim().isEmpty == true ? 'Enter business name' : null),
          const SizedBox(height: 16),
        ],

        _lbl('Email Address'),
        _TF(ctrl: _emailCtrl, hint: 'owner@example.com',
            icon: Icons.email_outlined, type: TextInputType.emailAddress,
            validator: (v) => v?.trim().isEmpty == true ? 'Enter email' : null),
        const SizedBox(height: 16),

        if (_view != _View.forgotPw) ...[
          _lbl('Password'),
          _TF(
            ctrl: _pwCtrl, hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            onObscure: () => setState(() => _obscure = !_obscure),
            action: _view == _View.signIn ? TextInputAction.done : TextInputAction.next,
            onSubmit: _view == _View.signIn ? (_) => _signIn() : null,
            validator: (v) => v?.isEmpty == true ? 'Enter password' : null,
          ),
          const SizedBox(height: 16),
        ],

        if (_view == _View.signUp) ...[
          _lbl('Confirm Password'),
          _TF(ctrl: _pw2Ctrl, hint: '••••••••',
              icon: Icons.lock_outline_rounded, obscure: _obscure,
              action: TextInputAction.done,
              validator: (v) => v?.isEmpty == true ? 'Confirm your password' : null),
          const SizedBox(height: 16),
        ],

        // Error / info banners
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_btnLabel,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),

        // Forgot links — sign in view only
        if (_view == _View.signIn) ...[
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: () => _switchView(_View.forgotPw),
              child: Text('Forgot password?',
                  style: GoogleFonts.inter(fontSize: 13, color: primary, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: _showForgotUsernameHelp,
              child: Text('Forgot username?',
                  style: GoogleFonts.inter(fontSize: 13, color: primary, fontWeight: FontWeight.w500)),
            ),
          ]),
        ],

        // Forgot pw hint
        if (_view == _View.forgotPw && _info == null) ...[
          const SizedBox(height: 10),
          Center(
            child: Text('Enter your email and tap Send Reset Link.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkMuted)),
          ),
        ],
      ],
    ]);
  }

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
  );

  String get _title => switch (_view) {
    _View.signIn      => 'Welcome back',
    _View.signUp      => 'Create account',
    _View.forgotPw    => 'Reset password',
    _View.verifyEmail => 'Verify your email',
  };
  String get _subtitle => switch (_view) {
    _View.signIn      => 'Sign in to your business account',
    _View.signUp      => 'Register your water delivery business',
    _View.forgotPw    => 'We\'ll send you a reset link',
    _View.verifyEmail => 'One last step — check your inbox',
  };
  String get _btnLabel => switch (_view) {
    _View.signIn      => 'Sign In',
    _View.signUp      => 'Create Account',
    _View.forgotPw    => 'Send Reset Link',
    _View.verifyEmail => 'I\'ve Verified My Email',
  };
  VoidCallback get _action => switch (_view) {
    _View.signIn      => _signIn,
    _View.signUp      => _signUp,
    _View.forgotPw    => _sendReset,
    _View.verifyEmail => _manualVerificationCheck,
  };
}

// ── Verify step row ───────────────────────────────────────────────────────────
class _VerifyStep extends StatelessWidget {
  final String num, text;
  const _VerifyStep({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Center(child: Text(num,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: primary))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted, height: 1.4))),
    ]);
  }
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
    final c = isError ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: c, height: 1.4))),
      ]),
    );
  }
}
