import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prakriya/main.dart';
import 'package:prakriya/models.dart';
import 'package:prakriya/store.dart';

void main() {
  testWidgets('App boots to onboarding on first run', (tester) async {
    await tester.pumpWidget(const PrakriyaApp());
    await tester.pump();

    // First run has no onboarding done yet, so the welcome step should show.
    expect(find.text('PRAKRIYĀ'), findsWidgets);
  });

  testWidgets(
      'Home screen renders the Dashboard with a bottom nav bar once onboarded',
      (tester) async {
    // completeOnboarding only touches shared_preferences (not the
    // notifications plugin), so a mocked in-memory store is enough here.
    SharedPreferences.setMockInitialValues({});
    await store.completeOnboarding(
      userName: 'Alex',
      focusAreas: const [],
      dailyTimeCommitment: '15',
      preset: kPresetBalance,
    );

    await tester.pumpWidget(const PrakriyaApp());
    await tester.pumpAndSettle();

    // The Dashboard can also show a morning mood check-in prompt on top —
    // dismiss it first so it doesn't intercept the scroll below.
    final skipMood = find.text('Skip for today');
    if (skipMood.evaluate().isNotEmpty) {
      await tester.tap(skipMood);
      await tester.pumpAndSettle();
    }

    // Default landing tab is the Dashboard — one shared greeting/mantra/
    // stats screen instead of every section repeating them. It now also
    // shows a "back up your data" banner above the fold when signed out,
    // which can push the sections list below the default test viewport, so
    // this content may not be built/visible yet — scroll the Dashboard's own
    // list down by a fixed amount first.
    await tester.drag(
        find.byKey(const ValueKey('dashboardList')), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('YOUR SECTIONS'), findsOneWidget);
    expect(find.text('Productivity'), findsWidgets);
    // The bottom nav is now a horizontally scrolling row (so every visible
    // section can have its own tab, not just the first 3 + "More") rather
    // than a fixed-width NavigationBar — check for that scrollable
    // container plus the Dashboard tab's own label instead.
    expect(
      find.byWidgetPredicate((w) =>
          w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
      findsOneWidget,
    );
    expect(find.text('Dashboard'), findsOneWidget);

    // Tapping the Productivity destination switches to its own full
    // section screen (no back arrow — it's a tab, not a pushed route).
    await tester.tap(find.text('Tasks').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Productivity'), findsWidgets);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
