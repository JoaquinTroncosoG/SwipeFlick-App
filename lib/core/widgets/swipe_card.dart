import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

enum SwipeDirection { left, right }

class SwipeCardController {
  _SwipeCardState? _state;

  void _attach(_SwipeCardState state) => _state = state;
  void _detach() => _state = null;

  void swipeLeft() => _state?.animateSwipe(SwipeDirection.left);
  void swipeRight() => _state?.animateSwipe(SwipeDirection.right);
}

class SwipeCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final SwipeCardController? controller;
  final bool isTopCard;

  const SwipeCard({
    super.key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.controller,
    this.isTopCard = true,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> with SingleTickerProviderStateMixin {
  Offset _position = Offset.zero;
  double _angle = 0;
  late AnimationController _animController;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _angleAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void didUpdateWidget(covariant SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _animController.dispose();
    super.dispose();
  }

  void animateSwipe(SwipeDirection direction) {
    if (!widget.isTopCard) return;

    final targetX = direction == SwipeDirection.right ? 600.0 : -600.0;
    final targetAngle = direction == SwipeDirection.right ? 0.35 : -0.35;

    _positionAnimation = Tween<Offset>(
      begin: _position,
      end: Offset(targetX, _position.dy),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    _angleAnimation = Tween<double>(
      begin: _angle,
      end: targetAngle,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    _animController.forward(from: 0.0).then((_) {
      if (direction == SwipeDirection.right) {
        widget.onSwipeRight();
      } else {
        widget.onSwipeLeft();
      }
      _resetPosition();
    });
  }

  void _resetPosition() {
    setState(() {
      _position = Offset.zero;
      _angle = 0;
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.isTopCard) return;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isTopCard) return;
    setState(() {
      _position += details.delta;
      // Rotar proporcionalmente al desplazamiento horizontal
      _angle = (_position.dx / 320) * (pi / 14);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isTopCard) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.3;

    if (_position.dx > threshold) {
      animateSwipe(SwipeDirection.right);
    } else if (_position.dx < -threshold) {
      animateSwipe(SwipeDirection.left);
    } else {
      // Regresar al centro con rebote suave
      _positionAnimation = Tween<Offset>(
        begin: _position,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

      _angleAnimation = Tween<double>(
        begin: _angle,
        end: 0,
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

      _animController.forward(from: 0.0).then((_) {
        _resetPosition();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTopCard) {
      return widget.child;
    }

    final likeOpacity = (_position.dx / 120).clamp(0.0, 1.0);
    final nopeOpacity = (-_position.dx / 120).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final pos = _animController.isAnimating ? _positionAnimation.value : _position;
        final rot = _animController.isAnimating ? _angleAnimation.value : _angle;

        return Transform.translate(
          offset: pos,
          child: Transform.rotate(
            angle: rot,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          children: [
            widget.child,
            // Stamp "ME GUSTA" (Verde / Derecha)
            if (likeOpacity > 0.05)
              Positioned(
                top: 36,
                left: 28,
                child: Opacity(
                  opacity: likeOpacity,
                  child: Transform.rotate(
                    angle: -0.25,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success, width: 3),
                      ),
                      child: Text(
                        'ME GUSTA',
                        style: AppTextStyles.swipeBadge.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Stamp "PASAR" (Rojo / Izquierda)
            if (nopeOpacity > 0.05)
              Positioned(
                top: 36,
                right: 28,
                child: Opacity(
                  opacity: nopeOpacity,
                  child: Transform.rotate(
                    angle: 0.25,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error, width: 3),
                      ),
                      child: Text(
                        'PASAR',
                        style: AppTextStyles.swipeBadge.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
