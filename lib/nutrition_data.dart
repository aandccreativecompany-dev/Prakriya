import '../services/extras.dart';
import '../store.dart';

/// Nutrient keys, in the order every [Food.per100g] list is written.
const List<String> kNutrientKeys = [
  'kcal',
  'protein',
  'carbs',
  'fat',
  'fiber',
  'iron',
  'calcium',
  'magnesium',
  'zinc',
  'potassium',
  'sodium',
  'vitC',
  'vitA',
  'b12',
  'vitD',
  'folate',
];

const List<String> kMacroKeys = ['protein', 'carbs', 'fat', 'fiber'];

const List<String> kMicroKeys = [
  'iron',
  'calcium',
  'magnesium',
  'zinc',
  'potassium',
  'sodium',
  'vitC',
  'vitA',
  'b12',
  'vitD',
  'folate',
];

const Map<String, String> kNutrientLabels = {
  'kcal': 'Calories',
  'protein': 'Protein',
  'carbs': 'Carbohydrates',
  'fat': 'Fat',
  'fiber': 'Fibre',
  'iron': 'Iron',
  'calcium': 'Calcium',
  'magnesium': 'Magnesium',
  'zinc': 'Zinc',
  'potassium': 'Potassium',
  'sodium': 'Sodium (limit)',
  'vitC': 'Vitamin C',
  'vitA': 'Vitamin A',
  'b12': 'Vitamin B12',
  'vitD': 'Vitamin D',
  'folate': 'Folate',
};

const Map<String, String> kNutrientUnits = {
  'kcal': 'kcal',
  'protein': 'g',
  'carbs': 'g',
  'fat': 'g',
  'fiber': 'g',
  'iron': 'mg',
  'calcium': 'mg',
  'magnesium': 'mg',
  'zinc': 'mg',
  'potassium': 'mg',
  'sodium': 'mg',
  'vitC': 'mg',
  'vitA': 'mcg',
  'b12': 'mcg',
  'vitD': 'mcg',
  'folate': 'mcg',
};

/// Daily reference amounts, aimed at adults. Iron, calcium, vitamin A, C, D,
/// folate and protein follow the ICMR-NIN 2020 RDAs for Indians (iron 19 mg
/// men / 29 mg women, calcium 1000 mg, vitamin C 80/65 mg, vitamin A
/// 1000/840 mcg, vitamin D 15 mcg (600 IU), folate 300/220 mcg, protein
/// about 54/46 g). Magnesium, zinc, potassium and B12 are the commonly used
/// adult values. Sodium is an upper limit (WHO: under 2000 mg). Macros other
/// than protein are derived from the calorie goal.
double dailyTarget(String key, {required bool female, required int kcalGoal}) {
  switch (key) {
    case 'kcal':
      return kcalGoal.toDouble();
    case 'protein':
      return female ? 46 : 54;
    case 'carbs':
      return kcalGoal * 0.55 / 4;
    case 'fat':
      return kcalGoal * 0.30 / 9;
    case 'fiber':
      return 30;
    case 'iron':
      return female ? 29 : 19;
    case 'calcium':
      return 1000;
    case 'magnesium':
      return female ? 370 : 440;
    case 'zinc':
      return female ? 13.2 : 17;
    case 'potassium':
      return 3500;
    case 'sodium':
      return 2000;
    case 'vitC':
      return female ? 65 : 80;
    case 'vitA':
      return female ? 840 : 1000;
    case 'b12':
      return 2.2;
    case 'vitD':
      return 15;
    case 'folate':
      return female ? 220 : 300;
  }
  return 1;
}

class Food {
  final String name;
  final double serveGrams;
  final String serveLabel;

  /// Values per 100 g, in [kNutrientKeys] order.
  final List<double> per100g;
  const Food(this.name, this.serveGrams, this.serveLabel, this.per100g);

  Map<String, double> nutrientsFor(double grams) {
    final factor = grams / 100.0;
    return <String, double>{
      for (var i = 0; i < kNutrientKeys.length; i++)
        kNutrientKeys[i]: per100g[i] * factor,
    };
  }
}

Map<String, double> emptyTotals() =>
    <String, double>{for (final k in kNutrientKeys) k: 0.0};

/// Sum of every nutrient logged on [day] (entries added through the nutrient
/// tracker carry values; older quick-add entries count as zero).
Map<String, double> dayNutrientTotals(DateTime day) {
  final totals = emptyTotals();
  for (final entry in store.nutritionEntriesFor(day)) {
    final values = extras.entryNutrients[entry.id];
    if (values == null) continue;
    values.forEach((key, value) {
      if (totals.containsKey(key)) totals[key] = totals[key]! + value;
    });
  }
  return totals;
}

String formatAmount(double value) {
  if (value >= 10) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

/// Approximate averages per 100 g of the food as usually eaten (cooked where
/// that is how it is eaten), rounded from USDA FoodData Central and the
/// Indian Food Composition Tables. Real values vary by recipe and brand, so
/// treat them as good estimates, not lab results.
const List<Food> kFoods = [
  Food('Cooked white rice', 150, '1 katori', [130.0, 2.7, 28.0, 0.3, 0.4, 0.4, 10.0, 12.0, 0.5, 35.0, 1.0, 0.0, 0.0, 0.0, 0.0, 3.0]),
  Food('Cooked brown rice', 150, '1 katori', [112.0, 2.3, 23.5, 0.8, 1.8, 0.5, 10.0, 43.0, 0.6, 79.0, 5.0, 0.0, 0.0, 0.0, 0.0, 4.0]),
  Food('Chapati / roti', 40, '1 roti', [297.0, 9.6, 50.0, 5.0, 5.0, 3.2, 40.0, 90.0, 2.0, 250.0, 400.0, 0.0, 0.0, 0.0, 0.0, 30.0]),
  Food('Paratha (plain)', 80, '1 paratha', [326.0, 7.5, 45.0, 13.0, 3.5, 2.6, 30.0, 55.0, 1.2, 160.0, 380.0, 0.0, 0.0, 0.0, 0.0, 25.0]),
  Food('Puri', 30, '1 puri', [350.0, 7.0, 42.0, 17.0, 2.5, 2.0, 25.0, 40.0, 1.0, 130.0, 250.0, 0.0, 0.0, 0.0, 0.0, 20.0]),
  Food('Plain dosa', 80, '1 dosa', [168.0, 3.9, 29.0, 3.7, 1.2, 1.4, 20.0, 30.0, 0.7, 100.0, 150.0, 0.0, 0.0, 0.0, 0.0, 10.0]),
  Food('Idli', 40, '1 idli', [130.0, 4.5, 27.0, 0.4, 1.0, 0.8, 15.0, 20.0, 0.6, 80.0, 200.0, 0.0, 0.0, 0.0, 0.0, 10.0]),
  Food('Upma', 200, '1 bowl', [130.0, 3.0, 20.0, 4.2, 1.5, 0.8, 15.0, 20.0, 0.5, 90.0, 250.0, 1.0, 15.0, 0.0, 0.0, 12.0]),
  Food('Poha', 150, '1 plate', [130.0, 2.5, 25.0, 2.5, 1.0, 1.5, 10.0, 25.0, 0.5, 80.0, 200.0, 2.0, 20.0, 0.0, 0.0, 10.0]),
  Food('Khichdi', 250, '1 bowl', [110.0, 4.0, 19.0, 2.0, 1.5, 1.0, 20.0, 25.0, 0.8, 130.0, 200.0, 0.5, 5.0, 0.0, 0.0, 20.0]),
  Food('Biryani (chicken)', 250, '1 plate', [150.0, 7.0, 20.0, 5.0, 1.0, 1.0, 20.0, 25.0, 1.2, 150.0, 380.0, 1.0, 20.0, 0.3, 0.2, 10.0]),
  Food('Veg pulao', 200, '1 bowl', [140.0, 3.0, 23.0, 4.0, 1.5, 0.8, 20.0, 25.0, 0.6, 120.0, 300.0, 2.0, 40.0, 0.0, 0.0, 15.0]),
  Food('Ragi mudde / porridge', 200, '1 serving', [100.0, 2.5, 21.0, 0.4, 2.0, 1.2, 100.0, 40.0, 0.6, 150.0, 5.0, 0.0, 0.0, 0.0, 0.0, 10.0]),
  Food('Oats (cooked)', 200, '1 bowl', [71.0, 2.5, 12.0, 1.5, 1.7, 0.9, 9.0, 26.0, 0.9, 70.0, 4.0, 0.0, 0.0, 0.0, 0.0, 6.0]),
  Food('Quinoa (cooked)', 150, '1 katori', [120.0, 4.4, 21.0, 1.9, 2.8, 1.5, 17.0, 64.0, 1.1, 172.0, 7.0, 0.0, 0.0, 0.0, 0.0, 42.0]),
  Food('Pasta (cooked)', 150, '1 plate', [158.0, 5.8, 31.0, 0.9, 1.8, 1.3, 7.0, 18.0, 0.5, 44.0, 1.0, 0.0, 0.0, 0.0, 0.0, 7.0]),
  Food('White bread', 30, '1 slice', [265.0, 9.0, 49.0, 3.2, 2.7, 3.6, 260.0, 25.0, 0.9, 115.0, 491.0, 0.0, 0.0, 0.0, 0.0, 111.0]),
  Food('Whole wheat bread', 35, '1 slice', [250.0, 12.5, 43.0, 3.5, 6.0, 2.4, 160.0, 75.0, 1.8, 250.0, 450.0, 0.0, 0.0, 0.0, 0.0, 50.0]),
  Food('Dal (toor, cooked)', 150, '1 katori', [100.0, 6.0, 14.0, 2.5, 3.5, 1.8, 30.0, 35.0, 0.9, 250.0, 150.0, 1.0, 5.0, 0.0, 0.0, 80.0]),
  Food('Moong dal (cooked)', 150, '1 katori', [105.0, 7.0, 19.0, 0.4, 7.6, 1.4, 27.0, 48.0, 0.8, 266.0, 2.0, 1.0, 2.0, 0.0, 0.0, 159.0]),
  Food('Rajma (cooked)', 150, '1 katori', [127.0, 8.7, 22.8, 0.5, 6.4, 2.9, 28.0, 45.0, 1.0, 403.0, 2.0, 1.2, 0.0, 0.0, 0.0, 130.0]),
  Food('Chole / chickpeas (cooked)', 150, '1 katori', [164.0, 8.9, 27.4, 2.6, 7.6, 2.9, 49.0, 48.0, 1.5, 291.0, 7.0, 1.3, 1.0, 0.0, 0.0, 172.0]),
  Food('Sambar', 200, '1 bowl', [60.0, 3.0, 8.5, 1.8, 2.0, 1.2, 30.0, 25.0, 0.5, 220.0, 250.0, 4.0, 30.0, 0.0, 0.0, 40.0]),
  Food('Rasam', 200, '1 bowl', [30.0, 1.0, 5.0, 0.7, 0.6, 0.5, 15.0, 10.0, 0.2, 120.0, 250.0, 3.0, 10.0, 0.0, 0.0, 10.0]),
  Food('Mixed vegetable curry', 150, '1 katori', [70.0, 2.0, 8.0, 3.5, 2.5, 0.8, 30.0, 20.0, 0.4, 200.0, 250.0, 8.0, 150.0, 0.0, 0.0, 25.0]),
  Food('Palak (spinach, cooked)', 150, '1 katori', [23.0, 3.0, 3.8, 0.3, 2.4, 3.6, 136.0, 87.0, 0.8, 466.0, 70.0, 9.8, 469.0, 0.0, 0.0, 146.0]),
  Food('Bhindi (okra, cooked)', 100, '1 serving', [22.0, 1.9, 4.5, 0.2, 2.5, 0.4, 77.0, 57.0, 0.6, 135.0, 6.0, 16.3, 20.0, 0.0, 0.0, 46.0]),
  Food('Cauliflower (cooked)', 100, '1 serving', [23.0, 1.8, 4.1, 0.5, 2.3, 0.4, 16.0, 9.0, 0.2, 142.0, 15.0, 44.3, 0.0, 0.0, 0.0, 44.0]),
  Food('Broccoli (cooked)', 100, '1 cup', [35.0, 2.4, 7.2, 0.4, 3.3, 0.7, 40.0, 21.0, 0.45, 293.0, 41.0, 64.9, 77.0, 0.0, 0.0, 108.0]),
  Food('Brinjal (cooked)', 100, '1 serving', [35.0, 0.8, 8.7, 0.2, 2.5, 0.25, 6.0, 11.0, 0.12, 123.0, 1.0, 1.3, 1.0, 0.0, 0.0, 14.0]),
  Food('Green peas (cooked)', 80, '1/2 cup', [84.0, 5.4, 15.6, 0.2, 5.5, 1.5, 27.0, 39.0, 1.2, 271.0, 3.0, 14.2, 38.0, 0.0, 0.0, 65.0]),
  Food('Sweet corn (cooked)', 100, '1 cob', [96.0, 3.4, 21.0, 1.5, 2.4, 0.5, 2.0, 26.0, 0.6, 218.0, 1.0, 5.5, 9.0, 0.0, 0.0, 46.0]),
  Food('Potato (boiled)', 150, '1 medium', [87.0, 1.9, 20.0, 0.1, 1.8, 0.3, 5.0, 22.0, 0.3, 379.0, 4.0, 13.0, 0.0, 0.0, 0.0, 9.0]),
  Food('Sweet potato (boiled)', 150, '1 medium', [76.0, 1.4, 17.7, 0.1, 2.5, 0.7, 27.0, 20.0, 0.3, 230.0, 27.0, 12.8, 788.0, 0.0, 0.0, 6.0]),
  Food('Carrot', 80, '1 medium', [41.0, 0.9, 9.6, 0.2, 2.8, 0.3, 33.0, 12.0, 0.24, 320.0, 69.0, 5.9, 835.0, 0.0, 0.0, 19.0]),
  Food('Beetroot (boiled)', 100, '1 small', [44.0, 1.7, 10.0, 0.2, 2.0, 0.8, 16.0, 23.0, 0.35, 305.0, 77.0, 3.6, 2.0, 0.0, 0.0, 80.0]),
  Food('Tomato', 100, '1 medium', [18.0, 0.9, 3.9, 0.2, 1.2, 0.27, 10.0, 11.0, 0.17, 237.0, 5.0, 13.7, 42.0, 0.0, 0.0, 15.0]),
  Food('Cucumber', 100, '1 cup', [15.0, 0.7, 3.6, 0.1, 0.5, 0.28, 16.0, 13.0, 0.2, 147.0, 2.0, 2.8, 5.0, 0.0, 0.0, 7.0]),
  Food('Onion', 50, '1 small', [40.0, 1.1, 9.3, 0.1, 1.7, 0.2, 23.0, 10.0, 0.17, 146.0, 4.0, 7.4, 0.0, 0.0, 0.0, 19.0]),
  Food('Banana', 120, '1 medium', [89.0, 1.1, 22.8, 0.3, 2.6, 0.3, 5.0, 27.0, 0.15, 358.0, 1.0, 8.7, 3.0, 0.0, 0.0, 20.0]),
  Food('Apple', 150, '1 medium', [52.0, 0.3, 13.8, 0.2, 2.4, 0.1, 6.0, 5.0, 0.04, 107.0, 1.0, 4.6, 3.0, 0.0, 0.0, 3.0]),
  Food('Orange', 130, '1 medium', [47.0, 0.9, 11.8, 0.1, 2.4, 0.1, 40.0, 10.0, 0.07, 181.0, 0.0, 53.2, 11.0, 0.0, 0.0, 30.0]),
  Food('Mango', 150, '1 cup', [60.0, 0.8, 15.0, 0.4, 1.6, 0.16, 11.0, 10.0, 0.09, 168.0, 1.0, 36.4, 54.0, 0.0, 0.0, 43.0]),
  Food('Papaya', 150, '1 bowl', [43.0, 0.5, 11.0, 0.3, 1.7, 0.25, 20.0, 21.0, 0.08, 182.0, 8.0, 60.9, 47.0, 0.0, 0.0, 37.0]),
  Food('Guava', 100, '1 medium', [68.0, 2.6, 14.3, 1.0, 5.4, 0.26, 18.0, 22.0, 0.23, 417.0, 2.0, 228.0, 31.0, 0.0, 0.0, 49.0]),
  Food('Grapes', 100, '1 cup', [69.0, 0.7, 18.0, 0.2, 0.9, 0.36, 10.0, 7.0, 0.07, 191.0, 2.0, 3.2, 3.0, 0.0, 0.0, 2.0]),
  Food('Pomegranate', 100, '1/2 cup', [83.0, 1.7, 18.7, 1.2, 4.0, 0.3, 10.0, 12.0, 0.35, 236.0, 3.0, 10.2, 0.0, 0.0, 0.0, 38.0]),
  Food('Watermelon', 200, '1 wedge', [30.0, 0.6, 7.6, 0.2, 0.4, 0.24, 7.0, 10.0, 0.1, 112.0, 1.0, 8.1, 28.0, 0.0, 0.0, 3.0]),
  Food('Milk (whole)', 200, '1 glass', [61.0, 3.2, 4.8, 3.3, 0.0, 0.0, 113.0, 10.0, 0.4, 132.0, 43.0, 0.0, 46.0, 0.45, 0.1, 5.0]),
  Food('Curd / yogurt', 150, '1 katori', [61.0, 3.5, 4.7, 3.3, 0.0, 0.1, 121.0, 12.0, 0.6, 155.0, 46.0, 0.5, 27.0, 0.37, 0.1, 7.0]),
  Food('Buttermilk (chaas)', 200, '1 glass', [40.0, 3.3, 4.8, 0.9, 0.0, 0.05, 116.0, 11.0, 0.4, 151.0, 105.0, 0.9, 10.0, 0.2, 0.1, 5.0]),
  Food('Paneer', 50, '2 cubes', [265.0, 18.0, 1.2, 21.0, 0.0, 0.2, 208.0, 8.0, 1.5, 100.0, 30.0, 0.0, 150.0, 0.8, 0.3, 20.0]),
  Food('Egg (boiled)', 50, '1 egg', [155.0, 12.6, 1.1, 10.6, 0.0, 1.2, 50.0, 10.0, 1.1, 126.0, 124.0, 0.0, 160.0, 1.1, 2.2, 44.0]),
  Food('Chicken breast (cooked)', 100, '1 piece', [165.0, 31.0, 0.0, 3.6, 0.0, 1.0, 15.0, 29.0, 1.0, 256.0, 74.0, 0.0, 6.0, 0.3, 0.1, 4.0]),
  Food('Chicken curry', 150, '1 katori', [130.0, 12.0, 4.0, 7.5, 0.8, 1.0, 20.0, 22.0, 1.2, 200.0, 330.0, 2.0, 30.0, 0.3, 0.1, 8.0]),
  Food('Fish (cooked, average)', 100, '1 piece', [140.0, 24.0, 0.0, 4.5, 0.0, 0.5, 30.0, 30.0, 0.6, 350.0, 80.0, 0.0, 20.0, 2.5, 5.0, 10.0]),
  Food('Mutton (cooked)', 100, '1 serving', [258.0, 25.0, 0.0, 17.0, 0.0, 1.9, 17.0, 23.0, 4.5, 310.0, 72.0, 0.0, 0.0, 2.6, 0.1, 8.0]),
  Food('Tofu', 100, '1 serving', [76.0, 8.1, 1.9, 4.8, 0.3, 5.4, 350.0, 30.0, 0.8, 121.0, 7.0, 0.1, 0.0, 0.0, 0.0, 15.0]),
  Food('Soya chunks (cooked)', 100, '1 serving', [120.0, 14.0, 8.0, 0.5, 4.0, 3.0, 100.0, 100.0, 1.5, 350.0, 10.0, 0.0, 0.0, 0.0, 0.0, 100.0]),
  Food('Almonds', 20, '10 almonds', [579.0, 21.2, 21.6, 49.9, 12.5, 3.7, 269.0, 270.0, 3.1, 733.0, 1.0, 0.0, 0.0, 0.0, 0.0, 44.0]),
  Food('Peanuts (roasted)', 30, '1 handful', [585.0, 23.7, 21.5, 49.7, 8.0, 1.3, 54.0, 176.0, 3.3, 658.0, 6.0, 0.0, 0.0, 0.0, 0.0, 145.0]),
  Food('Walnuts', 20, '4 halves', [654.0, 15.2, 13.7, 65.2, 6.7, 2.9, 98.0, 158.0, 3.1, 441.0, 2.0, 1.3, 1.0, 0.0, 0.0, 98.0]),
  Food('Cashews', 20, '10 cashews', [553.0, 18.2, 30.2, 43.9, 3.3, 6.7, 37.0, 292.0, 5.8, 660.0, 12.0, 0.5, 0.0, 0.0, 0.0, 25.0]),
  Food('Ghee', 5, '1 tsp', [900.0, 0.0, 0.0, 100.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 700.0, 0.0, 0.0, 0.0]),
  Food('Butter', 10, '1 tsp', [717.0, 0.9, 0.1, 81.0, 0.0, 0.0, 24.0, 2.0, 0.1, 24.0, 11.0, 0.0, 684.0, 0.17, 1.5, 3.0]),
  Food('Cooking oil', 5, '1 tsp', [884.0, 0.0, 0.0, 100.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
  Food('Sugar', 5, '1 tsp', [387.0, 0.0, 100.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
  Food('Jaggery', 10, '1 piece', [383.0, 0.4, 98.0, 0.1, 0.0, 11.0, 80.0, 70.0, 0.4, 1000.0, 30.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
  Food('Honey', 20, '1 tbsp', [304.0, 0.3, 82.4, 0.0, 0.2, 0.42, 6.0, 2.0, 0.22, 52.0, 4.0, 0.5, 0.0, 0.0, 0.0, 2.0]),
  Food('Tea with milk and sugar', 150, '1 cup', [45.0, 1.2, 7.0, 1.5, 0.0, 0.0, 35.0, 4.0, 0.2, 60.0, 15.0, 0.0, 15.0, 0.1, 0.0, 2.0]),
  Food('Coffee with milk and sugar', 150, '1 cup', [45.0, 1.3, 6.5, 1.6, 0.0, 0.0, 35.0, 5.0, 0.2, 70.0, 15.0, 0.0, 15.0, 0.1, 0.0, 2.0]),
  Food('Black coffee / tea', 200, '1 cup', [2.0, 0.1, 0.0, 0.0, 0.0, 0.0, 2.0, 3.0, 0.0, 49.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
  Food('Coconut water', 250, '1 glass', [19.0, 0.7, 3.7, 0.2, 1.1, 0.29, 24.0, 25.0, 0.1, 250.0, 105.0, 2.4, 0.0, 0.0, 0.0, 3.0]),
  Food('Orange juice', 200, '1 glass', [45.0, 0.7, 10.4, 0.2, 0.2, 0.2, 11.0, 11.0, 0.05, 200.0, 1.0, 50.0, 10.0, 0.0, 0.0, 30.0]),
  Food('Samosa', 60, '1 samosa', [262.0, 3.5, 25.0, 17.0, 2.5, 1.2, 20.0, 20.0, 0.6, 250.0, 400.0, 1.0, 5.0, 0.0, 0.0, 15.0]),
  Food('Pizza (cheese)', 110, '1 slice', [266.0, 11.0, 33.0, 10.0, 2.3, 2.5, 188.0, 24.0, 1.5, 172.0, 598.0, 1.4, 55.0, 0.4, 0.5, 70.0]),
  Food('Potato chips', 30, '1 small packet', [536.0, 7.0, 53.0, 35.0, 4.8, 1.3, 24.0, 70.0, 1.0, 1200.0, 525.0, 0.0, 0.0, 0.0, 0.0, 20.0]),
  Food('Biscuits (plain)', 30, '3 biscuits', [450.0, 7.0, 76.0, 12.0, 2.0, 2.0, 30.0, 20.0, 0.6, 100.0, 400.0, 0.0, 0.0, 0.0, 0.0, 20.0]),
  Food('Dark chocolate', 20, '2 squares', [546.0, 4.9, 61.0, 31.0, 7.0, 8.0, 56.0, 146.0, 2.0, 559.0, 20.0, 0.0, 0.0, 0.0, 0.0, 5.0]),
  Food('Ice cream', 70, '1 scoop', [207.0, 3.5, 24.0, 11.0, 0.7, 0.1, 128.0, 14.0, 0.8, 199.0, 80.0, 0.6, 118.0, 0.4, 0.2, 5.0]),
];
