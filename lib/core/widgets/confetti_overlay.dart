import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool isPlaying;

  const ConfettiOverlay({
    super.key,
    required this.child,
    required this.isPlaying,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addListener(() {
        setState(() {
          for (final p in _particles) {
            p.update();
          }
        });
      });

    if (widget.isPlaying) {
      _startBurst();
    }
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _startBurst();
    }
  }

  void _startBurst() {
    _particles.clear();
    const colors = [
      AppColors.accent,
      AppColors.accentHover,
      Colors.white,
      AppColors.success,
      Colors.amber,
    ];

    for (int i = 0; i < 65; i++) {
      _particles.add(
        _ConfettiParticle(
          x: 0.5 + (_rnd.nextDouble() - 0.5) * 0.4,
          y: 0.4,
          vx: (_rnd.nextDouble() - 0.5) * 1.6,
          vy: -_rnd.nextDouble() * 2.2 - 0.8,
          size: _rnd.nextDouble() * 8 + 4,
          color: colors[_rnd.nextInt(colors.length)],
          rotation: _rnd.nextDouble() * 2 * pi,
          vRot: (_rnd.nextDouble() - 0.5) * 0.2,
        ),
      );
    }
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_controller.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(particles: _particles, opacity: 1.0 - _controller.value),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double rotation;
  double vRot;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.vRot,
  });

  void update() {
    x += vx * 0.01;
    y += vy * 0.01;
    vy += 0.04; // Gravedad
    rotation += vRot;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double opacity;

  _ConfettiPainter({required this.particles, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      final cx = p.x * size.width;
      final cy = p.y * size.height;
      canvas.translate(cx, cy);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
