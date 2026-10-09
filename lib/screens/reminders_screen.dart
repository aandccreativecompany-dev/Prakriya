import 'package:flutter/material.dart';

import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with WidgetsBindingObserver {
  bool _exactOk = true;
  bool _permissionGranted = true;
  String _testMessage = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the system "Alarms & reminders" screen: pick up the
  // new permission state and reschedule with exact alarms straight away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.rescheduleReminders().then((_) => _checkPermission());
    }
  }

  Future<void> _checkPermission() async {
    final granted = await Notifications.instance.permissionGranted();
    final status = await Notifications.instance.statusSummary();
    final exact = await Notifications.instance.exactAllowed();
    if (mounted) {
      setState(() {
        _exactOk = exact;
        _permissionGranted = granted;
        _status = status;
      });
    }
  }

  Future<void> _runTest(Future<String> Function() test) async {
    setState(() => _testMessage = 'Working…');
    final result = await test();
    final status = await Notifications.instance.statusSummary();
    if (mounted) {
      setState(() {
        _testMessage = result;
        _status = status;
      });
    }
  }

  Future<void> _enable(ReminderSetting reminder, bool value) async {
    if (value && !_permissionGranted) {
      final granted = await Notifications.instance.requestPermission();
      if (mounted) setState(() => _permissionGranted = granted);
      if (!granted) return;
    }
    await store.setReminderEnabled(reminder, value);
    final status = await Notifications.instance.statusSummary();
    if (mounted) {
      setState(() => _status = status);
      toastSaved(context);
    }
  }

  Future<void> _pickTime(ReminderSetting reminder) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
    );
    if (picked != null) {
      await store.setReminderTime(reminder, picked.hour, picked.minute);
      final status = await Notifications.instance.statusSummary();
      if (mounted) {
        setState(() => _status = status);
        toastSaved(context);
      }
    }
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                  children: [
                    const ScreenHeader(
                      icon: Icons.notifications_none,
                      title: 'Reminders',
                      subtitle: "Prakriyā reaches out so you don't have to remember to open it.",
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_permissionGranted)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: ModuleCard(
                                accent: true,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Notifications are switched off',
                                        style: body(13.5, Surfaces.accentText(dark),
                                            weight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Text(
                                        'Prakriyā needs permission before it can send reminders.',
                                        style: body(12.5, Surfaces.bodyText(dark))),
                                    const SizedBox(height: 14),
                                    GoldButton(
                                      labelText: 'Allow notifications',
                                      onPressed: () async {
                                        final granted = await Notifications.instance
                                            .requestPermission();
                                        if (mounted) {
                                          setState(() => _permissionGranted = granted);
                                        }
                                        await store.rescheduleReminders();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_permissionGranted && !_exactOk)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: ModuleCard(
                                accent: true,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Allow on-time reminders',
                                        style: body(13.5, Surfaces.accentText(dark),
                                            weight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Text(
                                        'Without this, your phone can delay or skip reminders when it is idle. Tap below, then switch on "Allow setting alarms and reminders" for Prakriyā.',
                                        style: body(12.5, Surfaces.bodyText(dark))),
                                    const SizedBox(height: 14),
                                    GoldButton(
                                      labelText: 'Allow on-time reminders',
                                      onPressed: () =>
                                          Notifications.instance.requestExact(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: ModuleCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Check that reminders work on this phone',
                                      style: body(13.5, Surfaces.heading(dark),
                                          weight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text(
                                      'Tap "Send now" to see one immediately. Tap "In 1 minute", then close the app and wait: that is the same path your daily reminders use.',
                                      style: body(12, Surfaces.muted(dark)).copyWith(height: 1.4)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _runTest(
                                              Notifications.instance.sendTestNow),
                                          child: const Text('Send now'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _runTest(Notifications
                                              .instance.scheduleTestInOneMinute),
                                          child: const Text('In 1 minute'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_testMessage.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(_testMessage,
                                        style: body(12, Surfaces.accentText(dark))),
                                  ],
                                  if (_status.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(_status,
                                        style: body(11.5, Surfaces.muted(dark))),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          for (var i = 0; i < store.reminders.length; i++)
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 260 + i * 60),
                              curve: Curves.easeOutCubic,
                              builder: (context, t, child) => Transform.translate(
                                offset: Offset(0, (1 - t.clamp(0, 1)) * 10),
                                child: Opacity(opacity: t.clamp(0, 1), child: child),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ModuleCard(
                                  accent: store.reminders[i].enabled,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(store.reminders[i].title,
                                                    style: body(14,
                                                        Surfaces.heading(dark),
                                                        weight: FontWeight.w700)),
                                                const SizedBox(height: 4),
                                                Text(_subtitleFor(store.reminders[i].id),
                                                    style: body(11.5,
                                                        Surfaces.muted(dark))),
                                              ],
                                            ),
                                          ),
                                          BrandSwitch(
                                            value: store.reminders[i].enabled,
                                            onChanged: (value) =>
                                                _enable(store.reminders[i], value),
                                          ),
                                        ],
                                      ),
                                      if (store.reminders[i].enabled &&
                                          store.reminders[i].id !=
                                              'spendAlerts') ...[
                                        const SizedBox(height: 14),
                                        Divider(
                                            height: 1,
                                            color: Surfaces.accentBorder(dark)),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _pickTime(store.reminders[i]),
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.symmetric(vertical: 8),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Time',
                                                    style: body(13,
                                                        Surfaces.bodyText(dark),
                                                        weight: FontWeight.w500)),
                                                Text(store.reminders[i].clockLabel,
                                                    style: display(
                                                        15, Surfaces.accent(dark))),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('KEY DATES', style: label(Surfaces.muted(dark))),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _addKeyDate(context),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.add_circle_outline,
                                      size: 20, color: Surfaces.accent(dark)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Birthdays, anniversaries, renewals — anything that matters once a year, notified at 9am on the day.',
                            textAlign: TextAlign.justify,
                            style: body(12, Surfaces.muted(dark)).copyWith(height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          if (store.keyDates.isEmpty)
                            ModuleCard(
                              child: Text('Nothing added yet — tap + to add one.',
                                  style: body(13, Surfaces.muted(dark))),
                            )
                          else
                            for (final keyDate in _sortedKeyDates())
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ModuleCard(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Surfaces.accent(dark).withValues(alpha: 0.16),
                                        ),
                                        child: Icon(Icons.cake_outlined,
                                            size: 18, color: Surfaces.accent(dark)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(keyDate.title,
                                                style: body(13.5, Surfaces.heading(dark),
                                                    weight: FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text(_keyDateSubtitle(keyDate),
                                                style: body(11.5, Surfaces.muted(dark))),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          await store.removeKeyDate(keyDate);
                                          if (mounted) toastSaved(context, label: 'Removed');
                                        },
                                        icon: Icon(Icons.close, size: 18, color: Surfaces.muted(dark)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          const SizedBox(height: 12),
                          Text('QUIET HOURS', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('Skip on weekends',
                                      style: body(13.5, Surfaces.bodyText(dark),
                                          weight: FontWeight.w500)),
                                ),
                                BrandSwitch(
                                  value: store.state.skipWeekends,
                                  onChanged: (value) async {
                                    await store.setSkipWeekends(value);
                                    if (mounted) toastSaved(context);
                                  },
                                ),
                              ],
                            ),
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

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  List<KeyDate> _sortedKeyDates() {
    final list = List<KeyDate>.from(store.keyDates);
    list.sort((a, b) {
      final aKey = a.month * 100 + a.day;
      final bKey = b.month * 100 + b.day;
      return aKey.compareTo(bKey);
    });
    return list;
  }

  String _keyDateSubtitle(KeyDate keyDate) {
    final now = DateTime.now();
    var year = now.year;
    final lastDay = DateTime(year, keyDate.month + 1, 0).day;
    var target = DateTime(year, keyDate.month, keyDate.day.clamp(1, lastDay));
    if (target.isBefore(DateTime(now.year, now.month, now.day))) {
      year += 1;
      final lastDayNext = DateTime(year, keyDate.month + 1, 0).day;
      target = DateTime(year, keyDate.month, keyDate.day.clamp(1, lastDayNext));
    }
    final daysAway = target.difference(DateTime(now.year, now.month, now.day)).inDays;
    final dateLabel = '${_monthNames[keyDate.month - 1]} ${keyDate.day}';
    if (daysAway == 0) return '$dateLabel · Today!';
    if (daysAway == 1) return '$dateLabel · Tomorrow';
    return '$dateLabel · in $daysAway days';
  }

  Future<void> _addKeyDate(BuildContext context) async {
    final titleCtrl = TextEditingController();
    DateTime picked = DateTime.now();
    final dark = Theme.of(context).brightness == Brightness.dark;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Surfaces.heading(dark)),
              title: Text('New key date', style: display(17, Surfaces.heading(dark))),
              actions: [
                IconButton(
                  tooltip: 'Save',
                  onPressed: () => Navigator.pop(context, true),
                  icon: Icon(Icons.check_circle, color: Surfaces.accent(dark), size: 28),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: Container(
              decoration: Surfaces.pageBackground(dark),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        style: body(15, Surfaces.bodyText(dark), weight: FontWeight.w600),
                        decoration: const InputDecoration(hintText: "e.g. Mom's birthday"),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final now = DateTime.now();
                          final result = await showDatePicker(
                            context: context,
                            initialDate: picked,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 6),
                            helpText: 'Pick the month and day (year is ignored)',
                          );
                          if (result != null) setSheetState(() => picked = result);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Surfaces.accentBorder(dark)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event, size: 18, color: Surfaces.accent(dark)),
                              const SizedBox(width: 10),
                              Text('${_monthNames[picked.month - 1]} ${picked.day}',
                                  style: body(14, Surfaces.bodyText(dark), weight: FontWeight.w600)),
                              const Spacer(),
                              Icon(Icons.chevron_right, size: 18, color: Surfaces.muted(dark)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Repeats every year on this month and day.',
                          style: body(11.5, Surfaces.muted(dark))),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );

    if (result == true && titleCtrl.text.trim().isNotEmpty) {
      await store.addKeyDate(titleCtrl.text, picked.month, picked.day);
      if (mounted) toastSaved(context);
    }
  }

  String _subtitleFor(String id) {
    switch (id) {
      case 'mantra':
        return 'Sent with your top 3 priorities';
      case 'midday':
        return 'Your open priorities, around midday';
      case 'evening':
        return 'Habits and tomorrow';
      case 'spendWeekly':
        return 'A nudge to review your wallet, every Sunday';
      case 'spendMonthly':
        return 'A nudge to review last month, on the 1st';
      case 'spendAlerts':
        return 'Instant alert at 80% and 100% of your monthly budget';
      default:
        return 'Habits and tomorrow';
    }
  }
}
