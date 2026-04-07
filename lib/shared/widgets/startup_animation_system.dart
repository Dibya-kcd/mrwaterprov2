import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Comprehensive startup animation system with micro-interactions
class StartupAnimationSystem extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool enableHaptics;

  const StartupAnimationSystem({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.enableHaptics = true,
  });

  @override
  State<StartupAnimationSystem> createState() => _StartupAnimationSystemState();
}

class _StartupAnimationSystemState extends State<StartupAnimationSystem>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final List<AnimationController> _particleControllers;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main animation controller
    _mainController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Individual animations
    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    );

    _slideAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    );

    _glowAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.3, 0.7, curve: Curves.easeInOut),
    );

    // Particle animation controllers
    _particleControllers = List.generate(8, (index) {
      return AnimationController(
        duration: Duration(milliseconds: 1000 + index * 200),
        vsync: this,
      );
    });

    _startAnimations();
  }

  void _startAnimations() async {
    // Start main animation
    _mainController.forward();

    // Start particle animations with delays
    for (int i = 0; i < _particleControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _particleControllers[i].repeat(reverse: true);
        }
      });
    }

    // Haptic feedback
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    for (final controller in _particleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeAnimation,
        _scaleAnimation,
        _slideAnimation,
        _glowAnimation,
        ..._particleControllers,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - _slideAnimation.value)),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Stack(
                children: [
                  // Main content
                  widget.child,
                  
                  // Particle effects
                  ..._particleControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return _ParticleEffect(
                      animation: controller,
                      index: index,
                      glowIntensity: _glowAnimation.value,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Particle effect component
class _ParticleEffect extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final double glowIntensity;

  const _ParticleEffect({
    required this.animation,
    required this.index,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final positions = [
      const Offset(0.1, 0.2),
      const Offset(0.8, 0.1),
      const Offset(0.9, 0.7),
      const Offset(0.2, 0.8),
      const Offset(0.5, 0.1),
      const Offset(0.1, 0.6),
      const Offset(0.7, 0.9),
      const Offset(0.3, 0.4),
    ];

    final position = positions[index % positions.length];
    
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticlePainter(
              position: position,
              animation: animation.value,
              glowIntensity: glowIntensity,
              primary: primary,
              particleSize: 4.0 + index * 2.0,
            ),
          );
        },
      ),
    );
  }
}

// Custom painter for particles
class _ParticlePainter extends CustomPainter {
  final Offset position;
  final double animation;
  final double glowIntensity;
  final Color primary;
  final double particleSize;

  _ParticlePainter({
    required this.position,
    required this.animation,
    required this.glowIntensity,
    required this.primary,
    required this.particleSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final particleX = position.dx * size.width;
    final particleY = position.dy * size.height;
    
    // Calculate particle position with animation
    final offsetX = 50 * (1 - animation) * (position.dx - 0.5);
    final offsetY = 50 * (1 - animation) * (position.dy - 0.5);
    
    final particlePosition = Offset(particleX + offsetX, particleY + offsetY);
    
    // Draw glow
    final glowPaint = Paint()
      ..color = primary.withValues(alpha: glowIntensity * 0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    canvas.drawCircle(particlePosition, particleSize * 2, glowPaint);
    
    // Draw particle
    final particlePaint = Paint()
      ..color = primary.withValues(alpha: glowIntensity * 0.6)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(particlePosition, particleSize, particlePaint);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.animation != animation ||
           oldDelegate.glowIntensity != glowIntensity;
  }
}

// Micro-interaction button wrapper
class MicroInteractionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Duration animationDuration;
  final bool enableHaptics;
  final bool enableScale;
  final bool enableGlow;

  const MicroInteractionButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.animationDuration = const Duration(milliseconds: 150),
    this.enableHaptics = true,
    this.enableScale = true,
    this.enableGlow = true,
  });

  @override
  State<MicroInteractionButton> createState() => _MicroInteractionButtonState();
}

class _MicroInteractionButtonState extends State<MicroInteractionButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _glowController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleTapDown() {
    if (widget.enableScale) _scaleController.forward();
    if (widget.enableGlow) _glowController.forward();
    if (widget.enableHaptics) HapticFeedback.lightImpact();
  }

  void _handleTapUp() {
    if (widget.enableScale) _scaleController.reverse();
    if (widget.enableGlow) _glowController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (widget.enableScale) _scaleController.reverse();
    if (widget.enableGlow) _glowController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _handleTapDown(),
      onTapUp: (_) => _handleTapUp(),
      onTapCancel: () => _handleTapCancel(),
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: widget.enableGlow
                  ? BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(
                            alpha: _glowAnimation.value * 0.3,
                          ),
                          blurRadius: 8 * _glowAnimation.value,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : null,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

// Animated container with entrance effect
class AnimatedEntranceContainer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Offset slideOffset;
  final bool enableFade;
  final bool enableScale;
  final Curve curve;

  const AnimatedEntranceContainer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.slideOffset = const Offset(0, 0.3),
    this.enableFade = true,
    this.enableScale = false,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedEntranceContainer> createState() => _AnimatedEntranceContainerState();
}

class _AnimatedEntranceContainerState extends State<AnimatedEntranceContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: widget.slideOffset * (1 - _animation.value),
          child: Transform.scale(
            scale: widget.enableScale ? (0.8 + 0.2 * _animation.value) : 1.0,
            child: Opacity(
              opacity: widget.enableFade ? _animation.value : 1.0,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

// Ripple effect overlay
class RippleEffectOverlay extends StatefulWidget {
  final Widget child;
  final Color? rippleColor;
  final bool enableOnTap;

  const RippleEffectOverlay({
    super.key,
    required this.child,
    this.rippleColor,
    this.enableOnTap = true,
  });

  @override
  State<RippleEffectOverlay> createState() => _RippleEffectOverlayState();
}

class _RippleEffectOverlayState extends State<RippleEffectOverlay>
    with TickerProviderStateMixin {
  final List<RippleData> _ripples = [];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.enableOnTap)
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) => _addRipple(details.globalPosition),
              child: CustomPaint(
                painter: _RipplePainter(
                  ripples: _ripples,
                  rippleColor: widget.rippleColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _addRipple(Offset position) {
    final ripple = RippleData(
      position: position,
      controller: AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    ripple.animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: ripple.controller, curve: Curves.easeOut),
    );

    setState(() => _ripples.add(ripple));
    
    ripple.controller.forward().then((_) {
      if (mounted) {
        setState(() => _ripples.remove(ripple));
        ripple.controller.dispose();
      }
    });
  }
}

class RippleData {
  final Offset position;
  final AnimationController controller;
  Animation<double>? animation;

  RippleData({
    required this.position,
    required this.controller,
  });
}

class _RipplePainter extends CustomPainter {
  final List<RippleData> ripples;
  final Color rippleColor;

  _RipplePainter({
    required this.ripples,
    required this.rippleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      final paint = Paint()
        ..color = rippleColor.withValues(alpha: (1 - (ripple.animation?.value ?? 0)) * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final radius = 100.0 * (ripple.animation?.value ?? 0);
      canvas.drawCircle(ripple.position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.ripples.length != ripples.length;
  }
}

// Loading skeleton with shimmer effect
class ShimmerLoadingContainer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const ShimmerLoadingContainer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerLoadingContainer> createState() => _ShimmerLoadingContainerState();
}

class _ShimmerLoadingContainerState extends State<ShimmerLoadingContainer>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              widget.baseColor ?? Colors.grey.withValues(alpha: 0.2),
              widget.highlightColor ?? Colors.grey.withValues(alpha: 0.4),
              widget.baseColor ?? Colors.grey.withValues(alpha: 0.2),
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(-1.0 + _animation.value, 0),
            end: Alignment(1.0 + _animation.value, 0),
          ).createShader(bounds),
          child: widget.child,
        );
      },
    );
  }
}

// Parallax scrolling effect
class ParallaxContainer extends StatefulWidget {
  final Widget child;
  final double parallaxFactor;
  final Axis direction;

  const ParallaxContainer({
    super.key,
    required this.child,
    this.parallaxFactor = 0.5,
    this.direction = Axis.vertical,
  });

  @override
  State<ParallaxContainer> createState() => _ParallaxContainerState();
}

class _ParallaxContainerState extends State<ParallaxContainer> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        setState(() {});
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverFillRemaining(
            child: Transform.translate(
              offset: widget.direction == Axis.vertical
                  ? Offset(0, -_scrollController.offset * widget.parallaxFactor)
                  : Offset(-_scrollController.offset * widget.parallaxFactor, 0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
