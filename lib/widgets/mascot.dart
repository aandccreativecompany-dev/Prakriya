import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Pip — the little bird who climbs the gold steps. The app's mascot: it
/// matches the bird companion, and the same artwork is the launcher icon.
///
/// [PipPainter] draws the whole scene in a 1024 x 1024 design space, scaled to
/// whatever square it is given. `t` runs 0..1: the steps rise one by one, Pip
/// hops up them, lands on top, blinks, and the sparkles twinkle. At `t == 1`
/// it is the finished, resting picture.
class PipPainter extends CustomPainter {
  final double t;
  final bool glow;
  const PipPainter(this.t, {this.glow = true});

  static const _steps = <Rect>[
    Rect.fromLTWH(150, 760, 190, 130),
    Rect.fromLTWH(318, 650, 190, 240),
    Rect.fromLTWH(486, 540, 190, 350),
    Rect.fromLTWH(654, 430, 220, 460),
  ];
  static const _stepColors = <List<Color>>[
    [Color(0xFFF6C453), Color(0xFFC98A12)],
    [Color(0xFFF6C453), Color(0xFFC98A12)],
    [Color(0xFFFFE08A), Color(0xFFE7A71E)],
    [Color(0xFFFFF1C4), Color(0xFFF6CB5E)],
  ];
  static const _r = 112.0; // Pip's body radius

  double _seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  /// Where Pip's body centre rests on step [i].
  Offset _perch(int i) {
    final r = _steps[i];
    return Offset(r.center.dx, r.top - _r + 14);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 1024.0;
    canvas.save();
    canvas.translate((size.width - 1024 * s) / 2, (size.height - 1024 * s) / 2);
    canvas.scale(s);

    // Soft sun glow behind the top step.
    if (glow) {
      final g = Paint()
        ..shader = ui.Gradient.radial(const Offset(760, 300), 330, [
          const Color(0xFFFFD66B).withValues(alpha: 0.5 * _seg(0.1, 0.8)),
          const Color(0xFFFFD66B).withValues(alpha: 0),
        ]);
      canvas.drawCircle(const Offset(760, 300), 330, g);
    }

    // Twinkling sparkles.
    final tw = t * 2 * math.pi * 2;
    _star(canvas, 250, 300, 34, 0.55 + 0.35 * math.sin(tw), _seg(0.3, 0.6));
    _star(canvas, 150, 500, 22, 0.45 + 0.3 * math.sin(tw + 1.6), _seg(0.35, 0.65));
    _star(canvas, 560, 230, 26, 0.5 + 0.3 * math.sin(tw + 3.1), _seg(0.4, 0.7));
    _star(canvas, 900, 160, 20, 0.45 + 0.3 * math.sin(tw + 4.5), _seg(0.45, 0.75));

    // The steps rise one after another.
    for (var i = 0; i < _steps.length; i++) {
      final p = Curves.easeOutBack.transform(_seg(0.02 + i * 0.07, 0.24 + i * 0.07));
      final r = _steps[i];
      final h = r.height * p;
      if (h <= 0) continue;
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left, r.bottom - h, r.width, h), const Radius.circular(30));
      final paint = Paint()
        ..shader = ui.Gradient.linear(Offset(0, r.top), Offset(0, r.bottom), _stepColors[i]);
      canvas.drawRRect(rr, paint);
    }

    // Pip: pops in on the first step, hops up, lands, blinks.
    final appear = Curves.easeOutBack.transform(_seg(0.22, 0.36));
    if (appear > 0) {
      var pos = _perch(0);
      var squash = 0.0;
      for (var k = 0; k < 3; k++) {
        final a = 0.38 + k * 0.15, b = a + 0.13;
        final p = _seg(a, b);
        if (t >= a) {
          final from = _perch(k), to = _perch(k + 1);
          final e = Curves.easeInOut.transform(p);
          pos = Offset.lerp(from, to, e)!;
          pos = pos.translate(0, -math.sin(p * math.pi) * 120);
          if (p > 0 && p < 1) squash = -0.06 * math.sin(p * math.pi); // stretch in the air
        }
      }
      // little landing squash after the last hop
      final land = _seg(0.83, 0.95);
      if (land > 0 && land < 1) squash = 0.07 * math.sin(land * math.pi);
      final blink = _seg(0.9, 0.96);
      final eyeOpen = blink > 0 && blink < 1 ? (1 - math.sin(blink * math.pi)).clamp(0.1, 1.0) : 1.0;
      _pip(canvas, pos, appear, squash, eyeOpen);
    }
    canvas.restore();
  }

  void _star(Canvas c, double cx, double cy, double r, double opacity, double grow) {
    if (grow <= 0) return;
    final k = r * grow;
    final path = Path()
      ..moveTo(cx, cy - k)
      ..quadraticBezierTo(cx, cy, cx + k, cy)
      ..quadraticBezierTo(cx, cy, cx, cy + k)
      ..quadraticBezierTo(cx, cy, cx - k, cy)
      ..quadraticBezierTo(cx, cy, cx, cy - k)
      ..close();
    c.drawPath(path, Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: opacity.clamp(0.0, 1.0)));
  }

  void _pip(Canvas c, Offset center, double scale, double squash, double eyeOpen) {
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(scale * (1 + squash), scale * (1 - squash));
    // body
    c.drawCircle(
      Offset.zero,
      _r,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, -_r), const Offset(0, _r),
            const [Color(0xFFFFFFFF), Color(0xFFFFE9C7)]),
    );
    // head tuft
    c.drawPath(
      Path()
        ..moveTo(-8, -106)
        ..relativeQuadraticBezierTo(-6, -34, 16, -40)
        ..relativeQuadraticBezierTo(-2, 22, 14, 30)
        ..close(),
      Paint()..color = const Color(0xFFFFD66B),
    );
    // wing
    c.drawPath(
      Path()
        ..moveTo(-96, -12)
        ..relativeQuadraticBezierTo(-30, 40, 4, 74)
        ..relativeQuadraticBezierTo(36, -12, 40, -48)
        ..close(),
      Paint()..color = const Color(0xFFFBD9A0),
    );
    // beak
    c.drawPath(
      Path()
        ..moveTo(92, -10)
        ..relativeLineTo(46, 14)
        ..relativeLineTo(-46, 22)
        ..close(),
      Paint()..color = const Color(0xFFF4A62A),
    );
    // cheek
    c.drawCircle(const Offset(62, 12), 13, Paint()..color = const Color(0x99FFB7A5));
    // eye (blinks by squashing vertically)
    c.save();
    c.translate(40, -26);
    c.scale(1, eyeOpen);
    c.drawCircle(Offset.zero, 13, Paint()..color = const Color(0xFF2B1A57));
    c.drawCircle(const Offset(5, -5), 4.5, Paint()..color = Colors.white);
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(covariant PipPainter old) => old.t != t || old.glow != glow;
}

/// Static, resting Pip — for headers, the welcome step, empty states.
class PipMark extends StatelessWidget {
  final double size;
  const PipMark({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: PipPainter(1.0)),
      ),
    );
  }
}

/// The opening screen: Pip climbs the steps, the name fades in, then the
/// whole thing fades out over the app (which is already built underneath, so
/// there is no extra wait). Tap to skip; skipped entirely when the phone has
/// animations turned off.
class MascotIntro extends StatefulWidget {
  final Widget child;
  const MascotIntro({super.key, required this.child});

  @override
  State<MascotIntro> createState() => _MascotIntroState();
}

class _MascotIntroState extends State<MascotIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _gone = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    if (MediaQuery.of(context).disableAnimations) {
      _gone = true;
    } else {
      _c.forward().whenComplete(() {
        if (mounted) setState(() => _gone = true);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _skip() {
    if (_c.isAnimating && _c.value < 0.95) _c.animateTo(1.0, duration: const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // fade the whole overlay out in the last 12%
            final out = ((1 - t) / 0.12).clamp(0.0, 1.0);
            final textIn = Curves.easeOut.transform(((t - 0.55) / 0.25).clamp(0.0, 1.0));
            return IgnorePointer(
              ignoring: out < 0.05,
              child: Opacity(
                opacity: out,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _skip,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.2),
                        radius: 1.1,
                        colors: [Color(0xFF3A2470), Color(0xFF22143F), Brand.deep],
                        stops: [0, 0.6, 1],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RepaintBoundary(
                            child: SizedBox(
                              width: 260,
                              height: 260,
                              child: CustomPaint(painter: PipPainter(t, glow: true)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Opacity(
                            opacity: textIn,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - textIn)),
                              child: Column(
                                children: const [
                                  Text('Prakriyā',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                        decoration: TextDecoration.none,
                                      )),
                                  SizedBox(height: 6),
                                  Text('one small step, every day',
                                      style: TextStyle(
                                        color: Brand.goldPale,
                                        fontSize: 13.5,
                                        letterSpacing: 0.6,
                                        fontWeight: FontWeight.w400,
                                        decoration: TextDecoration.none,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
