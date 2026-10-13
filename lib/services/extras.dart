import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart' show dayKey;

/// Small, self-contained store for the newer lightweight features (focus
/// timer, gratitude lines, water/sleep log, checklist and recap state).
///
/// It deliberately lives outside [Store]/AppState: it keeps its own JSON blob
/// in SharedPreferences, so adding or changing it can never corrupt or reset
/// the user's existing saved data. Changes notify listeners immediately and
/// the disk write happens in the background.
/// Every block the home-screen widget can show, in default order.
const List<String> kWidgetBlockKeys = [
  'stats',
  'progress',
  'tasks',
  'habits',
  'water',
  'week',
  'mantra',
];

class Extras extends ChangeNotifier {
  static const _key = 'prakriya_extras_v1';

  /// day key -> focus minutes completed that day.
  final Map<String, int> focusMinutes = <String, int>{};

  /// day key -> one-line gratitude.
  final Map<String, String> gratitude = <String, String>{};

  /// day key -> glasses of water.
  final Map<String, int> water = <String, int>{};

  /// day key -> hours slept (the night leading into that day).
  final Map<String, double> sleep = <String, double>{};

  /// day key -> meditation minutes completed that day.
  final Map<String, int> meditationMinutes = <String, int>{};

  /// Nutrient values per logged nutrition entry id (kcal, protein, ...).
  final Map<String, Map<String, double>> entryNutrients =
      <String, Map<String, double>>{};

  int calorieGoal = 2000;
  bool female = false;

  /// Meditation sound choice, volume and the user's own stream link.
  String meditationSound = 'rain';
  double meditationVolume = 0.6;
  String musicUrl = '';

  /// Start bell, interval chime (minutes, 0 = off) and breathing pattern key.
  bool meditationStartBell = true;
  int meditationInterval = 0;
  String breathPattern = 'calm';

  /// Home-screen widget settings. Look: style, accent ('' = the style's own),
  /// background opacity (percent), text size and row density. Content: block
  /// order and which are off, dashboard stats, header, list behaviour, water.
  String widgetStyle = 'dusk';
  String widgetAccent = '';
  int widgetOpacity = 100;
  String widgetTextSize = 'medium';
  bool widgetCompact = false;
  List<String> widgetOrder = <String>[...kWidgetBlockKeys];
  List<String> widgetOff = <String>['water', 'week'];
  List<String> widgetStats = <String>['habits', 'tasks', 'streak'];
  bool widgetShowDoneTasks = true;
  String widgetTitleMode = 'app';
  bool widgetShowDate = true;
  String widgetRowTap = 'open';
  int widgetMaxRows = 0;
  int widgetWaterGoal = 8;

  /// False until the old per-section switches were copied across once.
  bool widgetBlocksSeeded = false;

  bool checklistDismissed = false;

  /// Monday day key of the week whose recap card was dismissed.
  String recapDismissedWeek = '';

  /// Day key on which yesterday's unfinished tasks were last carried over (or
  /// the offer was skipped), so the offer shows once per day.
  String carriedOverOn = '';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _readIntMap(decoded['focusMinutes'], focusMinutes);
          _readStringMap(decoded['gratitude'], gratitude);
          _readIntMap(decoded['water'], water);
          final s = decoded['sleep'];
          sleep.clear();
          if (s is Map) {
            s.forEach((dynamic k, dynamic v) {
              if (v is num) sleep['$k'] = v.toDouble();
            });
          }
          _readIntMap(decoded['meditationMinutes'], meditationMinutes);
          entryNutrients.clear();
          final en = decoded['entryNutrients'];
          if (en is Map) {
            en.forEach((dynamic id, dynamic values) {
              if (values is Map) {
                final inner = <String, double>{};
                values.forEach((dynamic k, dynamic v) {
                  if (v is num) inner['$k'] = v.toDouble();
                });
                entryNutrients['$id'] = inner;
              }
            });
          }
          final goal = decoded['calorieGoal'];
          if (goal is num && goal >= 800 && goal <= 6000) {
            calorieGoal = goal.toInt();
          }
          female = decoded['female'] == true;
          if (decoded['meditationSound'] is String) {
            meditationSound = decoded['meditationSound'] as String;
          }
          final vol = decoded['meditationVolume'];
          if (vol is num) meditationVolume = vol.toDouble().clamp(0.0, 1.0).toDouble();
          if (decoded['musicUrl'] is String) {
            musicUrl = decoded['musicUrl'] as String;
          }
          if (decoded['meditationStartBell'] is bool) {
            meditationStartBell = decoded['meditationStartBell'] as bool;
          }
          final interval = decoded['meditationInterval'];
          if (interval is num) meditationInterval = interval.toInt();
          if (decoded['breathPattern'] is String) {
            breathPattern = decoded['breathPattern'] as String;
          }
          if (decoded['widgetStyle'] is String) {
            widgetStyle = decoded['widgetStyle'] as String;
          }
          final order = _readStringList(decoded['widgetOrder']);
          final off = _readStringList(decoded['widgetOff']);
          if (off != null) widgetOff = off;
          if (order != null) {
            // Blocks added in later versions start switched off for people
            // who already had a saved layout.
            for (final k in kWidgetBlockKeys) {
              if (!order.contains(k) && !widgetOff.contains(k)) widgetOff.add(k);
            }
            widgetOrder = _completeOrder(order);
          }
          final stats = _readStringList(decoded['widgetStats']);
          if (stats != null) widgetStats = stats.take(4).toList();
          if (decoded['widgetShowDoneTasks'] is bool) {
            widgetShowDoneTasks = decoded['widgetShowDoneTasks'] as bool;
          }
          if (decoded['widgetAccent'] is String) {
            widgetAccent = decoded['widgetAccent'] as String;
          }
          final opacity = decoded['widgetOpacity'];
          if (opacity is num) {
            widgetOpacity = opacity.toInt().clamp(30, 100).toInt();
          }
          if (decoded['widgetTextSize'] is String) {
            widgetTextSize = decoded['widgetTextSize'] as String;
          }
          widgetCompact = decoded['widgetCompact'] == true;
          if (decoded['widgetTitleMode'] is String) {
            widgetTitleMode = decoded['widgetTitleMode'] as String;
          }
          if (decoded['widgetShowDate'] is bool) {
            widgetShowDate = decoded['widgetShowDate'] as bool;
          }
          if (decoded['widgetRowTap'] is String) {
            widgetRowTap = decoded['widgetRowTap'] as String;
          }
          final maxRows = decoded['widgetMaxRows'];
          if (maxRows is num) widgetMaxRows = maxRows.toInt().clamp(0, 20).toInt();
          final waterGoal = decoded['widgetWaterGoal'];
          if (waterGoal is num) {
            widgetWaterGoal = waterGoal.toInt().clamp(1, 30).toInt();
          }
          widgetBlocksSeeded = decoded['widgetBlocksSeeded'] == true;
          checklistDismissed = decoded['checklistDismissed'] == true;
          recapDismissedWeek = decoded['recapDismissedWeek'] is String
              ? decoded['recapDismissedWeek'] as String
              : '';
          carriedOverOn = decoded['carriedOverOn'] is String
              ? decoded['carriedOverOn'] as String
              : '';
        }
      }
    } catch (e) {
      debugPrint('Extras.load failed: $e');
    }
    notifyListeners();
  }

  static List<String>? _readStringList(dynamic source) {
    if (source is! List) return null;
    return <String>[for (final e in source) '$e'];
  }

  /// A saved order that predates a block (or lost one) still lists every
  /// block exactly once.
  static List<String> _completeOrder(List<String> saved) {
    final out = <String>[for (final k in saved) if (kWidgetBlockKeys.contains(k)) k];
    for (final k in kWidgetBlockKeys) {
      if (!out.contains(k)) out.add(k);
    }
    return out.toSet().toList();
  }

  static void _readIntMap(dynamic source, Map<String, int> into) {
    into.clear();
    if (source is Map) {
      source.forEach((dynamic k, dynamic v) {
        if (v is num) into['$k'] = v.toInt();
      });
    }
  }

  static void _readStringMap(dynamic source, Map<String, String> into) {
    into.clear();
    if (source is Map) {
      source.forEach((dynamic k, dynamic v) {
        if (v is String) into['$k'] = v;
      });
    }
  }

  void _changed() {
    notifyListeners();
    unawaited(_write());
  }

  Future<void> _write() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(<String, dynamic>{
          'focusMinutes': focusMinutes,
          'gratitude': gratitude,
          'water': water,
          'sleep': sleep,
          'meditationMinutes': meditationMinutes,
          'entryNutrients': entryNutrients,
          'calorieGoal': calorieGoal,
          'female': female,
          'meditationSound': meditationSound,
          'meditationVolume': meditationVolume,
          'musicUrl': musicUrl,
          'meditationStartBell': meditationStartBell,
          'meditationInterval': meditationInterval,
          'breathPattern': breathPattern,
          'widgetStyle': widgetStyle,
          'widgetAccent': widgetAccent,
          'widgetOpacity': widgetOpacity,
          'widgetTextSize': widgetTextSize,
          'widgetCompact': widgetCompact,
          'widgetTitleMode': widgetTitleMode,
          'widgetShowDate': widgetShowDate,
          'widgetRowTap': widgetRowTap,
          'widgetMaxRows': widgetMaxRows,
          'widgetWaterGoal': widgetWaterGoal,
          'widgetOrder': widgetOrder,
          'widgetOff': widgetOff,
          'widgetStats': widgetStats,
          'widgetShowDoneTasks': widgetShowDoneTasks,
          'widgetBlocksSeeded': widgetBlocksSeeded,
          'checklistDismissed': checklistDismissed,
          'recapDismissedWeek': recapDismissedWeek,
          'carriedOverOn': carriedOverOn,
        }),
      );
    } catch (e) {
      debugPrint('Extras save failed: $e');
    }
  }

  // ---- Focus ----

  String get todayKey => dayKey(DateTime.now());

  int focusMinutesOn(DateTime day) => focusMinutes[dayKey(day)] ?? 0;

  int get totalFocusMinutes =>
      focusMinutes.values.fold<int>(0, (sum, v) => sum + v);

  void addFocusMinutes(int minutes) {
    focusMinutes[todayKey] = (focusMinutes[todayKey] ?? 0) + minutes;
    _changed();
  }

  /// Consecutive days with at least one focus session. A day that hasn't had
  /// a session yet doesn't break a streak that was alive yesterday.
  int get focusStreak {
    var cursor = DateTime.now();
    if (focusMinutesOn(cursor) == 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (focusMinutesOn(cursor) > 0) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  // ---- Meditation ----

  int meditationMinutesOn(DateTime day) => meditationMinutes[dayKey(day)] ?? 0;

  int get totalMeditationMinutes =>
      meditationMinutes.values.fold<int>(0, (sum, v) => sum + v);

  void addMeditationMinutes(int minutes) {
    meditationMinutes[todayKey] = (meditationMinutes[todayKey] ?? 0) + minutes;
    _changed();
  }

  int get meditationStreak {
    var cursor = DateTime.now();
    if (meditationMinutesOn(cursor) == 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (meditationMinutesOn(cursor) > 0) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  void setMeditationPrefs({String? sound, double? volume, String? url}) {
    if (sound != null) meditationSound = sound;
    if (volume != null) meditationVolume = volume.clamp(0.0, 1.0).toDouble();
    if (url != null) musicUrl = url.trim();
    _changed();
  }

  void setMeditationExtras({bool? startBell, int? interval, String? pattern}) {
    if (startBell != null) meditationStartBell = startBell;
    if (interval != null) meditationInterval = interval;
    if (pattern != null) breathPattern = pattern;
    _changed();
  }

  // ---- Home screen widget ----

  bool widgetBlockOn(String key) => !widgetOff.contains(key);

  void setWidgetStyle(String style) {
    widgetStyle = style;
    _changed();
  }

  /// Look settings; pass only what changes.
  void setWidgetLook({
    String? accent,
    int? opacity,
    String? textSize,
    bool? compact,
  }) {
    if (accent != null) widgetAccent = accent;
    if (opacity != null) widgetOpacity = opacity.clamp(30, 100).toInt();
    if (textSize != null) widgetTextSize = textSize;
    if (compact != null) widgetCompact = compact;
    _changed();
  }

  /// Content settings; pass only what changes.
  void setWidgetContent({
    String? titleMode,
    bool? showDate,
    String? rowTap,
    int? maxRows,
    int? waterGoal,
  }) {
    if (titleMode != null) widgetTitleMode = titleMode;
    if (showDate != null) widgetShowDate = showDate;
    if (rowTap != null) widgetRowTap = rowTap;
    if (maxRows != null) widgetMaxRows = maxRows.clamp(0, 20).toInt();
    if (waterGoal != null) widgetWaterGoal = waterGoal.clamp(1, 30).toInt();
    _changed();
  }

  /// Applies a ready-made layout in one go.
  void applyWidgetLayout({
    required List<String> order,
    required List<String> off,
    required List<String> stats,
  }) {
    widgetOrder = _completeOrder(order);
    widgetOff = List<String>.from(off);
    widgetStats = stats.take(4).toList();
    widgetBlocksSeeded = true;
    _changed();
  }

  void setWidgetBlockOn(String key, bool on) {
    widgetOff.remove(key);
    if (!on) widgetOff.add(key);
    widgetBlocksSeeded = true;
    _changed();
  }

  void setWidgetOrder(List<String> order) {
    widgetOrder = _completeOrder(order);
    widgetBlocksSeeded = true;
    _changed();
  }

  /// Which dashboard stats show (at most four, in the order given).
  void setWidgetStats(List<String> stats) {
    widgetStats = stats.take(4).toList();
    _changed();
  }

  void setWidgetShowDoneTasks(bool value) {
    widgetShowDoneTasks = value;
    _changed();
  }

  /// One-time copy of the older per-section switches into the block list.
  void seedWidgetBlocks({required List<String> off}) {
    if (widgetBlocksSeeded) return;
    widgetOff = List<String>.from(off);
    widgetBlocksSeeded = true;
    _changed();
  }

  // ---- Nutrition ----

  void setEntryNutrients(String entryId, Map<String, double> values) {
    entryNutrients[entryId] = values;
    _changed();
  }

  void removeEntryNutrients(String entryId) {
    if (entryNutrients.remove(entryId) != null) _changed();
  }

  void setNutritionProfile({int? goal, bool? isFemale}) {
    if (goal != null && goal >= 800 && goal <= 6000) calorieGoal = goal;
    if (isFemale != null) female = isFemale;
    _changed();
  }

  // ---- Gratitude ----

  void setGratitude(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      gratitude.remove(todayKey);
    } else {
      gratitude[todayKey] = trimmed;
    }
    _changed();
  }

  // ---- Water & sleep ----

  int waterOn(DateTime day) => water[dayKey(day)] ?? 0;

  void changeWater(int delta) {
    final next = ((water[todayKey] ?? 0) + delta).clamp(0, 30).toInt();
    water[todayKey] = next;
    _changed();
  }

  /// Adjusts the water count for a specific day (used when ticks made on the
  /// home-screen widget are applied after midnight).
  void changeWaterOn(DateTime day, int delta) {
    final key = dayKey(day);
    water[key] = ((water[key] ?? 0) + delta).clamp(0, 30).toInt();
    _changed();
  }

  double? sleepOn(DateTime day) => sleep[dayKey(day)];

  void setSleep(double hours) {
    if (sleep[todayKey] == hours) {
      sleep.remove(todayKey);
    } else {
      sleep[todayKey] = hours;
    }
    _changed();
  }

  // ---- Checklist / recap / carry-over ----

  void dismissChecklist() {
    checklistDismissed = true;
    _changed();
  }

  /// Monday of the current week, as a day key.
  String get thisWeekKey {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dayKey(today.subtract(Duration(days: today.weekday - 1)));
  }

  void dismissRecap() {
    recapDismissedWeek = thisWeekKey;
    _changed();
  }

  void markCarriedOver() {
    carriedOverOn = todayKey;
    _changed();
  }
}

final Extras extras = Extras();
