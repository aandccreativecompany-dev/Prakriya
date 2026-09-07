import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _periods = [
  ('day', "Today's pulse"),
  ('week', "This week's pulse"),
  ('month', "This month's pulse"),
];

/// A branching, auto-generated overview of how the day/week/month is going —
/// habits, priorities, mood, and journaling pulled straight from the store,
/// arranged as a central node with branch nodes around it — plus a free-text
/// notes field per period so it's not purely automatic.
class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _noteControllers = {
    'day': TextEditingController(),
    'week': TextEditingController(),
    'month': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
    for (final entry in _noteControllers.entries) {
      entry.value.text = store.mindMapNoteFor(entry.key);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveNote(String period) async {
    await store.setMindMapNote(period, _noteControllers[period]!.text);
    if (mounted) toastSaved(context);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          body: Container(
            decoration: Surfaces.pageBackground(dark),
            child: SafeArea(
              child: FadeSlideIn(
                child: Column(
                  children: [
                    const ScreenHeader(
                      icon: Icons.account_tree_outlined,
                      title: 'Organized mind map',
                      subtitle: 'Everything at a glance, plus your own notes.',
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Surfaces.card(dark),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Surfaces.cardBorder(dark)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: Surfaces.accent(dark),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          labelColor: Brand.deep,
                          unselectedLabelColor: Surfaces.muted(dark),
                          labelStyle: body(12.5, Brand.deep, weight: FontWeight.w700),
                          unselectedLabelStyle: body(12.5, Surfaces.muted(dark)),
                          tabs: const [
                            Tab(text: 'Day'),
                            Tab(text: 'Week'),
                            Tab(text: 'Month'),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          for (final (period, label) in _periods)
                            _MindMapTab(
                              period: period,
                              centerLabel: label,
                              noteController: _noteControllers[period]!,
                              onSaveNote: () => _saveNote(period),
                            ),
                        ],
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

class _MindMapTab extends StatelessWidget {
  final String period;
  final String centerLabel;
  final TextEditingController noteController;
  final VoidCallback onSaveNote;

  const _MindMapTab({
    required this.period,
    required this.centerLabel,
    required this.noteController,
    required this.onSaveNote,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final snap = store.mindMapSnapshot(period);
    final habitsPct = snap.habitsTotal == 0
        ? 0
        : ((snap.habitsDone / snap.habitsTotal) * 100).round();
    final prioritiesPct = snap.prioritiesTotal == 0
        ? 0
        : ((snap.prioritiesDone / snap.prioritiesTotal) * 100).round();
    final overall = snap.habitsTotal == 0 && snap.prioritiesTotal == 0
        ? 0
        : ((habitsPct + prioritiesPct) / (snap.prioritiesTotal == 0 ? 1 : 2)).round();

    // A whimsical, varied palette instead of the old mostly-monochrome gold
    // — one distinct color per branch, cycling through the app's accent
    // palette family so it stays visually consistent with the rest of the
    // colorful redesign elsewhere in the app.
    const branchColors = [
      Color(0xFFF2B93B), // gold
      Color(0xFFC79BF0), // amethyst
      Color(0xFF7FC8F8), // sky
      Color(0xFFF08BA0), // rose
      Color(0xFF6FDCA8), // emerald
    ];
    final branches = [
      _BranchData(
        icon: Icons.self_improvement,
        label: 'Habits',
        value: snap.habitsTotal == 0 ? 'None tracked' : '$habitsPct% done',
        color: branchColors[0],
      ),
      _BranchData(
        icon: Icons.checklist_rounded,
        label: 'Priorities',
        value: snap.prioritiesTotal == 0 ? 'Nothing set' : '$prioritiesPct% done',
        color: branchColors[1],
      ),
      _BranchData(
        icon: Icons.mood_outlined,
        label: 'Mood',
        value: snap.mood ?? 'Not logged',
        color: branchColors[2],
      ),
      _BranchData(
        icon: Icons.nights_stay_outlined,
        label: 'Reflection',
        value: snap.journaled ? 'Written' : 'Not yet',
        color: branchColors[3],
      ),
      _BranchData(
        icon: Icons.auto_awesome,
        label: 'Journaling',
        value: '${snap.scriptsCount} total',
        color: branchColors[4],
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          SizedBox(
            height: 380,
            width: double.infinity,
            child: _MindMapRadial(
              centerLabel: centerLabel,
              centerValue: '$overall%',
              branches: branches,
              dark: dark,
            ),
          ),
          const SizedBox(height: 20),
          _StickyNotesSection(period: period),
          const SizedBox(height: 20),
          ModuleCard(
            eyebrow: 'Notes for this period',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: body(13.5, Surfaces.bodyText(dark)),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'What stands out about this ${period == 'day' ? 'day' : period}?',
                    hintStyle: body(13, Surfaces.muted(dark)),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onSaveNote,
                    child: Text('Save note',
                        style: body(12.5, Surfaces.accent(dark), weight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Short, colorful sticky notes pinned to the mind map — a lighter, more
/// visual complement to the single paragraph note. Several can exist per
/// period tab; each is its own little rotated colored card.
class _StickyNotesSection extends StatelessWidget {
  final String period;
  const _StickyNotesSection({required this.period});

  static const _noteColors = [
    Color(0xFFF2B93B),
    Color(0xFFF08BA0),
    Color(0xFF7FC8F8),
    Color(0xFF6FDCA8),
    Color(0xFFC79BF0),
    Color(0xFFFF9770),
  ];

  Future<void> _addNote(BuildContext context) async {
    final controller = TextEditingController();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New sticky note', style: display(16, Surfaces.heading(dark))),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'A quick thought for this period'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Add')),
        ],
      ),
    );
    if (text != null && text.trim().isNotEmpty) {
      final colorIndex = store.mindMapStickyNotesFor(period).length % _noteColors.length;
      await store.addMindMapStickyNote(period, text, colorIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final notes = store.mindMapStickyNotesFor(period);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('STICKY NOTES', style: label(Surfaces.eyebrow(dark))),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _addNote(context),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.add_circle_outline, size: 18, color: Surfaces.accent(dark)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (notes.isEmpty)
          Text('Nothing pinned yet — tap + for a quick note.',
              style: body(12.5, Surfaces.muted(dark)))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final note in notes)
                _StickyNoteCard(
                  note: note,
                  color: _noteColors[note.colorIndex % _noteColors.length],
                  dark: dark,
                  onRemove: () => store.removeMindMapStickyNote(period, note),
                ),
            ],
          ),
      ],
    );
  }
}

class _StickyNoteCard extends StatelessWidget {
  final MindMapStickyNote note;
  final Color color;
  final bool dark;
  final VoidCallback onRemove;

  const _StickyNoteCard({
    required this.note,
    required this.color,
    required this.dark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (note.id.hashCode % 5 - 2) * 0.02, // a tiny whimsical tilt, ±~5°
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.26 : 0.9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.3 : 0.12), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin, size: 12, color: dark ? Colors.white : Brand.deep),
                const Spacer(),
                InkWell(
                  onTap: onRemove,
                  child: Icon(Icons.close, size: 14, color: dark ? Colors.white70 : Brand.deep),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              note.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: body(11.5, dark ? Colors.white : Brand.deep, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _BranchData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Central node plus branch nodes connected by lines — the "organized mind
/// map" visual, auto-laid-out in a circle around the centre regardless of
/// how many branches there are.
class _MindMapRadial extends StatelessWidget {
  final String centerLabel;
  final String centerValue;
  final List<_BranchData> branches;
  final bool dark;

  const _MindMapRadial({
    required this.centerLabel,
    required this.centerValue,
    required this.branches,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size.width / 2, size.height / 2);
        // Branch nodes are 104 wide (52 half-width) — the old `- 46` inset
        // left barely any margin past that half-width, so on a narrow phone
        // the leftmost/rightmost nodes could clip against the screen edge.
        // `- 68` guarantees at least a 16px margin, clamped so very small
        // containers still get a legible, non-overlapping layout instead of
        // a near-zero or negative radius collapsing every node onto the
        // centre.
        final radius = math.max(90.0, math.min(size.width, size.height) / 2 - 68);
        final positions = <Offset>[];
        for (var i = 0; i < branches.length; i++) {
          final angle = (-90 + (360 / branches.length) * i) * math.pi / 180;
          positions.add(Offset(
            center.dx + radius * math.cos(angle),
            center.dy + radius * math.sin(angle),
          ));
        }
        return Stack(
          children: [
            CustomPaint(
              size: size,
              painter: _BranchLinePainter(
                center: center,
                points: positions,
                colors: [for (final b in branches) b.color.withValues(alpha: 0.45)],
              ),
            ),
            Positioned(
              left: center.dx - 56,
              top: center.dy - 56,
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Brand.gold, Brand.goldLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Brand.gold.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 2),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(centerValue, style: display(22, Brand.deep)),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          centerLabel,
                          textAlign: TextAlign.center,
                          style: body(9.5, Brand.deep, weight: FontWeight.w700),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            for (var i = 0; i < branches.length; i++)
              Positioned(
                left: positions[i].dx - 52,
                top: positions[i].dy - 32,
                child: _BranchNode(data: branches[i], dark: dark),
              ),
          ],
        );
      },
    );
  }
}

class _BranchNode extends StatelessWidget {
  final _BranchData data;
  final bool dark;
  const _BranchNode({required this.data, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Surfaces.card(dark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 16, color: data.color),
          const SizedBox(height: 4),
          Text(data.label,
              style: body(10.5, Surfaces.heading(dark), weight: FontWeight.w700),
              textAlign: TextAlign.center),
          Text(data.value,
              style: body(9.5, Surfaces.muted(dark)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BranchLinePainter extends CustomPainter {
  final Offset center;
  final List<Offset> points;
  final List<Color> colors;
  const _BranchLinePainter({required this.center, required this.points, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length; i++) {
      final paint = Paint()
        ..color = i < colors.length ? colors[i] : Colors.grey.withValues(alpha: 0.35)
        ..strokeWidth = 1.6;
      canvas.drawLine(center, points[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BranchLinePainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.points != points || oldDelegate.colors != colors;
}
