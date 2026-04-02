import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

// ── Cool Jar Icon (Snowflake) ─────────────────────────────────────────────────
class CoolJarIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const CoolJarIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? AppColors.coolColor(isDark);
    return SizedBox(width: size, height: size,
        child: CustomPaint(painter: _SnowflakePainter(c)));
  }
}

class _SnowflakePainter extends CustomPainter {
  final Color color;
  _SnowflakePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;
    final br = size.width * 0.18;

    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final ex = cx + r * math.cos(angle);
      final ey = cy + r * math.sin(angle);
      canvas.drawLine(Offset(cx, cy), Offset(ex, ey), p);

      final mid = r * 0.5;
      final mx = cx + mid * math.cos(angle);
      final my = cy + mid * math.sin(angle);
      for (final delta in [-math.pi / 4, math.pi / 4]) {
        final ba = angle + delta;
        canvas.drawLine(Offset(mx, my), Offset(mx + br * math.cos(ba), my + br * math.sin(ba)), p);
      }
    }

    canvas.drawCircle(Offset(cx, cy), size.width * 0.09,
        Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── PET Jar Icon (Bottle silhouette) ─────────────────────────────────────────
class PetJarIcon extends StatelessWidget {
  final double size;
  final Color? color;
  const PetJarIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? AppColors.petColor(isDark);
    return SizedBox(width: size, height: size,
        child: CustomPaint(painter: _BottlePainter(c)));
  }
}

class _BottlePainter extends CustomPainter {
  final Color color;
  _BottlePainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final w = s.width;
    final h = s.height;

    // Cap
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.36, h * 0.01, w * 0.28, h * 0.12),
            Radius.circular(w * 0.04)), fill);

    // Neck
    final neck = Path()
      ..moveTo(w * 0.36, h * 0.13)
      ..lineTo(w * 0.24, h * 0.28)
      ..lineTo(w * 0.76, h * 0.28)
      ..lineTo(w * 0.64, h * 0.13)
      ..close();
    canvas.drawPath(neck, fill);

    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.16, h * 0.28, w * 0.68, h * 0.69),
            Radius.circular(w * 0.14)), fill);

    // Highlight
    final hl = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.30, h * 0.36), Offset(w * 0.30, h * 0.80), hl);
    canvas.drawLine(Offset(w * 0.40, h * 0.34), Offset(w * 0.40, h * 0.50), hl);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Gradient Button ───────────────────────────────────────────────────────────
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final double height;
  final Widget? leadingIcon;
  final bool loading;

  const GradientButton({
    super.key, required this.label, this.onTap,
    this.gradient, this.height = 50, this.leadingIcon, this.loading = false,
  });

  @override
  State<GradientButton> createState() => _GradBtnState();
}

class _GradBtnState extends State<GradientButton> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _s = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _c.forward(),
    onTapUp: (_) { _c.reverse(); if (!widget.loading) widget.onTap?.call(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s,
      child: Container(height: widget.height,
        decoration: BoxDecoration(
          gradient: widget.loading
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
              : (widget.gradient ?? AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(12),
          boxShadow: widget.loading ? [] : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (widget.loading)
            const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else ...[
            if (widget.leadingIcon != null) ...[widget.leadingIcon!, const SizedBox(width: 8)],
            Text(widget.label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ]),
      ),
    ),
  );
}

// ── Quantity Stepper ──────────────────────────────────────────────────────────
class QuantityStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final Color? activeColor;
  final double size;

  const QuantityStepper({
    super.key, required this.value, required this.onChanged,
    this.min = 0, this.max = 99, this.activeColor, this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = activeColor ?? AppColors.primaryColor(isDark);
    final bg = isDark ? AppColors.surface2Dark : AppColors.surface2;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _SBtn(label: '−', enabled: value > min, color: c, bg: bg, size: size,
          onTap: value > min ? () => onChanged(value - 1) : null),
      SizedBox(width: size + 4,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Text('$value', key: ValueKey(value), textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(fontSize: size * 0.5, fontWeight: FontWeight.w600,
                color: value > 0 ? c : Theme.of(context).colorScheme.onSurface)),
        ),
      ),
      _SBtn(label: '+', enabled: value < max, color: c, bg: bg, size: size,
          onTap: value < max ? () => onChanged(value + 1) : null),
    ]);
  }
}

class _SBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final Color color, bg;
  final double size;
  final VoidCallback? onTap;
  const _SBtn({required this.label, required this.enabled, required this.color,
      required this.bg, required this.size, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: enabled ? color.withValues(alpha: 0.13) : bg,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: size, height: size,
        child: Center(child: Text(label,
          style: GoogleFonts.inter(fontSize: size * 0.5, fontWeight: FontWeight.w500,
              color: enabled ? color : AppColors.inkMuted))))),
  );
}

// ── App Card ──────────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final Border? border;

  const AppCard({super.key, required this.child, this.padding, this.onTap,
      this.color, this.radius = 16, this.border});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? (isDark ? AppColors.cardDark : AppColors.card);
    return GestureDetector(onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 12, offset: const Offset(0, 2))],
          border: border),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  const SectionHeader({super.key, required this.title, this.trailing, this.onTrailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
    child: Row(children: [
      Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
      if (trailing != null)
        GestureDetector(onTap: onTrailing,
          child: Text(trailing!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary))),
    ]),
  );
}

// ── Status Chip ───────────────────────────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

// ── Screen top header — consistent on every screen ───────────────────────────
class ScreenHeader extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const ScreenHeader({super.key, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkMuted)),
      ])),
      if (action != null) action!,
    ]),
  );
}

// ── Jar Count Badge ───────────────────────────────────────────────────────────
class JarBadge extends StatelessWidget {
  final String type; // cool | pet
  final int delivered;
  final int returned;
  const JarBadge({super.key, required this.type, required this.delivered, required this.returned});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = type == 'cool' ? AppColors.coolColor(isDark) : AppColors.petColor(isDark);
    if (delivered == 0 && returned == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 14, height: 14,
          child: type == 'cool' ? CoolJarIcon(size: 14, color: color) : PetJarIcon(size: 14, color: color)),
        const SizedBox(width: 4),
        if (delivered > 0) Text('↓$delivered',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        if (delivered > 0 && returned > 0) Text(' ', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: color)),
        if (returned > 0) Text('↑$returned',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.successColor(isDark))),
      ]),
    );
  }
}

// ── Amount Text ───────────────────────────────────────────────────────────────
class AmountText extends StatelessWidget {
  final double amount;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final String prefix;

  const AmountText(this.amount, {super.key, this.fontSize = 15,
      this.fontWeight = FontWeight.w600, this.color, this.prefix = '₹'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (amount < 0 ? AppColors.dangerColor(isDark) : AppColors.successColor(isDark));
    return Text('$prefix${amount.abs().toStringAsFixed(0)}',
        style: GoogleFonts.jetBrainsMono(fontSize: fontSize, fontWeight: fontWeight, color: c));
  }
}

// ── Customer Avatar ───────────────────────────────────────────────────────────
class CustomerAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color? color;

  const CustomerAvatar({super.key, required this.initials, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        color ?? AppColors.primary,
        (color ?? AppColors.primary).withValues(alpha: 0.65)
      ], begin: Alignment.topLeft, end: Alignment.bottomRight),
      shape: BoxShape.circle),
    child: Center(child: Text(initials,
        style: GoogleFonts.inter(fontSize: size * 0.33, fontWeight: FontWeight.w700, color: Colors.white))),
  );
}

// ── Sheet Helper ──────────────────────────────────────────────────────────────
Future<T?> showMrSheet<T>(BuildContext context,
    {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Padding(
        padding: MediaQuery.of(ctx).viewInsets,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(
                color: isDark ? AppColors.separatorDark : AppColors.separator,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Text(title, style: Theme.of(ctx).textTheme.headlineMedium)),
                IconButton(icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx)),
              ])),
            Divider(height: 1, color: isDark ? AppColors.separatorDark : AppColors.separator),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: builder(ctx),
            )),
          ]),
        ),
      );
    },
  );
}

// ── Confirm Dialog ────────────────────────────────────────────────────────────
Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message,
      String confirmLabel = 'Delete', Color? color}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Text(message, style: GoogleFonts.inter(fontSize: 14, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter())),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: color ?? AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text(confirmLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ── Toast ─────────────────────────────────────────────────────────────────────
void showToast(BuildContext context, String message,
    {bool success = false, bool error = false}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final color = error
      ? AppColors.dangerColor(isDark)
      : success ? AppColors.successColor(isDark)
      : (isDark ? AppColors.surface2Dark : AppColors.inkSoft);
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white)),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
    duration: const Duration(seconds: 2),
  ));
}

// ── Payment Mode Picker ───────────────────────────────────────────────────────
class PaymentModePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const PaymentModePicker({super.key, required this.selected, required this.onSelect});

  static const _modes = [
    ('cash', '💵', 'Cash'),
    ('upi', '📱', 'UPI'),
    ('bank', '🏦', 'Bank Transfer'),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: _modes.map(((String, String, String) m) {
      final active = selected == m.$1;
      final pr = Theme.of(context).colorScheme.primary;
      return GestureDetector(
        onTap: () => onSelect(m.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? pr.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? pr : Theme.of(context).dividerColor, width: 1.5),
          ),
          child: Text('${m.$2} ${m.$3}',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? pr : AppColors.inkMuted)),
        ),
      );
    }).toList(),
  );
}

// ── Field Label ───────────────────────────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  final String label;
  final String? hint;
  const FieldLabel(this.label, {super.key, this.hint});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.6, color: AppColors.inkMuted)),
      if (hint != null) ...[
        const SizedBox(width: 6),
        Text(hint!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkMuted)),
      ],
    ]),
  );
}

// ── Shimmer ───────────────────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const ShimmerBox({super.key, this.height = 80, this.width, this.radius = 12});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.height, width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + _c.value * 3, 0),
            end: Alignment(1 + _c.value * 3, 0),
            colors: isDark
                ? [AppColors.cardDark, AppColors.surface2Dark, AppColors.cardDark]
                : [AppColors.surface2, AppColors.separator, AppColors.surface2],
          ),
        ),
      ),
    );
  }
}
