import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'animation_utils.dart';

class ModernTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? initialValue;
  final bool obscureText;
  final TextInputType keyboardType;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;
  final int maxLines;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;

  const ModernTextField({
    super.key,
    this.label,
    this.hint,
    this.initialValue,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.controller,
    this.focusNode,
    this.autovalidateMode,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _hasError = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _validateField(String value) {
    if (widget.validator != null) {
      final error = widget.validator!(value);
      setState(() {
        _hasError = error != null;
        _errorText = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFocused = _focusNode.hasFocus;
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
              color: _hasError 
                  ? AppColors.dangerColor(isDark)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: AnimationUtils.fast,
          decoration: BoxDecoration(
            color: isDark 
                ? AppColors.surface2Dark 
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasError
                  ? AppColors.dangerColor(isDark)
                  : isFocused
                      ? primary
                      : isDark
                          ? AppColors.separatorDark
                          : AppColors.separator,
              width: _hasError || isFocused ? 1.5 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            enabled: widget.enabled,
            maxLines: widget.maxLines,
            onChanged: (value) {
              widget.onChanged?.call(value);
              if (widget.autovalidateMode == AutovalidateMode.always) {
                _validateField(value);
              }
            },
            onSubmitted: (value) {
              _validateField(value);
              widget.onSubmitted?.call(value);
            },
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        widget.prefixIcon,
                        color: _hasError
                            ? AppColors.dangerColor(isDark)
                            : isFocused
                                ? primary
                                : AppColors.inkMuted,
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
                          color: _hasError
                              ? AppColors.dangerColor(isDark)
                              : isFocused
                                  ? primary
                                  : AppColors.inkMuted,
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
                color: AppColors.inkMuted,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        if (_hasError && _errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 14,
                color: AppColors.dangerColor(isDark),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _errorText!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.dangerColor(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final double? width;
  final double height;
  final Widget? child;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.textColor,
    this.icon,
    this.width,
    this.height = 52,
    this.child,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationUtils.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.color ?? Theme.of(context).colorScheme.primary;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) {
              _controller.reverse();
              widget.onPressed?.call();
            },
            onTapCancel: () => _controller.reverse(),
            child: AnimatedContainer(
              duration: AnimationUtils.fast,
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.isOutlined
                    ? Colors.transparent
                    : isDisabled
                        ? primary.withValues(alpha: 0.3)
                        : primary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isOutlined
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.1))
                      : primary.withValues(alpha: 0.3),
                  width: widget.isOutlined ? 1 : 1.5,
                ),
                boxShadow: !widget.isOutlined && !isDisabled
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.textColor ?? Colors.white,
                          ),
                        ),
                      )
                    : widget.child ??
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                size: 18,
                                color: widget.textColor ??
                                    (widget.isOutlined
                                        ? primary
                                        : Colors.white),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.text,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: widget.textColor ??
                                    (widget.isOutlined
                                        ? primary
                                        : Colors.white),
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ModernChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;

  const ModernChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = color ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AnimationUtils.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : isDark
                  ? AppColors.surface2Dark
                  : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: isDark ? 0.5 : 0.3)
                : isDark
                    ? AppColors.separatorDark
                    : AppColors.separator,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? primary
                    : AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
