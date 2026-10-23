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

/// Whichever companion the user picked ('tree' or 'bird') at the same size.
class GrowthCompanion extends StatelessWidget {
  final String kind;
  final int stage;
  final bool idle;
  final double height;
  final bool animate;
  const GrowthCompanion({
    super.key,
    required this.kind,
    required this.stage,
    this.idle = false,
    this.height = 160,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    if (kind == 'bird') {
      return GrowthBird(stage: stage, sleepy: idle, height: height, animate: animate);
    }
    return GrowthPlant(stage: stage, thirsty: idle, height: height, animate: animate);
  }
}

/// The bird companion: an egg that hatches, grows feathers and finally
/// soars. When [sleepy] it dozes with closed eyes (never "dies" or shrinks).
class GrowthBird extends StatefulWidget {
  final int stage;
  final bool sleepy;
  final double height;
  final bool animate;
  const GrowthBird({
    super.key,
    required this.stage,
    this.sleepy = false,
    this.height = 160,
    this.animate = true,
  });

  @override
  State<GrowthBird> createState() => _GrowthBirdState();
}

class _GrowthBirdState extends State<GrowthBird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant GrowthBird oldWidget) {
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
          painter: GrowthBirdPainter(
            stage: widget.stage,
            sleepy: widget.sleepy,
            t: _controller.value,
            dark: dark,
          ),
        ),
      ),
    );
  }
}

class GrowthBirdPainter extends CustomPainter {
  final int stage;
  final bool sleepy;
  final double t;
  final bool dark;
  GrowthBirdPainter({
    required this.stage,
    required this.sleepy,
    required this.t,
    required this.dark,
  });

  static const Color _twig = Color(0xFF8B5E3C);

  Color _tone(Color c) =>
      sleepy ? Color.lerp(c, const Color(0xFF9A9AA8), 0.45)! : c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = stage.clamp(0, 6);
    final bob = math.sin(t * 2 * math.pi) * h * (sleepy ? 0.004 : 0.012);

    final glow = Paint()
      ..shader = RadialGradient(colors: [
        (dark ? const Color(0xFFF2B93B) : const Color(0xFFFFE9A8))
            .withValues(alpha: dark ? 0.10 : 0.35),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.58), radius: w * 0.5));
    canvas.drawCircle(Offset(w / 2, h * 0.58), w * 0.5, glow);

    if (s <= 3) {
      _nest(canvas, w, h);
    } else {
      _branch(canvas, w, h);
    }

    final perchY = h * 0.80;
    switch (s) {
      case 0:
        _egg(canvas, Offset(w / 2, perchY - h * 0.07 + bob), w * 0.095, h * 0.12);
      case 1:
        _hatchling(canvas, w, h, perchY, bob);
      default:
        _bird(canvas, w, h, perchY, bob, s);
    }

    if (sleepy && s >= 1) {
      final tp = TextPainter(
        text: TextSpan(
            text: 'z z',
            style: TextStyle(
                color: dark ? Colors.white70 : const Color(0xFF6B6B80),
                fontSize: w * 0.09,
                fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w * 0.66, h * 0.18 - bob * 2));
    }
  }

  void _nest(Canvas canvas, double w, double h) {
    final dark1 = Paint()..color = const Color(0xFF6B4423);
    final straw = Paint()
      ..color = const Color(0xFFC9A36B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w / 2, h * 0.86), width: w * 0.62, height: h * 0.17),
        dark1);
    for (var i = 0; i < 7; i++) {
      final x = w * (0.26 + i * 0.08);
      canvas.drawArc(
          Rect.fromCenter(center: Offset(x, h * 0.855), width: w * 0.2, height: h * 0.07),
          0.2 + i * 0.25,
          2.2,
          false,
          straw);
    }
  }

  void _branch(Canvas canvas, double w, double h) {
    final p = Paint()
      ..color = _twig
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.14, h * 0.84), Offset(w * 0.86, h * 0.82), p);
    final leaf = Paint()..color = _tone(const Color(0xFF4CAF6A));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.2, h * 0.79), width: w * 0.1, height: h * 0.045), leaf);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.8, h * 0.78), width: w * 0.1, height: h * 0.045), leaf);
  }

  void _egg(Canvas canvas, Offset c, double rx, double ry) {
    canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2),
        Paint()..color = _tone(const Color(0xFFF6EBD3)));
    final spot = Paint()..color = _tone(const Color(0xFFD9B98C));
    canvas.drawCircle(c + Offset(-rx * 0.35, -ry * 0.2), rx * 0.16, spot);
    canvas.drawCircle(c + Offset(rx * 0.3, ry * 0.25), rx * 0.2, spot);
    canvas.drawCircle(c + Offset(rx * 0.05, -ry * 0.55), rx * 0.12, spot);
  }

  void _hatchling(Canvas canvas, double w, double h, double perchY, double bob) {
    // Cracked shell with a small head popping out.
    final shell = Paint()..color = _tone(const Color(0xFFF6EBD3));
    final center = Offset(w / 2, perchY - h * 0.05 + bob);
    final head = center + Offset(0, -h * 0.07);
    canvas.drawCircle(head, w * 0.085, Paint()..color = _tone(const Color(0xFFF7D154)));
    _beak(canvas, head + Offset(w * 0.075, w * 0.01), w * 0.04, false);
    _eye(canvas, head + Offset(w * 0.025, -w * 0.015), w * 0.016);
    // Bottom half of the shell with a zig-zag edge.
    final path = Path()
      ..moveTo(center.dx - w * 0.1, center.dy)
      ..lineTo(center.dx - w * 0.06, center.dy - h * 0.03)
      ..lineTo(center.dx - w * 0.02, center.dy)
      ..lineTo(center.dx + w * 0.02, center.dy - h * 0.03)
      ..lineTo(center.dx + w * 0.06, center.dy)
      ..lineTo(center.dx + w * 0.1, center.dy - h * 0.03)
      ..arcToPoint(Offset(center.dx - w * 0.1, center.dy),
          radius: Radius.elliptical(w * 0.1, h * 0.1), clockwise: true)
      ..close();
    canvas.drawPath(path, shell);
  }

  void _beak(Canvas canvas, Offset at, double len, bool open) {
    final c = Paint()..color = _tone(const Color(0xFFF59E2F));
    final top = Path()
      ..moveTo(at.dx, at.dy - len * 0.35)
      ..lineTo(at.dx + len, at.dy - (open ? len * 0.2 : 0))
      ..lineTo(at.dx, at.dy + (open ? 0 : len * 0.3))
      ..close();
    canvas.drawPath(top, c);
    if (open) {
      final low = Path()
        ..moveTo(at.dx, at.dy + len * 0.05)
        ..lineTo(at.dx + len * 0.85, at.dy + len * 0.45)
        ..lineTo(at.dx, at.dy + len * 0.4)
        ..close();
      canvas.drawPath(low, c);
    }
  }

  void _eye(Canvas canvas, Offset at, double r) {
    if (sleepy) {
      canvas.drawArc(Rect.fromCircle(center: at, radius: r * 1.4), 0.2, 2.7, false,
          Paint()
            ..color = const Color(0xFF2B2140)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.7
            ..strokeCap = StrokeCap.round);
      return;
    }
    canvas.drawCircle(at, r, Paint()..color = const Color(0xFF2B2140));
    canvas.drawCircle(at + Offset(r * 0.3, -r * 0.3), r * 0.35, Paint()..color = Colors.white);
  }

  void _bird(Canvas canvas, double w, double h, double perchY, double bob, int s) {
    final k = w * (0.26 + 0.026 * (s - 2));
    final bodyC = <Color>[
      const Color(0xFFF7D154), // chick
      const Color(0xFFF2A65A), // fledgling
      const Color(0xFF5B9BD5), // young bird
      const Color(0xFF4F7FD6), // songbird
      const Color(0xFF7A55D9), // soaring
    ][s - 2];
    final bellyC = <Color>[
      const Color(0xFFFFF0A8),
      const Color(0xFFFFE3B8),
      const Color(0xFFF4F1E8),
      const Color(0xFFF2784B),
      const Color(0xFFF2B93B),
    ][s - 2];
    final body = _tone(bodyC);
    final belly = _tone(bellyC);
    final dkBody = Color.lerp(body, Colors.black, 0.22)!;

    // Body sits on the perch.
    final c = Offset(w / 2 - k * 0.05, perchY - k * 0.5 + bob);

    // Legs.
    final legs = Paint()
      ..color = _tone(const Color(0xFFE08A2E))
      ..strokeWidth = k * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + Offset(-k * 0.1, k * 0.38), c + Offset(-k * 0.1, k * 0.52), legs);
    canvas.drawLine(c + Offset(k * 0.12, k * 0.38), c + Offset(k * 0.12, k * 0.52), legs);

    // Raised wing behind the body for the soaring stage.
    if (s >= 6) {
      final big = Path()
        ..moveTo(c.dx - k * 0.1, c.dy - k * 0.1)
        ..quadraticBezierTo(c.dx - k * 0.9, c.dy - k * 1.15, c.dx - k * 0.3, c.dy - k * 1.0)
        ..quadraticBezierTo(c.dx - k * 0.5, c.dy - k * 0.55, c.dx + k * 0.05, c.dy - k * 0.3)
        ..close();
      canvas.drawPath(big, Paint()..color = dkBody);
      final big2 = Path()
        ..moveTo(c.dx + k * 0.1, c.dy - k * 0.15)
        ..quadraticBezierTo(c.dx + k * 0.5, c.dy - k * 1.25, c.dx + k * 0.9, c.dy - k * 0.95)
        ..quadraticBezierTo(c.dx + k * 0.65, c.dy - k * 0.55, c.dx + k * 0.2, c.dy - k * 0.25)
        ..close();
      canvas.drawPath(big2, Paint()..color = body.withValues(alpha: 0.85));
    }

    // Tail.
    if (s >= 3) {
      final tail = Path()
        ..moveTo(c.dx - k * 0.4, c.dy)
        ..lineTo(c.dx - k * (0.8 + 0.06 * (s - 3)), c.dy - k * 0.18)
        ..lineTo(c.dx - k * (0.78 + 0.06 * (s - 3)), c.dy + k * 0.2)
        ..close();
      canvas.drawPath(tail, Paint()..color = dkBody);
    }

    // Body + belly.
    canvas.drawOval(
        Rect.fromCenter(center: c, width: k * 1.0, height: k * 0.86), Paint()..color = body);
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(k * 0.1, k * 0.12), width: k * 0.62, height: k * 0.5),
        Paint()..color = belly);

    // Head.
    final head = c + Offset(k * 0.32, -k * 0.42);
    // Tuft / crest.
    if (s >= 3) {
      final crest = Paint()
        ..color = s >= 6 ? _tone(const Color(0xFFF2B93B)) : dkBody
        ..strokeWidth = k * 0.07
        ..strokeCap = StrokeCap.round;
      final n = s >= 6 ? 3 : 2;
      for (var i = 0; i < n; i++) {
        canvas.drawLine(head + Offset(-k * 0.05 + i * k * 0.07, -k * 0.28),
            head + Offset(-k * 0.16 + i * k * 0.1, -k * (0.5 + 0.05 * i)), crest);
      }
    }
    canvas.drawCircle(head, k * 0.34, Paint()..color = body);
    _beak(canvas, head + Offset(k * 0.3, k * 0.02), k * 0.22, s == 5 && !sleepy);
    _eye(canvas, head + Offset(k * 0.1, -k * 0.06), k * 0.06);
    if (s >= 2) {
      canvas.drawCircle(head + Offset(k * 0.14, k * 0.1), k * 0.05,
          Paint()..color = const Color(0xFFF08BA0).withValues(alpha: 0.55));
    }

    // Folded wing over the body (not for the soaring pose's raised wing).
    final wing = Path()
      ..moveTo(c.dx - k * 0.18, c.dy - k * 0.12)
      ..quadraticBezierTo(c.dx - k * 0.02, c.dy - k * 0.3, c.dx + k * 0.22, c.dy - k * 0.04)
      ..quadraticBezierTo(c.dx + k * 0.05, c.dy + k * 0.32, c.dx - k * 0.3, c.dy + k * 0.18)
      ..close();
    canvas.drawPath(wing, Paint()..color = dkBody);

    // Songbird's notes and the soaring bird's sparkles.
    if (s == 5 && !sleepy) {
      final tp = TextPainter(
        text: TextSpan(
            text: '♪ ♫',
            style: TextStyle(
                color: const Color(0xFFF2B93B),
                fontSize: w * 0.09,
                fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w * 0.68, h * 0.17 - bob * 3));
    }
    if (s >= 6 && !sleepy) {
      final sp = Paint()..color = const Color(0xFFFFE17A);
      for (final o in <Offset>[
        Offset(w * 0.2, h * 0.22),
        Offset(w * 0.8, h * 0.3),
        Offset(w * 0.72, h * 0.12),
        Offset(w * 0.3, h * 0.1),
      ]) {
        canvas.drawCircle(o.translate(0, bob), w * 0.012, sp);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GrowthBirdPainter old) =>
      old.stage != stage || old.sleepy != sleepy || old.t != t || old.dark != dark;
}
