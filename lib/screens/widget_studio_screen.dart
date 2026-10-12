import 'package:flutter/material.dart';

import '../models.dart';
import '../services/extras.dart';
import '../services/home_widget_service.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Design the Android home-screen widget: choose what it shows and in what
/// order, edit today's to-do list, and see an exact live preview. The preview
/// is interactive: tick tasks and habits, tap a task to edit or delete it.
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

  Future<void> _addTask() async {
    final result = await showDialog<_TaskEdit>(
      context: context,
      builder: (_) => const _TaskDialog(),
    );
    if (result == null || result.delete) return;
    await store.addTask(result.text);
  }

  Future<void> _editTask(WidgetTaskLine line) async {
    final result = await showDialog<_TaskEdit>(
      context: context,
      builder: (_) => _TaskDialog(initial: line.task.title),
    );
    if (result == null) return;
    if (result.delete) {
      await store.removeTask(line.index);
    } else {
      await store.renameTask(line.index, result.text);
    }
  }

  Future<void> _toggleHabitInWidget(Habit h) async {
    final all = store.habits.map((x) => x.id).toList();
    final current = all.where(store.widgetHabitSelected).toSet();
    if (current.contains(h.id)) {
      if (current.length <= 1) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Keep at least one habit, or switch the habit checklist off.')));
        return;
      }
      current.remove(h.id);
    } else {
      current.add(h.id);
    }
    await store.setWidgetHabitIds(
        current.length == all.length ? <String>[] : current.toList());
  }

  void _toggleStat(String key) {
    final current = List<String>.from(extras.widgetStats);
    if (current.contains(key)) {
      current.remove(key);
    } else {
      if (current.length >= 4) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('Up to four stats. Remove one first.')));
        return;
      }
      current.add(key);
    }
    extras.setWidgetStats(current);
  }

  Future<void> _addToHome() async {
    if (_busy) return;
    setState(() => _busy = true);
    var needHelp = false;
    if (_canPin == true) {
      final ok = await HomeWidgetService.instance.requestPin();
      if (!ok) needHelp = true;
    } else {
      needHelp = true;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (needHelp) _showHowTo();
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
              'Drag it where you want it, then drop it. Make it taller to see more.',
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
              final habitsOn = extras.widgetBlockOn('habits');
              final statsOn = extras.widgetBlockOn('stats');
              return Column(
                children: [
                  const ScreenHeader(
                    icon: Icons.widgets_outlined,
                    title: 'Widget studio',
                    subtitle: 'Your dashboard and to-do list on the home screen',
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                      children: [
                        Text('LIVE PREVIEW', style: label(Surfaces.muted(dark))),
                        const SizedBox(height: 10),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: _WidgetPreview(
                              snap: snap,
                              onAddTask: _addTask,
                              onEditTask: _editTask,
                              onToggleTask: (line) => store.toggleTask(line.index),
                              onToggleHabit: (h) => store.toggleHabit(h),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'Same as your home screen. Tick things off, tap a task to edit or delete it, or tap + to add one.',
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
                        Text('WHAT SHOWS, AND IN WHAT ORDER',
                            style: label(Surfaces.muted(dark))),
                        const SizedBox(height: 6),
                        Text('Switch blocks on or off. Press and drag the handle to reorder.',
                            style: body(11.5, Surfaces.muted(dark))),
                        const SizedBox(height: 10),
                        ModuleCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final list = List<String>.from(extras.widgetOrder);
                              final item = list.removeAt(oldIndex);
                              list.insert(newIndex, item);
                              extras.setWidgetOrder(list);
                            },
                            children: [
                              for (var i = 0; i < extras.widgetOrder.length; i++)
                                _BlockRow(
                                  key: ValueKey<String>(extras.widgetOrder[i]),
                                  index: i,
                                  blockKey: extras.widgetOrder[i],
                                  on: extras.widgetBlockOn(extras.widgetOrder[i]),
                                  onChanged: (v) =>
                                      extras.setWidgetBlockOn(extras.widgetOrder[i], v),
                                ),
                            ],
                          ),
                        ),
                        if (statsOn) ...[
                          const SizedBox(height: 24),
                          Text('DASHBOARD STATS', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 6),
                          Text('Pick up to four.',
                              style: body(11.5, Surfaces.muted(dark))),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in kWidgetStatOptions)
                                _HabitChip(
                                  name: option.$2,
                                  selected: extras.widgetStats.contains(option.$1),
                                  onTap: () => _toggleStat(option.$1),
                                ),
                            ],
                          ),
                        ],
                        if (extras.widgetBlockOn('tasks')) ...[
                          const SizedBox(height: 24),
                          ModuleCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('Keep finished tasks in the list',
                                      style: body(13.5, Surfaces.bodyText(dark),
                                          weight: FontWeight.w500)),
                                ),
                                Switch(
                                  value: extras.widgetShowDoneTasks,
                                  activeTrackColor: Surfaces.accent(dark),
                                  onChanged: extras.setWidgetShowDoneTasks,
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (habitsOn && habits.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text('WHICH HABITS', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 6),
                          Text('Tap to include or leave out a habit.',
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
                                  onTap: () => _toggleHabitInWidget(h),
                                ),
                            ],
                          ),
                        ],
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
                                  onTap: () => extras.setWidgetStyle(option.key),
                                ),
                              ),
                          ],
                        ),
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
                                  'On the widget, tap a circle to tick a task or habit. Tap a title to open your list. Tap + to add a task. Ticks are saved to the app the next time it opens. A taller widget shows more rows. It refreshes whenever you change something here, and about every 30 minutes on its own.',
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

class _TaskEdit {
  final String text;
  final bool delete;
  const _TaskEdit(this.text, this.delete);
}

class _TaskDialog extends StatefulWidget {
  final String? initial;
  const _TaskDialog({this.initial});

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(_TaskEdit(text, false));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Edit task' : 'New task'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(hintText: 'What needs doing today?'),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const _TaskEdit('', true)),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _BlockRow extends StatelessWidget {
  final int index;
  final String blockKey;
  final bool on;
  final ValueChanged<bool> onChanged;
  const _BlockRow({
    super.key,
    required this.index,
    required this.blockKey,
    required this.on,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    var title = blockKey;
    var hint = '';
    for (final b in kWidgetBlocks) {
      if (b.$1 == blockKey) {
        title = b.$2;
        hint = b.$3;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
              child: Icon(Icons.drag_indicator, color: Surfaces.muted(dark)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: body(13.5, Surfaces.bodyText(dark),
                        weight: FontWeight.w600)),
                Text(hint, style: body(11, Surfaces.muted(dark))),
              ],
            ),
          ),
          Switch(
            value: on,
            activeTrackColor: Surfaces.accent(dark),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// An exact copy of what the home-screen widget draws, but live: ticks go
/// straight to the store and tasks can be edited or added.
class _WidgetPreview extends StatelessWidget {
  final WidgetSnapshot snap;
  final VoidCallback onAddTask;
  final ValueChanged<WidgetTaskLine> onEditTask;
  final ValueChanged<WidgetTaskLine> onToggleTask;
  final ValueChanged<Habit> onToggleHabit;
  const _WidgetPreview({
    required this.snap,
    required this.onAddTask,
    required this.onEditTask,
    required this.onToggleTask,
    required this.onToggleHabit,
  });

  @override
  Widget build(BuildContext context) {
    final style = widgetStyleFor(snap.style);
    final text = Color(style.text);
    final muted = Color(style.muted);
    final accent = Color(style.accent);
    final doneColor = Color(style.done);

    Widget header(String title, String count) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: body(10.5, muted, weight: FontWeight.w800)),
              ),
              Text(count, style: body(10.5, muted)),
            ],
          ),
        );

    Widget note(String message) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(message, style: body(12, muted)),
        );

    Widget row({
      required bool done,
      required String name,
      required VoidCallback onTick,
      VoidCallback? onTap,
    }) =>
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTick,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
                child: Icon(
                    done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                    size: 21,
                    color: done ? doneColor : accent),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(13.5, done ? doneColor : text)),
                ),
              ),
            ),
          ],
        );

    final children = <Widget>[];
    for (final block in snap.blocks) {
      switch (block) {
        case 'stats':
          if (snap.stats.isNotEmpty) {
            children.add(Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  for (final s in snap.stats)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.value,
                              style: body(19, text, weight: FontWeight.w800)),
                          Text(s.label, style: body(10.5, muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ));
          }
          break;
        case 'progress':
          if (snap.total > 0) {
            children.add(Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      snap.done >= snap.total
                          ? 'Everything done today'
                          : '${snap.done} of ${snap.total} done today',
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
              ),
            ));
          }
          break;
        case 'tasks':
          final shownTasks = snap.showDoneTasks
              ? snap.tasks
              : snap.tasks.where((t) => !t.task.done).toList();
          children.add(header('TO-DO',
              snap.tasks.isEmpty ? '' : '${snap.tasksDone}/${snap.tasks.length}'));
          if (shownTasks.isEmpty) {
            children.add(note(snap.tasks.isEmpty
                ? 'No tasks yet. Tap + to add one.'
                : 'All done. Nicely done.'));
          }
          for (final line in shownTasks) {
            children.add(row(
              done: line.task.done,
              name: line.task.title,
              onTick: () => onToggleTask(line),
              onTap: () => onEditTask(line),
            ));
          }
          break;
        case 'habits':
          children.add(header('HABITS',
              snap.habits.isEmpty ? '' : '${snap.habitsDone}/${snap.habits.length}'));
          if (snap.habits.isEmpty) {
            children.add(note('No habits selected. Pick some below.'));
          }
          for (final line in snap.habits) {
            children.add(row(
              done: line.done,
              name: line.habit.name,
              onTick: () => onToggleHabit(line.habit),
            ));
          }
          break;
        case 'mantra':
          if (snap.mantra.isNotEmpty) {
            children.add(Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('“${snap.mantra}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: body(12.5, text).copyWith(fontStyle: FontStyle.italic)),
            ));
          }
          break;
      }
    }

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prakriyā',
                        style: body(15, Color(style.title), weight: FontWeight.w800)),
                    Text(snap.dateLabel, style: body(10.5, muted)),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onAddTask,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.add, color: accent, size: 26),
                ),
              ),
            ],
          ),
          ...children,
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Switch a block on below to fill your widget.',
                  style: body(12, muted)),
            ),
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
