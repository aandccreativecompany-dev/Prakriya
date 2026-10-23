import 'package:flutter_test/flutter_test.dart';
import 'package:prakriya/services/growth.dart';

DayFacts day(int offset, {int habits = 0, int total = 4, int tasks = 0, int taskTotal = 3,
    bool mood = false, bool contacted = false}) {
  return DayFacts(
    day: DateTime(2026, 1, 1).add(Duration(days: offset)),
    habitsDone: habits,
    habitsTotal: total,
    tasksDone: tasks,
    tasksTotal: taskTotal,
    moodLogged: mood,
    contacted: contacted,
  );
}

void main() {
  test('an empty day earns nothing and a perfect day earns 100', () {
    expect(GrowthEngine.pointsFor(day(0)), 0);
    final full = DayFacts(
      day: DateTime(2026, 1, 1),
      habitsDone: 4,
      habitsTotal: 4,
      tasksDone: 3,
      tasksTotal: 3,
      moodLogged: true,
      journaled: true,
      mindActions: 2,
      mealsLogged: 3,
      waterLogged: true,
      contacted: true,
    );
    expect(GrowthEngine.pointsFor(full), 100);
  });

  test('stages follow the point thresholds', () {
    expect(GrowthEngine.stageFor(0).index, 0);
    expect(GrowthEngine.stageFor(39).index, 0);
    expect(GrowthEngine.stageFor(40).index, 1);
    expect(GrowthEngine.stageFor(2400).index, 6);
    expect(GrowthEngine.stageFor(99999).index, 6);
  });

  test('a quiet stretch makes the plant thirsty but never shrinks it', () {
    final facts = <DayFacts>[
      for (var i = 0; i < 10; i++) day(i, habits: 4, tasks: 3, mood: true),
      for (var i = 10; i < 14; i++) day(i),
    ];
    final snap = GrowthEngine.build(facts);
    expect(snap.thirsty, isTrue);
    final before = GrowthEngine.build(facts.sublist(0, 10));
    expect(snap.points, before.points);
    expect(snap.stage.index, before.stage.index);
  });

  test('the wheel reflects the last seven days and flags the weakest axis', () {
    final facts = <DayFacts>[
      for (var i = 0; i < 7; i++) day(i, habits: 4, tasks: 0),
    ];
    final snap = GrowthEngine.build(facts, moneyScore: null);
    final habits = snap.wheel.firstWhere((a) => a.key == 'habits');
    expect(habits.value, closeTo(1.0, 0.001));
    final money = snap.wheel.firstWhere((a) => a.key == 'money');
    expect(money.tracked, isFalse);
    expect(snap.weakest, isNotNull);
    expect(snap.weakest!.key, isNot('habits'));
    expect(snap.daily.length, 7);
    expect(snap.smooth.length, 7);
  });

  test('stage-ups are recorded on the day they happen', () {
    final facts = <DayFacts>[
      for (var i = 0; i < 3; i++) day(i, habits: 4, tasks: 3, mood: true, contacted: true),
    ];
    final snap = GrowthEngine.build(facts);
    expect(snap.stageUps.isNotEmpty, isTrue);
  });
}
