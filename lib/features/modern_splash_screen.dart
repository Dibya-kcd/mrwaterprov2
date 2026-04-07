import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ModernSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final VoidCallback? onComplete;
  const ModernSplashScreen({super.key, required this.nextScreen, this.onComplete});

  @override
  State<ModernSplashScreen> createState() => _ModernSplashScreenState();
}

class _ModernSplashScreenState extends State<ModernSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoOpacityAnimation;
  late final Animation<double> _textSlideAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _particleAnimation;
  late final AnimationController _waveController;
  late final Animation<double> _waveAnimation;

  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Main animation controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });

    // Logo scale animation
    _logoScaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    // Logo opacity animation
    _logoOpacityAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.1, 0.8, curve: Curves.easeInOut),
    );

    // Text slide animation
    _textSlideAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    );

    // Glow animation
    _glowAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
    );

    // Particle animation
    _particleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
    );

    // Wave animation controller
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    );

    _waveController.repeat(reverse: true);
    _mainController.forward();
  }

  void _finish() {
    if (_isCompleted) return;
    _isCompleted = true;
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF000000),
                    const Color(0xFF1A1A1A),
                    primary.withValues(alpha: 0.2),
                    const Color(0xFF2D2D2D),
                  ]
                : [
                    const Color(0xFF007AFF),
                    const Color(0xFF5AC8FA),
                    const Color(0xFF5856D6),
                    const Color(0xFFAF52DE),
                  ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            _ParticleBackground(
              animation: _particleAnimation,
              isDark: isDark,
            ),

            // Wave effects
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WavePainter(
                    waveAnimation: _waveAnimation.value,
                    primary: primary,
                    isDark: isDark,
                  ),
                  child: Container(),
                );
              },
            ),

            // Main content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with glow effect
                    _AnimatedLogo(
                      scaleAnimation: _logoScaleAnimation,
                      opacityAnimation: _logoOpacityAnimation,
                      glowAnimation: _glowAnimation,
                      primary: primary,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 40),

                    // App name and tagline
                    _AnimatedText(
                      slideAnimation: _textSlideAnimation,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 60),

                    // Loading indicator
                    _LoadingIndicator(
                      animation: _textSlideAnimation,
                      primary: primary,
                    ),
                  ],
                ),
              ),
            ),

            // Floating elements
            _FloatingElements(
              animation: _particleAnimation,
              primary: primary,
            ),
          ],
        ),
      ),
    );
  }
}

// Animated logo component
class _AnimatedLogo extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;
  final Animation<double> glowAnimation;
  final Color primary;
  final bool isDark;

  const _AnimatedLogo({
    required this.scaleAnimation,
    required this.opacityAnimation,
    required this.glowAnimation,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scaleAnimation, opacityAnimation, glowAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: Opacity(
            opacity: opacityAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow effect
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        primary.withValues(alpha: glowAnimation.value * 0.6),
                        primary.withValues(alpha: glowAnimation.value * 0.3),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                // Outer ring
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary,
                        primary.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 0),
                      ),
                      BoxShadow(
                        color: primary.withValues(alpha: 0.2),
                        blurRadius: 60,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
                // Inner circle with water drop icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                       child: Icon(
                         Icons.water_drop_rounded,
                         size: 60,
                         color: primary,
                       ),
                     ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Animated text component
class _AnimatedText extends StatelessWidget {
  final Animation<double> slideAnimation;
  final bool isDark;

  const _AnimatedText({
    required this.slideAnimation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - slideAnimation.value)),
          child: Opacity(
            opacity: slideAnimation.value,
            child: Column(
              children: [
                Text(
                  'MrWater Pro',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Premium Water Delivery Management',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Loading indicator component
class _LoadingIndicator extends StatelessWidget {
  final Animation<double> animation;
  final Color primary;

  const _LoadingIndicator({
    required this.animation,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Column(
            children: [
              SizedBox(
                width: 200,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: animation.value,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing...',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Particle background component
class _ParticleBackground extends StatelessWidget {
  final Animation<double> animation;
  final bool isDark;

  const _ParticleBackground({
    required this.animation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            animation: animation.value,
            isDark: isDark,
          ),
          child: Container(),
        );
      },
    );
  }
}

// Floating elements component
class _FloatingElements extends StatelessWidget {
  final Animation<double> animation;
  final Color primary;

  const _FloatingElements({
    required this.animation,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          children: [
            // Top right floating circle
            Positioned(
              top: 100,
              right: 50,
              child: Transform.translate(
                offset: Offset(
                  20 * (1 - animation.value),
                  -30 * (1 - animation.value),
                ),
                child: Opacity(
                  opacity: animation.value * 0.3,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          primary.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            // Bottom left floating circle
            Positioned(
              bottom: 150,
              left: 40,
              child: Transform.translate(
                offset: Offset(
                  -25 * (1 - animation.value),
                  20 * (1 - animation.value),
                ),
                child: Opacity(
                  opacity: animation.value * 0.2,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            // Top left small circle
            Positioned(
              top: 200,
              left: 80,
              child: Transform.translate(
                offset: Offset(
                  -15 * (1 - animation.value),
                  -15 * (1 - animation.value),
                ),
                child: Opacity(
                  opacity: animation.value * 0.25,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          primary.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Custom painter for wave effects
class _WavePainter extends CustomPainter {
  final double waveAnimation;
  final Color primary;
  final bool isDark;

  _WavePainter({
    required this.waveAnimation,
    required this.primary,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primary.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Create wave pattern
    const waveHeight = 50.0;
    const waveFrequency = 0.02;
    final wavePhase = waveAnimation * 2 * 3.14159;

    path.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x += 5) {
      final y = size.height - 100 - 
                waveHeight * (1 + waveAnimation) * 
                (0.5 + 0.5 * math.sin(x * waveFrequency + wavePhase));
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);

    // Second wave
    final paint2 = Paint()
      ..color = primary.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x += 5) {
      final y = size.height - 150 - 
                waveHeight * 0.7 * (1 + waveAnimation) * 
                (0.5 + 0.5 * math.sin(x * waveFrequency + wavePhase + math.pi));
      path2.lineTo(x, y);
    }
    
    path2.lineTo(size.width, size.height);
    path2.close();
    
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.waveAnimation != waveAnimation;
  }
}

// Custom painter for particles
class _ParticlePainter extends CustomPainter {
  final double animation;
  final bool isDark;

  _ParticlePainter({
    required this.animation,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaint = Paint()
      ..color = isDark 
          ? Colors.white.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // Create floating particles
    final particles = <Offset>[];
    final random = math.Random(42); // Fixed seed for consistent positions

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      particles.add(Offset(x, y));
    }

    // Draw particles with animation
    for (int i = 0; i < particles.length; i++) {
      final particle = particles[i];
      final size = 2.0 + 3.0 * math.sin(animation * 2 * math.pi + i);
      final opacity = 0.3 + 0.3 * math.sin(animation * 3 * math.pi + i * 0.5);
      
      particlePaint.color = (isDark 
          ? Colors.white 
          : Colors.white).withValues(alpha: opacity);
      
      canvas.drawCircle(particle, size, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
