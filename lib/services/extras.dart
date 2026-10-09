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
    final next = ((water[todayKey] ?? 0) + delta).clamp(0, 30);
    water[todayKey] = next;
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
