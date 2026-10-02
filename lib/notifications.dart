import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Local scheduled notifications. No server, no push, works offline.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  static const _channelId = 'prakriya_daily';
  static const _channelName = 'Daily reminders';
  static const _channelDescription =
      'Your mantra, open tasks, and the evening close.';

  Future<void> init() async {
    if (_initialised) return;

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      // Falls back to UTC rather than crash on an unrecognised zone name.
      // This used to also silently shift every reminder's fire time by the
      // device's UTC offset (see _nextInstance) — that part is fixed now,
      // but this print is kept so a logcat capture can still confirm
      // whether a given device's timezone name is failing to resolve here.
      // ignore: avoid_print
      print('Prakriya: timezone lookup failed, falling back to UTC: $e');
    }

    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
    } catch (_) {
      // A handful of OEM Android builds throw here (missing/renamed
      // notification resources, a stale plugin channel after an OS update).
      // Reminders just won't be available this session — that's a much
      // better failure than taking the whole app down with it, which is
      // what letting this escape used to do (store.load() awaits init()
      // before app launch can proceed).
    }
    // Marked initialised either way: a plugin that failed once tends to keep
    // failing, and re-throwing on every subsequent call (permission checks,
    // every reschedule) is exactly the repeated-crash pattern this guards
    // against.
    _initialised = true;
  }

  /// Ask once, when the user turns reminders on — never at launch.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<bool> permissionGranted() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final enabled = await android.areNotificationsEnabled();
    return enabled ?? false;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
      );

  /// Schedules one key date at 9am on its next occurrence (this year if it
  /// hasn't passed yet, else next year). No native yearly-repeat mode
  /// exists in this plugin, so this relies on [scheduleAll] running again
  /// at every app launch (it already does, via Store.load) to roll the
  /// occurrence forward once the date passes.
  Future<void> _scheduleKeyDate(KeyDate keyDate) async {
    // See the note on _nextInstance below: the wall-clock math here is done
    // in plain Dart DateTime (always correctly local to the device, no
    // timezone-database lookup involved) and only converted to a
    // tz.TZDateTime — via .from(), which preserves the exact instant — at
    // the very end, purely because the plugin's API asks for one.
    final now = DateTime.now();
    var year = now.year;
    // Clamp the day to whatever the target month actually has (handles a
    // Feb 29 saved in a leap year, or any other invalid combination) —
    // without this, DateTime(..., 29) for Feb in a non-leap year would
    // silently roll over into March instead of firing in February.
    int lastDayOf(int y, int m) => DateTime(y, m + 1, 0).day;
    var day = keyDate.day.clamp(1, lastDayOf(year, keyDate.month));
    var scheduled = DateTime(year, keyDate.month, day, 9, 0);
    if (!scheduled.isAfter(now)) {
      year += 1;
      day = keyDate.day.clamp(1, lastDayOf(year, keyDate.month));
      scheduled = DateTime(year, keyDate.month, day, 9, 0);
    }
    // A stable id derived from the key date's own id, offset well clear of
    // the fixed 1/2/3 used by the daily reminders above.
    final id = 1000 + (keyDate.id.hashCode.abs() % 8000);
    await _plugin.zonedSchedule(
      id,
      '🎉 ${keyDate.title}',
      "Today's the day — ${keyDate.title}.",
      tz.TZDateTime.from(scheduled, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Computes "today (or tomorrow, if the time already passed) at
  /// hour:minute" using plain Dart DateTime — which is always correctly the
  /// device's own local time, with no timezone-database lookup involved —
  /// then converts the result to a tz.TZDateTime only at the end, via
  /// .from(), purely because that's the type flutter_local_notifications'
  /// scheduling API expects. TZDateTime.from() preserves the exact instant
  /// of the DateTime it's given regardless of which Location it's tagged
  /// with, so this gives the right fire time even on a device where
  /// FlutterTimezone.getLocalTimezone() returned a name tz.getLocation()
  /// couldn't parse and init() silently fell back to UTC above: doing the
  /// arithmetic in tz.TZDateTime(tz.local, ...) directly, as this used to,
  /// would silently schedule every reminder at the UTC clock time instead
  /// of the device's real local time whenever that fallback kicked in —
  /// for IST that's a fixed 5.5-hour shift, enough to make a reminder set
  /// for "2 minutes from now" fire hours later (or earlier) instead.
  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(scheduled, tz.local);
  }

  /// Next occurrence of [weekday] (1 = Monday .. 7 = Sunday, matching
  /// [DateTime.weekday]) at the given time.
  tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    var scheduled = _nextInstance(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Next occurrence of the given day-of-month at the given time — clamped
  /// so a "31st" target never overflows into the following month. See the
  /// note on _nextInstance above for why the arithmetic is done in plain
  /// Dart DateTime rather than tz.TZDateTime(tz.local, ...).
  tz.TZDateTime _nextDayOfMonth(int day, int hour, int minute) {
    final now = DateTime.now();
    int lastDayOf(int y, int m) => DateTime(y, m + 1, 0).day;
    var year = now.year;
    var month = now.month;
    var scheduled =
        DateTime(year, month, day.clamp(1, lastDayOf(year, month)), hour, minute);
    if (!scheduled.isAfter(now)) {
      month += 1;
      if (month > 12) {
        month = 1;
        year += 1;
      }
      scheduled =
          DateTime(year, month, day.clamp(1, lastDayOf(year, month)), hour, minute);
    }
    return tz.TZDateTime.from(scheduled, tz.local);
  }

  /// Fires immediately — used for the budget-threshold alert, which can't be
  /// scheduled ahead of time because it depends on live spending data.
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await init();
      if (!await permissionGranted()) return;
      await _plugin.show(id, title, body, _details);
    } catch (_) {
      // Best-effort, same as everything else here.
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstance(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Rebuilds the whole schedule. Called on launch, on edit, and after reboot
  /// (the OS drops pending alarms when the device restarts).
  /// Rebuilds the whole schedule. Best-effort end to end: reminders are a
  /// nice-to-have layered on top of the app, never something the app's
  /// ability to open should depend on. This used to let a single bad
  /// `zonedSchedule` call (a revoked exact-alarm permission after an Android
  /// update, a stale plugin channel, a duplicate id) throw straight out of
  /// `Store.load()` — which is awaited before `runApp()` in main() — so one
  /// unlucky reminder or key date meant the app never rendered anything
  /// again on any future launch. Every step below is now isolated so that
  /// can't happen; at worst, reminders silently stop firing instead.
  Future<void> scheduleAll({
    required List<ReminderSetting> reminders,
    required String mantra,
    required List<String> openTasks,
    List<KeyDate> keyDates = const [],
  }) async {
    try {
      await init();
      await _plugin.cancelAll();

      if (!await permissionGranted()) return;

      for (final keyDate in keyDates) {
        try {
          await _scheduleKeyDate(keyDate);
        } catch (_) {
          // Skip this one key date, keep going with the rest.
        }
      }

      for (final reminder in reminders) {
        if (!reminder.enabled) continue;
        try {
          switch (reminder.id) {
            case 'mantra':
              final tasks = openTasks.isEmpty
                  ? 'Set your three priorities for today.'
                  : openTasks.join(' · ');
              await _schedule(
                id: 1,
                title: 'Your mantra for today',
                body: '$mantra\n\n$tasks',
                hour: reminder.hour,
                minute: reminder.minute,
              );
              break;

            case 'midday':
              // Fires only when something is still open.
              if (openTasks.isEmpty) break;
              final count = openTasks.length;
              await _schedule(
                id: 2,
                title: count == 1
                    ? '1 priority still open'
                    : '$count priorities still open',
                body: openTasks.join('\n'),
                hour: reminder.hour,
                minute: reminder.minute,
              );
              break;

            case 'evening':
              await _schedule(
                id: 3,
                title: 'Close the day',
                body: 'Ninety seconds: tick your habits and look at tomorrow.',
                hour: reminder.hour,
                minute: reminder.minute,
              );
              break;

            case 'spendWeekly':
              await _plugin.zonedSchedule(
                4,
                '📊 Your week in spending',
                'Open your wallet to see where it went this week.',
                _nextWeekday(DateTime.sunday, reminder.hour, reminder.minute),
                _details,
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              );
              break;

            case 'spendMonthly':
              await _plugin.zonedSchedule(
                5,
                '📅 Your month in spending',
                'A new month just started — check last month\'s totals in your wallet.',
                _nextDayOfMonth(1, reminder.hour, reminder.minute),
                _details,
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
              );
              break;

            case 'spendAlerts':
              // No fixed time to schedule — this toggle only gates the
              // instant, live alert fired from Store.maybeSendSpendAlert.
              break;
          }
        } catch (_) {
          // Skip this one reminder, keep going with the rest.
        }
      }
    } catch (_) {
      // Whatever else went wrong (plugin unavailable, permission check
      // itself threw, etc.) — reminders just don't get (re)scheduled this
      // time. The rest of the app must not depend on this succeeding.
    }
  }
}
