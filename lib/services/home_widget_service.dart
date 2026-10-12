import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models.dart';
import '../store.dart';
import 'extras.dart';

/// One look the home-screen widget can have. The same palette drives the
/// in-app preview and the native widget (which has its own copy in Kotlin).
class WidgetStyleOption {
  final String key;
  final String label;
  final int bgStart;
  final int bgEnd;
  final int border;
  final int title;
  final int text;
  final int muted;
  final int accent;
  final int done;
  const WidgetStyleOption({
    required this.key,
    required this.label,
    required this.bgStart,
    required this.bgEnd,
    required this.border,
    required this.title,
    required this.text,
    required this.muted,
    required this.accent,
    required this.done,
  });
}

const List<WidgetStyleOption> kWidgetStyles = [
  WidgetStyleOption(
      key: 'dusk',
      label: 'Dusk',
      bgStart: 0xFF2A1650,
      bgEnd: 0xFF150C28,
      border: 0xFF44307A,
      title: 0xFFF2B93B,
      text: 0xFFF4EEFF,
      muted: 0xFFA99BD0,
      accent: 0xFFF2B93B,
      done: 0xFF7F72A8),
  WidgetStyleOption(
      key: 'sunrise',
      label: 'Sunrise',
      bgStart: 0xFFFFF4E2,
      bgEnd: 0xFFFFD7AE,
      border: 0xFFF0B98A,
      title: 0xFFC2531A,
      text: 0xFF3A2216,
      muted: 0xFF8A5A3C,
      accent: 0xFFE2661F,
      done: 0xFFB59A86),
  WidgetStyleOption(
      key: 'forest',
      label: 'Forest',
      bgStart: 0xFF1B4A3A,
      bgEnd: 0xFF0D2620,
      border: 0xFF2E6B55,
      title: 0xFF7BE0B2,
      text: 0xFFE6F5EC,
      muted: 0xFF8FBFA6,
      accent: 0xFF5ED39A,
      done: 0xFF6E9C87),
  WidgetStyleOption(
      key: 'paper',
      label: 'Paper',
      bgStart: 0xFFFFFDF7,
      bgEnd: 0xFFF6EFE0,
      border: 0xFFE4D9C3,
      title: 0xFF5A32A8,
      text: 0xFF2B2140,
      muted: 0xFF8E84A3,
      accent: 0xFF6B3FC4,
      done: 0xFFA89FB8),
];

WidgetStyleOption widgetStyleFor(String key) {
  for (final s in kWidgetStyles) {
    if (s.key == key) return s;
  }
  return kWidgetStyles.first;
}

class WidgetHabitLine {
  final Habit habit;
  final bool done;
  const WidgetHabitLine(this.habit, this.done);
}

/// One of today's tasks, with its position in the store's list (needed to
/// tick, edit or delete it).
class WidgetTaskLine {
  final int index;
  final Task task;
  const WidgetTaskLine(this.index, this.task);
}

class WidgetStat {
  final String key;
  final String label;
  final String value;
  const WidgetStat(this.key, this.label, this.value);
}

/// Blocks the widget can show, in their default order.
const List<(String key, String label, String hint)> kWidgetBlocks = [
  ('stats', 'Dashboard stats', 'Up to four numbers at a glance'),
  ('progress', 'Progress bar', "How much of today is done"),
  ('tasks', 'To-do list', 'Today\'s tasks, tick them right on the widget'),
  ('habits', 'Habit checklist', 'Tick habits right on the widget'),
  ('mantra', 'Daily mantra', "Today's line to carry"),
];

/// Stats the dashboard block can show.
const List<(String key, String label)> kWidgetStatOptions = [
  ('habits', 'Habits'),
  ('tasks', 'Tasks'),
  ('streak', 'Day streak'),
  ('focus', 'Focus'),
  ('meditate', 'Meditated'),
  ('water', 'Water'),
];

/// Everything the widget shows right now, computed once so the in-app
/// preview and the native widget never disagree.
class WidgetSnapshot {
  final String style;
  final String dateLabel;
  final String mantra;
  final int streak;
  final List<String> blocks;
  final List<WidgetStat> stats;
  final List<WidgetHabitLine> habits;
  final List<WidgetTaskLine> tasks;
  final bool showDoneTasks;
  const WidgetSnapshot({
    required this.style,
    required this.dateLabel,
    required this.mantra,
    required this.streak,
    required this.blocks,
    required this.stats,
    required this.habits,
    required this.tasks,
    required this.showDoneTasks,
  });

  int get habitsDone => habits.where((h) => h.done).length;
  int get tasksDone => tasks.where((t) => t.task.done).length;
  int get total => habits.length + tasks.length;
  int get done => habitsDone + tasksDone;
}

/// Keeps the Android home-screen widget in sync with the app, in both
/// directions.
///
/// App to widget: the look, the blocks to show and today's lists are written
/// as text into shared preferences and the widget is told to redraw.
/// Widget to app: ticking a task or habit on the widget redraws it at once
/// and queues the change under `widget_pending`; [syncFromWidget] applies
/// that queue to the store the next time the app runs. Taps on titles open
/// the app, which reports them through [pendingOpen].
///
/// The native provider and layouts live in `android_overrides/widget/` and
/// are copied into the generated Android project by CI.
class HomeWidgetService {
  HomeWidgetService._();
  static final instance = HomeWidgetService._();

  static const _androidWidgetName = 'HabitsWidgetProvider';
  static const _qualifiedName = 'ai.aandccreative.prakriya.HabitsWidgetProvider';

  /// A screen the widget asked to open ('tasks', 'addtask', 'dashboard').
  /// The home screen consumes it, so a PIN lock is never bypassed.
  final ValueNotifier<String?> pendingOpen = ValueNotifier<String?>(null);

  bool _wired = false;
  Timer? _debounce;
  bool _pushing = false;
  bool _again = false;

  /// Starts listening and pushing widget data on every change. Safe to call
  /// more than once.
  void wire() {
    if (_wired) return;
    _wired = true;
    store.addListener(_schedule);
    extras.addListener(_schedule);
    try {
      HomeWidget.widgetClicked.listen(_handleUri, onError: (Object _) {});
      HomeWidget.initiallyLaunchedFromHomeWidget()
          .then(_handleUri)
          .catchError((Object _) {});
    } catch (_) {
      // No widget plugin on this platform.
    }
    _schedule();
  }

  void _handleUri(Uri? uri) {
    if (uri == null || uri.scheme != 'prakriya' || uri.host != 'widget') return;
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'open') {
      pendingOpen.value = segments[1];
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_push());
    });
  }

  /// Manual "update now".
  Future<void> forceRefresh() => _push();

  // ---- Snapshot ----

  /// What the widget shows right now.
  WidgetSnapshot snapshot() {
    final today = DateTime.now();

    final habitLines = <WidgetHabitLine>[];
    for (final h in store.habits) {
      if (store.widgetHabitSelected(h.id)) {
        habitLines.add(WidgetHabitLine(h, h.isDoneOn(today)));
      }
    }

    // Open tasks first, finished ones after; each keeps its store position.
    final all = store.todaysTasks;
    final open = <WidgetTaskLine>[];
    final finished = <WidgetTaskLine>[];
    for (var i = 0; i < all.length; i++) {
      (all[i].done ? finished : open).add(WidgetTaskLine(i, all[i]));
    }
    final taskLines = <WidgetTaskLine>[...open, ...finished];

    final streak = _overallStreak();
    final stats = <WidgetStat>[];
    for (final key in extras.widgetStats) {
      switch (key) {
        case 'habits':
          final habitsDone = habitLines.where((h) => h.done).length;
          stats.add(WidgetStat('habits', 'Habits',
              habitLines.isEmpty ? '–' : '$habitsDone/${habitLines.length}'));
          break;
        case 'tasks':
          final tasksDone = taskLines.where((t) => t.task.done).length;
          stats.add(WidgetStat('tasks', 'Tasks',
              taskLines.isEmpty ? '–' : '$tasksDone/${taskLines.length}'));
          break;
        case 'streak':
          stats.add(WidgetStat('streak', 'Day streak', '$streak'));
          break;
        case 'focus':
          stats.add(WidgetStat('focus', 'Focus', '${extras.focusMinutesOn(today)}m'));
          break;
        case 'meditate':
          stats.add(WidgetStat(
              'meditate', 'Meditated', '${extras.meditationMinutesOn(today)}m'));
          break;
        case 'water':
          stats.add(WidgetStat('water', 'Water', '${extras.waterOn(today)}'));
          break;
      }
    }

    return WidgetSnapshot(
      style: extras.widgetStyle,
      dateLabel: _dateLabel(today),
      mantra: store.mantraOfTheDay,
      streak: streak,
      blocks: <String>[
        for (final k in extras.widgetOrder)
          if (extras.widgetBlockOn(k)) k,
      ],
      stats: stats,
      habits: habitLines,
      tasks: taskLines,
      showDoneTasks: extras.widgetShowDoneTasks,
    );
  }

  static String _dateLabel(DateTime d) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  /// Consecutive days with at least one habit done. A day that has not had a
  /// check-in yet does not break a streak that was alive yesterday.
  int _overallStreak() {
    if (store.habits.isEmpty) return 0;
    bool anyDone(DateTime day) => store.habits.any((h) => h.isDoneOn(day));
    var cursor = DateTime.now();
    if (!anyDone(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    var count = 0;
    while (count < 400 && anyDone(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  // ---- Pinning ----

  /// Whether this phone's launcher can show the "add widget" prompt.
  Future<bool> canPin() async {
    try {
      return (await HomeWidget.isRequestPinWidgetSupported()) == true;
    } catch (_) {
      return false;
    }
  }

  /// Asks the launcher to add the widget. Returns false if that failed.
  Future<bool> requestPin() async {
    try {
      await _push();
      await HomeWidget.requestPinWidget(qualifiedAndroidName: _qualifiedName);
      return true;
    } catch (e) {
      debugPrint('requestPinWidget failed: $e');
      return false;
    }
  }

  // ---- Widget to app ----

  /// Applies ticks made on the home-screen widget to the store. Safe to call
  /// at any time; does nothing when nothing is queued.
  Future<void> syncFromWidget() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>('widget_pending',
          defaultValue: '[]');
      if (raw == null || raw.isEmpty || raw == '[]') return;
      await HomeWidget.saveWidgetData<String>('widget_pending', '[]');
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final todayKey = dayKey(DateTime.now());
      final now = DateTime.now();
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final day = entry['day'];
        if (day is String && day.isNotEmpty && day != todayKey) continue;
        final kind = entry['k'];
        final key = entry['key'];
        final want = entry['v'] == true;
        if (key is! String) continue;
        if (kind == 'habit') {
          for (final h in store.habits) {
            if (h.id == key) {
              if (h.isDoneOn(now) != want) await store.toggleHabit(h);
              break;
            }
          }
        } else if (kind == 'task') {
          final tasks = store.todaysTasks;
          final hint = entry['i'];
          var index = -1;
          if (hint is int &&
              hint >= 0 &&
              hint < tasks.length &&
              tasks[hint].title == key) {
            index = hint;
          } else {
            for (var i = 0; i < tasks.length; i++) {
              if (tasks[i].title == key && tasks[i].done != want) {
                index = i;
                break;
              }
            }
          }
          if (index >= 0 && tasks[index].done != want) {
            await store.toggleTask(index);
          }
        }
      }
    } catch (e) {
      debugPrint('syncFromWidget failed: $e');
    }
  }

  // ---- App to widget ----

  Future<void> _push() async {
    if (_pushing) {
      _again = true;
      return;
    }
    _pushing = true;
    try {
      do {
        _again = false;
        await _pushOnce();
      } while (_again);
    } finally {
      _pushing = false;
    }
  }

  Future<void> _pushOnce() async {
    try {
      // Ticks made on the widget come first, so the data we write back
      // already includes them.
      await syncFromWidget();

      // One-time: carry the older per-section switches into the block list.
      if (!extras.widgetBlocksSeeded) {
        extras.seedWidgetBlocks(off: <String>[
          if (!store.widgetShowHabits) 'habits',
          if (!store.widgetShowPriorities) 'tasks',
          if (!store.widgetShowMantra) 'mantra',
        ]);
      }

      final snap = snapshot();
      final tasksJson = jsonEncode([
        for (final t in snap.tasks)
          {'i': t.index, 't': t.task.title, 'd': t.task.done},
      ]);
      final habitsJson = jsonEncode([
        for (final h in snap.habits)
          {'id': h.habit.id, 'n': h.habit.name, 'd': h.done},
      ]);
      final statsJson = jsonEncode([
        for (final s in snap.stats) {'k': s.key, 'l': s.label, 'v': s.value},
      ]);

      Future<void> put(String key, String value) async {
        await HomeWidget.saveWidgetData<String>(key, value);
      }

      await put('widget_style', snap.style);
      await put('widget_date', snap.dateLabel);
      await put('widget_day', dayKey(DateTime.now()));
      await put('widget_blocks', jsonEncode(snap.blocks));
      await put('widget_stats', statsJson);
      await put('widget_tasks', tasksJson);
      await put('widget_habits', habitsJson);
      await put('widget_mantra', snap.mantra);
      await put('widget_show_done_tasks', snap.showDoneTasks ? '1' : '0');
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (_) {
      // No widget added yet, or a platform without the native provider.
      // Nothing else in the app depends on this succeeding.
    }
  }
}
