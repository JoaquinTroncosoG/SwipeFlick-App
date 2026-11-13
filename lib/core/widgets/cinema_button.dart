import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

enum CinemaButtonVariant { primary, secondary, ghost, outline }

class CinemaButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CinemaButtonVariant variant;
  final bool isLoading;
  final double? width;
  final double height;

  const CinemaButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.variant = CinemaButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.height = 50,
  });

  @override
  State<CinemaButton> createState() => _CinemaButtonState();
}

class _CinemaButtonState extends State<CinemaButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Border? border;

    switch (widget.variant) {
      case CinemaButtonVariant.primary:
        bg = AppColors.accent;
        fg = AppColors.background;
        break;
      case CinemaButtonVariant.secondary:
        bg = AppColors.surfaceElevated;
        fg = AppColors.textPrimary;
        border = Border.all(color: AppColors.surfaceBorder, width: 1);
        break;
      case CinemaButtonVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.textPrimary;
        border = Border.all(color: AppColors.accent, width: 1.5);
        break;
      case CinemaButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.accent;
        break;
    }

    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: isEnabled ? widget.onPressed : null,
        child: Container(
          width: widget.width,
          height: widget.height,
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          decoration: BoxDecoration(
            color: isEnabled ? bg : bg.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: border,
            boxShadow: widget.variant == CinemaButtonVariant.primary && isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 19, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: AppTextStyles.button.copyWith(
                          color: fg,
                          fontWeight: widget.variant == CinemaButtonVariant.primary
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
