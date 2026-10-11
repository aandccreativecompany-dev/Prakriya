import 'package:flutter/material.dart';

import '../models.dart';
import '../services/extras.dart';
import '../services/home_widget_service.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Design the Android home-screen widget: pick a look, choose what it shows,
/// see a live preview (tap a habit to tick it) and add it to the home screen.
class WidgetStudioScreen extends StatefulWidget {
  const WidgetStudioScreen({super.key});

  @override
  State<WidgetStudioScreen> createState() => _WidgetStudioScreenState();
}

class _WidgetStudioScreenState extends State<WidgetStudioScreen> {
  bool? _canPin;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    HomeWidgetService.instance.canPin().then((value) {
      if (mounted) setState(() => _canPin = value);
    });
  }

  Future<void> _toggleHabit(Habit h) async {
    final all = store.habits.map((x) => x.id).toList();
    final current = all.where(store.widgetHabitSelected).toSet();
    if (current.contains(h.id)) {
      if (current.length <= 1) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Keep at least one habit, or switch the checklist off.')));
        return;
      }
      current.remove(h.id);
    } else {
      current.add(h.id);
    }
    await store.setWidgetHabitIds(
        current.length == all.length ? <String>[] : current.toList());
  }

  Future<void> _addToHome() async {
    if (_busy) return;
    setState(() => _busy = true);
    var shownHelp = false;
    if (_canPin == true) {
      final ok = await HomeWidgetService.instance.requestPin();
      if (!ok) shownHelp = true;
    } else {
      shownHelp = true;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (shownHelp) {
      _showHowTo();
    }
  }

  void _showHowTo() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Surfaces.sheet(dark),
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add it to your home screen',
                style: display(20, Surfaces.heading(dark))),
            const SizedBox(height: 12),
            for (final step in const [
              'Press and hold an empty spot on your home screen.',
              'Tap "Widgets".',
              'Find "Prakriyā" and press and hold the widget.',
              'Drag it where you want it, then drop it.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18, color: Surfaces.accent(dark)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(step,
                            style: body(13.5, Surfaces.bodyText(dark)))),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
                'Some phones (Vivo, Xiaomi, Oppo) ask for a "Display on home screen" or shortcut permission the first time. Allow it.',
                style: body(12, Surfaces.muted(dark))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[store, extras]),
            builder: (context, _) {
              final snap = HomeWidgetService.instance.snapshot();
              final habits = store.habits;
              return Column(
                children: [
                  const ScreenHeader(
                    icon: Icons.widgets_outlined,
                    title: 'Widget studio',
                    subtitle: 'Design what you see on your home screen',
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                      children: [
                        Text('LIVE PREVIEW', style: label(Surfaces.muted(dark))),
                        const SizedBox(height: 10),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: _WidgetPreview(snap: snap),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'Tap a habit above to tick it. The widget on your home screen follows.',
                            textAlign: TextAlign.center,
                            style: body(11.5, Surfaces.muted(dark))),
                        const SizedBox(height: 18),
                        GoldButton(
                          labelText:
                              _busy ? 'Opening...' : 'Add widget to home screen',
                          onPressed: _addToHome,
                        ),
                        if (_canPin == false)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                'Your launcher cannot add it for you. Tap the button for the quick steps.',
                                textAlign: TextAlign.center,
                                style: body(11.5, Surfaces.muted(dark))),
                          ),
                        const SizedBox(height: 24),
                        Text('LOOK', style: label(Surfaces.muted(dark))),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final option in kWidgetStyles)
                              Expanded(
                                child: _StyleSwatch(
                                  option: option,
                                  selected: extras.widgetStyle == option.key,
                                  onTap: () =>
                                      extras.setWidgetLook(style: option.key),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('WHAT IT SHOWS', style: label(Surfaces.muted(dark))),
                        const SizedBox(height: 10),
                        ModuleCard(
                          child: Column(
                            children: [
                              _ToggleRow(
                                label: "Today's habits checklist",
                                value: store.widgetShowHabits,
                                onChanged: (v) => store.setWidgetShowHabits(v),
                              ),
                              _ToggleRow(
                                label: 'Progress bar',
                                value: extras.widgetShowProgress,
                                onChanged: (v) =>
                                    extras.setWidgetLook(progress: v),
                              ),
                              _ToggleRow(
                                label: 'Top to-do',
                                value: store.widgetShowPriorities,
                                onChanged: (v) =>
                                    store.setWidgetShowPriorities(v),
                              ),
                              _ToggleRow(
                                label: "Today's mantra",
                                value: store.widgetShowMantra,
                                onChanged: (v) => store.setWidgetShowMantra(v),
                              ),
                              _ToggleRow(
                                label: 'Streak counter',
                                value: extras.widgetShowStreak,
                                onChanged: (v) =>
                                    extras.setWidgetLook(streak: v),
                              ),
                            ],
                          ),
                        ),
                        if (store.widgetShowHabits && habits.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text('WHICH HABITS', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 6),
                          Text(
                              habits.length > 5
                                  ? 'The widget lists up to 5 habits. Progress counts every habit you select.'
                                  : 'Tap to include or leave out a habit.',
                              style: body(11.5, Surfaces.muted(dark))),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final h in habits)
                                _HabitChip(
                                  name: h.name,
                                  selected: store.widgetHabitSelected(h.id),
                                  onTap: () => _toggleHabit(h),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        ModuleCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Good to know',
                                  style: body(13.5, Surfaces.heading(dark),
                                      weight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text(
                                  'The widget refreshes whenever you change something in the app, and about every 30 minutes on its own. Tap it to open Prakriyā. You can resize it: a taller widget shows more.',
                                  style: body(12.5, Surfaces.muted(dark))
                                      .copyWith(height: 1.45)),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () async {
                                  await HomeWidgetService.instance.forceRefresh();
                                  if (context.mounted) {
                                    toastSaved(context, label: 'Widget refreshed');
                                  }
                                },
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft),
                                icon: Icon(Icons.refresh,
                                    size: 16, color: Surfaces.accent(dark)),
                                label: Text('Refresh widget now',
                                    style: body(13, Surfaces.accent(dark),
                                        weight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
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
}

class _WidgetPreview extends StatelessWidget {
  final WidgetSnapshot snap;
  const _WidgetPreview({required this.snap});

  @override
  Widget build(BuildContext context) {
    final style = widgetStyleFor(snap.style);
    final text = Color(style.text);
    final muted = Color(style.muted);
    final accent = Color(style.accent);
    final nothing =
        snap.mantra.isEmpty && snap.priority.isEmpty && snap.habits.isEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(style.bgStart), Color(style.bgEnd)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Color(style.border)),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Prakriyā',
                    style: body(15, Color(style.title), weight: FontWeight.w800)),
              ),
              if (snap.showStreak && snap.streak > 0)
                Text('🔥 ${snap.streak}',
                    style: body(12.5, accent, weight: FontWeight.w800)),
            ],
          ),
          Text(snap.dateLabel, style: body(10.5, muted)),
          if (snap.showProgress && snap.total > 0) ...[
            const SizedBox(height: 10),
            Text(
                snap.done >= snap.total
                    ? 'All ${snap.total} habits done today ✓'
                    : '${snap.done} of ${snap.total} habits done',
                style: body(11.5, muted)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (snap.done / snap.total).clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                backgroundColor: muted.withValues(alpha: 0.28),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
          if (snap.priority.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('▸ ${snap.priority}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(12.5, text, weight: FontWeight.w700)),
          ],
          if (snap.habits.isNotEmpty) const SizedBox(height: 6),
          for (final line in snap.habits)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => store.toggleHabit(line.habit),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                        line.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: line.done ? Color(style.done) : accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(line.habit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(12.5, line.done ? Color(style.done) : text)
                              .copyWith(
                                  decoration: line.done
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none)),
                    ),
                  ],
                ),
              ),
            ),
          if (snap.mantra.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('“${snap.mantra}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: body(12, text).copyWith(fontStyle: FontStyle.italic)),
          ],
          if (nothing) ...[
            const SizedBox(height: 10),
            Text('Open Prakriyā to set up your day.',
                style: body(11.5, muted)),
          ],
        ],
      ),
    );
  }
}

class _StyleSwatch extends StatelessWidget {
  final WidgetStyleOption option;
  final bool selected;
  final VoidCallback onTap;
  const _StyleSwatch(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(option.bgStart), Color(option.bgEnd)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? Surfaces.accent(dark) : Color(option.border),
                  width: selected ? 3 : 1,
                ),
              ),
              child: Center(
                child: selected
                    ? Icon(Icons.check_circle, color: Color(option.accent), size: 22)
                    : Container(
                        width: 18,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Color(option.accent),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(option.label,
                style: body(12, selected ? Surfaces.heading(dark) : Surfaces.muted(dark),
                    weight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w500)),
        ),
        Switch(
          value: value,
          activeTrackColor: Surfaces.accent(dark),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _HabitChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _HabitChip(
      {required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Surfaces.accent(dark);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : Surfaces.accentBorder(dark)),
        ),
        child: Text(name,
            style: body(12, selected ? accent : Surfaces.muted(dark),
                weight: FontWeight.w600)),
      ),
    );
  }
}
