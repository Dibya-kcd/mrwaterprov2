import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/providers/app_state.dart';
import '../core/theme/app_colors.dart';

// Modern high-quality app logo with sleek design
class ModernAppLogo extends ConsumerWidget {
  final double height;
  final BoxFit fit;
  final bool onDark;
  final bool animated;
  final bool showGlow;
  final bool showText;
  
  const ModernAppLogo({
    super.key,
    this.height = 80,
    this.fit = BoxFit.contain,
    this.onDark = true,
    this.animated = true,
    this.showGlow = true,
    this.showText = false,
  });

  /// Full-width variant
  static Widget fullWidth({Key? key, bool animated = true}) => 
      _ModernAppLogoFullWidth(key: key, animated: animated);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    
    if (animated) {
      return _AnimatedModernLogo(
        height: height,
        primary: primary,
        onDark: onDark,
        showGlow: showGlow,
        showText: showText,
      );
    } else {
      return _StaticModernLogo(
        height: height,
        primary: primary,
        onDark: onDark,
        showGlow: showGlow,
        showText: showText,
      );
    }
  }
}

// Animated version of the modern logo
class _AnimatedModernLogo extends StatefulWidget {
  final double height;
  final Color primary;
  final bool onDark;
  final bool showGlow;
  final bool showText;

  const _AnimatedModernLogo({
    required this.height,
    required this.primary,
    required this.onDark,
    required this.showGlow,
    required this.showText,
  });

  @override
  State<_AnimatedModernLogo> createState() => _AnimatedModernLogoState();
}

class _AnimatedModernLogoState extends State<_AnimatedModernLogo>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;
  late final AnimationController _rotateController;
  late final Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    
    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);
    
    // Subtle rotation animation
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
    _rotateController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _glowAnimation, _rotateAnimation]),
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotateAnimation.value * 0.05,
          child: Transform.scale(
            scale: _pulseAnimation.value,
            child: _LogoContainer(
              height: widget.height,
              primary: widget.primary,
              onDark: widget.onDark,
              showGlow: widget.showGlow,
              glowIntensity: _glowAnimation.value,
              showText: widget.showText,
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LOGO PICKER WIDGET — for Settings
// ══════════════════════════════════════════════════════════════════════════════
class LogoPickerWidget extends ConsumerWidget {
  const LogoPickerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final primary  = Theme.of(context).colorScheme.primary;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: ModernAppLogo(
            height: 120,
            animated: true,
            showGlow: true,
            showText: true,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _PickerBtn(
                icon: Icons.photo_library_rounded,
                label: 'Choose Gallery',
                onTap: () => _pickLogo(ref, ImageSource.gallery),
                primary: primary,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PickerBtn(
                icon: Icons.camera_alt_rounded,
                label: 'Take Photo',
                onTap: () => _pickLogo(ref, ImageSource.camera),
                primary: primary,
                isDark: isDark,
              ),
            ),
          ],
        ),
        if (settings.logoLocalPath.isNotEmpty || settings.logoUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _resetLogo(ref),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset to Default Logo'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerColor(isDark),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickLogo(WidgetRef ref, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;

    final notifier = ref.read(settingsProvider.notifier);
    final updated = ref.read(settingsProvider).copyWith(
      logoLocalPath: file.path,
      logoUrl: '', // Clear network URL if local is picked
    );
    await notifier.save(updated);
  }

  Future<void> _resetLogo(WidgetRef ref) async {
    final notifier = ref.read(settingsProvider.notifier);
    final updated = ref.read(settingsProvider).copyWith(
      logoLocalPath: '',
      logoUrl: '',
    );
    await notifier.save(updated);
  }
}

class _PickerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color primary;
  final bool isDark;

  const _PickerBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Static version of the modern logo
class _StaticModernLogo extends StatelessWidget {
  final double height;
  final Color primary;
  final bool onDark;
  final bool showGlow;
  final bool showText;

  const _StaticModernLogo({
    required this.height,
    required this.primary,
    required this.onDark,
    required this.showGlow,
    required this.showText,
  });

  @override
  Widget build(BuildContext context) {
    return _LogoContainer(
      height: height,
      primary: primary,
      onDark: onDark,
      showGlow: showGlow,
      glowIntensity: 0.5,
      showText: showText,
    );
  }
}

// Main logo container component
class _LogoContainer extends StatelessWidget {
  final double height;
  final Color primary;
  final bool onDark;
  final bool showGlow;
  final double glowIntensity;
  final bool showText;

  const _LogoContainer({
    required this.height,
    required this.primary,
    required this.onDark,
    required this.showGlow,
    required this.glowIntensity,
    required this.showText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo with optional glow
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow effect
            if (showGlow)
              Container(
                width: height * 1.2,
                height: height * 1.2,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: glowIntensity * 0.4),
                      primary.withValues(alpha: glowIntensity * 0.2),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            
            // Main logo container
            Container(
              width: height,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary,
                    primary.withValues(alpha: 0.9),
                    primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(height * 0.25),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.4),
                    blurRadius: height * 0.25,
                    offset: Offset(0, height * 0.08),
                  ),
                  BoxShadow(
                    color: primary.withValues(alpha: 0.2),
                    blurRadius: height * 0.5,
                    offset: Offset(0, height * 0.16),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.water_drop_rounded,
                  size: height * 0.5,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Inner highlight
            Container(
              width: height * 0.8,
              height: height * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(height * 0.2),
              ),
            ),
          ],
        ),
        
        // Optional text
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            'MrWater Pro',
            style: GoogleFonts.inter(
              fontSize: height * 0.2,
              fontWeight: FontWeight.w800,
              color: onDark ? Colors.white : const Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Water Delivery Management',
            style: GoogleFonts.inter(
              fontSize: height * 0.1,
              fontWeight: FontWeight.w500,
              color: onDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
            ),
          ),
        ],
      ],
    );
  }
}

// Full-width variant
class _ModernAppLogoFullWidth extends ConsumerWidget {
  final bool animated;
  const _ModernAppLogoFullWidth({super.key, this.animated = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.of(context).size.width;
    final primary = Theme.of(context).colorScheme.primary;
    final height = w / 1.86;
    
    if (animated) {
      return _AnimatedModernLogo(
        height: 48,
        primary: primary,
        onDark: Theme.of(context).brightness == Brightness.dark,
        showGlow: true,
        showText: true,
      );
    } else {
      return _StaticModernLogo(
        height: height,
        primary: primary,
        onDark: Theme.of(context).brightness == Brightness.dark,
        showGlow: true,
        showText: true,
      );
    }
  }
}

// Minimal logo variant for small spaces
class MinimalAppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool animated;

  const MinimalAppLogo({
    super.key,
    this.size = 32,
    this.color,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Theme.of(context).colorScheme.primary;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Icon(
          Icons.water_drop_rounded,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Logo with text for headers
class LogoWithText extends ConsumerWidget {
  final double? logoSize;
  final String? customText;
  final bool showSubtitle;

  const LogoWithText({
    super.key,
    this.logoSize,
    this.customText,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = logoSize ?? 40;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MinimalAppLogo(
          size: size,
          animated: false,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              customText ?? 'MrWater Pro',
              style: GoogleFonts.inter(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                letterSpacing: -0.5,
              ),
            ),
            if (showSubtitle) ...[
              const SizedBox(height: 2),
              Text(
                'Water Delivery',
                style: GoogleFonts.inter(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// High-quality SVG-style logo painter
class ModernLogoPainter extends CustomPainter {
  final Color primaryColor;
  final double progress;
  final bool showGlow;

  ModernLogoPainter({
    required this.primaryColor,
    this.progress = 1.0,
    this.showGlow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle with gradient
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor,
          primaryColor.withValues(alpha: 0.8),
          primaryColor.withValues(alpha: 0.6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Water drop shape
    final dropPath = Path();
    final dropSize = radius * 0.6;
    
    // Create water drop path
    dropPath.moveTo(center.dx, center.dy - dropSize * 0.8);
    dropPath.quadraticBezierTo(
      center.dx - dropSize * 0.6, center.dy - dropSize * 0.3,
      center.dx - dropSize * 0.4, center.dy + dropSize * 0.2,
    );
    dropPath.quadraticBezierTo(
      center.dx, center.dy + dropSize * 0.6,
      center.dx, center.dy + dropSize * 0.8,
    );
    dropPath.quadraticBezierTo(
      center.dx, center.dy + dropSize * 0.6,
      center.dx + dropSize * 0.4, center.dy + dropSize * 0.2,
    );
    dropPath.quadraticBezierTo(
      center.dx + dropSize * 0.6, center.dy - dropSize * 0.3,
      center.dx, center.dy - dropSize * 0.8,
    );

    final dropPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Clip the drop based on progress
    if (progress < 1.0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(
        0, 
        size.height * (1 - progress), 
        size.width, 
        size.height * progress,
      ));
      canvas.drawPath(dropPath, dropPaint);
      canvas.restore();
    } else {
      canvas.drawPath(dropPath, dropPaint);
    }

    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final highlightPath = Path();
    highlightPath.addOval(Rect.fromCircle(
      center: Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
      radius: radius * 0.3,
    ));
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant ModernLogoPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
           oldDelegate.progress != progress ||
           oldDelegate.showGlow != showGlow;
  }
}

// Animated logo painter
class AnimatedModernLogoPainter extends StatefulWidget {
  final double size;
  final Color primaryColor;
  final Duration duration;

  const AnimatedModernLogoPainter({
    super.key,
    this.size = 100,
    required this.primaryColor,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<AnimatedModernLogoPainter> createState() => _AnimatedModernLogoPainterState();
}

class _AnimatedModernLogoPainterState extends State<AnimatedModernLogoPainter>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
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
      animation: _progressAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: ModernLogoPainter(
            primaryColor: widget.primaryColor,
            progress: _progressAnimation.value,
            showGlow: true,
          ),
        );
      },
    );
  }
}
