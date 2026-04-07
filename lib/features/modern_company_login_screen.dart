import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

enum _View { signIn, signUp, forgotPw, verifyEmail }

class ModernCompanyLoginScreen extends StatefulWidget {
  final void Function({required bool goDirectly}) onAuthenticated;
  final VoidCallback? onBack;
  const ModernCompanyLoginScreen({
    super.key,
    required this.onAuthenticated,
    this.onBack,
  });

  @override
  State<ModernCompanyLoginScreen> createState() => _ModernCompanyLoginScreenState();
}

class _ModernCompanyLoginScreenState extends State<ModernCompanyLoginScreen>
    with TickerProviderStateMixin {

  _View   _view    = _View.signIn;
  bool    _loading = false;
  bool    _obscure = true;
  String? _error;
  String? _info;
  String? _verifyEmail;
  Timer?  _verifyTimer;
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
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    
    _slideCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    
    _glowCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3000));
    _glowAnim = Tween<double>(begin: 0.2, end: 0.6).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _glowCtrl.repeat(reverse: true);
    
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _pwCtrl.dispose();
    _pw2Ctrl.dispose();   _bizCtrl.dispose();
    _fadeCtrl.dispose();  _slideCtrl.dispose();
    _glowCtrl.dispose();
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

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    
    HapticFeedback.lightImpact();
    
    try {
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _pwCtrl.text);
      if (!c.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();
        setState(() { _loading = false; _error = 'Please verify your email first'; });
        return;
      }
      HapticFeedback.heavyImpact();
      widget.onAuthenticated(goDirectly: true);
    } on FirebaseAuthException catch (e) {
      setState(() { 
        _loading = false; 
        _error = e.message ?? 'Authentication failed';
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    
    HapticFeedback.lightImpact();
    
    try {
      final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _pwCtrl.text);
      await c.user!.sendEmailVerification();
      _verifyEmail = _emailCtrl.text.trim();
      _switchView(_View.verifyEmail);
      _startEmailVerificationCheck();
      HapticFeedback.heavyImpact();
    } on FirebaseAuthException catch (e) {
      setState(() { 
        _loading = false; 
        _error = e.message ?? 'Registration failed';
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _startEmailVerificationCheck() {
    _dotTimer?.cancel();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() { _dotCount = (_dotCount % 3) + 1; });
    });
    
    _verifyTimer?.cancel();
    _verifyTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.emailVerified) {
          _dotTimer?.cancel();
          _verifyTimer?.cancel();
          HapticFeedback.heavyImpact();
          widget.onAuthenticated(goDirectly: true);
        }
      } catch (_) {}
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    
    HapticFeedback.lightImpact();
    
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailCtrl.text.trim());
      setState(() { 
        _loading = false; 
        _info = 'Password reset email sent. Check your inbox.';
      });
      HapticFeedback.heavyImpact();
    } on FirebaseAuthException catch (e) {
      setState(() { 
        _loading = false; 
        _error = e.message ?? 'Failed to send reset email';
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA),
      body: Container(
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
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final w = constraints.maxWidth;
                  
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.08),
                    child: Column(
                      children: [
                        SizedBox(height: h * 0.08),
                        
                        // Animated Logo with glow
                        AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (context, child) {
                            return Column(
                              children: [
                                // Glow effect
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        primary.withValues(alpha: _glowAnim.value * 0.4),
                                        Colors.transparent,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                // Logo
                                Transform.scale(
                                  scale: 1.0 + (_glowAnim.value - 0.4) * 0.1,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          primary,
                                          primary.withValues(alpha: 0.8),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.business_rounded,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Admin Portal',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'Company Authentication',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        SizedBox(height: h * 0.06),

                        // Form content
                        _buildFormContent(isDark, primary),

                        SizedBox(height: h * 0.04),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent(bool isDark, Color primary) {
    switch (_view) {
      case _View.signIn:
        return signInForm(isDark: isDark, primary: primary);
      case _View.signUp:
        return signUpForm(isDark: isDark, primary: primary);
      case _View.forgotPw:
        return forgotPasswordForm(isDark: isDark, primary: primary);
      case _View.verifyEmail:
        return verifyEmailForm(isDark: isDark, primary: primary);
    }
  }

  Widget signInForm({required bool isDark, required Color primary}) {
    return Column(
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              _ModernTextField(
                controller: _emailCtrl,
                label: 'Email Address',
                hint: 'Enter your company email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
                isDark: isDark,
                icon: Icons.email_rounded,
              ),
              const SizedBox(height: 20),
              _ModernTextField(
                controller: _pwCtrl,
                label: 'Password',
                hint: 'Enter your password',
                obscureText: _obscure,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
                isDark: isDark,
                icon: Icons.lock_rounded,
                suffixIcon: _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                onSuffixIconTap: () => setState(() => _obscure = !_obscure),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),

        // Error/Info messages
        if (_error != null) _ErrorMessage(message: _error!, isDark: isDark),
        if (_info != null) _InfoMessage(message: _info!, isDark: isDark),
        
        const SizedBox(height: 32),

        // Sign In button
        _ModernButton(
          text: 'Sign In',
          onPressed: _signIn,
          isLoading: _loading,
          isDark: isDark,
          primary: primary,
        ),

        const SizedBox(height: 20),

        // Forgot password link
        GestureDetector(
          onTap: () => _switchView(_View.forgotPw),
          child: Text(
            'Forgot password?',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Sign up link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
              ),
            ),
            GestureDetector(
              onTap: () => _switchView(_View.signUp),
              child: Text(
                'Sign Up',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget signUpForm({required bool isDark, required Color primary}) {
    return Column(
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              _ModernTextField(
                controller: _emailCtrl,
                label: 'Email Address',
                hint: 'Enter your company email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
                isDark: isDark,
                icon: Icons.email_rounded,
              ),
              const SizedBox(height: 20),
              _ModernTextField(
                controller: _pwCtrl,
                label: 'Password',
                hint: 'Create a strong password',
                obscureText: _obscure,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
                isDark: isDark,
                icon: Icons.lock_rounded,
                suffixIcon: _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                onSuffixIconTap: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 20),
              _ModernTextField(
                controller: _pw2Ctrl,
                label: 'Confirm Password',
                hint: 'Re-enter your password',
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your password';
                  if (v != _pwCtrl.text) return 'Passwords do not match';
                  return null;
                },
                isDark: isDark,
                icon: Icons.lock_rounded,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),

        // Sign Up button
        _ModernButton(
          text: 'Create Account',
          onPressed: _signUp,
          isLoading: _loading,
          isDark: isDark,
          primary: primary,
        ),

        const SizedBox(height: 20),

        // Sign in link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
              ),
            ),
            GestureDetector(
              onTap: () => _switchView(_View.signIn),
              child: Text(
                'Sign In',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget forgotPasswordForm({required bool isDark, required Color primary}) {
    return Column(
      children: [
        Text(
          'Reset Password',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email address and we\'ll send you a link to reset your password.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),

        Form(
          key: _formKey,
          child: _ModernTextField(
            controller: _emailCtrl,
            label: 'Email Address',
            hint: 'Enter your company email',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
            isDark: isDark,
            icon: Icons.email_rounded,
          ),
        ),
        
        const SizedBox(height: 32),

        // Error/Info messages
        if (_error != null) _ErrorMessage(message: _error!, isDark: isDark),
        if (_info != null) _InfoMessage(message: _info!, isDark: isDark),
        
        if (_info == null) ...[
          const SizedBox(height: 32),
          _ModernButton(
            text: 'Send Reset Email',
            onPressed: _resetPassword,
            isLoading: _loading,
            isDark: isDark,
            primary: primary,
          ),
        ],

        const SizedBox(height: 20),

        // Back to sign in
        GestureDetector(
          onTap: () => _switchView(_View.signIn),
          child: Text(
            'Back to Sign In',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget verifyEmailForm({required bool isDark, required Color primary}) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primary.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.email_rounded,
                  size: 32,
                  color: primary,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < _dotCount ? primary : primary.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),

        Text(
          'Verify Your Email',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a verification email to:\n${_verifyEmail ?? ""}',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),

        Text(
          'Check your inbox and click the verification link to continue.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// Modern text field component
class _ModernTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool isDark;
  final IconData? icon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;

  const _ModernTextField({
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    required this.isDark,
    this.icon,
    this.suffixIcon,
    this.onSuffixIconTap,
  });

  @override
  State<_ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<_ModernTextField> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white : const Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: widget.isDark 
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasFocus
                  ? primary
                  : widget.isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: widget.isDark ? Colors.white : const Color(0xFF1C1C1E),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        widget.icon,
                        color: widget.isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF8E8E93),
                        size: 20,
                      ),
                    )
                  : null,
              suffixIcon: widget.suffixIcon != null
                  ? GestureDetector(
                      onTap: widget.onSuffixIconTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          widget.suffixIcon,
                          color: widget.isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF8E8E93),
                          size: 20,
                        ),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              hintStyle: GoogleFonts.inter(
                color: widget.isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFFC7C7CC),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            onTap: () => setState(() => _hasFocus = true),
            onTapOutside: (_) => setState(() => _hasFocus = false),
          ),
        ),
      ],
    );
  }
}

// Modern button component
class _ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDark;
  final Color primary;

  const _ModernButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
    required this.isDark,
    required this.primary,
  });

  @override
  State<_ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<_ModernButton>
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
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: isDisabled
                    ? widget.primary.withValues(alpha: 0.3)
                    : widget.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: !isDisabled
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
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.text,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

// Error message component
class _ErrorMessage extends StatelessWidget {
  final String message;
  final bool isDark;

  const _ErrorMessage({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerColor(isDark).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.dangerColor(isDark).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.dangerColor(isDark),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.dangerColor(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Info message component
class _InfoMessage extends StatelessWidget {
  final String message;
  final bool isDark;

  const _InfoMessage({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
