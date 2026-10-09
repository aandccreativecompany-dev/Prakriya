import 'package:flutter/material.dart';

import '../models.dart';
import '../nutrition_data.dart';
import '../services/extras.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

String _defaultMeal() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'breakfast';
  if (hour < 16) return 'lunch';
  if (hour < 19) return 'snack';
  return 'dinner';
}

String _trimNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

/// Logs a meal entry and attaches its nutrient values.
Future<void> logFoodWithNutrients({
  required String meal,
  required String name,
  required Map<String, double> nutrients,
}) async {
  final clean = name.trim();
  if (clean.isEmpty) return;
  await store.addNutritionEntry(meal, clean);
  final entries = store.nutritionEntries;
  if (entries.isNotEmpty && entries.first.name == clean) {
    extras.setEntryNutrients(entries.first.id, nutrients);
  }
}

class NutritionTrackerScreen extends StatefulWidget {
  const NutritionTrackerScreen({super.key});

  @override
  State<NutritionTrackerScreen> createState() => _NutritionTrackerScreenState();
}

class _NutritionTrackerScreenState extends State<NutritionTrackerScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Food> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kFoods.take(12).toList();
    return kFoods.where((f) => f.name.toLowerCase().contains(q)).take(25).toList();
  }

  Future<void> _showSettings() async {
    final goalController = TextEditingController(text: '${extras.calorieGoal}');
    var female = extras.female;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialog) {
          return AlertDialog(
            title: const Text('Your daily targets'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: goalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Calorie goal (kcal per day)'),
                ),
                const SizedBox(height: 16),
                const Text('Reference values for vitamins and minerals'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Adult man'),
                      selected: !female,
                      onSelected: (_) => setDialog(() => female = false),
                    ),
                    ChoiceChip(
                      label: const Text('Adult woman'),
                      selected: female,
                      onSelected: (_) => setDialog(() => female = true),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final goal = int.tryParse(goalController.text.trim());
                  extras.setNutritionProfile(goal: goal, isFemale: female);
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _showAddFood(Food food) async {
    final gramsController = TextEditingController(text: _trimNumber(food.serveGrams));
    var meal = _defaultMeal();
    var added = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final dark = Theme.of(ctx).brightness == Brightness.dark;
          final grams = double.tryParse(gramsController.text.trim()) ?? 0.0;
          final n = food.nutrientsFor(grams);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name,
                    style: body(17, Surfaces.heading(dark), weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('1 serving = ${food.serveLabel} (about ${_trimNumber(food.serveGrams)} g)',
                    style: body(12, Surfaces.muted(dark))),
                const SizedBox(height: 14),
                TextField(
                  controller: gramsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setSheet(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Amount eaten', suffixText: 'grams'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in const [0.5, 1.0, 1.5, 2.0])
                      ActionChip(
                        label: Text('${_trimNumber(m)} serving'),
                        onPressed: () {
                          gramsController.text = _trimNumber(food.serveGrams * m);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in kMealTypes)
                      ChoiceChip(
                        label: Text(kMealTypeLabels[m] ?? m),
                        selected: meal == m,
                        onSelected: (_) => setSheet(() => meal = m),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                    '${n['kcal']!.round()} kcal  ·  Protein ${formatAmount(n['protein']!)} g  ·  Carbs ${formatAmount(n['carbs']!)} g  ·  Fat ${formatAmount(n['fat']!)} g  ·  Fibre ${formatAmount(n['fiber']!)} g',
                    style: body(12.5, Surfaces.accentText(dark), weight: FontWeight.w600)),
                const SizedBox(height: 16),
                GoldButton(
                  labelText: 'Add to ${kMealTypeLabels[meal] ?? meal}',
                  onPressed: () async {
                    if (grams <= 0 || grams > 5000) return;
                    await logFoodWithNutrients(
                      meal: meal,
                      name: '${food.name} (${_trimNumber(grams)} g)',
                      nutrients: n,
                    );
                    added = true;
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          );
        });
      },
    );
    if (added && mounted) toastSaved(context, label: 'Added');
  }

  Future<void> _showCustomFood() async {
    final name = TextEditingController();
    final kcal = TextEditingController();
    final protein = TextEditingController();
    final carbs = TextEditingController();
    final fat = TextEditingController();
    final fibre = TextEditingController();
    var meal = _defaultMeal();
    var added = false;

    Widget numberField(TextEditingController c, String labelText) => Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: labelText),
            ),
          ),
        );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final dark = Theme.of(ctx).brightness == Brightness.dark;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Custom food',
                    style: body(17, Surfaces.heading(dark), weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Enter the values for the amount you ate (check the pack label).',
                    style: body(12, Surfaces.muted(dark))),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Food name'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  numberField(kcal, 'kcal'),
                  numberField(protein, 'Protein g'),
                  numberField(carbs, 'Carbs g'),
                ]),
                Row(children: [
                  numberField(fat, 'Fat g'),
                  numberField(fibre, 'Fibre g'),
                  const Expanded(child: SizedBox.shrink()),
                ]),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in kMealTypes)
                      ChoiceChip(
                        label: Text(kMealTypeLabels[m] ?? m),
                        selected: meal == m,
                        onSelected: (_) => setSheet(() => meal = m),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                GoldButton(
                  labelText: 'Add',
                  onPressed: () async {
                    final title = name.text.trim();
                    final energy = double.tryParse(kcal.text.trim()) ?? 0.0;
                    if (title.isEmpty || energy <= 0) return;
                    final values = emptyTotals();
                    values['kcal'] = energy;
                    values['protein'] = double.tryParse(protein.text.trim()) ?? 0.0;
                    values['carbs'] = double.tryParse(carbs.text.trim()) ?? 0.0;
                    values['fat'] = double.tryParse(fat.text.trim()) ?? 0.0;
                    values['fiber'] = double.tryParse(fibre.text.trim()) ?? 0.0;
                    await logFoodWithNutrients(
                        meal: meal, name: title, nutrients: values);
                    added = true;
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          );
        });
      },
    );
    if (added && mounted) toastSaved(context, label: 'Added');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[store, extras]),
            builder: (context, _) {
              final totals = dayNutrientTotals(DateTime.now());
              final goal = extras.calorieGoal;
              final female = extras.female;
              final todays = store.todaysNutritionEntries;
              final untracked = todays
                  .where((e) => !extras.entryNutrients.containsKey(e.id))
                  .length;
              return Column(
                children: [
                  ScreenHeader(
                    icon: Icons.restaurant_menu,
                    title: 'Nutrient tracker',
                    subtitle: 'Calories, macros, vitamins and minerals for today.',
                    actions: [
                      IconButton(
                        onPressed: _showSettings,
                        icon: Icon(Icons.tune, color: Surfaces.accent(dark)),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        _SummaryCard(totals: totals, goal: goal, female: female, dark: dark),
                        const SizedBox(height: 14),
                        ModuleCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('VITAMINS AND MINERALS',
                                  style: label(Surfaces.muted(dark))),
                              const SizedBox(height: 10),
                              for (final key in kMicroKeys)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _NutrientBar(
                                    nutrientKey: key,
                                    value: totals[key] ?? 0.0,
                                    target: dailyTarget(key, female: female, kcalGoal: goal),
                                    dark: dark,
                                  ),
                                ),
                              Text(
                                  'Targets: ICMR-NIN 2020 reference values for ${female ? 'an adult woman' : 'an adult man'}. Change this with the sliders icon above.',
                                  style: body(11, Surfaces.muted(dark))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ModuleCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ADD FOOD', style: label(Surfaces.muted(dark))),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _search,
                                onChanged: (v) => setState(() => _query = v),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  hintText: 'Search dal, roti, banana, paneer...',
                                  hintStyle: body(13.5, Surfaces.muted(dark)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_matches.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Text('No match. Use "Add a custom food" below.',
                                      style: body(12.5, Surfaces.muted(dark))),
                                ),
                              for (final food in _matches)
                                InkWell(
                                  onTap: () => _showAddFood(food),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(food.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: body(14, Surfaces.heading(dark),
                                                      weight: FontWeight.w600)),
                                              Text(
                                                  '${food.serveLabel} · ${(food.per100g[0] * food.serveGrams / 100).round()} kcal',
                                                  style: body(11.5, Surfaces.muted(dark))),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.add_circle_outline,
                                            color: Surfaces.accent(dark)),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: _showCustomFood,
                                icon: const Icon(Icons.edit_note),
                                label: const Text('Add a custom food'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ModuleCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TODAY'S LOG", style: label(Surfaces.muted(dark))),
                              const SizedBox(height: 8),
                              if (todays.isEmpty)
                                Text('Nothing logged yet. Search a food above to start.',
                                    style: body(12.5, Surfaces.muted(dark))),
                              for (final e in todays)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(e.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: body(13.5, Surfaces.heading(dark),
                                                    weight: FontWeight.w600)),
                                            Text(
                                                '${kMealTypeLabels[e.mealType] ?? e.mealType}'
                                                '${extras.entryNutrients[e.id] != null ? ' · ${extras.entryNutrients[e.id]!['kcal']?.round() ?? 0} kcal' : ''}',
                                                style: body(11.5, Surfaces.muted(dark))),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          extras.removeEntryNutrients(e.id);
                                          await store.removeNutritionEntry(e);
                                        },
                                        icon: Icon(Icons.close,
                                            size: 18, color: Surfaces.muted(dark)),
                                      ),
                                    ],
                                  ),
                                ),
                              if (untracked > 0) ...[
                                const SizedBox(height: 6),
                                Text(
                                    '$untracked quick-added ${untracked == 1 ? 'entry has' : 'entries have'} no nutrient data, so ${untracked == 1 ? 'it is' : 'they are'} not counted above.',
                                    style: body(11, Surfaces.muted(dark))),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _WeekChart(goal: goal, dark: dark),
                        const SizedBox(height: 14),
                        Text(
                            'Nutrient values are approximate averages per 100 g from USDA FoodData Central and Indian food composition tables, so real amounts vary with recipe and brand. This is for awareness, not medical advice. Talk to a doctor or dietitian for health conditions.',
                            style: body(11, Surfaces.muted(dark))),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, double> totals;
  final int goal;
  final bool female;
  final bool dark;
  const _SummaryCard({
    required this.totals,
    required this.goal,
    required this.female,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final kcal = totals['kcal'] ?? 0.0;
    final ratio = goal <= 0 ? 0.0 : kcal / goal;
    final over = ratio > 1;
    final remaining = (goal - kcal).round();
    return ModuleCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: ratio.clamp(0.0, 1.0).toDouble(),
                        strokeWidth: 10,
                        backgroundColor: Surfaces.accent(dark).withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            over ? Colors.redAccent : Surfaces.accent(dark)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${kcal.round()}',
                            style: body(20, Surfaces.heading(dark),
                                weight: FontWeight.w800)),
                        Text('kcal', style: body(10.5, Surfaces.muted(dark))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily goal $goal kcal',
                        style: body(13.5, Surfaces.heading(dark), weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                        over
                            ? 'Over by ${-remaining} kcal'
                            : '$remaining kcal remaining',
                        style: body(12.5, Surfaces.accentText(dark),
                            weight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final key in kMacroKeys)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NutrientBar(
                nutrientKey: key,
                value: totals[key] ?? 0.0,
                target: dailyTarget(key, female: female, kcalGoal: goal),
                dark: dark,
              ),
            ),
        ],
      ),
    );
  }
}

class _NutrientBar extends StatelessWidget {
  final String nutrientKey;
  final double value;
  final double target;
  final bool dark;
  const _NutrientBar({
    required this.nutrientKey,
    required this.value,
    required this.target,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final unit = kNutrientUnits[nutrientKey] ?? '';
    final isLimit = nutrientKey == 'sodium';
    final ratio = target <= 0 ? 0.0 : value / target;
    final warn = isLimit && ratio > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(kNutrientLabels[nutrientKey] ?? nutrientKey,
                  style: body(12.5, Surfaces.bodyText(dark), weight: FontWeight.w600)),
            ),
            Text('${formatAmount(value)} / ${formatAmount(target)} $unit',
                style: body(11.5, Surfaces.muted(dark))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: Surfaces.accent(dark).withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation<Color>(
                warn ? Colors.redAccent : Surfaces.accent(dark)),
          ),
        ),
      ],
    );
  }
}

class _WeekChart extends StatelessWidget {
  final int goal;
  final bool dark;
  const _WeekChart({required this.goal, required this.dark});

  static const List<String> _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final values = <double>[
      for (final d in days) dayNutrientTotals(d)['kcal'] ?? 0.0,
    ];
    var maxValue = goal.toDouble();
    for (final v in values) {
      if (v > maxValue) maxValue = v;
    }
    return ModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CALORIES, LAST 7 DAYS', style: label(Surfaces.muted(dark))),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Container(
                        height: 4 + 84 * (values[i] / maxValue).clamp(0.0, 1.0).toDouble(),
                        decoration: BoxDecoration(
                          color: values[i] > goal
                              ? Colors.orangeAccent
                              : Surfaces.accent(dark).withValues(
                                  alpha: values[i] == 0 ? 0.25 : 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Center(
                    child: Text(_letters[d.weekday - 1],
                        style: body(10.5, Surfaces.muted(dark))),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
