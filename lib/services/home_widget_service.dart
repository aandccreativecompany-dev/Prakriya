import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

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
  final bool light;
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
    required this.light,
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
      key: 'dusk', label: 'Dusk', light: false,
      bgStart: 0xFF2A1650, bgEnd: 0xFF150C28, border: 0xFF44307A,
      title: 0xFFF2B93B, text: 0xFFF4EEFF, muted: 0xFFB4A8DA,
      accent: 0xFFF2B93B, done: 0xFF8A7DB0),
  WidgetStyleOption(
      key: 'midnight', label: 'Midnight', light: false,
      bgStart: 0xFF101014, bgEnd: 0xFF000000, border: 0xFF2A2A33,
      title: 0xFFFFFFFF, text: 0xFFF2F2F5, muted: 0xFF9A9AA8,
      accent: 0xFF7CC4FF, done: 0xFF70707E),
  WidgetStyleOption(
      key: 'ocean', label: 'Ocean', light: false,
      bgStart: 0xFF0F3B5C, bgEnd: 0xFF071B2E, border: 0xFF1F5F8B,
      title: 0xFF7FD8FF, text: 0xFFEAF6FF, muted: 0xFF93BAD6,
      accent: 0xFF4FC3F7, done: 0xFF6C90AA),
  WidgetStyleOption(
      key: 'forest', label: 'Forest', light: false,
      bgStart: 0xFF1B4A3A, bgEnd: 0xFF0D2620, border: 0xFF2E6B55,
      title: 0xFF7BE0B2, text: 0xFFE6F5EC, muted: 0xFF9CC8B2,
      accent: 0xFF5ED39A, done: 0xFF729F8B),
  WidgetStyleOption(
      key: 'graphite', label: 'Graphite', light: false,
      bgStart: 0xFF3A3F47, bgEnd: 0xFF1C1F24, border: 0xFF565C66,
      title: 0xFFFFC857, text: 0xFFF1F3F5, muted: 0xFFA9B0BA,
      accent: 0xFFFFC857, done: 0xFF7E858F),
  WidgetStyleOption(
      key: 'sunrise', label: 'Sunrise', light: true,
      bgStart: 0xFFFFF4E2, bgEnd: 0xFFFFD7AE, border: 0xFFF0B98A,
      title: 0xFFC2531A, text: 0xFF3A2216, muted: 0xFF7A4E32,
      accent: 0xFFE2661F, done: 0xFFA48A76),
  WidgetStyleOption(
      key: 'rose', label: 'Rose', light: true,
      bgStart: 0xFFFFF0F4, bgEnd: 0xFFFFD3DF, border: 0xFFF0AFC2,
      title: 0xFFB8264F, text: 0xFF3B1A25, muted: 0xFF7A4A5C,
      accent: 0xFFD6336C, done: 0xFFA98593),
  WidgetStyleOption(
      key: 'paper', label: 'Paper', light: true,
      bgStart: 0xFFFFFDF7, bgEnd: 0xFFF6EFE0, border: 0xFFE4D9C3,
      title: 0xFF5A32A8, text: 0xFF2B2140, muted: 0xFF766C8C,
      accent: 0xFF6B3FC4, done: 0xFF9E95AE),
];

WidgetStyleOption widgetStyleFor(String key) {
  for (final s in kWidgetStyles) {
    if (s.key == key) return s;
  }
  return kWidgetStyles.first;
}

/// Accent colours that can replace a style's own ('auto').
const List<(String key, String label, int color)> kWidgetAccents = [
  ('auto', 'Auto', 0),
  ('gold', 'Gold', 0xFFF2B93B),
  ('orange', 'Orange', 0xFFFF8A3D),
  ('rose', 'Rose', 0xFFF0517A),
  ('green', 'Green', 0xFF3DDC97),
  ('teal', 'Teal', 0xFF22C7C0),
  ('blue', 'Blue', 0xFF4C8DFF),
  ('violet', 'Violet', 0xFF9B6BFF),
];

/// Hex (#RRGGBB) of an accent key, or '' for 'auto' / unknown.
String widgetAccentHex(String key) {
  for (final a in kWidgetAccents) {
    if (a.$1 == key && a.$3 != 0) {
      return '#${(a.$3 & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
  }
  return '';
}

/// The colour a widget style actually uses for accents.
Color widgetAccentColor(WidgetStyleOption style, String accentKey) {
  for (final a in kWidgetAccents) {
    if (a.$1 == accentKey && a.$3 != 0) return Color(a.$3);
  }
  return Color(style.accent);
}

double widgetTextScale(String size) {
  switch (size) {
    case 'small':
      return 0.9;
    case 'large':
      return 1.2;
    default:
      return 1.0;
  }
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
  ('progress', 'Progress bar', 'How much of today is done'),
  ('tasks', 'To-do list', 'Today\'s tasks, tick them right on the widget'),
  ('habits', 'Habit checklist', 'Tick habits right on the widget'),
  ('water', 'Water tracker', 'Log glasses with - and + on the widget'),
  ('week', 'Week at a glance', 'Seven dots showing your last seven days'),
  ('mantra', 'Daily mantra', 'Today\'s line to carry'),
];

/// Stats the dashboard block can show.
const List<(String key, String label)> kWidgetStatOptions = [
  ('habits', 'Habits'),
  ('tasks', 'Tasks'),
  ('open', 'Tasks left'),
  ('streak', 'Day streak'),
  ('focus', 'Focus'),
  ('meditate', 'Meditated'),
  ('water', 'Water'),
  ('sleep', 'Sleep'),
];

/// Ready-made layouts.
class WidgetPreset {
  final String name;
  final String blurb;
  final List<String> on;
  final List<String> stats;
  const WidgetPreset(this.name, this.blurb, this.on, this.stats);
}

const List<WidgetPreset> kWidgetPresets = [
  WidgetPreset('Full dashboard', 'Stats, progress, tasks and habits',
      ['stats', 'progress', 'tasks', 'habits'], ['habits', 'tasks', 'streak']),
  WidgetPreset('To-do focus', 'Just your list, big and clear',
      ['tasks'], ['tasks']),
  WidgetPreset('Habit tracker', 'Habits with your week at a glance',
      ['progress', 'habits', 'week'], ['habits', 'streak']),
  WidgetPreset('Wellness', 'Habits, water and mantra',
      ['stats', 'habits', 'water', 'mantra'], ['streak', 'water', 'meditate']),
  WidgetPreset('Minimal', 'A quiet strip of numbers',
      ['stats'], ['habits', 'tasks', 'streak', 'water']),
];

class WidgetWeekDay {
  final String letter;
  final int percent;
  final bool today;
  const WidgetWeekDay(this.letter, this.percent, this.today);
}

/// Everything the widget shows right now, computed once so the in-app
/// preview and the native widget never disagree.
class WidgetSnapshot {
  final String title;
  final String dateLabel;
  final String mantra;
  final int streak;
  final List<String> blocks;
  final List<WidgetStat> stats;
  final List<WidgetHabitLine> habits;
  final List<WidgetTaskLine> tasks;
  final int water;
  final int waterGoal;
  final List<WidgetWeekDay> week;
  final bool showDoneTasks;
  const WidgetSnapshot({
    required this.title,
    required this.dateLabel,
    required this.mantra,
    required this.streak,
    required this.blocks,
    required this.stats,
    required this.habits,
    required this.tasks,
    required this.water,
    required this.waterGoal,
    required this.week,
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
/// App to widget: the look, the blocks to show and today's data are written
/// as text into shared preferences and the widget is told to redraw.
/// Widget to app: ticking a task or habit, or logging water, on the widget
/// redraws it at once and queues the change under `widget_pending`;
/// [syncFromWidget] applies that queue to the store the next time the app
/// runs. Taps on titles open the app, which reports them through
/// [pendingOpen].
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

  static String greeting(DateTime now, String name) {
    final h = now.hour;
    final part = h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
    final n = name.trim();
    return n.isEmpty ? part : '$part, $n';
  }

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
          final tasksDone = all.where((t) => t.done).length;
          stats.add(WidgetStat(
              'tasks', 'Tasks', all.isEmpty ? '–' : '$tasksDone/${all.length}'));
          break;
        case 'open':
          stats.add(WidgetStat('open', 'Tasks left', '${open.length}'));
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
        case 'sleep':
          final hours = extras.sleepOn(today);
          stats.add(WidgetStat('sleep', 'Sleep',
              hours == null ? '–' : '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)}h'));
          break;
      }
    }

    String title;
    switch (extras.widgetTitleMode) {
      case 'greeting':
        title = greeting(today, store.userName);
        break;
      case 'day':
        title = 'Today';
        break;
      default:
        title = 'Prakriyā';
    }

    return WidgetSnapshot(
      title: title,
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
      water: extras.waterOn(today),
      waterGoal: extras.widgetWaterGoal,
      week: _week(today),
      showDoneTasks: extras.widgetShowDoneTasks,
    );
  }

  /// The last seven days, oldest first: percent of selected habits done.
  List<WidgetWeekDay> _week(DateTime today) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final selected =
        store.habits.where((h) => store.widgetHabitSelected(h.id)).toList();
    final out = <WidgetWeekDay>[];
    for (var back = 6; back >= 0; back--) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: back));
      var percent = 0;
      if (selected.isNotEmpty) {
        final done = selected.where((h) => h.isDoneOn(day)).length;
        percent = ((done * 100) / selected.length).round();
      }
      out.add(WidgetWeekDay(letters[day.weekday - 1], percent, back == 0));
    }
    return out;
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

  /// Applies ticks made on the home-screen widget to the store. Each queued
  /// change carries the day it was made on, so a tick made just before
  /// midnight still lands on the right day. Safe to call at any time.
  Future<void> syncFromWidget() async {
    try {
      final raw = await HomeWidget.getWidgetData<String>('widget_pending',
          defaultValue: '[]');
      if (raw == null || raw.isEmpty || raw == '[]') return;
      await HomeWidget.saveWidgetData<String>('widget_pending', '[]');
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final entry in decoded) {
        if (entry is! Map) continue;
        var date = today;
        final dayText = entry['day'];
        if (dayText is String && dayText.isNotEmpty) {
          final parsed = DateTime.tryParse(dayText);
          if (parsed != null) {
            date = DateTime(parsed.year, parsed.month, parsed.day);
          }
        }
        // Ignore anything implausibly old or from the future.
        final age = today.difference(date).inDays;
        if (age < 0 || age > 7) continue;

        final kind = entry['k'];
        if (kind == 'water') {
          final delta = entry['delta'];
          if (delta is num && delta != 0) {
            extras.changeWaterOn(date, delta.toInt());
          }
          continue;
        }
        final key = entry['key'];
        if (key is! String) continue;
        final want = entry['v'] == true;
        if (kind == 'habit') {
          for (final h in store.habits) {
            if (h.id == key) {
              if (h.isDoneOn(date) != want) await store.toggleHabitOn(h, date);
              break;
            }
          }
        } else if (kind == 'task') {
          final tasks = store.tasksFor(date);
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
          if (index >= 0) await store.setTaskDoneOn(date, index, want);
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

  static String _taskJson(List<WidgetTaskLine> lines) => jsonEncode([
        for (final t in lines)
          {'i': t.index, 't': t.task.title, 'd': t.task.done},
      ]);

  Future<void> _pushOnce() async {
    try {
      // Ticks made on the widget come first, so the data we write back
      // already includes them.
      await syncFromWidget();

      // One-time: carry the older per-section switches into the block list.
      if (!extras.widgetBlocksSeeded) {
        extras.seedWidgetBlocks(off: <String>[
          'water',
          'week',
          if (!store.widgetShowHabits) 'habits',
          if (!store.widgetShowPriorities) 'tasks',
          if (!store.widgetShowMantra) 'mantra',
        ]);
      }

      final snap = snapshot();
      final now = DateTime.now();

      // Tomorrow's tasks, so the widget can show them after midnight even if
      // the app has not been opened yet.
      final tomorrow = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1));
      final tomorrowTasks = store.tasksFor(tomorrow);
      final tomorrowLines = <WidgetTaskLine>[
        for (var i = 0; i < tomorrowTasks.length; i++)
          if (!tomorrowTasks[i].done) WidgetTaskLine(i, tomorrowTasks[i]),
      ];

      final habitsJson = jsonEncode([
        for (final h in snap.habits)
          {'id': h.habit.id, 'n': h.habit.name, 'd': h.done},
      ]);
      final statsJson = jsonEncode([
        for (final s in snap.stats) {'k': s.key, 'l': s.label, 'v': s.value},
      ]);
      final weekJson = jsonEncode([
        for (final d in snap.week) {'l': d.letter, 'p': d.percent},
      ]);

      Future<void> put(String key, String value) async {
        await HomeWidget.saveWidgetData<String>(key, value);
      }

      await put('widget_style', extras.widgetStyle);
      await put('widget_accent', widgetAccentHex(extras.widgetAccent));
      await put('widget_opacity', '${extras.widgetOpacity}');
      await put('widget_text_size', extras.widgetTextSize);
      await put('widget_compact', extras.widgetCompact ? '1' : '0');
      await put('widget_title_mode', extras.widgetTitleMode);
      await put('widget_user', store.userName);
      await put('widget_show_date', extras.widgetShowDate ? '1' : '0');
      await put('widget_row_tap', extras.widgetRowTap);
      await put('widget_max_rows', '${extras.widgetMaxRows}');
      await put('widget_date', snap.dateLabel);
      await put('widget_day', dayKey(now));
      await put('widget_blocks', jsonEncode(snap.blocks));
      await put('widget_stats', statsJson);
      await put('widget_tasks', _taskJson(snap.tasks));
      await put('widget_tasks_next', _taskJson(tomorrowLines));
      await put('widget_next_day', dayKey(tomorrow));
      await put('widget_habits', habitsJson);
      await put('widget_water', '${snap.water}');
      await put('widget_water_goal', '${snap.waterGoal}');
      await put('widget_week', weekJson);
      await put('widget_show_done_tasks', snap.showDoneTasks ? '1' : '0');
      await put('widget_mantra', snap.mantra);
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (_) {
      // No widget added yet, or a platform without the native provider.
      // Nothing else in the app depends on this succeeding.
    }
  }
}
