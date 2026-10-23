import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart' show dayKey;
import '../services/extras.dart';
import '../services/growth.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/growth_plant.dart';

/// Shows a one-time celebration the first time the plant reaches a stage.
/// Safe to call often; it does nothing unless a new stage was reached.
Future<void> maybeCelebratePlant(BuildContext context) async {
  try {
    final snap = GrowthEngine.current();
    final stage = snap.stage.index;
    if (stage <= extras.plantStageSeen) return;
    extras.markPlantStageSeen(stage);
    if (stage == 0 || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: Surfaces.sheet(dark),
          title: Text('Your plant grew!', style: display(20, Surfaces.heading(dark))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GrowthPlant(stage: stage, height: 150),
              const SizedBox(height: 8),
              Text(snap.stage.name, style: display(18, Surfaces.accent(dark))),
              const SizedBox(height: 4),
              Text(snap.stage.blurb,
                  textAlign: TextAlign.center,
                  style: body(13, Surfaces.bodyText(dark))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep growing'),
            ),
          ],
        );
      },
    );
  } catch (_) {
    // A celebration must never break the screen behind it.
  }
}

/// The plant, the balance wheel and the growth curve in one place.
class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  final GlobalKey _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeCelebratePlant(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([store, extras]),
            builder: (context, _) {
              final snap = GrowthEngine.current();
              return ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  ScreenHeader(
                    icon: Icons.spa_outlined,
                    title: 'My Growth',
                    subtitle: 'Your plant grows as you tend your day',
                    actions: [
                      IconButton(
                        tooltip: 'Share',
                        onPressed: () => _share(context),
                        icon: Icon(Icons.ios_share, color: Surfaces.bodyText(dark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        RepaintBoundary(
                          key: _shareKey,
                          child: _PlantCard(snap: snap),
                        ),
                        const SizedBox(height: 14),
                        _WheelCard(snap: snap),
                        const SizedBox(height: 14),
                        _CurveCard(snap: snap),
                        const SizedBox(height: 14),
                        _LadderCard(snap: snap),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    try {
      final boundary =
          _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(p.join(
          dir.path, 'my_growth_${DateTime.now().microsecondsSinceEpoch}.png'));
      await file.writeAsBytes(data.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'My plant on Prakriyā',
      ));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't share right now — try again.")));
      }
    }
  }
}

class _PlantCard extends StatelessWidget {
  final GrowthSnapshot snap;
  const _PlantCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final next = snap.next;
    return ModuleCard(
      accent: true,
      child: Column(
        children: [
          Center(child: GrowthPlant(stage: snap.stage.index, thirsty: snap.thirsty)),
          const SizedBox(height: 6),
          Text(snap.stage.name, style: display(22, Surfaces.heading(dark))),
          const SizedBox(height: 4),
          Text(
            snap.thirsty
                ? 'Your plant is thirsty — one small action and it perks up.'
                : snap.stage.blurb,
            textAlign: TextAlign.center,
            style: body(13, Surfaces.bodyText(dark)),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: snap.toNext,
              minHeight: 8,
              backgroundColor: Surfaces.accent(dark).withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(Surfaces.accent(dark)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            next == null
                ? 'Fully grown — keep it flourishing'
                : '${next.minPoints - snap.points} growth points to ${next.name}',
            style: body(12, Surfaces.muted(dark)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(value: '${snap.points}', label: 'growth points'),
              _Stat(value: '${snap.activeDaysThisWeek}/7', label: 'active days'),
              _Stat(
                  value: '${(snap.smooth.isEmpty ? 0 : snap.smooth.last * 100).round()}%',
                  label: '7-day average'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(value, style: display(20, Surfaces.heading(dark))),
        const SizedBox(height: 2),
        Text(label, style: body(11, Surfaces.muted(dark))),
      ],
    );
  }
}

class _WheelCard extends StatelessWidget {
  final GrowthSnapshot snap;
  const _WheelCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final weak = snap.weakest;
    final strong = snap.strongest;
    return ModuleCard(
      eyebrow: 'Balance wheel · last 7 days',
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.1,
            child: CustomPaint(
              painter: BalanceWheelPainter(
                axes: snap.wheel,
                accent: Surfaces.accent(dark),
                grid: Surfaces.muted(dark).withValues(alpha: 0.35),
                text: Surfaces.bodyText(dark),
                muted: Surfaces.muted(dark),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (strong != null && weak != null && strong.key != weak.key)
            Text(
              'Strongest: ${strong.label}. Tend next: ${weak.label}.',
              textAlign: TextAlign.center,
              style: body(13, Surfaces.bodyText(dark)),
            )
          else
            Text('Do a little in each area and the wheel fills out.',
                textAlign: TextAlign.center,
                style: body(13, Surfaces.bodyText(dark))),
          if (snap.wheel.any((a) => !a.tracked)) ...[
            const SizedBox(height: 4),
            Text('Set a monthly budget in Finance to light up Money.',
                textAlign: TextAlign.center, style: body(11.5, Surfaces.muted(dark))),
          ],
        ],
      ),
    );
  }
}

class _CurveCard extends StatelessWidget {
  final GrowthSnapshot snap;
  const _CurveCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ModuleCard(
      eyebrow: 'Growth curve · last 30 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: GrowthCurvePainter(
                daily: snap.daily,
                smooth: snap.smooth,
                markers: [
                  for (var i = 0; i < snap.dailyDays.length; i++)
                    if (snap.stageUps.containsKey(dayKey(snap.dailyDays[i]))) i,
                ],
                accent: Surfaces.accent(dark),
                grid: Surfaces.muted(dark).withValues(alpha: 0.25),
                muted: Surfaces.muted(dark),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Bars are each day; the line is your 7-day average. Dots mark growth stages.',
              style: body(11.5, Surfaces.muted(dark))),
        ],
      ),
    );
  }
}

class _LadderCard extends StatelessWidget {
  final GrowthSnapshot snap;
  const _LadderCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ModuleCard(
      eyebrow: 'How your plant grows',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Every day you tend habits, priorities, mind, body and connections earns up to 100 growth points. '
            'Quiet days never shrink your plant — it just gets thirsty until you return.',
            style: body(12.5, Surfaces.bodyText(dark)),
          ),
          const SizedBox(height: 12),
          for (final s in kPlantStages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    s.index <= snap.stage.index
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: s.index <= snap.stage.index
                        ? Surfaces.accent(dark)
                        : Surfaces.muted(dark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.name, style: body(13, Surfaces.bodyText(dark))),
                  ),
                  Text('${s.minPoints}', style: body(12, Surfaces.muted(dark))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Radar chart of the six life areas.
class BalanceWheelPainter extends CustomPainter {
  final List<WheelAxis> axes;
  final Color accent;
  final Color grid;
  final Color text;
  final Color muted;
  BalanceWheelPainter({
    required this.axes,
    required this.accent,
    required this.grid,
    required this.text,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    if (n < 3) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 34;
    if (radius <= 0) return;

    Offset point(int i, double frac) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return center + Offset(math.cos(a), math.sin(a)) * (radius * frac);
    }

    final gridPaint = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final o = point(i, ring / 4);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, point(i, 1), gridPaint);
    }

    final shape = Path();
    for (var i = 0; i < n; i++) {
      final o = point(i, axes[i].value.clamp(0.04, 1.0).toDouble());
      if (i == 0) {
        shape.moveTo(o.dx, o.dy);
      } else {
        shape.lineTo(o.dx, o.dy);
      }
    }
    shape.close();
    canvas.drawPath(shape, Paint()..color = accent.withValues(alpha: 0.28));
    canvas.drawPath(
        shape,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
          point(i, axes[i].value.clamp(0.04, 1.0).toDouble()), 3.5, Paint()..color = accent);
    }

    for (var i = 0; i < n; i++) {
      final axis = axes[i];
      final pct = axis.tracked ? '${(axis.value * 100).round()}%' : '—';
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
              text: '${axis.label}\n',
              style: TextStyle(
                  color: text, fontSize: 12, fontWeight: FontWeight.w600)),
          TextSpan(text: pct, style: TextStyle(color: muted, fontSize: 11)),
        ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final o = point(i, 1.0) + (point(i, 1.0) - center) / radius * 20;
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant BalanceWheelPainter old) =>
      old.axes != axes || old.accent != accent || old.text != text;
}

/// Daily bars with a smoothed 7-day line over the top.
class GrowthCurvePainter extends CustomPainter {
  final List<double> daily;
  final List<double> smooth;
  final List<int> markers;
  final Color accent;
  final Color grid;
  final Color muted;
  GrowthCurvePainter({
    required this.daily,
    required this.smooth,
    required this.markers,
    required this.accent,
    required this.grid,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (daily.isEmpty) return;
    const left = 4.0;
    const bottom = 18.0;
    final w = size.width - left - 4;
    final h = size.height - bottom - 6;
    if (w <= 0 || h <= 0) return;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 6 + h * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
    }

    final n = daily.length;
    final slot = w / n;
    final barPaint = Paint()..color = accent.withValues(alpha: 0.28);
    for (var i = 0; i < n; i++) {
      final v = daily[i].clamp(0.0, 1.0).toDouble();
      final bh = math.max(2.0, h * v);
      final x = left + slot * i + slot * 0.15;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 6 + h - bh, slot * 0.7, bh), const Radius.circular(2)),
        barPaint,
      );
    }

    Offset at(int i) => Offset(
        left + slot * i + slot / 2,
        6 + h - h * smooth[i].clamp(0.0, 1.0).toDouble());
    if (smooth.length == n && n > 1) {
      final line = Path()..moveTo(at(0).dx, at(0).dy);
      for (var i = 1; i < n; i++) {
        line.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(
          line,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round);
      for (final m in markers) {
        if (m < 0 || m >= n) continue;
        canvas.drawCircle(at(m), 5.5, Paint()..color = Colors.white);
        canvas.drawCircle(at(m), 4, Paint()..color = accent);
      }
    }

    void label(String s, double x, TextAlign align) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: muted, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = align == TextAlign.right ? x - tp.width : x;
      tp.paint(canvas, Offset(dx, size.height - 14));
    }

    label('${n}d ago', left, TextAlign.left);
    label('today', left + w, TextAlign.right);
  }

  @override
  bool shouldRepaint(covariant GrowthCurvePainter old) =>
      old.daily != daily || old.smooth != smooth || old.accent != accent;
}
