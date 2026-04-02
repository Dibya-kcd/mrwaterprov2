// ══════════════════════════════════════════════════════════════════════════════
// splash_screen.dart  — Premium animated splash screen
//
// Pure Flutter animation — no video file, no loading delay, instant start.
// Removes the dependency on assets/videos/splash_video.mp4 entirely.
//
// Animation sequence (3.8 seconds total):
//   0.0s  Background gradient sweeps in
//   0.3s  Water-drop icon morphs in with ripple rings expanding outward
//   0.9s  Logo fades + slides up with ease
//   1.6s  Tagline types in character by character
//   2.4s  Loading bar sweeps across
//   3.2s  Everything fades out → app starts
//
// Compatible with _AppGate: same constructor API as old SplashScreen.
//   SplashScreen(nextScreen: ..., onComplete: ...)
//
// pubspec.yaml change: you can remove the video_player dependency and
// assets/videos/splash_video.mp4 — unless used elsewhere in the app.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Brand colours (self-contained — no AppColors import needed) ───────────────
const _kPrimary    = Color(0xFF1A6BFF);
const _kDeep       = Color(0xFF0A3FA0);
const _kCyan       = Color(0xFF0096C7);
const _kGlow       = Color(0xFF48AAFF);

// ── Total splash duration ─────────────────────────────────────────────────────
const _kTotalMs = 3800;

// ══════════════════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final VoidCallback? onComplete;
  const SplashScreen({super.key, required this.nextScreen, this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _master;
  late final AnimationController _ripple;   // loops continuously

  // ── Animations ───────────────────────────────────────────────────────────
  late final Animation<double> _bgFade;
  late final Animation<double> _dropScale;
  late final Animation<double> _dropOpacity;
  late final Animation<double> _logoOffset;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _tagline;
  late final Animation<double> _bar;
  late final Animation<double> _exitFade;
  // Ripple rings — staggered on the loop controller
  late final Animation<double> _r1, _r2, _r3;

  bool _navigating = false;
  bool _showSkip   = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ));

    _master = AnimationController(
        vsync: this, duration: const Duration(milliseconds: _kTotalMs));

    _ripple = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    _buildAnimations();
    _run();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_navigating) setState(() => _showSkip = true);
    });
  }

  // ── Helper: curved sub-animation on master ────────────────────────────────
  Animation<double> _seg(double from, double to,
      {Curve curve = Curves.easeOut}) =>
      CurvedAnimation(parent: _master,
          curve: Interval(from, to, curve: curve));

  // ── Helper: curved sub-animation on ripple loop ───────────────────────────
  Animation<double> _loop(double from, double to,
      {Curve curve = Curves.easeOut}) =>
      CurvedAnimation(parent: _ripple,
          curve: Interval(from, to, curve: curve));

  void _buildAnimations() {
    _bgFade      = _seg(0.00, 0.12, curve: Curves.easeIn);
    _dropOpacity = _seg(0.08, 0.24);
    _dropScale   = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.08, 0.32, curve: Curves.elasticOut)));
    _logoOffset  = Tween(begin: 30.0, end: 0.0).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.24, 0.50, curve: Curves.easeOutCubic)));
    _logoOpacity = _seg(0.24, 0.48);
    _tagline     = _seg(0.42, 0.68, curve: Curves.easeInOut);
    _bar         = _seg(0.62, 0.88, curve: Curves.easeInOut);
    _exitFade    = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _master,
            curve: const Interval(0.88, 1.0, curve: Curves.easeIn)));

    _r1 = _loop(0.00, 1.0);
    _r2 = _loop(0.25, 1.0);
    _r3 = _loop(0.50, 1.0);
  }

  Future<void> _run() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        precacheImage(const AssetImage('assets/images/mrwater_logo.png'), context);
      }
    });
    await _master.forward();
    if (mounted) _go();
  }

  void _go() {
    if (!mounted || _navigating) return;
    _navigating = true;
    if (widget.onComplete != null) { widget.onComplete!(); return; }
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => widget.nextScreen,
      transitionDuration: const Duration(milliseconds: 600),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _master.dispose();
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    // Vertical anchor — drop centre sits at 38% from top
    final dropCY = sz.height * 0.38;

    return Scaffold(
      backgroundColor: const Color(0xFF050E2A),
      body: AnimatedBuilder(
        animation: Listenable.merge([_master, _ripple]),
        builder: (ctx, _) => FadeTransition(
          opacity: _exitFade,
          child: Stack(fit: StackFit.expand, children: [

            // 1 ── Radial gradient background ─────────────────────────────
            Opacity(
              opacity: _bgFade.value,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.25),
                    radius: 1.45,
                    colors: [Color(0xFF0D2B6E), Color(0xFF061540), Color(0xFF020B26)],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 2 ── Static atmosphere particles ────────────────────────────
            Opacity(
              opacity: (_bgFade.value * 0.7).clamp(0.0, 1.0),
              child: CustomPaint(size: sz, painter: _DotsPainter()),
            ),

            // 3 ── Ripple rings ─────────────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              top: dropCY - 110,
              child: Opacity(
                opacity: _dropOpacity.value,
                child: Center(
                  child: CustomPaint(
                    size: const Size(220, 220),
                    painter: _RipplePainter(
                        r1: _r1.value, r2: _r2.value, r3: _r3.value),
                  ),
                ),
              ),
            ),

            // 4 ── Water-drop icon ─────────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              top: dropCY - 45,
              child: Center(
                child: Transform.scale(
                  scale: _dropScale.value.clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: _dropOpacity.value.clamp(0.0, 1.0),
                    child: Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_kGlow, _kPrimary, _kDeep],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _kPrimary.withValues(alpha: 0.55),
                              blurRadius: 40, spreadRadius: 4),
                          BoxShadow(color: _kCyan.withValues(alpha: 0.25),
                              blurRadius: 72, spreadRadius: 12),
                        ],
                      ),
                      child: const Icon(Icons.water_drop_rounded,
                          size: 46, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),

            // 5 ── Logo ────────────────────────────────────────────────────
            Positioned(
              left: 0, right: 0,
              top: dropCY + 60,
              child: Transform.translate(
                offset: Offset(0, _logoOffset.value),
                child: Opacity(
                  opacity: _logoOpacity.value,
                  child: Center(
                    child: Image.asset(
                      'assets/images/mrwater_logo.png',
                      height: 54,
                      filterQuality: FilterQuality.high,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text('MrWater',
                        style: GoogleFonts.dmSans(fontSize: 28,
                            fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),

            // 6 ── Tagline — typewriter reveal ──────────────────────────────
            Positioned(
              left: 32, right: 32,
              top: dropCY + 128,
              child: Opacity(
                opacity: (_tagline.value * 2.0).clamp(0.0, 1.0),
                child: Center(
                  child: _Typewriter(
                    text: 'Water delivery, simplified',
                    progress: _tagline.value,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.60),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),

            // 7 ── Progress bar ─────────────────────────────────────────────
            Positioned(
              bottom: sz.height * 0.12,
              left: 48, right: 48,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Track
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _bar.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kCyan, _kPrimary, _kGlow]),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: _kPrimary.withValues(alpha: 0.7),
                              blurRadius: 6, spreadRadius: 1),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Opacity(
                  opacity: (_bar.value * 3).clamp(0.0, 1.0),
                  child: Text(
                    _bar.value < 0.95 ? 'LOADING' : 'READY',
                    style: GoogleFonts.dmMono(
                      fontSize: 9.5,
                      color: Colors.white.withValues(alpha: 0.30),
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ]),
            ),

            // 8 ── Version stamp ───────────────────────────────────────────
            Positioned(
              bottom: 20, right: 20,
              child: Opacity(
                opacity: _logoOpacity.value * 0.35,
                child: Text('v2.1',
                    style: GoogleFonts.dmMono(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 1,
                    )),
              ),
            ),

            // 9 ── Skip button ──────────────────────────────────────────────
            if (_showSkip)
              Positioned(
                bottom: 32, right: 20,
                child: GestureDetector(
                  onTap: _go,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Skip',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.55)),
                    ]),
                  ),
                ),
              ),

          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RIPPLE PAINTER
// ══════════════════════════════════════════════════════════════════════════════
class _RipplePainter extends CustomPainter {
  final double r1, r2, r3;
  const _RipplePainter({required this.r1, required this.r2, required this.r3});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.47;
    _ring(canvas, c, r1, maxR);
    _ring(canvas, c, r2, maxR);
    _ring(canvas, c, r3, maxR);
  }

  void _ring(Canvas canvas, Offset c, double t, double maxR) {
    if (t <= 0) return;
    canvas.drawCircle(c, maxR * t,
        Paint()
          ..color = _kCyan.withValues(alpha: ((1 - t) * 0.32).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_RipplePainter o) =>
      o.r1 != r1 || o.r2 != r2 || o.r3 != r3;
}

// ══════════════════════════════════════════════════════════════════════════════
// DOTS PAINTER — fixed atmospheric particles
// ══════════════════════════════════════════════════════════════════════════════
class _DotsPainter extends CustomPainter {
  // Pre-generated with fixed seed so layout is identical every run
  static final _pts = _gen();
  static List<(double, double, double, double)> _gen() {
    final r = math.Random(7);
    return List.generate(42, (_) => (
      r.nextDouble(), r.nextDouble(),
      r.nextDouble() * 1.6 + 0.5,
      r.nextDouble() * 0.38 + 0.04,
    ));
  }

  @override
  void paint(Canvas canvas, Size s) {
    for (final (x, y, r, a) in _pts) {
      canvas.drawCircle(Offset(x * s.width, y * s.height), r,
          Paint()..color = Colors.white.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_DotsPainter _) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// TYPEWRITER TEXT
// ══════════════════════════════════════════════════════════════════════════════
class _Typewriter extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle style;
  const _Typewriter(
      {required this.text, required this.progress, required this.style});

  @override
  Widget build(BuildContext context) {
    final n = (text.length * progress).round().clamp(0, text.length);
    return Text(text.substring(0, n), style: style, textAlign: TextAlign.center);
  }
}
