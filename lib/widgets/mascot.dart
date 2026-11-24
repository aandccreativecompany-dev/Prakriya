import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's mark: the little stick-man climbing the gold steps — the same
/// picture as the launcher icon.
///
/// [ClimberPainter] draws the scene in a 1024 x 1024 design space (the icon's
/// own coordinates), scaled to whatever square it is given. `t` runs 0..1:
/// the steps rise one by one, the man walks up them with a real leg cycle,
/// arms swinging, then throws his arms up on top while sparkles twinkle.
/// At `t == 1` it is the finished, resting picture.
class ClimberPainter extends CustomPainter {
  final double t;
  final bool glow;
  const ClimberPainter(this.t, {this.glow = true});

  // Step tops / x-spans match assets/icon/icon.png.
  static const _tops = <double>[826, 700, 573, 447];
  static const _left = <double>[192, 352, 512, 672];
  static const _w = 160.0;
  static const _bottom = 952.0;
  static const _colors = <Color>[
    Color(0xFFB07D12),
    Color(0xFFDEA51A),
    Color(0xFFF2BA3E),
    Color(0xFFFDE9A9),
  ];
  static const _skin = Color(0xFFFFF6E3);

  static const _thigh = 96.0, _shin = 96.0, _torso = 118.0, _head = 36.0;
  static const _stroke = 30.0;

  double _seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
  double _cx(int i) => _left[i] + _w / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 1024.0;
    canvas.save();
    canvas.translate((size.width - 1024 * s) / 2, (size.height - 1024 * s) / 2);
    canvas.scale(s);

    if (glow) {
      final g = Paint()
        ..shader = ui.Gradient.radial(const Offset(760, 330), 360, [
          const Color(0xFFFFD66B).withValues(alpha: 0.38 * _seg(0.1, 0.85)),
          const Color(0xFFFFD66B).withValues(alpha: 0),
        ]);
      canvas.drawCircle(const Offset(760, 330), 360, g);
    }

    final tw = t * 2 * math.pi * 2;
    _star(canvas, 330, 250, 34, 0.55 + 0.35 * math.sin(tw), _seg(0.35, 0.6));
    _star(canvas, 180, 520, 22, 0.45 + 0.3 * math.sin(tw + 1.6), _seg(0.4, 0.65));
    _star(canvas, 520, 170, 26, 0.5 + 0.3 * math.sin(tw + 3.1), _seg(0.45, 0.7));
    _star(canvas, 900, 150, 22, 0.45 + 0.3 * math.sin(tw + 4.5), _seg(0.5, 0.75));

    // Steps rise one after another.
    for (var i = 0; i < 4; i++) {
      final p = Curves.easeOutCubic.transform(_seg(0.02 + i * 0.06, 0.22 + i * 0.06));
      final full = _bottom - _tops[i];
      final h = full * p;
      if (h <= 0) continue;
      canvas.drawRect(Rect.fromLTWH(_left[i], _bottom - h, _w, h), Paint()..color = _colors[i]);
    }

    final appear = _seg(0.2, 0.3);
    if (appear > 0) _man(canvas, appear);
    canvas.restore();
  }

  // ---- the man -----------------------------------------------------------

  Offset _lerp(Offset a, Offset b, double k) => Offset.lerp(a, b, k)!;

  /// Two-bone leg: hip -> knee -> foot, knee bending toward +x (forward).
  List<Offset> _leg(Offset hip, Offset foot) {
    var d = foot - hip;
    final reach = (_thigh + _shin) * 0.985;
    if (d.distance > reach) d = d / d.distance * reach;
    final f = hip + d;
    final L = d.distance;
    final a = (_thigh * _thigh - _shin * _shin + L * L) / (2 * L);
    final h = math.sqrt(math.max(0, _thigh * _thigh - a * a));
    final dir = d / L;
    final perp = Offset(-dir.dy, dir.dx); // rotate 90°
    var knee = hip + dir * a + perp * h;
    final knee2 = hip + dir * a - perp * h;
    if (knee2.dx > knee.dx) knee = knee2; // knee points forward
    return [hip, knee, f];
  }

  void _man(Canvas c, double appear) {
    final standY = _thigh + _shin - 14; // hip height above the step top
    // current climb: 0..2, progress p of that climb
    const t0 = 0.34, per = 0.15;
    var k = 0;
    var p = 0.0;
    if (t >= t0) {
      k = ((t - t0) / per).floor().clamp(0, 3);
      p = k >= 3 ? 1.0 : ((t - t0 - k * per) / per).clamp(0.0, 1.0);
      if (k >= 3) k = 2;
    }
    final from = k, to = k + 1;
    final e = Curves.easeInOutCubic.transform(p);

    final hipA = Offset(_cx(from), _tops[from] - standY);
    final hipB = Offset(_cx(to), _tops[to] - standY);
    var hip = _lerp(hipA, hipB, e);
    // a small bob: dip as the lead foot lands, rise on the push
    hip = hip.translate(0, 10 * math.sin(p * math.pi * 2));

    // Lead foot swings up to the next step first, trailing foot follows.
    Offset foot(Offset a, Offset b, double lo, double hi) {
      final q = ((p - lo) / (hi - lo)).clamp(0.0, 1.0);
      final eq = Curves.easeInOut.transform(q);
      final pos = _lerp(a, b, eq);
      return pos.translate(0, -math.sin(q * math.pi) * 46);
    }

    final leadA = Offset(_cx(from) + 22, _tops[from]);
    final leadB = Offset(_cx(to) - 18, _tops[to]);
    final trailA = Offset(_cx(from) - 26, _tops[from]);
    final trailB = Offset(_cx(to) + 24, _tops[to]);
    final lead = foot(leadA, leadB, 0.0, 0.6);
    final trail = foot(trailA, trailB, 0.4, 1.0);

    final top = t >= t0 + 3 * per; // arrived
    final cheer = Curves.easeOutBack.transform(_seg(t0 + 3 * per, t0 + 3 * per + 0.12));

    final lean = top ? 0.0 : 0.16;
    final neck = hip + Offset(math.sin(lean) * _torso, -math.cos(lean) * _torso);
    final headC = neck + Offset(math.sin(lean) * 40, -math.cos(lean) * 40);

    final legs = [_leg(hip, lead), _leg(hip, trail)];

    // arms: swing in opposition to the legs, then up in a cheer
    final sh = neck.translate(0, 14);
    final swing = math.sin(p * math.pi * 2) * 0.8;
    double armAngle(int side) {
      final walking = (side == 0 ? swing : -swing) + 0.35;
      return top ? ui.lerpDouble(walking, side == 0 ? 2.6 : 3.7, cheer)! : walking;
    }

    Offset hand(int side) {
      final a = armAngle(side);
      return sh + Offset(math.sin(a) * 92, math.cos(a) * 92);
    }

    final paint = Paint()
      ..color = _skin.withValues(alpha: appear)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = _skin.withValues(alpha: appear);

    // back arm, back leg first, then torso/front limbs
    c.drawLine(sh, hand(1), paint);
    c.drawPath(_poly(legs[1]), paint);
    c.drawLine(hip, neck, paint);
    c.drawPath(_poly(legs[0]), paint);
    c.drawLine(sh, hand(0), paint);
    c.drawCircle(headC, _head, fill);
  }

  Path _poly(List<Offset> pts) {
    final p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p;
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

  @override
  bool shouldRepaint(covariant ClimberPainter old) => old.t != t || old.glow != glow;
}

/// Static, resting mark — for headers, the welcome step, empty states.
class ClimberMark extends StatelessWidget {
  final double size;
  const ClimberMark({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: ClimberPainter(1.0)),
      ),
    );
  }
}

/// The opening screen: The stick-man climbs the steps, the name fades in, then the
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
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
    // The child must stay at the same spot in the tree for the whole life of
    // the widget — returning it bare once the intro ends would rebuild the
    // entire app underneath (state lost, first-frame prompts shown twice).
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_gone)
          const SizedBox.shrink()
        else
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
                              child: CustomPaint(painter: ClimberPainter(t, glow: true)),
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
                                  Text('one small step at a time',
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
