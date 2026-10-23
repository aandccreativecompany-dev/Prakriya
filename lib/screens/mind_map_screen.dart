import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models.dart';
import '../services/growth.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'evening_reflection_screen.dart';
import 'scripting_screen.dart';

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
                          // Fill each third and drop the divider line, so the
                          // selected pill sits centred on its tab instead of
                          // hugging the label.
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.all(4),
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            color: Surfaces.accent(dark),
                            borderRadius: BorderRadius.circular(11),
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

const _moodChoices = [
  ('Rough', '😔'),
  ('Meh', '😕'),
  ('Okay', '😐'),
  ('Good', '🙂'),
  ('Amazing', '🤩'),
];

/// One bubble around the pulse orb.
class _BranchData {
  final String key;
  final IconData icon;
  final String label;
  final String value;

  /// 0..1 — fills the ring around the bubble's icon.
  final double fill;
  final Color color;
  const _BranchData({
    required this.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.fill,
    required this.color,
  });
}

/// The interactive heart of the screen: a breathing pulse orb with a bubble
/// per life area. Tap a bubble to open it right under the map and act on it
/// (tick habits, finish priorities, set your mood) — the orb and rings
/// update live. Tap the orb itself to jump to whichever area needs love.
class _MindMapTab extends StatefulWidget {
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
  State<_MindMapTab> createState() => _MindMapTabState();
}

class _MindMapTabState extends State<_MindMapTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  String? _selected;
  int? _trailSel;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  static const _branchColors = [
    Color(0xFFF2B93B), // gold
    Color(0xFFC79BF0), // amethyst
    Color(0xFF7FC8F8), // sky
    Color(0xFFF08BA0), // rose
    Color(0xFF6FDCA8), // emerald
  ];

  double _moodFill(String? mood) {
    if (mood == null) return 0;
    final i = _moodChoices.indexWhere((m) => m.$1 == mood);
    return i < 0 ? 0 : (i + 1) / _moodChoices.length;
  }

  String _moodText(String? mood) {
    if (mood == null) return 'Not logged';
    final i = _moodChoices.indexWhere((m) => m.$1 == mood);
    return i < 0 ? mood : '${_moodChoices[i].$2} $mood';
  }

  List<_BranchData> _branches() {
    final snap = store.mindMapSnapshot(widget.period);
    final habitsFill =
        snap.habitsTotal == 0 ? 0.0 : (snap.habitsDone / snap.habitsTotal).clamp(0.0, 1.0).toDouble();
    final prioFill = snap.prioritiesTotal == 0
        ? 0.0
        : (snap.prioritiesDone / snap.prioritiesTotal).clamp(0.0, 1.0).toDouble();
    return [
      _BranchData(
        key: 'habits',
        icon: Icons.self_improvement,
        label: 'Habits',
        value: snap.habitsTotal == 0 ? 'None tracked' : '${(habitsFill * 100).round()}% done',
        fill: habitsFill,
        color: _branchColors[0],
      ),
      _BranchData(
        key: 'priorities',
        icon: Icons.checklist_rounded,
        label: 'Priorities',
        value: snap.prioritiesTotal == 0 ? 'Nothing set' : '${(prioFill * 100).round()}% done',
        fill: prioFill,
        color: _branchColors[1],
      ),
      _BranchData(
        key: 'mood',
        icon: Icons.mood_outlined,
        label: 'Mood',
        value: _moodText(snap.mood),
        fill: _moodFill(snap.mood),
        color: _branchColors[2],
      ),
      _BranchData(
        key: 'reflection',
        icon: Icons.nights_stay_outlined,
        label: 'Reflection',
        value: snap.journaled ? 'Written' : 'Not yet',
        fill: snap.journaled ? 1.0 : 0.0,
        color: _branchColors[3],
      ),
      _BranchData(
        key: 'journaling',
        icon: Icons.auto_awesome,
        label: 'Journaling',
        value: '${snap.scriptsCount} total',
        fill: (snap.scriptsCount / 5).clamp(0.0, 1.0).toDouble(),
        color: _branchColors[4],
      ),
    ];
  }

  /// The area that most needs attention (lowest fill; ties go in order).
  _BranchData _weakest(List<_BranchData> branches) {
    var out = branches.first;
    for (final b in branches) {
      if (b.fill < out.fill) out = b;
    }
    return out;
  }

  void _select(String? key) {
    HapticFeedback.selectionClick();
    setState(() => _selected = _selected == key ? null : key);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final branches = _branches();
    // The orb averages whichever of habits / priorities actually have data
    // for this period, so an empty list never drags the score down.
    final snap = store.mindMapSnapshot(widget.period);
    final parts = <double>[
      if (snap.habitsTotal > 0) branches[0].fill,
      if (snap.prioritiesTotal > 0) branches[1].fill,
    ];
    final overall =
        parts.isEmpty ? 0.0 : parts.reduce((a, b) => a + b) / parts.length;
    final weakest = _weakest(branches);
    final selected = _selected == null
        ? null
        : branches.firstWhere((b) => b.key == _selected, orElse: () => branches.first);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          SizedBox(
            height: 400,
            width: double.infinity,
            child: _MindMapRadial(
              centerLabel: widget.centerLabel,
              overall: overall,
              branches: branches,
              selectedKey: _selected,
              breath: _breath,
              dark: dark,
              onSelect: _select,
              onOrbTap: () => _select(weakest.key),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: selected == null
                  ? _HintCard(
                      key: const ValueKey('hint'),
                      overall: overall,
                      weakest: weakest,
                      dark: dark,
                    )
                  : _DetailCard(
                      key: ValueKey(selected.key),
                      data: selected,
                      period: widget.period,
                      dark: dark,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _PulseTrail(
            period: widget.period,
            selected: _trailSel,
            onSelect: (i) => setState(() => _trailSel = i),
          ),
          const SizedBox(height: 20),
          _StickyNotesSection(period: widget.period),
          const SizedBox(height: 20),
          ModuleCard(
            eyebrow: 'Notes for this period',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: widget.noteController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: body(13.5, Surfaces.bodyText(dark)),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText:
                        'What stands out about this ${widget.period == 'day' ? 'day' : widget.period}?',
                    hintStyle: body(13, Surfaces.muted(dark)),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: widget.onSaveNote,
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

/// Shown when no bubble is open: the orb's state of mind and a nudge.
class _HintCard extends StatelessWidget {
  final double overall;
  final _BranchData weakest;
  final bool dark;
  const _HintCard({
    super.key,
    required this.overall,
    required this.weakest,
    required this.dark,
  });

  String get _line {
    if (overall >= 0.67) return 'Glowing. Keep the momentum going.';
    if (overall >= 0.34) return 'Building steadily — a little more lights it up.';
    return 'Warming up — one small step gets it moving.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Surfaces.accent(dark).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_line, style: body(13.5, Surfaces.heading(dark), weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Tap a bubble to open it here, or tap the glowing orb to jump to ${weakest.label}, '
            'the area that could use you most.',
            style: body(12.5, Surfaces.bodyText(dark)),
          ),
        ],
      ),
    );
  }
}

/// The open bubble: what it holds plus quick actions that change real data.
class _DetailCard extends StatelessWidget {
  final _BranchData data;
  final String period;
  final bool dark;
  const _DetailCard({
    super.key,
    required this.data,
    required this.period,
    required this.dark,
  });

  Widget _pill(String text, {required bool on, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? data.color.withValues(alpha: 0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: data.color.withValues(alpha: on ? 1 : 0.6)),
        ),
        child: Text(
          text,
          style: body(12, on ? Brand.deep : Surfaces.bodyText(dark),
              weight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _action(BuildContext context, String text, Widget screen) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
        icon: Icon(Icons.arrow_forward, size: 16, color: data.color),
        label: Text(text, style: body(12.5, data.color, weight: FontWeight.w700)),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final now = DateTime.now();
    switch (data.key) {
      case 'habits':
        final habits = store.habits;
        if (habits.isEmpty) {
          return Text('No habits yet — add some in the Habits tab.',
              style: body(12.5, Surfaces.muted(dark)));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tap to tick off for today',
                style: body(12, Surfaces.muted(dark))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in habits)
                  _pill(h.name, on: h.isDoneOn(now), onTap: () => store.toggleHabit(h)),
              ],
            ),
          ],
        );
      case 'priorities':
        final tasks = store.todaysTasks;
        if (tasks.isEmpty) {
          return Text('No priorities set for today — add one in the Tasks tab.',
              style: body(12.5, Surfaces.muted(dark)));
        }
        final shown = tasks.length > 6 ? 6 : tasks.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < shown; i++)
              InkWell(
                onTap: () => store.toggleTask(i),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        tasks[i].done ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                        color: data.color,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tasks[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: body(13, Surfaces.bodyText(dark)).copyWith(
                            decoration:
                                tasks[i].done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (tasks.length > shown)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${tasks.length - shown} more in Tasks',
                    style: body(11.5, Surfaces.muted(dark))),
              ),
          ],
        );
      case 'mood':
        final current = store.todaysMood;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How are you feeling today?', style: body(12, Surfaces.muted(dark))),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (label, emoji) in _moodChoices)
                  GestureDetector(
                    onTap: () => store.setTodaysMood(label),
                    child: AnimatedScale(
                      scale: current == label ? 1.18 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      child: Column(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 2),
                          Text(label,
                              style: body(10.5,
                                  current == label ? data.color : Surfaces.muted(dark),
                                  weight: current == label
                                      ? FontWeight.w800
                                      : FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      case 'reflection':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.fill >= 1
                  ? 'You wrote your evening reflection. A calm way to close the day.'
                  : 'A few lines about your wins and what you are grateful for.',
              style: body(12.5, Surfaces.bodyText(dark)),
            ),
            _action(context, 'Open evening reflection', const EveningReflectionScreen()),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your journaling and scripting entries — the words that shape what you build.',
              style: body(12.5, Surfaces.bodyText(dark)),
            ),
            _action(context, 'Open journaling', const ScriptingScreen()),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Surfaces.card(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 18, color: data.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(data.label,
                    style: display(16, Surfaces.heading(dark))),
              ),
              Text(data.value, style: body(12, Surfaces.muted(dark))),
            ],
          ),
          const SizedBox(height: 10),
          _content(context),
        ],
      ),
    );
  }
}

/// A row of glowing dots, one per day, sized and tinted by how that day went.
/// Tap a dot to read it.
class _PulseTrail extends StatelessWidget {
  final String period;
  final int? selected;
  final ValueChanged<int?> onSelect;
  const _PulseTrail({
    required this.period,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final all = GrowthEngine.factsFromApp();
    final want = period == 'month' ? 30 : 7;
    final days = all.length <= want ? all : all.sublist(all.length - want);
    if (days.isEmpty) return const SizedBox.shrink();
    final sel = (selected ?? days.length - 1).clamp(0, days.length - 1).toInt();
    final f = days[sel];
    final score = GrowthEngine.scoreFor(f);
    final dot = period == 'month' ? 9.0 : 16.0;
    return ModuleCard(
      eyebrow: 'Pulse trail · last ${days.length} days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: period == 'month' ? 5 : 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < days.length; i++)
                GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    width: dot + 14 * GrowthEngine.scoreFor(days[i]),
                    height: dot + 14 * GrowthEngine.scoreFor(days[i]),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        Surfaces.muted(dark).withValues(alpha: 0.25),
                        Surfaces.accent(dark),
                        GrowthEngine.scoreFor(days[i]).clamp(0.0, 1.0).toDouble(),
                      ),
                      border: i == sel
                          ? Border.all(color: Surfaces.heading(dark), width: 2)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_dayLabel(f.day)} · ${(score * 100).round()}% pulse',
            style: body(12.5, Surfaces.bodyText(dark), weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime d) {
    const dn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dn[d.weekday - 1]}, ${d.day} ${mn[d.month - 1]}';
  }
}

/// The orb plus its bubbles, laid out around it.
class _MindMapRadial extends StatelessWidget {
  final String centerLabel;
  final double overall;
  final List<_BranchData> branches;
  final String? selectedKey;
  final Animation<double> breath;
  final bool dark;
  final ValueChanged<String> onSelect;
  final VoidCallback onOrbTap;

  const _MindMapRadial({
    required this.centerLabel,
    required this.overall,
    required this.branches,
    required this.selectedKey,
    required this.breath,
    required this.dark,
    required this.onSelect,
    required this.onOrbTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size.width / 2, size.height / 2);
        // Bubbles are 104 wide; keep at least a 16px margin from the edges and
        // never collapse onto the orb on very small screens.
        final radius = math.max(96.0, math.min(size.width, size.height) / 2 - 70);
        final positions = <Offset>[];
        for (var i = 0; i < branches.length; i++) {
          final angle = (-90 + (360 / branches.length) * i) * math.pi / 180;
          positions.add(Offset(
            center.dx + radius * math.cos(angle),
            center.dy + radius * math.sin(angle),
          ));
        }
        final mood = overall >= 0.67
            ? const Color(0xFF6FDCA8)
            : (overall >= 0.34 ? Brand.gold : const Color(0xFFC79BF0));
        return Stack(
          children: [
            CustomPaint(
              size: size,
              painter: _BranchLinePainter(
                center: center,
                points: positions,
                colors: [for (final b in branches) b.color],
                fills: [for (final b in branches) b.fill],
                selected: branches.indexWhereKey(selectedKey),
              ),
            ),
            Positioned(
              left: center.dx - 60,
              top: center.dy - 60,
              child: GestureDetector(
                onTap: onOrbTap,
                child: AnimatedBuilder(
                  animation: breath,
                  builder: (context, _) {
                    final glow = 14 + 14 * breath.value;
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: overall),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: _OrbRingPainter(progress: v, color: mood, track: Surfaces.muted(dark).withValues(alpha: 0.25)),
                          child: Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [mood, Color.lerp(mood, Colors.black, 0.18)!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: mood.withValues(alpha: 0.45),
                                      blurRadius: glow,
                                      spreadRadius: 2),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${(v * 100).round()}%',
                                      style: display(22, Brand.deep)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      centerLabel,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: body(9.5, Brand.deep, weight: FontWeight.w700),
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
              ),
            ),
            for (var i = 0; i < branches.length; i++)
              Positioned(
                left: positions[i].dx - 52,
                top: positions[i].dy - 44,
                child: GestureDetector(
                  onTap: () => onSelect(branches[i].key),
                  child: AnimatedScale(
                    scale: branches[i].key == selectedKey ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    child: _BranchNode(
                      data: branches[i],
                      dark: dark,
                      selected: branches[i].key == selectedKey,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

extension on List<_BranchData> {
  int indexWhereKey(String? key) {
    if (key == null) return -1;
    return indexWhere((b) => b.key == key);
  }
}

class _BranchNode extends StatelessWidget {
  final _BranchData data;
  final bool dark;
  final bool selected;
  const _BranchNode({required this.data, required this.dark, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Surfaces.card(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: data.color.withValues(alpha: selected ? 1 : 0.45),
            width: selected ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: selected
                  ? data.color.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
              blurRadius: selected ? 14 : 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CustomPaint(
              painter: _OrbRingPainter(
                progress: data.fill,
                color: data.color,
                track: data.color.withValues(alpha: 0.2),
                stroke: 3.5,
              ),
              child: Center(child: Icon(data.icon, size: 17, color: data.color)),
            ),
          ),
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

/// A circular progress ring: a faint track and a rounded arc from 12 o'clock.
class _OrbRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double stroke;
  const _OrbRingPainter({
    required this.progress,
    required this.color,
    required this.track,
    this.stroke = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * p,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(covariant _OrbRingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Lines from the orb to each bubble: thicker and brighter the fuller the
/// bubble is, boldest for the open one.
class _BranchLinePainter extends CustomPainter {
  final Offset center;
  final List<Offset> points;
  final List<Color> colors;
  final List<double> fills;
  final int selected;
  const _BranchLinePainter({
    required this.center,
    required this.points,
    required this.colors,
    required this.fills,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length; i++) {
      final fill = i < fills.length ? fills[i] : 0.0;
      final base = i < colors.length ? colors[i] : Colors.grey;
      final paint = Paint()
        ..color = base.withValues(alpha: i == selected ? 0.95 : 0.35 + 0.3 * fill)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (i == selected ? 3.5 : 1.6) + 2.0 * fill;
      canvas.drawLine(center, points[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BranchLinePainter old) => true;
}
