import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mantras.dart';
import 'models.dart';
import 'notifications.dart';
import 'services/coach_chat_service.dart';
import 'services/update_checker.dart';
import 'theme.dart' show AppThemePreset, setAccentId, setFontFamily, setFontScale;
import 'tips.dart';

const _storageKey = 'prakriya_state_v1';
// The app's old name, kept only so `load()` below can migrate anyone whose
// data is still sitting under this key forward — see the rename comment
// there. Never write to this key.
const _legacyStorageKey = 'ritualist_state_v1';

/// Single source of truth. Persists to shared_preferences as one JSON blob.
class Store extends ChangeNotifier {
  AppState _state = AppState.initial();
  bool ready = false;

  /// Set once a background GitHub Releases check finds something newer than
  /// this build — null the rest of the time. Purely in-memory (not
  /// persisted): a fresh check runs, and this is reset, on every launch.
  UpdateInfo? updateAvailable;

  /// Best-effort, silent check for a newer release — never blocks app
  /// startup and never throws. Safe to call once per launch (see main.dart);
  /// a dismissed version is skipped until something newer comes out.
  Future<void> checkForUpdate() async {
    try {
      final info = await UpdateChecker.instance.checkForUpdate();
      if (info == null) return;
      if (info.version == _state.dismissedUpdateVersion) return;
      updateAvailable = info;
      notifyListeners();
    } catch (_) {
      // Best-effort — no network, GitHub unreachable, whatever.
    }
  }

  Future<void> dismissUpdate() async {
    final info = updateAvailable;
    if (info == null) return;
    _state.dismissedUpdateVersion = info.version;
    updateAvailable = null;
    await _commit();
  }

  bool get signInBannerDismissed => _state.signInBannerDismissed;

  Future<void> dismissSignInBanner() async {
    _state.signInBannerDismissed = true;
    await _commit();
  }

  AppState get state => _state;

  List<Habit> get habits => _state.habits;
  List<ReminderSetting> get reminders => _state.reminders;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // The app was renamed from "Ritualist" to "Prakriyā" (storage key
    // included) — an in-place update under the SAME applicationId (Android
    // package rename aside, e.g. if that part is ever reverted or on a
    // platform where it doesn't apply) would otherwise look like a fresh
    // install with the old data still sitting under the old key, unread. A
    // brand-new applicationId gets its own empty storage regardless, so
    // this is a no-op there — but it's what makes an in-place update safe
    // either way.
    var raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      final legacy = prefs.getString(_legacyStorageKey);
      if (legacy != null && legacy.isNotEmpty) {
        raw = legacy;
        unawaited(prefs.setString(_storageKey, legacy));
      }
    }
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _state = AppState.fromJson(decoded);
        }
      } catch (_) {
        _state = AppState.initial();
      }
    }
    // Each of these touches a saved preference (theme accent/font choice) —
    // guarded individually so a single bad value from an old app version
    // can't stop the others, or worse, stop `ready`/`notifyListeners()`
    // below from ever running.
    try {
      setAccentId(_state.themeAccentId);
    } catch (_) {}
    try {
      setFontFamily(_state.fontFamilyId);
    } catch (_) {}
    try {
      setFontScale(_state.fontScaleId);
    } catch (_) {}
    try {
      ensureMantraRotationCurrent();
    } catch (_) {}
    ready = true;
    notifyListeners();
    // Scheduling reminders is best-effort by itself (see Notifications.
    // scheduleAll), but this call is still wrapped here too: it's awaited
    // directly inside main()'s startup sequence before the first frame is
    // ever drawn, so nothing here may ever throw past this point.
    try {
      await rescheduleReminders();
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_state.toJson()));
  }

  // Every write used to `await _save()` before returning, which meant any
  // screen that did `await store.addX(...); Navigator.pop(context);` sat
  // waiting on a full disk write (a platform-channel round trip through
  // shared_preferences) before it could pop back to a screen that would
  // show the new entry — reported as "it takes time for a new item to show
  // up". notifyListeners() below still fires synchronously and immediately,
  // so anything already on screen (an AnimatedBuilder over `store`) updates
  // at once; the disk write itself is chained onto this queue instead of
  // being awaited by the caller, so callers return right away while saves
  // still happen in the background, strictly in order, one at a time (never
  // overlapping, never dropped, and never able to save an older snapshot
  // after a newer one).
  Future<void> _saveQueue = Future.value();

  // Deliberately not `await`-ing the queued save below (this still returns
  // `Future<void>` — an already-completed one — so every existing
  // `await store.addX(...)` call site keeps compiling and working exactly
  // as before; it just no longer actually blocks on disk I/O).
  Future<void> _commit() async {
    notifyListeners();
    _saveQueue = _saveQueue.then((_) => _save()).catchError((Object error, StackTrace stack) {
      debugPrint('Store save failed: $error\n$stack');
    });
  }

  /// Waits for every queued save to actually reach disk — call this before
  /// the app is about to go away (backgrounded/killed) or before anything
  /// that reads persisted state from outside the store (a cloud push), so
  /// neither one can race ahead of a write that's still in flight.
  Future<void> flush() => _saveQueue;

  /// True when there's essentially nothing here yet — a fresh install, or
  /// onboarding not even finished. Used to gate the one-time "no cloud copy
  /// exists locally, pull mine down" sync so it can never overwrite real,
  /// newer local data with a stale cloud snapshot (see CloudSync.pullIfFreshInstall).
  bool get looksEmpty =>
      !_state.onboardingComplete &&
      _state.scripts.isEmpty &&
      _state.habits.isEmpty &&
      _state.tasksByDay.isEmpty &&
      _state.spendEntries.isEmpty &&
      _state.savingsEntries.isEmpty &&
      _state.visionItems.isEmpty &&
      _state.weeklyGoals.isEmpty &&
      _state.monthlyGoals.isEmpty &&
      _state.financeGoals.isEmpty &&
      _state.healthGoals.isEmpty &&
      _state.mindsetGoals.isEmpty &&
      _state.relationshipsGoals.isEmpty;

  /// Swaps in a whole different AppState — used when a cloud backup is
  /// pulled down after signing in — and immediately persists + notifies,
  /// same as any other write.
  Future<void> replaceState(AppState newState) async {
    _state = newState;
    await _commit();
    await rescheduleReminders();
  }

  // ---- Tasks ----

  List<Task> tasksFor(DateTime date) =>
      _state.tasksByDay[dayKey(date)] ?? <Task>[];

  List<Task> get todaysTasks => tasksFor(DateTime.now());

  int get openTaskCount => todaysTasks.where((t) => !t.done).length;

  Future<void> addTask(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final key = dayKey(DateTime.now());
    final list = _state.tasksByDay.putIfAbsent(key, () => <Task>[]);
    list.insert(0, Task(title: trimmed));
    await _commit();
  }

  Future<void> toggleTask(int index) async {
    final list = _state.tasksByDay[dayKey(DateTime.now())];
    if (list == null || index < 0 || index >= list.length) return;
    list[index].done = !list[index].done;
    await _commit();
  }

  Future<void> removeTask(int index) async {
    final list = _state.tasksByDay[dayKey(DateTime.now())];
    if (list == null || index < 0 || index >= list.length) return;
    list.removeAt(index);
    await _commit();
  }

  // ---- Habits ----

  Future<void> toggleHabit(Habit habit) async {
    habit.toggle(DateTime.now());
    await _commit();
  }

  /// Toggle a habit's completion for any calendar day, not just today — for
  /// the tappable habit calendar (users can back-fill or correct any date).
  Future<void> toggleHabitOn(Habit habit, DateTime date) async {
    final target = _findHabit(habit.id) ?? habit;
    target.toggle(date);
    await _commit();
  }

  Future<void> addHabit(String name, {int? iconIndex, int? colorIndex}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _state.habits.add(Habit(
      name: trimmed,
      iconIndex: iconIndex ?? 0,
      colorIndex: colorIndex ?? _state.habits.length,
    ));
    await _commit();
  }

  /// Looked up by id rather than trusting the caller's object reference —
  /// keeps add/remove/edit correct even if a widget is holding a stale
  /// instance from a previous rebuild.
  Habit? _findHabit(String id) {
    for (final h in _state.habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> removeHabit(Habit habit) async {
    _state.habits.removeWhere((h) => h.id == habit.id);
    await _commit();
  }

  Future<void> renameHabit(Habit habit, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final target = _findHabit(habit.id) ?? habit;
    target.name = trimmed;
    await _commit();
  }

  Future<void> setHabitStyle(Habit habit, {int? iconIndex, int? colorIndex}) async {
    final target = _findHabit(habit.id) ?? habit;
    if (iconIndex != null) target.iconIndex = iconIndex;
    if (colorIndex != null) target.colorIndex = colorIndex;
    await _commit();
  }

  int get habitsDoneToday =>
      _state.habits.where((h) => h.isDoneOn(DateTime.now())).length;

  // ---- Mantra ----

  /// Today's mantra, from a shuffled rotation that never repeats until
  /// every entry in [mantras] has been shown once (then reshuffles,
  /// skipping an immediate repeat of the last one shown) — see
  /// `ensureMantraRotationCurrent`, which actually advances the rotation
  /// once per calendar day. This getter stays pure/read-only (no state
  /// mutation here) so it's always safe to call from a build() method;
  /// if the rotation hasn't been set up yet for the current mantra list
  /// size, it falls back to the old deterministic-by-day index until
  /// `ensureMantraRotationCurrent` (called at startup and on resume)
  /// catches up.
  Mantra get mantraEntryOfTheDay {
    if (mantras.isEmpty) return const Mantra('', '');
    final total = mantras.length;
    final order = _state.mantraShuffleOrder;
    final cursor = _state.mantraShuffleCursor;
    if (order.length == total && cursor >= 0 && cursor < total) {
      return mantras[order[cursor]];
    }
    final dayNumber = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    return mantras[(dayNumber + _state.mantraSeed).abs() % total];
  }

  String get mantraOfTheDay => mantraEntryOfTheDay.text;

  /// Advances the mantra rotation exactly once per calendar day. Safe to
  /// call as often as you like (at startup, on every app resume) — it's a
  /// no-op unless the day has actually changed since the last time it ran,
  /// or the rotation has never been set up / no longer matches the current
  /// mantra list length (e.g. after an app update added more mantras).
  void ensureMantraRotationCurrent() {
    final total = mantras.length;
    if (total == 0) return;
    final today = dayKey(DateTime.now());
    if (_state.mantraLastShownDay == today &&
        _state.mantraShuffleOrder.length == total) {
      return;
    }
    if (_state.mantraShuffleOrder.length != total) {
      _state.mantraShuffleOrder = _shuffledMantraOrder(total);
      _state.mantraShuffleCursor = 0;
    } else {
      _state.mantraShuffleCursor++;
      if (_state.mantraShuffleCursor >= total) {
        final lastShown = _state.mantraShuffleOrder.last;
        _state.mantraShuffleOrder = _shuffledMantraOrder(total, avoidFirst: lastShown);
        _state.mantraShuffleCursor = 0;
      }
    }
    _state.mantraLastShownDay = today;
    _commit();
  }

  List<int> _shuffledMantraOrder(int total, {int? avoidFirst}) {
    final order = List<int>.generate(total, (i) => i)..shuffle();
    if (avoidFirst != null && order.length > 1 && order.first == avoidFirst) {
      final tmp = order[0];
      order[0] = order[1];
      order[1] = tmp;
    }
    return order;
  }

  // ---- Productivity tip ----

  String get tipOfTheDay {
    final dayNumber = DateTime.now().difference(DateTime(2026, 1, 1)).inDays;
    final index = (dayNumber + _state.mantraSeed) % productivityTips.length;
    return productivityTips[index.abs()];
  }

  // ---- Mood check-in / evening prompt ----

  String? get todaysMood => _state.moodByDay[dayKey(DateTime.now())];

  bool get shouldShowMoodPrompt =>
      onboardingComplete &&
      _state.lastMoodPromptDay != dayKey(DateTime.now());

  Future<void> recordMoodPromptShown() async {
    _state.lastMoodPromptDay = dayKey(DateTime.now());
    await _commit();
  }

  Future<void> setTodaysMood(String mood) async {
    _state.moodByDay[dayKey(DateTime.now())] = mood;
    await recordMoodPromptShown();
  }

  bool get shouldShowEveningPrompt =>
      onboardingComplete &&
      DateTime.now().hour >= 19 &&
      _state.lastEveningPromptDay != dayKey(DateTime.now());

  Future<void> recordEveningPromptShown() async {
    _state.lastEveningPromptDay = dayKey(DateTime.now());
    await _commit();
  }

  // ---- Theme ----

  ThemeMode get themeMode {
    switch (_state.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(String mode) async {
    _state.themeMode = mode;
    await _commit();
  }

  /// Which accent palette (theme.dart's kAccentPalettes) is active.
  String get themeAccentId => _state.themeAccentId;

  Future<void> setThemeAccent(String id) async {
    _state.themeAccentId = id;
    setAccentId(id);
    await _commit();
  }

  /// Which reading font (theme.dart's kFontFamilies) is active for body text.
  String get fontFamilyId => _state.fontFamilyId;

  Future<void> setFontFamilyChoice(String id) async {
    _state.fontFamilyId = id;
    setFontFamily(id);
    await _commit();
  }

  /// Which text size scale (theme.dart's kFontScales) is active.
  String get fontScaleId => _state.fontScaleId;

  Future<void> setFontScaleChoice(String id) async {
    _state.fontScaleId = id;
    setFontScale(id);
    await _commit();
  }

  /// Applies a curated [AppThemePreset] in one tap — sets accent, font, and
  /// text size together. The independent pickers stay available afterward
  /// for further tweaking.
  Future<void> applyThemePreset(AppThemePreset preset) async {
    _state.themeAccentId = preset.accentId;
    _state.fontFamilyId = preset.fontFamilyId;
    _state.fontScaleId = preset.fontScaleId;
    setAccentId(preset.accentId);
    setFontFamily(preset.fontFamilyId);
    setFontScale(preset.fontScaleId);
    await _commit();
  }

  /// Which kHomePageSections key opens first on launch.
  String get defaultPageKey => _state.defaultPageKey;

  Future<void> setDefaultPage(String key) async {
    _state.defaultPageKey = key;
    await _commit();
  }

  /// Chosen interval (seconds) for the exercise interval bell timer.
  int get exerciseBellIntervalSeconds => _state.exerciseBellIntervalSeconds;

  Future<void> setExerciseBellInterval(int seconds) async {
    if (seconds <= 0) return;
    _state.exerciseBellIntervalSeconds = seconds;
    await _commit();
  }

  // ---- Wallet / spending tracker ----

  List<SpendCategory> get spendCategories => _state.spendCategories;
  List<SpendEntry> get spendEntries => _state.spendEntries;

  Future<void> addSpendCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _state.spendCategories.add(
        SpendCategory(id: '${DateTime.now().microsecondsSinceEpoch}', name: trimmed));
    await _commit();
  }

  Future<void> renameSpendCategory(SpendCategory category, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    category.name = trimmed;
    await _commit();
  }

  Future<void> removeSpendCategory(SpendCategory category) async {
    // Also drops any logged entries pointing at it, so the tracker never
    // ends up showing an expense under a category that no longer exists.
    _state.spendCategories.remove(category);
    _state.spendEntries.removeWhere((e) => e.categoryId == category.id);
    await _commit();
  }

  Future<void> addSpendSubcategory(SpendCategory category, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || category.subcategories.contains(trimmed)) return;
    category.subcategories.add(trimmed);
    await _commit();
  }

  Future<void> removeSpendSubcategory(SpendCategory category, String name) async {
    category.subcategories.remove(name);
    await _commit();
  }

  Future<void> addSpendEntry({
    required String categoryId,
    String subcategory = '',
    required double amount,
    required bool isNeed,
    String note = '',
  }) async {
    if (amount <= 0) return;
    _state.spendEntries.insert(
      0,
      SpendEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        categoryId: categoryId,
        subcategory: subcategory.trim(),
        amount: amount,
        isNeed: isNeed,
        note: note.trim(),
        date: DateTime.now(),
      ),
    );
    await _commit();
    await _maybeSendSpendAlert();
  }

  /// Fires a one-time "80% of budget" and "100%+ of budget" local
  /// notification for the current calendar month, based on the Needs+Wants
  /// portion of the income set in the budget calculator (savings isn't
  /// "spend"). Silently does nothing until income is set, and never fires
  /// twice for the same threshold in the same month.
  Future<void> _maybeSendSpendAlert() async {
    final alertsOn = _state.reminders
        .where((r) => r.id == 'spendAlerts')
        .any((r) => r.enabled);
    final income = _state.financeBudgetIncome;
    if (!alertsOn || income == null || income <= 0) return;

    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month}';
    if (_state.spendAlertMonthKey != monthKey) {
      _state.spendAlertMonthKey = monthKey;
      _state.spendAlertLevel = 0;
    }

    final spendBudget =
        income * (financeBudgetNeedsPct + financeBudgetWantsPct) / 100;
    if (spendBudget <= 0) return;
    final pct = (spentThisMonth / spendBudget) * 100;

    if (pct >= 100 && _state.spendAlertLevel < 100) {
      _state.spendAlertLevel = 100;
      await _commit();
      await Notifications.instance.showInstant(
        id: 6001,
        title: '⚠️ Monthly budget exceeded',
        body:
            'You\'ve spent ${pct.round()}% of this month\'s needs + wants budget.',
      );
    } else if (pct >= 80 && _state.spendAlertLevel < 80) {
      _state.spendAlertLevel = 80;
      await _commit();
      await Notifications.instance.showInstant(
        id: 6000,
        title: '💸 80% of your budget spent',
        body: 'You\'re at ${pct.round()}% of this month\'s spending budget.',
      );
    }
  }

  Future<void> removeSpendEntry(SpendEntry entry) async {
    _state.spendEntries.remove(entry);
    await _commit();
  }

  /// Edits a previously logged expense in place — until now the only way
  /// to fix a mis-entered spend was to delete it and re-add it from scratch.
  Future<void> updateSpendEntry(
    SpendEntry entry, {
    required String categoryId,
    String subcategory = '',
    required double amount,
    required bool isNeed,
    String note = '',
  }) async {
    if (amount <= 0) return;
    entry.categoryId = categoryId;
    entry.subcategory = subcategory.trim();
    entry.amount = amount;
    entry.isNeed = isNeed;
    entry.note = note.trim();
    await _commit();
  }

  SpendCategory? spendCategoryById(String id) {
    for (final c in _state.spendCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  double get totalSpent =>
      _state.spendEntries.fold(0.0, (sum, e) => sum + e.amount);
  double get totalNeedSpent =>
      _state.spendEntries.where((e) => e.isNeed).fold(0.0, (sum, e) => sum + e.amount);
  double get totalWantSpent =>
      _state.spendEntries.where((e) => !e.isNeed).fold(0.0, (sum, e) => sum + e.amount);

  Map<String, double> get spentByCategoryId {
    final result = <String, double>{};
    for (final e in _state.spendEntries) {
      result[e.categoryId] = (result[e.categoryId] ?? 0) + e.amount;
    }
    return result;
  }

  DateTime get _startOfThisWeek {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    return midnight.subtract(Duration(days: midnight.weekday - 1)); // Monday
  }

  DateTime get _startOfThisMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Total logged since a given start instant — the general-purpose version
  /// of [spentInCurrentBudgetPeriod] that works whether or not the user has
  /// actually set a budget, so "how much this week/month" is always visible.
  double spentSince(DateTime start) => _state.spendEntries
      .where((e) => !e.date.isBefore(start))
      .fold(0.0, (sum, e) => sum + e.amount);

  double get spentThisWeek => spentSince(_startOfThisWeek);
  double get spentThisMonth => spentSince(_startOfThisMonth);

  /// Per-category totals restricted to a window — feeds both the weekly/
  /// monthly summary and the category breakdown chart.
  Map<String, double> spentByCategorySince(DateTime start) {
    final result = <String, double>{};
    for (final e in _state.spendEntries) {
      if (e.date.isBefore(start)) continue;
      result[e.categoryId] = (result[e.categoryId] ?? 0) + e.amount;
    }
    return result;
  }

  /// Total logged per day over the last [days] days (including today),
  /// oldest first — the data behind the spend trend sparkline/bars.
  List<double> dailySpendTotals(int days) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    final totals = List<double>.filled(days, 0.0);
    for (final e in _state.spendEntries) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      final offset = d.difference(start).inDays;
      if (offset >= 0 && offset < days) totals[offset] += e.amount;
    }
    return totals;
  }

  // ---- Wallet budget (monthly/weekly) ----

  double? get spendBudgetAmount => _state.spendBudgetAmount;
  String get spendBudgetPeriod => _state.spendBudgetPeriod;

  Future<void> setSpendBudget(double amount, String period) async {
    if (amount < 0) return;
    _state.spendBudgetAmount = amount;
    _state.spendBudgetPeriod = period == 'weekly' ? 'weekly' : 'monthly';
    await _commit();
  }

  Future<void> clearSpendBudget() async {
    _state.spendBudgetAmount = null;
    await _commit();
  }

  DateTime get _currentBudgetWindowStart {
    final now = DateTime.now();
    if (_state.spendBudgetPeriod == 'weekly') {
      final today = DateTime(now.year, now.month, now.day);
      return today.subtract(Duration(days: today.weekday - 1)); // Monday
    }
    return DateTime(now.year, now.month, 1);
  }

  /// Sum of everything logged inside the current budget window (this
  /// calendar month, or this Monday-to-now week) — what the budget bar
  /// compares against.
  double get spentInCurrentBudgetPeriod {
    final start = _currentBudgetWindowStart;
    return _state.spendEntries
        .where((e) => !e.date.isBefore(start))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // ---- Savings & investments ----

  List<SavingsEntry> get savingsEntries => _state.savingsEntries;

  Future<void> addSavingsEntry({
    required String type,
    required double amount,
    String note = '',
  }) async {
    if (amount <= 0) return;
    _state.savingsEntries.insert(
      0,
      SavingsEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        amount: amount,
        note: note.trim(),
        date: DateTime.now(),
      ),
    );
    await _commit();
  }

  Future<void> removeSavingsEntry(SavingsEntry entry) async {
    _state.savingsEntries.remove(entry);
    await _commit();
  }

  double get totalSavings =>
      _state.savingsEntries.fold(0.0, (sum, e) => sum + e.amount);

  Map<String, double> get savingsByType {
    final result = <String, double>{};
    for (final e in _state.savingsEntries) {
      result[e.type] = (result[e.type] ?? 0) + e.amount;
    }
    return result;
  }

  // ---- Shared vision board (cached locally so the code isn't re-entered) ----

  String? get sharedBoardCode => _state.sharedBoardCode;
  String? get sharedBoardTitle => _state.sharedBoardTitle;

  Future<void> setSharedBoard(String? code, String? title) async {
    _state.sharedBoardCode = code;
    _state.sharedBoardTitle = title;
    await _commit();
  }

  // ---- Reminders ----

  Future<void> setReminderEnabled(ReminderSetting reminder, bool value) async {
    reminder.enabled = value;
    await _commit();
    await rescheduleReminders();
  }

  Future<void> setReminderTime(
      ReminderSetting reminder, int hour, int minute) async {
    reminder.hour = hour;
    reminder.minute = minute;
    await _commit();
    await rescheduleReminders();
  }

  Future<void> setSkipWeekends(bool value) async {
    _state.skipWeekends = value;
    await _commit();
    await rescheduleReminders();
  }

  Future<void> rescheduleReminders() async {
    await Notifications.instance.scheduleAll(
      reminders: _state.reminders,
      keyDates: _state.keyDates,
      mantra: mantraOfTheDay,
      openTasks: todaysTasks.where((t) => !t.done).map((t) => t.title).toList(),
    );
  }

  // ---- Key dates (yearly reminders) ----

  List<KeyDate> get keyDates => _state.keyDates;

  Future<void> addKeyDate(String title, int month, int day) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _state.keyDates.add(KeyDate(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: trimmed,
      month: month,
      day: day,
    ));
    await _commit();
    await rescheduleReminders();
  }

  Future<void> removeKeyDate(KeyDate keyDate) async {
    _state.keyDates.remove(keyDate);
    await _commit();
    await rescheduleReminders();
  }

  // ---- Onboarding ----

  bool get onboardingComplete => _state.onboardingComplete;

  String get userName => _state.userName;

  String get dailyTimeCommitment => _state.dailyTimeCommitment;

  List<String> get focusAreas => _state.focusAreas;

  Future<void> completeOnboarding({
    required String userName,
    required List<String> focusAreas,
    required String dailyTimeCommitment,
    required String preset,
  }) async {
    _state.onboardingComplete = true;
    _state.userName = userName.trim();
    _state.focusAreas = focusAreas;
    _state.dailyTimeCommitment = dailyTimeCommitment;
    _state.preset = preset;
    await _commit();
  }

  Future<void> retakeOnboarding() async {
    _state.onboardingComplete = false;
    await _commit();
  }

  // ---- Module picker (card order + visibility) ----

  List<ModuleConfig> get modules => _state.modules;

  List<String> get visibleModuleIds => _state.modules
      .where((m) => m.enabled)
      .map((m) => m.id)
      .toList(growable: false);

  Future<void> setModuleEnabled(String id, bool enabled) async {
    for (final m in _state.modules) {
      if (m.id == id) m.enabled = enabled;
    }
    await _commit();
  }

  Future<void> reorderModule(int oldIndex, int newIndex) async {
    var to = newIndex;
    if (to > oldIndex) to -= 1;
    final item = _state.modules.removeAt(oldIndex);
    _state.modules.insert(to, item);
    await _commit();
  }

  // ---- Journaling (Brain Dump) — manifestation scripts + free brain dumps ----

  List<Script> get scripts => _state.scripts;

  Future<void> addScript(String title, String body, {String mode = 'manifest'}) async {
    if (title.trim().isEmpty && body.trim().isEmpty) return;
    _state.scripts
        .insert(0, Script(title: title.trim(), body: body.trim(), mode: mode));
    await _commit();
  }

  Future<void> updateScript(Script script, String title, String body,
      {String? mode}) async {
    script.title = title.trim();
    script.body = body.trim();
    if (mode != null) script.mode = mode;
    await _commit();
  }

  Future<void> removeScript(Script script) async {
    _state.scripts.remove(script);
    await _commit();
  }

  // ---- Finance & Money tools: Goal Roadmap + 50/30/20 budget calculator ----

  FinanceRoadmap? get financeRoadmap => _state.financeRoadmap;

  Future<void> setFinanceRoadmap(String dreamGoal, double targetAmount, int months) async {
    _state.financeRoadmap =
        FinanceRoadmap(dreamGoal: dreamGoal.trim(), targetAmount: targetAmount, months: months);
    await _commit();
  }

  Future<void> toggleRoadmapMonth(int index) async {
    final roadmap = _state.financeRoadmap;
    if (roadmap == null || index < 0 || index >= roadmap.monthsDone.length) return;
    roadmap.monthsDone[index] = !roadmap.monthsDone[index];
    await _commit();
  }

  Future<void> clearFinanceRoadmap() async {
    _state.financeRoadmap = null;
    await _commit();
  }

  double? get financeBudgetIncome => _state.financeBudgetIncome;

  Future<void> setFinanceBudgetIncome(double income) async {
    _state.financeBudgetIncome = income;
    await _commit();
  }

  double get financeBudgetNeedsPct => _state.financeBudgetNeedsPct;
  double get financeBudgetWantsPct => _state.financeBudgetWantsPct;
  double get financeBudgetSavingsPct => _state.financeBudgetSavingsPct;

  /// Sets all three budget split percentages at once — callers are
  /// responsible for keeping them summing to ~100, which the slider UI does
  /// by redistributing the other two whenever one moves.
  Future<void> setFinanceBudgetSplit(double needs, double wants, double savings) async {
    _state.financeBudgetNeedsPct = needs;
    _state.financeBudgetWantsPct = wants;
    _state.financeBudgetSavingsPct = savings;
    await _commit();
  }

  Future<void> resetFinanceBudgetSplit() async {
    _state.financeBudgetNeedsPct = 50;
    _state.financeBudgetWantsPct = 30;
    _state.financeBudgetSavingsPct = 20;
    await _commit();
  }

  // ---- Mindset & Growth tools ----

  List<Reframe> get customReframes => _state.customReframes;

  Future<void> addCustomReframe(String negative, String positive) async {
    if (negative.trim().isEmpty || positive.trim().isEmpty) return;
    _state.customReframes.add(Reframe(negative: negative.trim(), positive: positive.trim()));
    await _commit();
  }

  Future<void> removeCustomReframe(int index) async {
    if (index < 0 || index >= _state.customReframes.length) return;
    _state.customReframes.removeAt(index);
    await _commit();
  }

  List<String> get todaysStressFills =>
      _state.stressBucketFills[dayKey(DateTime.now())] ?? <String>[];
  List<String> get todaysStressEmpties =>
      _state.stressBucketEmpties[dayKey(DateTime.now())] ?? <String>[];

  Future<void> toggleStressFill(String item) async {
    final key = dayKey(DateTime.now());
    final list = _state.stressBucketFills.putIfAbsent(key, () => <String>[]);
    if (!list.remove(item)) list.add(item);
    await _commit();
  }

  Future<void> toggleStressEmpty(String item) async {
    final key = dayKey(DateTime.now());
    final list = _state.stressBucketEmpties.putIfAbsent(key, () => <String>[]);
    if (!list.remove(item)) list.add(item);
    await _commit();
  }

  List<String> get todaysDose => _state.doseByDay[dayKey(DateTime.now())] ?? <String>[];

  Future<void> toggleDoseActivity(String activity) async {
    final key = dayKey(DateTime.now());
    final list = _state.doseByDay.putIfAbsent(key, () => <String>[]);
    if (!list.remove(activity)) list.add(activity);
    await _commit();
  }

  // ---- Evening reflection (journal) ----

  JournalEntry journalFor(DateTime date) =>
      _state.journalByDay[dayKey(date)] ?? JournalEntry();

  JournalEntry get todaysJournal => journalFor(DateTime.now());

  Future<void> saveTodaysJournal(
      List<String> achievements, String gratitude) async {
    final entry = JournalEntry(achievements: achievements, gratitude: gratitude);
    if (entry.isEmpty) {
      _state.journalByDay.remove(dayKey(DateTime.now()));
    } else {
      _state.journalByDay[dayKey(DateTime.now())] = entry;
    }
    await _commit();
  }

  // ---- Vision board ----

  List<VisionItem> get visionItems => _state.visionItems;

  Future<void> addVisionItem(String caption, {String? imagePath}) async {
    final trimmed = caption.trim();
    if (trimmed.isEmpty && imagePath == null) return;
    _state.visionItems.add(VisionItem(
      caption: trimmed,
      colorIndex: _state.visionItems.length,
      imagePath: imagePath,
    ));
    await _commit();
  }

  Future<void> removeVisionItem(VisionItem item) async {
    _state.visionItems.remove(item);
    await _commit();
  }

  /// Updates one tile's own shape/size/image framing — the per-tile
  /// customization that replaced the old board-wide-only shape setting.
  Future<void> updateVisionItemStyle(
    VisionItem item, {
    String? shape,
    int? spanX,
    int? spanY,
    double? imageOffsetX,
    double? imageOffsetY,
    double? imageZoom,
    String? frameStyle,
    String? filter,
  }) async {
    if (shape != null) item.shape = shape;
    if (spanX != null) item.spanX = spanX.clamp(1, 2);
    if (spanY != null) item.spanY = spanY.clamp(1, 2);
    if (imageOffsetX != null) item.imageOffsetX = imageOffsetX.clamp(0.0, 1.0);
    if (imageOffsetY != null) item.imageOffsetY = imageOffsetY.clamp(0.0, 1.0);
    if (imageZoom != null) item.imageZoom = imageZoom.clamp(1.0, 2.5);
    if (frameStyle != null && kVisionFrames.contains(frameStyle)) item.frameStyle = frameStyle;
    if (filter != null && kVisionFilters.contains(filter)) item.filter = filter;
    await _commit();
  }

  String get visionBoardBackground => _state.visionBoardBackground;

  Future<void> setVisionBoardBackground(String value) async {
    if (!kVisionBackgrounds.contains(value)) return;
    _state.visionBoardBackground = value;
    await _commit();
  }

  /// Applies a curated layout's shape/size recipe to the existing tiles, in
  /// order, cycling the recipe if there are more tiles than slots.
  Future<void> applyVisionLayout(VisionLayoutSpec layout) async {
    if (_state.visionItems.isEmpty || layout.slots.isEmpty) return;
    for (var i = 0; i < _state.visionItems.length; i++) {
      final slot = layout.slots[i % layout.slots.length];
      _state.visionItems[i].shape = slot.$1;
      _state.visionItems[i].spanX = slot.$2;
      _state.visionItems[i].spanY = slot.$3;
    }
    _state.visionBoardLayoutName = layout.name;
    await _commit();
  }

  String? get visionBoardLayoutName => _state.visionBoardLayoutName;

  // ---- Weekly / monthly goals ----

  List<Task> get weeklyGoals => _state.weeklyGoals;
  List<Task> get monthlyGoals => _state.monthlyGoals;

  Future<void> addWeeklyGoal(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _state.weeklyGoals.insert(0, Task(title: trimmed));
    await _commit();
  }

  Future<void> toggleWeeklyGoal(int index) async {
    if (index < 0 || index >= _state.weeklyGoals.length) return;
    _state.weeklyGoals[index].done = !_state.weeklyGoals[index].done;
    await _commit();
  }

  Future<void> removeWeeklyGoal(int index) async {
    if (index < 0 || index >= _state.weeklyGoals.length) return;
    _state.weeklyGoals.removeAt(index);
    await _commit();
  }

  Future<void> addMonthlyGoal(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _state.monthlyGoals.insert(0, Task(title: trimmed));
    await _commit();
  }

  Future<void> toggleMonthlyGoal(int index) async {
    if (index < 0 || index >= _state.monthlyGoals.length) return;
    _state.monthlyGoals[index].done = !_state.monthlyGoals[index].done;
    await _commit();
  }

  Future<void> removeMonthlyGoal(int index) async {
    if (index < 0 || index >= _state.monthlyGoals.length) return;
    _state.monthlyGoals.removeAt(index);
    await _commit();
  }

  // ---- Finance & Money goals / Health & Body goals ----

  List<Task> get financeGoals => _state.financeGoals;
  List<Task> get healthGoals => _state.healthGoals;

  Future<void> addFinanceGoal(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _state.financeGoals.insert(0, Task(title: trimmed));
    await _commit();
  }

  Future<void> toggleFinanceGoal(int index) async {
    if (index < 0 || index >= _state.financeGoals.length) return;
    _state.financeGoals[index].done = !_state.financeGoals[index].done;
    await _commit();
  }

  Future<void> removeFinanceGoal(int index) async {
    if (index < 0 || index >= _state.financeGoals.length) return;
    _state.financeGoals.removeAt(index);
    await _commit();
  }

  Future<void> addHealthGoal(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _state.healthGoals.insert(0, Task(title: trimmed));
    await _commit();
  }

  Future<void> toggleHealthGoal(int index) async {
    if (index < 0 || index >= _state.healthGoals.length) return;
    _state.healthGoals[index].done = !_state.healthGoals[index].done;
    await _commit();
  }

  Future<void> removeHealthGoal(int index) async {
    if (index < 0 || index >= _state.healthGoals.length) return;
    _state.healthGoals.removeAt(index);
    await _commit();
  }

  // ---- Mindset & Growth / Relationships & Connection goals ----

  List<Task> get mindsetGoals => _state.mindsetGoals;
  List<Task> get relationshipsGoals => _state.relationshipsGoals;

  Future<void> addMindsetGoal(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _state.mindsetGoals.insert(0, Task(title: trimmed));
    await _commit();
  }

  Future<void> toggleMindsetGoal(int index) async {
    if (index < 0 || index >= _state.mindsetGoals.length) return;
    _state.mindsetGoals[index].done = !_state.mindsetGoals[index].done;
    await _commit();
  }

  Future<void> removeMindsetGoal(int index) async {
    if (index < 0 || index >= _state.mindsetGoals.length) return;
    _state.mindsetGoals.removeAt(index);
    await _commit();
  }

  Future<void> addRelationshipsGoal(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _state.relationshipsGoals.insert(0, Task(title: trimmed));
    await _commit();
  }

  Future<void> toggleRelationshipsGoal(int index) async {
    if (index < 0 || index >= _state.relationshipsGoals.length) return;
    _state.relationshipsGoals[index].done = !_state.relationshipsGoals[index].done;
    await _commit();
  }

  Future<void> removeRelationshipsGoal(int index) async {
    if (index < 0 || index >= _state.relationshipsGoals.length) return;
    _state.relationshipsGoals.removeAt(index);
    await _commit();
  }

  // ---- Nutrition & Insights: lightweight quick-add meal log ----

  List<NutritionEntry> get nutritionEntries => _state.nutritionEntries;

  List<NutritionEntry> nutritionEntriesFor(DateTime day) {
    final key = dayKey(day);
    return _state.nutritionEntries.where((e) => dayKey(e.date) == key).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<NutritionEntry> get todaysNutritionEntries => nutritionEntriesFor(DateTime.now());

  Future<void> addNutritionEntry(String mealType, String name, {String note = ''}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _state.nutritionEntries.insert(
      0,
      NutritionEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        mealType: kMealTypes.contains(mealType) ? mealType : 'snack',
        name: trimmed,
        note: note.trim(),
        date: DateTime.now(),
      ),
    );
    await _commit();
  }

  Future<void> removeNutritionEntry(NutritionEntry entry) async {
    _state.nutritionEntries.remove(entry);
    await _commit();
  }

  /// Whether at least one meal was logged on [day] — the unit the streak and
  /// weekly insight below both count, in keeping with "notice the pattern"
  /// rather than "hit a number".
  bool loggedOn(DateTime day) => nutritionEntriesFor(day).isNotEmpty;

  /// Consecutive days (counting back from today) with at least one meal
  /// logged — same shape as [Habit.streak] so it reads consistently with the
  /// rest of the app.
  int get nutritionStreak {
    var count = 0;
    var cursor = DateTime.now();
    while (loggedOn(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Last 7 days (oldest first), each paired with whether a meal was logged
  /// that day — powers the one weekly insight strip on the Nutrition card.
  List<(DateTime day, bool logged)> get nutritionWeekOverview {
    final today = DateTime.now();
    return [
      for (var i = 6; i >= 0; i--)
        (
          DateTime(today.year, today.month, today.day).subtract(Duration(days: i)),
          loggedOn(DateTime(today.year, today.month, today.day).subtract(Duration(days: i))),
        ),
    ];
  }

  // ---- In-app mindset coach chat ----

  List<CoachMessage> get coachMessages => _state.coachMessages;

  int get coachMessagesSentToday {
    final key = dayKey(DateTime.now());
    return _state.coachMessages
        .where((m) => m.role == 'user' && dayKey(m.date) == key)
        .length;
  }

  bool get coachDailyLimitReached => coachMessagesSentToday >= kCoachDailyMessageLimit;

  /// Sends [text] to the coach and appends both the user's turn and the
  /// assistant's reply to the transcript. Returns null on success, or a
  /// friendly error string the screen can show inline (daily limit hit,
  /// network failure, upstream failure) — nothing here throws past this
  /// point.
  Future<String?> sendCoachMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (coachDailyLimitReached) {
      return "You've reached today's chat limit — back tomorrow for more.";
    }

    _state.coachMessages.add(
      CoachMessage(role: 'user', content: trimmed, date: DateTime.now()),
    );
    // Keep the persisted transcript bounded — the coach only ever sends the
    // last ~16 turns as context anyway (below), so months of daily use
    // shouldn't make this list grow without limit.
    const maxStored = 120;
    if (_state.coachMessages.length > maxStored) {
      _state.coachMessages.removeRange(0, _state.coachMessages.length - maxStored);
    }
    await _commit();

    try {
      final recent = _state.coachMessages.length > 16
          ? _state.coachMessages.sublist(_state.coachMessages.length - 16)
          : _state.coachMessages;
      final reply = await CoachChatService.instance.send([
        for (final m in recent) (role: m.role, content: m.content),
      ]);
      _state.coachMessages.add(
        CoachMessage(role: 'assistant', content: reply, date: DateTime.now()),
      );
      await _commit();
      return null;
    } catch (e) {
      return "Couldn't reach the coach right now — check your connection and try again.";
    }
  }

  Future<void> clearCoachChat() async {
    _state.coachMessages.clear();
    await _commit();
  }

  // ---- Relationships & Connection: people to stay in touch with ----

  List<RelationshipContact> get relationshipContacts => _state.relationshipContacts;

  Future<void> addRelationshipContact(String name,
      {String relation = 'friend', int cadenceDays = 7}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _state.relationshipContacts.add(RelationshipContact(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      relation: relation,
      cadenceDays: cadenceDays,
    ));
    await _commit();
  }

  Future<void> removeRelationshipContact(RelationshipContact contact) async {
    _state.relationshipContacts.remove(contact);
    await _commit();
  }

  Future<void> logContactNow(RelationshipContact contact) async {
    contact.lastContactAt = DateTime.now();
    await _commit();
  }

  Future<void> updateRelationshipContact(RelationshipContact contact,
      {String? name, String? relation, int? cadenceDays, String? note}) async {
    if (name != null && name.trim().isNotEmpty) contact.name = name.trim();
    if (relation != null) contact.relation = relation;
    if (cadenceDays != null) contact.cadenceDays = cadenceDays.clamp(1, 365);
    if (note != null) contact.note = note.trim();
    await _commit();
  }

  // ---- Organized mind map ----

  /// Auto-computed performance snapshot for 'day' | 'week' | 'month'.
  ({int habitsDone, int habitsTotal, int prioritiesDone, int prioritiesTotal,
      String? mood, bool journaled, int scriptsCount})
      mindMapSnapshot(String period) {
    final today = DateTime.now();
    final days = period == 'day' ? 1 : (period == 'week' ? 7 : 30);
    var prioritiesDone = 0, prioritiesTotal = 0, habitsDone = 0;
    String? lastMood;
    var journaled = false;
    for (var i = 0; i < days; i++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final tasks = tasksFor(day);
      prioritiesTotal += tasks.length;
      prioritiesDone += tasks.where((t) => t.done).length;
      for (final habit in _state.habits) {
        if (habit.isDoneOn(day)) habitsDone++;
      }
      if (i == 0) {
        lastMood = _state.moodByDay[dayKey(day)];
        journaled = !journalFor(day).isEmpty;
      }
    }
    return (
      habitsDone: habitsDone,
      habitsTotal: _state.habits.length * days,
      prioritiesDone: prioritiesDone,
      prioritiesTotal: prioritiesTotal,
      mood: lastMood,
      journaled: journaled,
      scriptsCount: _state.scripts.length,
    );
  }

  String mindMapNoteFor(String period) => _state.mindMapNotes[period] ?? '';

  Future<void> setMindMapNote(String period, String text) async {
    if (text.trim().isEmpty) {
      _state.mindMapNotes.remove(period);
    } else {
      _state.mindMapNotes[period] = text;
    }
    await _commit();
  }

  List<MindMapStickyNote> mindMapStickyNotesFor(String period) =>
      _state.mindMapStickyNotes[period] ?? const [];

  Future<void> addMindMapStickyNote(String period, String text, int colorIndex) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final list = _state.mindMapStickyNotes.putIfAbsent(period, () => []);
    list.add(MindMapStickyNote(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      text: trimmed,
      colorIndex: colorIndex,
    ));
    await _commit();
  }

  Future<void> removeMindMapStickyNote(String period, MindMapStickyNote note) async {
    _state.mindMapStickyNotes[period]?.remove(note);
    await _commit();
  }

  // ---- Home screen widget preferences ----

  bool get widgetShowHabits => _state.widgetShowHabits;
  bool get widgetShowPriorities => _state.widgetShowPriorities;
  bool get widgetShowMantra => _state.widgetShowMantra;

  Future<void> setWidgetShowHabits(bool value) async {
    _state.widgetShowHabits = value;
    await _commit();
  }

  Future<void> setWidgetShowPriorities(bool value) async {
    _state.widgetShowPriorities = value;
    await _commit();
  }

  Future<void> setWidgetShowMantra(bool value) async {
    _state.widgetShowMantra = value;
    await _commit();
  }

  /// Empty means "all habits" — the widget itself still caps at 5 for
  /// space, but this lets someone with a longer list choose which ones.
  List<String> get widgetHabitIds => _state.widgetHabitIds;

  Future<void> toggleWidgetHabit(String habitId) async {
    if (_state.widgetHabitIds.contains(habitId)) {
      _state.widgetHabitIds.remove(habitId);
    } else {
      _state.widgetHabitIds.add(habitId);
    }
    await _commit();
  }

  bool widgetHabitSelected(String habitId) =>
      _state.widgetHabitIds.isEmpty || _state.widgetHabitIds.contains(habitId);

  // ---- Home screen swipe hint ----

  bool get hasSeenSwipeHint => _state.hasSeenSwipeHint;

  Future<void> markSwipeHintSeen() async {
    if (_state.hasSeenSwipeHint) return;
    _state.hasSeenSwipeHint = true;
    await _commit();
  }

  // ---- Avatar / vision board shape ----

  String get avatarGender => _state.avatarGender;

  Future<void> setAvatarGender(String value) async {
    _state.avatarGender = value;
    await _commit();
  }

  String get visionBoardShape => _state.visionBoardShape;

  Future<void> setVisionBoardShape(String value) async {
    if (!kVisionShapes.contains(value)) return;
    _state.visionBoardShape = value;
    await _commit();
  }

  // ---- App lock (PIN + optional biometric) ----

  bool get hasPin => _state.pinHash != null;
  bool get biometricEnabled => _state.biometricEnabled;

  Future<void> setPin(String pin) async {
    _state.pinHash = hashPin(pin);
    await _commit();
  }

  Future<void> clearPin() async {
    _state.pinHash = null;
    _state.biometricEnabled = false;
    await _commit();
  }

  bool verifyPin(String pin) => _state.pinHash == hashPin(pin);

  Future<void> setBiometricEnabled(bool value) async {
    _state.biometricEnabled = value;
    await _commit();
  }

  // ---- Weekly momentum ----

  /// Priorities completed and habit check-ins over the last 7 days, today included.
  ({int prioritiesDone, int prioritiesTotal, int habitChecks, int habitPossible,
      int bestStreak}) weeklyMomentum() {
    final today = DateTime.now();
    var prioritiesDone = 0;
    var prioritiesTotal = 0;
    var habitChecks = 0;
    for (var i = 0; i < 7; i++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final tasks = tasksFor(day);
      prioritiesTotal += tasks.length;
      prioritiesDone += tasks.where((t) => t.done).length;
      for (final habit in _state.habits) {
        if (habit.isDoneOn(day)) habitChecks++;
      }
    }
    final bestStreak = _state.habits.isEmpty
        ? 0
        : _state.habits.map((h) => h.streak(today)).reduce((a, b) => a > b ? a : b);
    return (
      prioritiesDone: prioritiesDone,
      prioritiesTotal: prioritiesTotal,
      habitChecks: habitChecks,
      habitPossible: _state.habits.length * 7,
      bestStreak: bestStreak,
    );
  }

  // ---- Dashboard section performance (the "YOUR SECTIONS" tiles) ----

  /// A tailored completion percentage (0-1, or null when the section has
  /// nothing to measure yet) plus a short detail line, per
  /// [kHomePageSections] key — what replaces the old plain nav-duplicate
  /// tiles on the Dashboard. Each section uses whatever data it already
  /// has that reads as "today's/this period's performance" rather than one
  /// forced generic metric.
  ({double? pct, String detail}) sectionPerformance(String key) {
    switch (key) {
      case 'productivity':
        final today = todaysTasks;
        final pct = today.isEmpty
            ? null
            : today.where((t) => t.done).length / today.length;
        final streak = weeklyMomentum().bestStreak;
        return (
          pct: pct,
          detail: streak > 0 ? '$streak-day streak' : 'No streak yet',
        );

      case 'outcome':
        final wroteToday = _state.scripts.any((s) => _isToday(s.createdAt)) ||
            _state.journalByDay.containsKey(dayKey(DateTime.now()));
        final total = _state.scripts.length + _state.visionItems.length;
        return (
          pct: wroteToday ? 1.0 : 0.0,
          detail: total == 0 ? 'Nothing yet' : '$total total entries',
        );

      case 'finance':
        final income = _state.financeBudgetIncome;
        final budget = income == null
            ? null
            : income * (financeBudgetNeedsPct + financeBudgetWantsPct) / 100;
        final spent = spentThisMonth;
        return (
          pct: (budget == null || budget <= 0) ? null : (spent / budget).clamp(0.0, 1.0),
          detail: '₹${spent.toStringAsFixed(0)} this month',
        );

      case 'health':
        return _goalListPerformance(_state.healthGoals);
      case 'mindset':
        return _goalListPerformance(_state.mindsetGoals);
      case 'relationships':
        return _goalListPerformance(_state.relationshipsGoals);

      default:
        return (pct: null, detail: '');
    }
  }

  ({double? pct, String detail}) _goalListPerformance(List<Task> goals) {
    if (goals.isEmpty) return (pct: null, detail: 'No goals set');
    final done = goals.where((g) => g.done).length;
    return (pct: done / goals.length, detail: '$done/${goals.length} goals done');
  }

  bool _isToday(DateTime d) => dayKey(d) == dayKey(DateTime.now());

  // ---- Backup ----

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(_state.toJson());

  Future<bool> importJson(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      _state = AppState.fromJson(decoded);
      await _commit();
      await rescheduleReminders();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final store = Store();
