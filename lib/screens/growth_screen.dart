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
    final cs = companionStage(extras.companion, stage);
    if (stage <= extras.plantStageSeen) return;
    extras.markPlantStageSeen(stage);
    if (stage == 0 || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: Surfaces.sheet(dark),
          title: Text(
              extras.companion == 'bird' ? 'Your bird grew!' : 'Your plant grew!',
              style: display(20, Surfaces.heading(dark))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GrowthCompanion(kind: extras.companion, stage: stage, height: 150),
              const SizedBox(height: 8),
              Text(cs.name, style: display(18, Surfaces.accent(dark))),
              const SizedBox(height: 4),
              Text(cs.blurb,
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
                    subtitle: 'Your companion grows as you tend your day',
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
                        const _CompanionPicker(),
                        const SizedBox(height: 12),
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
        text: extras.companion == 'bird'
            ? 'My bird on Prakriyā'
            : 'My plant on Prakriyā',
      ));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't share right now — try again.")));
      }
    }
  }
}


const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dateText(DateTime d) =>
    '${_dayNames[d.weekday - 1]}, ${d.day} ${_monthNames[d.month - 1]}';

/// Tree or bird — progress is shared, so switching never loses anything.
class _CompanionPicker extends StatelessWidget {
  const _CompanionPicker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment<String>(
              value: 'tree', label: Text('Tree'), icon: Icon(Icons.park_outlined)),
          ButtonSegment<String>(
              value: 'bird', label: Text('Bird'), icon: Icon(Icons.flutter_dash)),
        ],
        selected: {extras.companion},
        showSelectedIcon: false,
        onSelectionChanged: (v) => extras.setCompanion(v.first),
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  final GrowthSnapshot snap;
  const _PlantCard({required this.snap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final kind = extras.companion;
    final cs = companionStage(kind, snap.stage.index);
    final next = snap.next;
    final nextName =
        next == null ? '' : companionStage(kind, next.index).name.toLowerCase();
    return ModuleCard(
      accent: true,
      child: Column(
        children: [
          Center(
            child: GrowthCompanion(
                kind: kind, stage: snap.stage.index, idle: snap.thirsty),
          ),
          const SizedBox(height: 6),
          Text(cs.name, style: display(22, Surfaces.heading(dark))),
          const SizedBox(height: 4),
          Text(
            snap.thirsty
                ? (kind == 'bird'
                    ? 'Your bird is sleepy — one small action wakes it up.'
                    : 'Your plant is thirsty — one small action and it perks up.')
                : cs.blurb,
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
                : '${next.minPoints - snap.points} growth points to become a $nextName',
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

const Map<String, String> _axisTips = {
  'habits': 'Tick one habit you can finish in two minutes.',
  'priorities': 'Pick one priority for today and do it first.',
  'mind': 'Log your mood, or take a one-minute breathing break.',
  'body': 'Log a meal and a glass of water.',
  'connect': 'Message someone you have not spoken to lately.',
  'money': 'Set a monthly budget in Finance to light this up.',
};

/// Tap the wheel to inspect any area: its 7-day score, a tiny day-by-day bar
/// strip, and one suggested next step.
class _WheelCard extends StatefulWidget {
  final GrowthSnapshot snap;
  const _WheelCard({required this.snap});

  @override
  State<_WheelCard> createState() => _WheelCardState();
}

class _WheelCardState extends State<_WheelCard> {
  String? _selKey;

  String get _activeKey =>
      _selKey ?? widget.snap.weakest?.key ?? widget.snap.wheel.first.key;

  void _pick(Offset local, Size size) {
    final axes = widget.snap.wheel;
    final n = axes.length;
    final center = Offset(size.width / 2, size.height / 2);
    final d = local - center;
    if (d.distance < 12) return;
    var a = math.atan2(d.dy, d.dx) + math.pi / 2;
    final step = 2 * math.pi / n;
    while (a < 0) {
      a += 2 * math.pi;
    }
    final idx = (a / step).round() % n;
    setState(() => _selKey = axes[idx].key);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final snap = widget.snap;
    final axes = snap.wheel;
    final key = _activeKey;
    var selIndex = axes.indexWhere((a) => a.key == key);
    if (selIndex < 0) selIndex = 0;
    final axis = axes[selIndex];
    final daily = snap.axisDaily(axis.key);
    final week = snap.recent.length <= 7
        ? snap.recent
        : snap.recent.sublist(snap.recent.length - 7);

    return ModuleCard(
      eyebrow: 'Balance wheel · last 7 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.1,
            child: LayoutBuilder(
              builder: (context, c) {
                final size = Size(c.maxWidth, c.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _pick(d.localPosition, size),
                  child: CustomPaint(
                    size: size,
                    painter: BalanceWheelPainter(
                      axes: axes,
                      selected: selIndex,
                      accent: Surfaces.accent(dark),
                      grid: Surfaces.muted(dark).withValues(alpha: 0.35),
                      text: Surfaces.bodyText(dark),
                      muted: Surfaces.muted(dark),
                    ),
                  ),
                );
              },
            ),
          ),
          Center(
            child: Text('Tap an area to explore it',
                style: body(11.5, Surfaces.muted(dark))),
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Surfaces.accent(dark).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(axis.label,
                            style: display(17, Surfaces.heading(dark))),
                      ),
                      Text(axis.tracked ? '${(axis.value * 100).round()}%' : '—',
                          style: display(17, Surfaces.accent(dark))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_axisTips[axis.key] ?? '',
                      style: body(12.5, Surfaces.bodyText(dark))),
                  if (daily.length == week.length && daily.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < daily.length; i++)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: 4 + 30 * daily[i].clamp(0.0, 1.0).toDouble(),
                                    margin: const EdgeInsets.symmetric(horizontal: 5),
                                    decoration: BoxDecoration(
                                      color: Surfaces.accent(dark)
                                          .withValues(alpha: daily[i] > 0 ? 0.9 : 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_dayNames[week[i].day.weekday - 1].substring(0, 1),
                                      style: body(10.5, Surfaces.muted(dark))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Touch or drag along the chart to read any day.
class _CurveCard extends StatefulWidget {
  final GrowthSnapshot snap;
  const _CurveCard({required this.snap});

  @override
  State<_CurveCard> createState() => _CurveCardState();
}

class _CurveCardState extends State<_CurveCard> {
  int? _sel;

  void _pick(double dx, double width) {
    final n = widget.snap.daily.length;
    if (n == 0) return;
    final slot = (width - GrowthCurvePainter.left - GrowthCurvePainter.right) / n;
    if (slot <= 0) return;
    final i = ((dx - GrowthCurvePainter.left) / slot).floor().clamp(0, n - 1).toInt();
    if (i != _sel) setState(() => _sel = i);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final snap = widget.snap;
    final n = snap.daily.length;
    final idx = n == 0 ? 0 : (_sel ?? n - 1).clamp(0, n - 1).toInt();
    final markers = [
      for (var i = 0; i < snap.dailyDays.length; i++)
        if (snap.stageUps.containsKey(dayKey(snap.dailyDays[i]))) i,
    ];

    return ModuleCard(
      eyebrow: 'Growth curve · last 30 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, c) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _pick(d.localPosition.dx, c.maxWidth),
                  onHorizontalDragStart: (d) => _pick(d.localPosition.dx, c.maxWidth),
                  onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, c.maxWidth),
                  child: CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: GrowthCurvePainter(
                      daily: snap.daily,
                      smooth: snap.smooth,
                      markers: markers,
                      selected: idx,
                      accent: Surfaces.accent(dark),
                      grid: Surfaces.muted(dark).withValues(alpha: 0.25),
                      muted: Surfaces.muted(dark),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          if (n == 0)
            Text('Your curve appears after your first day.',
                style: body(12, Surfaces.muted(dark)))
          else
            _DayInfo(
              facts: snap.recent[idx],
              score: snap.daily[idx],
              avg: snap.smooth[idx],
              stageUp: snap.stageUps[dayKey(snap.recent[idx].day)],
              isToday: idx == n - 1,
            ),
          const SizedBox(height: 6),
          Text('Touch or slide along the chart to look at any day.',
              style: body(11.5, Surfaces.muted(dark))),
        ],
      ),
    );
  }
}

class _DayInfo extends StatelessWidget {
  final DayFacts facts;
  final double score;
  final double avg;
  final int? stageUp;
  final bool isToday;
  const _DayInfo({
    required this.facts,
    required this.score,
    required this.avg,
    required this.stageUp,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chips = <String>[
      if (facts.habitsTotal > 0) 'Habits ${facts.habitsDone}/${facts.habitsTotal}',
      if (facts.tasksTotal > 0) 'Priorities ${facts.tasksDone}/${facts.tasksTotal}',
      if (facts.moodLogged) 'Mood logged',
      if (facts.journaled) 'Reflection',
      if (facts.mindActions > 0) 'Mind ×${facts.mindActions}',
      if (facts.mealsLogged > 0) 'Meals ×${facts.mealsLogged}',
      if (facts.waterLogged) 'Water',
      if (facts.contacted) 'Reached out',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Surfaces.accent(dark).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(isToday ? 'Today · ${_dateText(facts.day)}' : _dateText(facts.day),
                    style: body(13, Surfaces.heading(dark), weight: FontWeight.w700)),
              ),
              Text('${(score * 100).round()}%',
                  style: display(18, Surfaces.accent(dark))),
            ],
          ),
          const SizedBox(height: 2),
          Text('7-day average ${(avg * 100).round()}%',
              style: body(11.5, Surfaces.muted(dark))),
          if (stageUp != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Surfaces.accent(dark)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Growth milestone: reached ${companionStage(extras.companion, stageUp!).name}',
                      style: body(12, Surfaces.accentText(dark), weight: FontWeight.w600)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (chips.isEmpty)
            Text('Nothing logged this day.', style: body(12, Surfaces.muted(dark)))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Surfaces.card(dark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Surfaces.cardBorder(dark)),
                    ),
                    child: Text(c, style: body(11, Surfaces.bodyText(dark))),
                  ),
              ],
            ),
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
    final kind = extras.companion;
    final stages = kind == 'bird' ? kBirdStages : kPlantStages;
    return ModuleCard(
      eyebrow: 'How your ${kind == 'bird' ? 'bird' : 'plant'} grows',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Every day you tend habits, priorities, mind, body and connections earns up to 100 growth points. '
            'Quiet days never shrink your ${kind == 'bird' ? 'bird' : 'plant'} — '
            '${kind == 'bird' ? 'it just naps' : 'it just gets thirsty'} until you return.',
            style: body(12.5, Surfaces.bodyText(dark)),
          ),
          const SizedBox(height: 12),
          for (final s in stages)
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

/// Radar chart of the six life areas; [selected] is drawn emphasised.
class BalanceWheelPainter extends CustomPainter {
  final List<WheelAxis> axes;
  final int selected;
  final Color accent;
  final Color grid;
  final Color text;
  final Color muted;
  BalanceWheelPainter({
    required this.axes,
    required this.selected,
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
      canvas.drawLine(
          center,
          point(i, 1),
          i == selected
              ? (Paint()
                ..color = accent.withValues(alpha: 0.7)
                ..strokeWidth = 2)
              : gridPaint);
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
      final o = point(i, axes[i].value.clamp(0.04, 1.0).toDouble());
      if (i == selected) {
        canvas.drawCircle(o, 9, Paint()..color = accent.withValues(alpha: 0.25));
        canvas.drawCircle(o, 5.5, Paint()..color = accent);
      } else {
        canvas.drawCircle(o, 3.5, Paint()..color = accent);
      }
    }

    for (var i = 0; i < n; i++) {
      final axis = axes[i];
      final isSel = i == selected;
      final pct = axis.tracked ? '${(axis.value * 100).round()}%' : '—';
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
              text: '${axis.label}\n',
              style: TextStyle(
                  color: isSel ? accent : text,
                  fontSize: isSel ? 13 : 12,
                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600)),
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
      old.axes != axes ||
      old.selected != selected ||
      old.accent != accent ||
      old.text != text;
}

/// Daily bars with a smoothed 7-day line and a movable inspector.
class GrowthCurvePainter extends CustomPainter {
  static const double left = 4;
  static const double right = 4;
  static const double _bottom = 18;

  final List<double> daily;
  final List<double> smooth;
  final List<int> markers;
  final int selected;
  final Color accent;
  final Color grid;
  final Color muted;
  GrowthCurvePainter({
    required this.daily,
    required this.smooth,
    required this.markers,
    required this.selected,
    required this.accent,
    required this.grid,
    required this.muted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (daily.isEmpty) return;
    final w = size.width - left - right;
    final h = size.height - _bottom - 6;
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
    final barSel = Paint()..color = accent.withValues(alpha: 0.6);
    for (var i = 0; i < n; i++) {
      final v = daily[i].clamp(0.0, 1.0).toDouble();
      final bh = math.max(2.0, h * v);
      final x = left + slot * i + slot * 0.15;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 6 + h - bh, slot * 0.7, bh), const Radius.circular(2)),
        i == selected ? barSel : barPaint,
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
      if (selected >= 0 && selected < n) {
        final p = at(selected);
        canvas.drawLine(
            Offset(p.dx, 4),
            Offset(p.dx, 6 + h),
            Paint()
              ..color = accent.withValues(alpha: 0.55)
              ..strokeWidth = 1.5);
        canvas.drawCircle(p, 8, Paint()..color = accent.withValues(alpha: 0.25));
        canvas.drawCircle(p, 5, Paint()..color = accent);
        canvas.drawCircle(p, 2, Paint()..color = Colors.white);
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
      old.daily != daily ||
      old.smooth != smooth ||
      old.selected != selected ||
      old.accent != accent;
}
