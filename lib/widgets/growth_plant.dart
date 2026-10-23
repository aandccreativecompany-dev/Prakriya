import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The plant that grows with the user's progress. [stage] is 0 (seed) to 6
/// (fruiting tree). When [thirsty] the leaves fade and droop a little — it
/// recovers the moment the user does anything.
class GrowthPlant extends StatefulWidget {
  final int stage;
  final bool thirsty;
  final double height;
  final bool animate;
  const GrowthPlant({
    super.key,
    required this.stage,
    this.thirsty = false,
    this.height = 160,
    this.animate = true,
  });

  @override
  State<GrowthPlant> createState() => _GrowthPlantState();
}

class _GrowthPlantState extends State<GrowthPlant>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant GrowthPlant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: widget.height,
      width: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: GrowthPlantPainter(
            stage: widget.stage,
            thirsty: widget.thirsty,
            t: _controller.value,
            dark: dark,
          ),
        ),
      ),
    );
  }
}

class GrowthPlantPainter extends CustomPainter {
  final int stage;
  final bool thirsty;

  /// 0..1 loop used for a gentle sway.
  final double t;
  final bool dark;
  GrowthPlantPainter({
    required this.stage,
    required this.thirsty,
    required this.t,
    required this.dark,
  });

  Color get _leaf =>
      thirsty ? const Color(0xFF9AA77A) : const Color(0xFF4CAF6A);
  Color get _leafDark =>
      thirsty ? const Color(0xFF7F8C62) : const Color(0xFF2E8B57);
  static const Color _wood = Color(0xFF8B5E3C);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sway = math.sin(t * 2 * math.pi) * 0.035 * (thirsty ? 0.4 : 1.0);
    final droop = thirsty ? 0.16 : 0.0;
    final s = stage.clamp(0, 6);

    // Soft glow behind the plant.
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        (dark ? const Color(0xFFF2B93B) : const Color(0xFFFFE9A8))
            .withValues(alpha: dark ? 0.10 : 0.35),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.6), radius: w * 0.5));
    canvas.drawCircle(Offset(w / 2, h * 0.6), w * 0.5, glow);

    // Soil mound.
    final soil = Paint()..color = const Color(0xFF6B4423);
    final soilTop = Paint()..color = const Color(0xFF8A5A33);
    final ground = Offset(w / 2, h * 0.86);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w / 2, h * 0.9), width: w * 0.62, height: h * 0.14),
        soil);
    canvas.drawOval(
        Rect.fromCenter(center: ground, width: w * 0.5, height: h * 0.09), soilTop);

    canvas.save();
    // Sway around the base of the plant.
    canvas.translate(ground.dx, ground.dy);
    canvas.rotate(sway + droop * 0.3);
    canvas.translate(-ground.dx, -ground.dy);

    switch (s) {
      case 0:
        _seed(canvas, ground, w);
      case 1:
        _stem(canvas, ground, h * 0.16, w * 0.018);
        _leafPair(canvas, Offset(ground.dx, ground.dy - h * 0.16), w * 0.11, droop, 0.4);
      case 2:
        _stem(canvas, ground, h * 0.28, w * 0.022);
        _leafPair(canvas, Offset(ground.dx, ground.dy - h * 0.14), w * 0.12, droop, 0.5);
        _leafPair(canvas, Offset(ground.dx, ground.dy - h * 0.27), w * 0.13, droop, 0.45);
      case 3:
        _stem(canvas, ground, h * 0.42, w * 0.03);
        _leafPair(canvas, Offset(ground.dx, ground.dy - h * 0.12), w * 0.13, droop, 0.55);
        _leafPair(canvas, Offset(ground.dx, ground.dy - h * 0.23), w * 0.14, droop, 0.5);
        _leafPair(canvas, Offset(ground.dx, ground.dy - h * 0.34), w * 0.14, droop, 0.45);
        _leaf2(canvas, Offset(ground.dx, ground.dy - h * 0.42), w * 0.1, -math.pi / 2);
      default:
        _tree(canvas, ground, w, h, s, droop);
    }
    canvas.restore();
  }

  void _seed(Canvas canvas, Offset ground, double w) {
    final p = Paint()..color = const Color(0xFF5A3A1E);
    canvas.save();
    canvas.translate(ground.dx, ground.dy - w * 0.01);
    canvas.rotate(-0.4);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.12, height: w * 0.075), p);
    canvas.restore();
  }

  void _stem(Canvas canvas, Offset base, double length, double width) {
    final p = Paint()
      ..color = _leafDark
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(base, Offset(base.dx, base.dy - length), p);
  }

  void _leafPair(Canvas canvas, Offset at, double len, double droop, double lift) {
    _leaf2(canvas, at, len, -math.pi * lift + droop);
    _leaf2(canvas, at, len, -math.pi * (1 - lift) - droop);
  }

  /// One leaf growing from [at] in the direction [angle].
  void _leaf2(Canvas canvas, Offset at, double len, double angle) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.5, -len * 0.38, len, 0)
      ..quadraticBezierTo(len * 0.5, len * 0.38, 0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = _leaf);
    canvas.drawLine(
        Offset.zero,
        Offset(len * 0.9, 0),
        Paint()
          ..color = _leafDark.withValues(alpha: 0.7)
          ..strokeWidth = 1.2);
    canvas.restore();
  }

  void _tree(Canvas canvas, Offset ground, double w, double h, int s, double droop) {
    final trunkH = h * (0.34 + 0.02 * (s - 4));
    final trunkW = w * (0.05 + 0.008 * (s - 4));
    final trunk = Paint()
      ..color = _wood
      ..strokeWidth = trunkW
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final top = Offset(ground.dx, ground.dy - trunkH);
    canvas.drawLine(ground, top, trunk);
    // Two side branches.
    canvas.drawLine(Offset(ground.dx, ground.dy - trunkH * 0.55),
        Offset(ground.dx - w * 0.12, ground.dy - trunkH * 0.85), trunk..strokeWidth = trunkW * 0.55);
    canvas.drawLine(Offset(ground.dx, ground.dy - trunkH * 0.45),
        Offset(ground.dx + w * 0.13, ground.dy - trunkH * 0.78), trunk);

    // Canopy: overlapping circles, drooping a touch when thirsty.
    final r = w * (0.17 + 0.02 * (s - 4));
    final cy = top.dy - r * 0.35 + droop * h * 0.15;
    final centers = <Offset>[
      Offset(top.dx, cy - r * 0.55),
      Offset(top.dx - r * 0.95, cy + r * 0.1),
      Offset(top.dx + r * 0.95, cy + r * 0.1),
      Offset(top.dx - r * 0.45, cy + r * 0.2),
      Offset(top.dx + r * 0.45, cy + r * 0.2),
    ];
    final dark1 = Paint()..color = _leafDark;
    final light = Paint()..color = _leaf;
    for (final c in centers) {
      canvas.drawCircle(c, r * 0.82, dark1);
    }
    for (final c in centers) {
      canvas.drawCircle(c.translate(-r * 0.08, -r * 0.1), r * 0.62, light);
    }

    if (s == 5) {
      final petal = Paint()..color = const Color(0xFFF59AB4);
      final heart = Paint()..color = const Color(0xFFFFE17A);
      final spots = <Offset>[
        Offset(top.dx - r * 0.2, cy - r * 0.9),
        Offset(top.dx + r * 0.7, cy - r * 0.2),
        Offset(top.dx - r * 1.1, cy + r * 0.05),
        Offset(top.dx + r * 0.1, cy + r * 0.25),
        Offset(top.dx + r * 1.2, cy + r * 0.35),
        Offset(top.dx - r * 0.6, cy + r * 0.5),
      ];
      for (final p in spots) {
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * math.pi / 5;
          canvas.drawCircle(p + Offset(math.cos(a), math.sin(a)) * (r * 0.1), r * 0.075, petal);
        }
        canvas.drawCircle(p, r * 0.06, heart);
      }
    }
    if (s >= 6) {
      final fruit = Paint()..color = const Color(0xFFE5573F);
      final shine = Paint()..color = Colors.white.withValues(alpha: 0.6);
      final spots = <Offset>[
        Offset(top.dx - r * 0.3, cy - r * 0.7),
        Offset(top.dx + r * 0.8, cy - r * 0.05),
        Offset(top.dx - r * 1.1, cy + r * 0.2),
        Offset(top.dx + r * 0.2, cy + r * 0.4),
        Offset(top.dx + r * 1.15, cy + r * 0.45),
        Offset(top.dx - r * 0.6, cy + r * 0.55),
        Offset(top.dx + r * 0.35, cy - r * 0.45),
      ];
      for (final p in spots) {
        canvas.drawCircle(p, r * 0.12, fruit);
        canvas.drawCircle(p.translate(-r * 0.04, -r * 0.04), r * 0.035, shine);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GrowthPlantPainter old) =>
      old.stage != stage || old.thirsty != thirsty || old.t != t || old.dark != dark;
}
