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

/// Everything the widget shows right now, computed once so the in-app preview
/// and the native widget can never disagree.
class WidgetSnapshot {
  final String style;
  final String dateLabel;
  final String mantra;
  final String priority;
  final List<WidgetHabitLine> habits;
  final int done;
  final int total;
  final int streak;
  final bool showProgress;
  final bool showStreak;
  const WidgetSnapshot({
    required this.style,
    required this.dateLabel,
    required this.mantra,
    required this.priority,
    required this.habits,
    required this.done,
    required this.total,
    required this.streak,
    required this.showProgress,
    required this.showStreak,
  });
}

/// Keeps the Android home-screen widget's data in sync with the app.
///
/// The native provider and layouts live in `android_overrides/widget/` and are
/// copied into the generated Android project by CI. Everything is passed to it
/// as text through shared preferences.
class HomeWidgetService {
  HomeWidgetService._();
  static final instance = HomeWidgetService._();

  static const _androidWidgetName = 'HabitsWidgetProvider';
  static const _qualifiedName = 'ai.aandccreative.prakriya.HabitsWidgetProvider';

  bool _wired = false;
  Timer? _debounce;

  /// Starts listening and pushing widget data on every change. Safe to call
  /// more than once.
  void wire() {
    if (_wired) return;
    _wired = true;
    store.addListener(_schedule);
    extras.addListener(_schedule);
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_push());
    });
  }

  /// Manual "update now".
  Future<void> forceRefresh() => _push();

  /// What the widget shows right now.
  WidgetSnapshot snapshot() {
    final today = DateTime.now();
    final habitLines = <WidgetHabitLine>[];
    var done = 0;
    var total = 0;
    if (store.widgetShowHabits) {
      final selected =
          store.habits.where((h) => store.widgetHabitSelected(h.id)).toList();
      total = selected.length;
      for (final h in selected) {
        final isDone = h.isDoneOn(today);
        if (isDone) done++;
      }
      for (final h in selected.take(5)) {
        habitLines.add(WidgetHabitLine(h, h.isDoneOn(today)));
      }
    }
    var priority = '';
    if (store.widgetShowPriorities) {
      final open = store.todaysTasks.where((t) => !t.done).toList();
      if (open.isNotEmpty) priority = open.first.title;
    }
    final mantra = store.widgetShowMantra ? store.mantraOfTheDay : '';
    return WidgetSnapshot(
      style: extras.widgetStyle,
      dateLabel: _dateLabel(today),
      mantra: mantra,
      priority: priority,
      habits: habitLines,
      done: done,
      total: total,
      streak: _overallStreak(),
      showProgress: extras.widgetShowProgress,
      showStreak: extras.widgetShowStreak,
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

  Future<void> _push() async {
    try {
      final snap = snapshot();
      final habitsJson = jsonEncode([
        for (final line in snap.habits)
          {'name': line.habit.name, 'done': line.done},
      ]);
      await HomeWidget.saveWidgetData<String>('widget_habits', habitsJson);
      await HomeWidget.saveWidgetData<String>('widget_top_priority', snap.priority);
      await HomeWidget.saveWidgetData<String>('widget_mantra', snap.mantra);
      await HomeWidget.saveWidgetData<String>('widget_style', snap.style);
      await HomeWidget.saveWidgetData<String>('widget_date', snap.dateLabel);
      await HomeWidget.saveWidgetData<String>('widget_done', '${snap.done}');
      await HomeWidget.saveWidgetData<String>('widget_total', '${snap.total}');
      await HomeWidget.saveWidgetData<String>('widget_streak', '${snap.streak}');
      await HomeWidget.saveWidgetData<String>(
          'widget_show_progress', snap.showProgress ? '1' : '0');
      await HomeWidget.saveWidgetData<String>(
          'widget_show_streak', snap.showStreak ? '1' : '0');
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (_) {
      // No widget added yet, or a platform without the native provider.
      // Nothing else in the app depends on this succeeding.
    }
  }
}
