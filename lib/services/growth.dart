import '../models.dart';
import '../store.dart';
import 'extras.dart';

/// What happened on one calendar day, boiled down to plain numbers. The
/// growth engine below only ever sees these, so it is pure and easy to test.
class DayFacts {
  final DateTime day;
  final int habitsDone;
  final int habitsTotal;
  final int tasksDone;
  final int tasksTotal;
  final bool moodLogged;
  final bool journaled;

  /// Mind-care actions: Dose of happiness items, stress bucket moves, focus
  /// or meditation sessions.
  final int mindActions;
  final int mealsLogged;
  final bool waterLogged;
  final bool contacted;

  const DayFacts({
    required this.day,
    this.habitsDone = 0,
    this.habitsTotal = 0,
    this.tasksDone = 0,
    this.tasksTotal = 0,
    this.moodLogged = false,
    this.journaled = false,
    this.mindActions = 0,
    this.mealsLogged = 0,
    this.waterLogged = false,
    this.contacted = false,
  });

  double get habitsFrac => habitsTotal == 0 ? 0 : habitsDone / habitsTotal;
  double get tasksFrac => tasksTotal == 0 ? 0 : tasksDone / tasksTotal;

  /// 0..1 for the Mind axis: mood, journal and one mind action each count.
  double get mindFrac =>
      ((moodLogged ? 1 : 0) + (journaled ? 1 : 0) + (mindActions > 0 ? 1 : 0)) / 3;

  /// 0..1 for the Body axis: a meal logged and water logged.
  double get bodyFrac => ((mealsLogged > 0 ? 1 : 0) + (waterLogged ? 1 : 0)) / 2;

  /// Whether anything at all was done — keeps the plant happy.
  bool get active =>
      habitsDone > 0 ||
      tasksDone > 0 ||
      moodLogged ||
      journaled ||
      mindActions > 0 ||
      mealsLogged > 0 ||
      waterLogged ||
      contacted;
}

/// One stage of the plant's life.
class PlantStage {
  final int index;
  final String name;
  final String blurb;
  final int minPoints;
  const PlantStage(this.index, this.name, this.blurb, this.minPoints);
}

const List<PlantStage> kPlantStages = [
  PlantStage(0, 'Seed', 'Resting in the soil, waiting for your first win.', 0),
  PlantStage(1, 'Sprout', 'A first green shoot — you showed up.', 40),
  PlantStage(2, 'Seedling', 'Two leaves open to the light.', 150),
  PlantStage(3, 'Sapling', 'A strong little stem, still growing fast.', 400),
  PlantStage(4, 'Young tree', 'Branching out in every direction.', 800),
  PlantStage(5, 'In bloom', 'Flowers open — your effort is showing.', 1400),
  PlantStage(6, 'Fruiting tree', 'Rooted, full and generous. Keep tending it.', 2400),
];

/// One axis of the balance wheel.
class WheelAxis {
  final String key;
  final String label;

  /// 0..1 over the last seven days.
  final double value;

  /// False when there is nothing to measure yet (e.g. no budget set).
  final bool tracked;
  const WheelAxis(this.key, this.label, this.value, {this.tracked = true});
}

class GrowthSnapshot {
  final int points;
  final PlantStage stage;
  final PlantStage? next;

  /// 0..1 progress between this stage and the next (1 when fully grown).
  final double toNext;

  /// True when the last few days were quiet; the plant looks thirsty. It
  /// never loses a stage or points — no guilt mechanics.
  final bool thirsty;
  final int activeDaysThisWeek;
  final List<WheelAxis> wheel;

  /// Oldest first; one value (0..1) per day for the curve.
  final List<double> daily;
  final List<DateTime> dailyDays;
  final List<double> smooth;

  /// Day-keys where the plant moved up a stage, for markers on the curve.
  final Map<String, int> stageUps;
  const GrowthSnapshot({
    required this.points,
    required this.stage,
    required this.next,
    required this.toNext,
    required this.thirsty,
    required this.activeDaysThisWeek,
    required this.wheel,
    required this.daily,
    required this.dailyDays,
    required this.smooth,
    required this.stageUps,
  });

  /// The weakest tracked axis — what to tend next.
  WheelAxis? get weakest {
    WheelAxis? out;
    for (final a in wheel) {
      if (!a.tracked) continue;
      if (out == null || a.value < out.value) out = a;
    }
    return out;
  }

  WheelAxis? get strongest {
    WheelAxis? out;
    for (final a in wheel) {
      if (!a.tracked) continue;
      if (out == null || a.value > out.value) out = a;
    }
    return out;
  }
}

class GrowthEngine {
  GrowthEngine._();

  /// How many days back growth points are counted from.
  static const int lookbackDays = 365;

  /// Points one day earns (max 100).
  static int pointsFor(DayFacts f) {
    final p = f.habitsFrac * 30 +
        f.tasksFrac * 25 +
        f.mindFrac * 20 +
        f.bodyFrac * 15 +
        (f.contacted ? 10 : 0);
    return p.round();
  }

  /// A day's overall score, 0..1.
  static double scoreFor(DayFacts f) => pointsFor(f) / 100.0;

  static PlantStage stageFor(int points) {
    var out = kPlantStages.first;
    for (final s in kPlantStages) {
      if (points >= s.minPoints) out = s;
    }
    return out;
  }

  /// Builds everything the growth screens show. [facts] is oldest first and
  /// ends with today. [moneyScore] is 0..1 or null if no budget is set.
  static GrowthSnapshot build(List<DayFacts> facts, {double? moneyScore}) {
    var total = 0;
    final stageUps = <String, int>{};
    var running = 0;
    var lastStage = 0;
    for (final f in facts) {
      total += pointsFor(f);
      running = total;
      final st = stageFor(running).index;
      if (st > lastStage) {
        stageUps[dayKey(f.day)] = st;
        lastStage = st;
      }
    }
    final stage = stageFor(total);
    PlantStage? next;
    for (final s in kPlantStages) {
      if (s.index == stage.index + 1) next = s;
    }
    final toNext = next == null
        ? 1.0
        : ((total - stage.minPoints) / (next.minPoints - stage.minPoints))
            .clamp(0.0, 1.0)
            .toDouble();

    // Thirsty: three full days (today excluded if still empty) with nothing.
    var quiet = 0;
    for (var i = facts.length - 1; i >= 0; i--) {
      if (facts[i].active) break;
      quiet++;
    }
    final thirsty = facts.isNotEmpty && quiet >= 3;

    final week = facts.length <= 7 ? facts : facts.sublist(facts.length - 7);
    final activeDays = week.where((f) => f.active).length;

    double avg(double Function(DayFacts) pick) =>
        week.isEmpty ? 0 : week.map(pick).reduce((a, b) => a + b) / week.length;

    // Reaching out on three days of the week fills this axis.
    final connectDays = week.where((f) => f.contacted).length;
    final connectValue = (connectDays / 3.0).clamp(0.0, 1.0).toDouble();

    final wheel = <WheelAxis>[
      WheelAxis('habits', 'Habits', avg((f) => f.habitsFrac)),
      WheelAxis('priorities', 'Priorities', avg((f) => f.tasksFrac)),
      WheelAxis('mind', 'Mind', avg((f) => f.mindFrac)),
      WheelAxis('body', 'Body', avg((f) => f.bodyFrac)),
      WheelAxis('connect', 'Connect', connectValue),
      WheelAxis('money', 'Money', moneyScore ?? 0, tracked: moneyScore != null),
    ];

    final recent = facts.length <= 30 ? facts : facts.sublist(facts.length - 30);
    final daily = <double>[for (final f in recent) scoreFor(f)];
    final smooth = <double>[];
    for (var i = 0; i < daily.length; i++) {
      final from = i - 6 < 0 ? 0 : i - 6;
      var sum = 0.0;
      for (var j = from; j <= i; j++) {
        sum += daily[j];
      }
      smooth.add(sum / (i - from + 1));
    }

    return GrowthSnapshot(
      points: total,
      stage: stage,
      next: next,
      toNext: toNext,
      thirsty: thirsty,
      activeDaysThisWeek: activeDays,
      wheel: wheel,
      daily: daily,
      dailyDays: [for (final f in recent) f.day],
      smooth: smooth,
      stageUps: stageUps,
    );
  }

  /// Reads the app's real data into [DayFacts], oldest first, ending today.
  /// Starts at the first day with any data so new users are not penalised.
  static List<DayFacts> factsFromApp({DateTime? now}) {
    final today = now ?? DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final state = store.state;

    // Find the earliest day with any recorded activity.
    DateTime? first;
    void consider(String key) {
      final d = DateTime.tryParse(key);
      if (d == null) return;
      final day = DateTime(d.year, d.month, d.day);
      if (day.isAfter(end)) return;
      if (first == null || day.isBefore(first!)) first = day;
    }

    for (final h in state.habits) {
      h.completedDays.forEach(consider);
    }
    state.tasksByDay.forEach((k, v) {
      if (v.any((t) => t.done)) consider(k);
    });
    state.moodByDay.keys.forEach(consider);
    state.journalByDay.forEach((k, v) {
      if (!v.isEmpty) consider(k);
    });
    for (final e in state.nutritionEntries) {
      consider(dayKey(e.date));
    }
    extras.contactDays.forEach(consider);
    extras.water.forEach((k, v) {
      if (v > 0) consider(k);
    });

    final limit = end.subtract(const Duration(days: lookbackDays));
    var start = first ?? end;
    if (start.isBefore(limit)) start = limit;
    // Always show at least a week so the curve and wheel have shape.
    final weekAgo = end.subtract(const Duration(days: 6));
    if (start.isAfter(weekAgo)) start = weekAgo;

    final out = <DayFacts>[];
    final nutritionDays = <String, int>{};
    for (final e in state.nutritionEntries) {
      final k = dayKey(e.date);
      nutritionDays[k] = (nutritionDays[k] ?? 0) + 1;
    }
    for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      final key = dayKey(d);
      final tasks = state.tasksByDay[key] ?? const <Task>[];
      final journal = state.journalByDay[key];
      final mindActions = (state.doseByDay[key]?.length ?? 0) +
          (state.stressBucketFills[key]?.length ?? 0) +
          (state.stressBucketEmpties[key]?.length ?? 0) +
          (extras.meditationMinutesOn(d) > 0 ? 1 : 0) +
          (extras.focusMinutesOn(d) > 0 ? 1 : 0);
      out.add(DayFacts(
        day: d,
        habitsDone: state.habits.where((h) => h.isDoneOn(d)).length,
        habitsTotal: state.habits.length,
        tasksDone: tasks.where((t) => t.done).length,
        tasksTotal: tasks.length,
        moodLogged: state.moodByDay.containsKey(key),
        journaled: journal != null && !journal.isEmpty,
        mindActions: mindActions,
        mealsLogged: nutritionDays[key] ?? 0,
        waterLogged: (extras.water[key] ?? 0) > 0,
        contacted: extras.contactedOn(d),
      ));
    }
    return out;
  }

  /// 0..1: how well this month's spending is tracking against the budget, or
  /// null when no budget has been set.
  static double? moneyScore() {
    final income = store.financeBudgetIncome;
    if (income == null) return null;
    final budget =
        income * (store.financeBudgetNeedsPct + store.financeBudgetWantsPct) / 100;
    if (budget <= 0) return null;
    final spent = store.spentThisMonth;
    if (spent <= budget) return 1.0;
    return (budget / spent).clamp(0.0, 1.0).toDouble();
  }

  static GrowthSnapshot current() =>
      build(factsFromApp(), moneyScore: moneyScore());
}
