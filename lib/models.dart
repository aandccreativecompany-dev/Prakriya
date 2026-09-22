// Plain data models. Everything serialises to JSON and lives on the device.

import 'theme.dart' show kAccentPalettes, kFontFamilies, kFontScales;

String dayKey(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

class Task {
  String title;
  bool done;

  Task({required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'title': title, 'done': done};

  static Task fromJson(Map<String, dynamic> json) => Task(
        title: (json['title'] ?? '') as String,
        done: (json['done'] ?? false) as bool,
      );
}

/// Curated icons a habit can carry — index into this list is what's stored.
const List<String> kHabitIconNames = [
  'edit_note', // journaling
  'directions_walk', // movement
  'self_improvement', // meditation
  'water_drop', // hydration
  'menu_book', // reading
  'bedtime', // sleep
  'no_cell', // screen-free
  'restaurant', // eating/nutrition
  'fitness_center', // exercise
  'favorite', // gratitude / wellbeing
  'wb_sunny', // morning routine
  'volunteer_activism', // kindness/giving
];

/// Monotonically increasing so two habits created in the same microsecond
/// still get distinct ids.
int _habitIdSeq = 0;
String _newHabitId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_habitIdSeq++}';

class Habit {
  /// Stable identity, independent of object reference — list keys and
  /// add/remove/edit lookups use this instead of instance equality, so they
  /// keep working correctly across rebuilds and JSON round-trips.
  final String id;
  String name;
  List<String> completedDays;
  int iconIndex;
  int colorIndex;

  Habit({
    String? id,
    required this.name,
    List<String>? completedDays,
    this.iconIndex = 0,
    this.colorIndex = 0,
  })  : id = id ?? _newHabitId(),
        completedDays = completedDays ?? <String>[];

  bool isDoneOn(DateTime date) => completedDays.contains(dayKey(date));

  void toggle(DateTime date) {
    final key = dayKey(date);
    if (completedDays.contains(key)) {
      completedDays.remove(key);
    } else {
      completedDays.add(key);
    }
  }

  /// Consecutive days completed, counting back from today.
  int streak(DateTime today) {
    var count = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    while (completedDays.contains(dayKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  int completionsInLast(int days, DateTime today) {
    var count = 0;
    for (var i = 0; i < days; i++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      if (completedDays.contains(dayKey(day))) count++;
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'completedDays': completedDays,
        'iconIndex': iconIndex,
        'colorIndex': colorIndex,
      };

  static Habit fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String?,
        name: (json['name'] ?? '') as String,
        completedDays: ((json['completedDays'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => e.toString())
            .toList(),
        iconIndex: (json['iconIndex'] ?? 0) as int,
        colorIndex: (json['colorIndex'] ?? 0) as int,
      );
}

class ReminderSetting {
  final String id;
  final String title;
  bool enabled;
  int hour;
  int minute;

  ReminderSetting({
    required this.id,
    required this.title,
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  String get clockLabel {
    final suffix = hour < 12 ? 'AM' : 'PM';
    var h = hour % 12;
    if (h == 0) h = 12;
    return '$h:${minute.toString().padLeft(2, '0')} $suffix';
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'enabled': enabled, 'hour': hour, 'minute': minute};
}

/// One short colorful sticky note pinned onto the organized mind map.
class MindMapStickyNote {
  String id;
  String text;
  int colorIndex;

  MindMapStickyNote({required this.id, required this.text, this.colorIndex = 0});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'colorIndex': colorIndex};

  static MindMapStickyNote? fromJson(Map<String, dynamic> json) {
    final text = json['text'];
    if (text is! String || text.isEmpty) return null;
    final id = json['id'];
    final colorIndex = json['colorIndex'];
    return MindMapStickyNote(
      id: id is String && id.isNotEmpty ? id : '${text.hashCode}',
      text: text,
      colorIndex: colorIndex is int ? colorIndex : 0,
    );
  }
}

/// One customizable spending category header (e.g. "Food") with its own
/// customizable sub-headers (e.g. "Groceries", "Dining out") — per the
/// explicit ask that both levels be user-editable, not a fixed list.
class SpendCategory {
  String id;
  String name;
  List<String> subcategories;

  SpendCategory({required this.id, required this.name, List<String>? subcategories})
      : subcategories = subcategories ?? [];

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'subcategories': subcategories};

  static SpendCategory? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    final id = json['id'];
    final rawSubs = json['subcategories'];
    return SpendCategory(
      id: id is String && id.isNotEmpty ? id : '${name.hashCode}',
      name: name,
      subcategories: rawSubs is List ? rawSubs.map((e) => e.toString()).toList() : [],
    );
  }
}

/// One logged expense — tagged Need or Want per the explicit ask, so the
/// tracker can show not just "where the money went" but "how much of it
/// was actually necessary."
class SpendEntry {
  String id;
  String categoryId;
  String subcategory;
  double amount;
  bool isNeed;
  String note;
  DateTime date;

  SpendEntry({
    required this.id,
    required this.categoryId,
    this.subcategory = '',
    required this.amount,
    required this.isNeed,
    this.note = '',
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'subcategory': subcategory,
        'amount': amount,
        'isNeed': isNeed,
        'note': note,
        'date': date.toIso8601String(),
      };

  static SpendEntry? fromJson(Map<String, dynamic> json) {
    final categoryId = json['categoryId'];
    final amount = json['amount'];
    if (categoryId is! String || categoryId.isEmpty) return null;
    final parsedAmount = amount is num ? amount.toDouble() : double.tryParse('$amount');
    if (parsedAmount == null || parsedAmount <= 0) return null;
    final id = json['id'];
    final rawDate = json['date'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    return SpendEntry(
      id: id is String && id.isNotEmpty
          ? id
          : '${DateTime.now().microsecondsSinceEpoch}',
      categoryId: categoryId,
      subcategory: json['subcategory'] is String ? json['subcategory'] as String : '',
      amount: parsedAmount,
      isNeed: json['isNeed'] == true,
      note: json['note'] is String ? json['note'] as String : '',
      date: parsedDate ?? DateTime.now(),
    );
  }
}

/// One savings/investment contribution, tagged by [kSavingsTypes] — separate
/// from spendEntries (money going out) since this is money being set aside,
/// tracked as a running total per type rather than a single Need/Want split.
class SavingsEntry {
  String id;
  String type;
  double amount;
  String note;
  DateTime date;

  SavingsEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.note = '',
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'amount': amount,
        'note': note,
        'date': date.toIso8601String(),
      };

  static SavingsEntry? fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final amount = json['amount'];
    if (type is! String || type.isEmpty) return null;
    final parsedAmount = amount is num ? amount.toDouble() : double.tryParse('$amount');
    if (parsedAmount == null || parsedAmount <= 0) return null;
    final id = json['id'];
    final rawDate = json['date'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    return SavingsEntry(
      id: id is String && id.isNotEmpty ? id : '${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      amount: parsedAmount,
      note: json['note'] is String ? json['note'] as String : '',
      date: parsedDate ?? DateTime.now(),
    );
  }
}

/// Real-world savings/investment vehicles the wallet lets someone track a
/// running total against — deliberately broader than just "savings account"
/// so it covers the common ways people actually build wealth.
const kSavingsTypes = [
  'emergencyFund',
  'stocks',
  'mutualFunds',
  'gold',
  'fixedDeposit',
  'ppfEpf',
  'realEstate',
  'crypto',
  'other',
];

const kSavingsTypeLabels = {
  'emergencyFund': 'Emergency fund',
  'stocks': 'Stocks',
  'mutualFunds': 'Mutual funds',
  'gold': 'Gold',
  'fixedDeposit': 'Fixed deposit',
  'ppfEpf': 'PPF / EPF',
  'realEstate': 'Real estate',
  'crypto': 'Crypto',
  'other': 'Other',
};

const kSavingsTypeIcons = {
  'emergencyFund': 'shield_outlined',
  'stocks': 'trending_up',
  'mutualFunds': 'pie_chart_outline',
  'gold': 'workspace_premium_outlined',
  'fixedDeposit': 'lock_clock_outlined',
  'ppfEpf': 'account_balance_outlined',
  'realEstate': 'home_work_outlined',
  'crypto': 'currency_bitcoin',
  'other': 'savings_outlined',
};

/// One person the user is intentionally investing in, for the Relationships
/// & Connection section's "who to reach out to" tracker — a lightweight take
/// on the relationship-maintenance pattern used by contact-care apps: pick
/// how often you want to stay in touch, log when you last did, and the app
/// surfaces whoever's overdue.
class RelationshipContact {
  String id;
  String name;
  String relation;

  /// How often the user wants to check in, in days (e.g. 7, 14, 30).
  int cadenceDays;
  DateTime? lastContactAt;
  String note;

  RelationshipContact({
    required this.id,
    required this.name,
    this.relation = 'friend',
    this.cadenceDays = 7,
    this.lastContactAt,
    this.note = '',
  });

  bool get isOverdue {
    if (lastContactAt == null) return true;
    return DateTime.now().difference(lastContactAt!).inDays >= cadenceDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relation': relation,
        'cadenceDays': cadenceDays,
        'lastContactAt': lastContactAt?.toIso8601String(),
        'note': note,
      };

  static RelationshipContact? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    final id = json['id'];
    final rawCadence = json['cadenceDays'];
    final cadence = rawCadence is int
        ? rawCadence
        : (rawCadence is num ? rawCadence.toInt() : 7);
    final rawLast = json['lastContactAt'];
    return RelationshipContact(
      id: id is String && id.isNotEmpty ? id : '${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      relation: json['relation'] is String ? json['relation'] as String : 'friend',
      cadenceDays: cadence.clamp(1, 365),
      lastContactAt: rawLast is String ? DateTime.tryParse(rawLast) : null,
      note: json['note'] is String ? json['note'] as String : '',
    );
  }
}

/// One quick-add meal note for the lightweight Nutrition & Insights tracker.
/// Deliberately NOT a calorie/macro counter — see [kMealTypes] — the goal is
/// noticing eating patterns and pairing them with the mindset journaling the
/// rest of the app already does, not database-grade nutrition math.
class NutritionEntry {
  String id;
  String mealType; // one of kMealTypes
  String name;
  String note;
  DateTime date;

  NutritionEntry({
    required this.id,
    required this.mealType,
    required this.name,
    this.note = '',
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'mealType': mealType,
        'name': name,
        'note': note,
        'date': date.toIso8601String(),
      };

  static NutritionEntry? fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    final id = json['id'];
    final rawDate = json['date'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final mealType = json['mealType'];
    return NutritionEntry(
      id: id is String && id.isNotEmpty
          ? id
          : '${DateTime.now().microsecondsSinceEpoch}',
      mealType:
          mealType is String && kMealTypes.contains(mealType) ? mealType : 'snack',
      name: name,
      note: json['note'] is String ? json['note'] as String : '',
      date: parsedDate ?? DateTime.now(),
    );
  }
}

/// Quick-add meal categories — kept short with no calorie/macro fields per
/// the "lightweight, non-overwhelming" design.
const kMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

const kMealTypeLabels = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'snack': 'Snack',
};

const kMealTypeIcons = {
  'breakfast': 'wb_sunny_outlined',
  'lunch': 'lunch_dining_outlined',
  'dinner': 'dinner_dining_outlined',
  'snack': 'cookie_outlined',
};

/// One card in the in-app Products showcase — a static catalog, not user
/// data, so nothing here is persisted in AppState. The free item links to
/// the hosted PDF directly; paid items link out to the website's Products
/// page (which itself will point to Gumroad/Payhip once checkout is live) —
/// matching the website's own choice never to bundle a paid file somewhere
/// it could be pulled out and shared for free.
class DigitalProduct {
  final String id;
  final String title;
  final String blurb;
  final String priceLabel;
  final bool isFree;
  final String url;

  const DigitalProduct({
    required this.id,
    required this.title,
    required this.blurb,
    required this.priceLabel,
    required this.isFree,
    required this.url,
  });
}

const kDigitalProducts = [
  DigitalProduct(
    id: 'growth-challenge',
    title: 'The 7-Day Growth Mindset Challenge',
    blurb:
        'A short, structured challenge to shift out of a fixed mindset — one focused prompt a day, for seven days.',
    priceLabel: 'Free',
    isFree: true,
    url:
        'https://aandccreativeventures.netlify.app/downloads/7-Day-Growth-Mindset-Challenge.pdf',
  ),
  DigitalProduct(
    id: 'money-mindset',
    title: 'Money Mindset — 60-Day Workbook',
    blurb:
        'A guided 60-day workbook for rebuilding your relationship with money, one page at a time.',
    priceLabel: 'Coming soon',
    isFree: false,
    url: 'https://aandccreativeventures.netlify.app/products',
  ),
  DigitalProduct(
    id: 'brain-rewiring-planner',
    title: 'Brain Rewiring — Sept–Dec Planner',
    blurb:
        'A seasonal quarter-long planner for rewiring habits and focus, built around a defined date range.',
    priceLabel: 'Coming soon',
    isFree: false,
    url: 'https://aandccreativeventures.netlify.app/products',
  ),
  DigitalProduct(
    id: 'brain-rewiring-journal',
    title: 'Brain Rewiring — 365-Day Journal',
    blurb:
        'Our flagship marker-style daily journal — a full year of guided prompts for rewiring thought patterns.',
    priceLabel: 'Coming soon',
    isFree: false,
    url: 'https://aandccreativeventures.netlify.app/products',
  ),
];

/// One turn in the in-app mindset-coach conversation (see
/// coach_chat_screen.dart / coach_chat_service.dart). General-purpose by
/// design: nothing else in AppState (habits, mood, journal, spending) is
/// ever sent to the coach — this is just the transcript of what the user
/// typed and what came back, no more sensitive than any other on-device
/// text, so it's stored and JSON-round-tripped the same way as every other
/// tracked list in this file.
class CoachMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime date;

  CoachMessage({required this.role, required this.content, required this.date});

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'date': date.toIso8601String(),
      };

  static CoachMessage? fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final content = json['content'];
    if (role is! String || (role != 'user' && role != 'assistant')) return null;
    if (content is! String || content.isEmpty) return null;
    final rawDate = json['date'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    return CoachMessage(role: role, content: content, date: parsedDate ?? DateTime.now());
  }
}

/// Master switch for the in-app AI coach (Coach tab + its Netlify Function
/// backend). Off for now — flip back to true to bring the tab back; no
/// other code needs to change, the screen/service/store methods are all
/// still there, just unreachable from the UI while this is false.
const kCoachChatEnabled = false;

/// How many coach messages a user may send per calendar day — a cost
/// control on a per-request-priced API, not a security boundary (there's no
/// server-side per-user auth to enforce it against a modified client — see
/// the hard caps in the Netlify Function itself for the real backstop).
const kCoachDailyMessageLimit = 20;

const kRelationTypes = ['family', 'friend', 'partner', 'colleague', 'mentor', 'other'];

const kRelationTypeLabels = {
  'family': 'Family',
  'friend': 'Friend',
  'partner': 'Partner',
  'colleague': 'Colleague',
  'mentor': 'Mentor',
  'other': 'Other',
};

/// A yearly recurring reminder for one date — a birthday, an anniversary,
/// a renewal, anything that matters once a year — separate from the daily
/// reminders above. Only month/day are kept (no year), since it repeats
/// every year by definition; the next occurrence is computed at schedule
/// time (this year if it hasn't passed yet, else next year).
class KeyDate {
  String id;
  String title;
  int month; // 1-12
  int day; // 1-31 (clamped to a day that exists in that month when scheduled)

  KeyDate({
    required this.id,
    required this.title,
    required this.month,
    required this.day,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'month': month, 'day': day};

  static KeyDate? fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final month = json['month'];
    final day = json['day'];
    if (title is! String || month is! int || day is! int) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final id = json['id'];
    return KeyDate(
      id: id is String && id.isNotEmpty ? id : '$month-$day-${title.hashCode}',
      title: title,
      month: month,
      day: day,
    );
  }
}

/// One entry in the Journaling (Brain Dump) list — either a manifestation
/// script (write the outcome as if it already happened) or a free-form
/// brain dump. [mode] is 'manifest' or 'dump'; unknown/legacy values are
/// treated as 'manifest' so entries saved before this field existed still
/// display correctly.
class Script {
  String title;
  String body;
  String mode;

  /// When this script was first saved — shown on its card so it's obvious
  /// at a glance that saving actually happened, not just a passing toast.
  DateTime createdAt;

  Script({
    required this.title,
    required this.body,
    this.mode = 'manifest',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'mode': mode,
        'createdAt': createdAt.toIso8601String(),
      };

  static Script fromJson(Map<String, dynamic> json) => Script(
        title: (json['title'] ?? '') as String,
        body: (json['body'] ?? '') as String,
        mode: (json['mode'] ?? 'manifest') as String,
        createdAt: json['createdAt'] is String
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

/// A finance "Goal Roadmap": one dream goal broken into monthly milestones,
/// each a simple checkbox — matches the Dream Goal → 12-Month Goal →
/// Monthly Milestones flow from the reference roadmap graphic.
class FinanceRoadmap {
  String dreamGoal;
  double targetAmount;
  int months;
  List<bool> monthsDone;

  // Clamped to a sane range — an unbounded value here (a stray extra digit
  // typed into the months field, or a corrupted backup) would otherwise
  // build one milestone-circle widget per month and could make the Finance
  // page freeze or crash after the number gets large enough.
  FinanceRoadmap({
    required this.dreamGoal,
    required this.targetAmount,
    required int months,
    List<bool>? monthsDone,
  })  : months = months.clamp(1, 360),
        monthsDone = monthsDone ?? List<bool>.filled(months.clamp(1, 360), false);

  double get perMonth => months == 0 ? 0 : targetAmount / months;
  int get monthsCompleted => monthsDone.where((d) => d).length;
  double get savedSoFar => perMonth * monthsCompleted;

  Map<String, dynamic> toJson() => {
        'dreamGoal': dreamGoal,
        'targetAmount': targetAmount,
        'months': months,
        'monthsDone': monthsDone,
      };

  static FinanceRoadmap fromJson(Map<String, dynamic> json) {
    final rawMonths = json['months'];
    final months = (rawMonths is int
            ? rawMonths
            : (rawMonths is num ? rawMonths.toInt() : 12))
        .clamp(1, 360);
    final rawDone = json['monthsDone'];
    final done = rawDone is List
        ? rawDone.map((e) => e == true).toList()
        : List<bool>.filled(months, false);
    while (done.length < months) {
      done.add(false);
    }
    return FinanceRoadmap(
      dreamGoal: (json['dreamGoal'] ?? '') as String,
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
      months: months,
      monthsDone: done,
    );
  }
}

/// A user-written "instead of / try" pair for the Thought Reframe tool —
/// supplements the built-in reference pairs shown alongside it.
class Reframe {
  String negative;
  String positive;
  Reframe({required this.negative, required this.positive});

  Map<String, dynamic> toJson() => {'negative': negative, 'positive': positive};

  static Reframe fromJson(Map<String, dynamic> json) => Reframe(
        negative: (json['negative'] ?? '') as String,
        positive: (json['positive'] ?? '') as String,
      );
}

/// Reference "instead of / try" pairs for the Thought Reframe tool.
const kReframePairs = [
  ('I don’t want to make a mistake.', 'Mistakes help me learn and grow.'),
  ('I can’t do it.', 'I will keep trying.'),
  ('I give up.', 'I believe in me.'),
  ('They are better at it than me.', 'What can I learn from them?'),
  ('This is too hard.', 'With more practice it will get easier.'),
];

/// Stress Bucket reference items — what fills it vs. what empties it.
const kStressFillItems = [
  'Worries',
  'Too much work',
  'Lack of sleep',
  'Overthinking',
  'Pressure & expectations',
];
const kStressEmptyItems = [
  'Talking about it',
  'Taking breaks',
  'Listening to music',
  'Exercise',
  'Spending time with loved ones',
  'Doing things you enjoy',
];

/// Daily DOSE reference activities, grouped by the "feel-good" chemical
/// each one nudges — dopamine, oxytocin, serotonin, endorphins.
const kDoseCategories = [
  ('Dopamine', 'The reward chemical', ['Create something', 'Achieve a goal', 'Finish a task']),
  ('Oxytocin', 'The love hormone', ['Socialize', 'Hug a family member or pet', 'Help others']),
  ('Serotonin', 'The mood stabiliser', ['Get out in sunlight', 'Try mindfulness', 'Try meditation']),
  ('Endorphins', 'The pain killer', ['Exercise', 'Listen to music', 'Watch a movie', 'Have a laugh']),
];

/// One day's evening reflection.
class JournalEntry {
  /// Up to 3 short "what did I achieve today" lines.
  List<String> achievements;
  String gratitude;

  /// Kept for backward compatibility with entries saved before v0.2 (the
  /// old "anything you want to let go of" prompt) — no longer written to,
  /// but preserved so existing journal history doesn't lose data.
  String reflection;

  JournalEntry({List<String>? achievements, this.gratitude = '', this.reflection = ''})
      : achievements = achievements ?? <String>['', '', ''];

  bool get isEmpty =>
      achievements.every((a) => a.trim().isEmpty) &&
      gratitude.trim().isEmpty &&
      reflection.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'achievements': achievements,
        'gratitude': gratitude,
        'reflection': reflection,
      };

  static JournalEntry fromJson(Map<String, dynamic> json) => JournalEntry(
        achievements: (json['achievements'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            <String>['', '', ''],
        gratitude: (json['gratitude'] ?? '') as String,
        reflection: (json['reflection'] ?? '') as String,
      );
}

/// One tile on the vision board — a caption, optionally backed by an image
/// copied into app-local storage from the device's own gallery (e.g. a
/// screenshot saved from Pinterest — the app has no Pinterest integration,
/// there's no public API for pulling their images directly).
class VisionItem {
  String caption;
  int colorIndex;
  String? imagePath;

  /// Per-tile shape — one of [kVisionShapes]. Empty string means "use the
  /// board's default shape" (back-compat with boards saved before every tile
  /// could have its own shape).
  String shape;

  /// How many grid cells this tile spans, out of the masonry grid's fixed
  /// column count — lets tiles be small, wide, tall, or large instead of
  /// uniform squares.
  int spanX;
  int spanY;

  /// Where the image is centred inside its tile (0..1 fractional alignment)
  /// and how far it's zoomed in — set by dragging/pinching in the tile editor
  /// so a photo can be recomposed after the tile's shape or size changes.
  double imageOffsetX;
  double imageOffsetY;
  double imageZoom;

  /// Decorative frame — one of [kVisionFrames]. Empty string means "none".
  String frameStyle;

  /// Photo colour-grading preset — one of [kVisionFilters]. Empty string
  /// means "none" (the original photo, untouched).
  String filter;

  VisionItem({
    required this.caption,
    this.colorIndex = 0,
    this.imagePath,
    this.shape = '',
    this.spanX = 1,
    this.spanY = 1,
    this.imageOffsetX = 0.5,
    this.imageOffsetY = 0.5,
    this.imageZoom = 1.0,
    this.frameStyle = '',
    this.filter = '',
  });

  Map<String, dynamic> toJson() => {
        'caption': caption,
        'colorIndex': colorIndex,
        'imagePath': imagePath,
        'shape': shape,
        'spanX': spanX,
        'spanY': spanY,
        'imageOffsetX': imageOffsetX,
        'imageOffsetY': imageOffsetY,
        'imageZoom': imageZoom,
        'frameStyle': frameStyle,
        'filter': filter,
      };

  static VisionItem fromJson(Map<String, dynamic> json) => VisionItem(
        caption: (json['caption'] ?? '') as String,
        colorIndex: (json['colorIndex'] ?? 0) as int,
        imagePath: json['imagePath'] as String?,
        shape: (json['shape'] ?? '') as String,
        spanX: (json['spanX'] ?? 1) as int,
        spanY: (json['spanY'] ?? 1) as int,
        imageOffsetX: ((json['imageOffsetX'] ?? 0.5) as num).toDouble(),
        imageOffsetY: ((json['imageOffsetY'] ?? 0.5) as num).toDouble(),
        imageZoom: ((json['imageZoom'] ?? 1.0) as num).toDouble(),
        frameStyle: (json['frameStyle'] ?? '') as String,
        filter: (json['filter'] ?? '') as String,
      );
}

/// One curated arrangement of tile shapes/sizes a user can apply to their
/// vision board in one tap, grouped into [kVisionLayoutCategories].
class VisionLayoutSpec {
  final String name;
  final String category;
  final List<(String shape, int spanX, int spanY)> slots;
  const VisionLayoutSpec({required this.name, required this.category, required this.slots});
}

/// ~25 layouts across 5 categories, each a short recipe of (shape, spanX,
/// spanY) slots. Applying one assigns its slots to the user's existing tiles
/// in order (cycling if there are more tiles than slots).
const kVisionLayoutCategories = [
  'Classic Grid',
  'Photo Collage',
  'Mosaic',
  'Minimal',
  'Bold & Playful',
  'Whimsical',
];

const List<VisionLayoutSpec> kVisionLayouts = [
  // Classic Grid — even, uniform, calm.
  VisionLayoutSpec(name: 'Even Squares', category: 'Classic Grid', slots: [
    ('square', 1, 1), ('square', 1, 1), ('square', 1, 1), ('square', 1, 1),
    ('square', 1, 1), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Rounded Rows', category: 'Classic Grid', slots: [
    ('roundedRect', 2, 1), ('roundedRect', 2, 1), ('roundedRect', 2, 1),
  ]),
  VisionLayoutSpec(name: 'Circle Grid', category: 'Classic Grid', slots: [
    ('circle', 1, 1), ('circle', 1, 1), ('circle', 1, 1), ('circle', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Two Columns', category: 'Classic Grid', slots: [
    ('square', 1, 1), ('square', 1, 1), ('roundedRect', 2, 1),
    ('square', 1, 1), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Wide Banner', category: 'Classic Grid', slots: [
    ('roundedRect', 2, 1), ('square', 1, 1), ('square', 1, 1),
    ('square', 1, 1), ('square', 1, 1),
  ]),
  // Photo Collage — one hero tile plus scattered smaller ones.
  VisionLayoutSpec(name: 'Hero + Grid', category: 'Photo Collage', slots: [
    ('roundedRect', 2, 2), ('square', 1, 1), ('square', 1, 1),
    ('square', 1, 1), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Corner Focus', category: 'Photo Collage', slots: [
    ('square', 1, 1), ('roundedRect', 2, 2), ('square', 1, 1),
    ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Center Stage', category: 'Photo Collage', slots: [
    ('circle', 1, 1), ('roundedRect', 2, 2), ('circle', 1, 1),
    ('square', 1, 1), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Story Wall', category: 'Photo Collage', slots: [
    ('roundedRect', 1, 2), ('square', 1, 1), ('square', 1, 1),
    ('roundedRect', 1, 2), ('square', 1, 1), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Scrapbook', category: 'Photo Collage', slots: [
    ('star', 1, 1), ('square', 1, 1), ('roundedRect', 2, 1),
    ('circle', 1, 1), ('square', 1, 1),
  ]),
  // Mosaic — varied spans, denser, more textured.
  VisionLayoutSpec(name: 'Brick Mosaic', category: 'Mosaic', slots: [
    ('square', 1, 1), ('square', 1, 1), ('roundedRect', 2, 1),
    ('roundedRect', 2, 1), ('square', 1, 1), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Staircase', category: 'Mosaic', slots: [
    ('square', 1, 1), ('roundedRect', 1, 2), ('square', 1, 1),
    ('roundedRect', 1, 2), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Puzzle', category: 'Mosaic', slots: [
    ('hexagon', 1, 1), ('hexagon', 1, 1), ('roundedRect', 2, 1),
    ('hexagon', 1, 1), ('hexagon', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Uneven Rows', category: 'Mosaic', slots: [
    ('roundedRect', 2, 1), ('square', 1, 1), ('square', 1, 1),
    ('square', 1, 1), ('roundedRect', 2, 1),
  ]),
  VisionLayoutSpec(name: 'Cluster', category: 'Mosaic', slots: [
    ('circle', 1, 1), ('square', 1, 1), ('circle', 1, 1),
    ('roundedRect', 2, 1), ('circle', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Diamond Cluster', category: 'Mosaic', slots: [
    ('diamond', 1, 1), ('diamond', 1, 1), ('roundedRect', 2, 1),
    ('diamond', 1, 1),
  ]),
  // Minimal — a few large, breathing tiles.
  VisionLayoutSpec(name: 'One Big Focus', category: 'Minimal', slots: [
    ('roundedRect', 2, 2),
  ]),
  VisionLayoutSpec(name: 'Two Pillars', category: 'Minimal', slots: [
    ('roundedRect', 1, 2), ('roundedRect', 1, 2),
  ]),
  VisionLayoutSpec(name: 'Simple Trio', category: 'Minimal', slots: [
    ('square', 1, 1), ('square', 1, 1), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Wide & Clean', category: 'Minimal', slots: [
    ('roundedRect', 2, 1), ('roundedRect', 2, 1),
  ]),
  VisionLayoutSpec(name: 'Single Circle Focus', category: 'Minimal', slots: [
    ('circle', 2, 2),
  ]),
  // Bold & Playful — stars, hearts, diamonds, mixed shapes.
  VisionLayoutSpec(name: 'Star Power', category: 'Bold & Playful', slots: [
    ('star', 1, 1), ('star', 1, 1), ('roundedRect', 2, 1), ('star', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Heart of It', category: 'Bold & Playful', slots: [
    ('heart', 2, 2), ('square', 1, 1), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Mixed Shapes', category: 'Bold & Playful', slots: [
    ('star', 1, 1), ('circle', 1, 1), ('heart', 1, 1),
    ('diamond', 1, 1), ('hexagon', 1, 1), ('square', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Celebration', category: 'Bold & Playful', slots: [
    ('star', 1, 1), ('heart', 1, 1), ('roundedRect', 2, 1),
    ('star', 1, 1), ('heart', 1, 1),
  ]),
  // Whimsical — softer, more organic/fun shapes for a less boxy board.
  VisionLayoutSpec(name: 'Daydream', category: 'Whimsical', slots: [
    ('cloud', 2, 1), ('flower', 1, 1), ('blob', 1, 1),
    ('cloud', 1, 1), ('arch', 1, 2),
  ]),
  VisionLayoutSpec(name: 'Garden Path', category: 'Whimsical', slots: [
    ('flower', 1, 1), ('flower', 1, 1), ('arch', 2, 1),
    ('blob', 1, 1), ('flower', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Soft Focus', category: 'Whimsical', slots: [
    ('blob', 2, 2), ('cloud', 1, 1), ('flower', 1, 1),
  ]),
  VisionLayoutSpec(name: 'Storybook', category: 'Whimsical', slots: [
    ('arch', 1, 2), ('cloud', 1, 1), ('flower', 1, 1),
    ('blob', 1, 1), ('arch', 1, 2),
  ]),
];

/// Visibility + order of one home-screen card. Order in the list is display order.
class ModuleConfig {
  final String id;
  bool enabled;

  ModuleConfig({required this.id, this.enabled = true});

  Map<String, dynamic> toJson() => {'id': id, 'enabled': enabled};

  static ModuleConfig fromJson(Map<String, dynamic> json) => ModuleConfig(
        id: (json['id'] ?? '') as String,
        enabled: (json['enabled'] ?? true) as bool,
      );
}

/// Every module the card stack knows how to render, in the default order.
const kAllModuleIds = [
  'mantra',
  'priorities',
  'habits',
  'tips',
  'scripting',
  'eveningReflection',
  'visionBoard',
  'mindMap',
  'reminders',
  'financeGoals',
  'healthGoals',
  'mindsetGoals',
  'relationshipsGoals',
  'nutritionLog',
];

const kModuleTitles = {
  'mantra': 'Mantra of the day',
  'priorities': 'Goals & to-dos',
  'habits': 'Habits',
  'tips': 'Productivity tip',
  'scripting': 'Journaling (Brain Dump)',
  'eveningReflection': 'Evening reflection',
  'visionBoard': 'Vision board',
  'mindMap': 'Organized mind map',
  'reminders': 'Daily reminders',
  'financeGoals': 'Finance & money goals',
  'healthGoals': 'Health & body',
  'mindsetGoals': 'Mindset & growth',
  'relationshipsGoals': 'Relationships & connection',
  'nutritionLog': 'Nutrition & insights',
};

/// The five habits every fresh install starts with — still fully editable
/// and deletable, just a friendlier starting point than an empty list.
List<Habit> defaultHabits() => [
      Habit(name: 'Exercise', iconIndex: 8, colorIndex: 0),
      Habit(name: 'Read 10 pages', iconIndex: 4, colorIndex: 1),
      Habit(name: 'Get sunlight', iconIndex: 10, colorIndex: 2),
      Habit(name: 'Personal care', iconIndex: 9, colorIndex: 3),
      Habit(name: 'Learn something new', iconIndex: 2, colorIndex: 4),
    ];

/// Starting set of spending categories — fully editable afterward (rename,
/// delete, add more, edit sub-headers) per the explicit ask that this not
/// be a fixed list.
List<SpendCategory> defaultSpendCategories() => [
      SpendCategory(id: 'food', name: 'Food', subcategories: ['Groceries', 'Dining out']),
      SpendCategory(id: 'transport', name: 'Transport', subcategories: ['Fuel', 'Public transit']),
      SpendCategory(id: 'shopping', name: 'Shopping', subcategories: ['Clothing', 'Electronics']),
      SpendCategory(id: 'bills', name: 'Bills', subcategories: ['Rent', 'Utilities', 'Subscriptions']),
      SpendCategory(id: 'other', name: 'Other', subcategories: []),
    ];

/// Vision board tile shapes the user can switch between — either as the
/// board-wide default or per individual tile.
const kVisionShapes = [
  'square',
  'circle',
  'star',
  'heart',
  'hexagon',
  'diamond',
  'roundedRect',
  'cloud',
  'flower',
  'arch',
  'blob',
];

const kVisionShapeLabels = {
  'square': 'Square',
  'circle': 'Circle',
  'star': 'Star',
  'heart': 'Heart',
  'hexagon': 'Hexagon',
  'diamond': 'Diamond',
  'roundedRect': 'Wide',
  'cloud': 'Cloud',
  'flower': 'Flower',
  'arch': 'Arch',
  'blob': 'Blob',
};

/// Decorative frame treatments a vision-board tile can wear, on top of its
/// shape — a lightweight stand-in for the "make it feel like a real mood
/// board" styles (polaroid borders, torn-paper edges, washi tape, a soft
/// drop shadow) rather than a flat clipped photo.
const kVisionFrames = ['none', 'polaroid', 'tornPaper', 'washiTape', 'dropShadow'];

const kVisionFrameLabels = {
  'none': 'Plain',
  'polaroid': 'Polaroid',
  'tornPaper': 'Torn paper',
  'washiTape': 'Washi tape',
  'dropShadow': 'Drop shadow',
};

/// Simple, dependency-free colour-grading presets applied to a tile's photo.
const kVisionFilters = ['none', 'warm', 'dreamy', 'bw'];

const kVisionFilterLabels = {
  'none': 'Original',
  'warm': 'Warm',
  'dreamy': 'Dreamy',
  'bw': 'B&W',
};

/// Background textures/themes for the whole board — a plain colour by
/// default, or one of a few textured/atmospheric options so the board can
/// feel more like a physical mood board than a bare grid.
const kVisionBackgrounds = ['default', 'cork', 'linen', 'gradient', 'dark'];

const kVisionBackgroundLabels = {
  'default': 'Default',
  'cork': 'Cork board',
  'linen': 'Linen',
  'gradient': 'Gradient',
  'dark': 'Midnight',
};

/// Which section of the swipeable home each module lives in. `mantra` isn't
/// listed — it sits above every section as a standalone banner.
const kProductivityModuleIds = ['priorities', 'habits', 'tips', 'reminders'];
const kOutcomeModuleIds = ['scripting', 'eveningReflection', 'visionBoard', 'mindMap'];
const kFinanceModuleIds = ['financeGoals'];
const kHealthModuleIds = ['healthGoals'];
const kMindsetModuleIds = ['mindsetGoals'];
const kRelationshipsModuleIds = ['relationshipsGoals'];
const kNutritionModuleIds = ['nutritionLog'];

/// One swipeable section of the home screen — bundles its title and the
/// module ids it holds so home_screen.dart's page-building and the
/// Settings "starting screen" picker both read from one shared list instead
/// of duplicating the section order in two places.
class HomePageSection {
  final String key;
  final String title;
  final List<String> moduleIds;
  const HomePageSection(this.key, this.title, this.moduleIds);
}

const kHomePageSections = [
  HomePageSection('productivity', 'Productivity', kProductivityModuleIds),
  HomePageSection('outcome', 'Outcome engineering', kOutcomeModuleIds),
  HomePageSection('finance', 'Finance & money', kFinanceModuleIds),
  HomePageSection('health', 'Health & body', kHealthModuleIds),
  HomePageSection('mindset', 'Mindset & growth', kMindsetModuleIds),
  HomePageSection('relationships', 'Relationships & connection', kRelationshipsModuleIds),
  HomePageSection('nutrition', 'Nutrition & insights', kNutritionModuleIds),
];

/// Onboarding presets — set by the quiz, changeable any time from settings.
const kPresetFocus = 'focus';
const kPresetManifest = 'manifest';
const kPresetBalance = 'balance';

/// A small non-cryptographic hash — good enough to check a locally-stored PIN
/// without keeping it as plain text. This is not encryption; the journal lock
/// is a privacy nudge, not a security boundary, exactly like the design intends.
String hashPin(String pin) {
  var hash = 5381;
  for (final unit in pin.codeUnits) {
    hash = ((hash << 5) + hash + unit) & 0x7fffffff;
  }
  return hash.toRadixString(16);
}

class AppState {
  Map<String, List<Task>> tasksByDay;
  List<Habit> habits;
  List<ReminderSetting> reminders;
  List<KeyDate> keyDates;
  int mantraSeed;

  /// A shuffled permutation of every mantra's index — advances one step per
  /// calendar day, guaranteeing no repeat until the whole list has been
  /// shown once (then reshuffled, avoiding an immediate repeat of the last
  /// one shown). Replaces the old `mantraSeed`-only rotation, which could
  /// repeat far sooner than intended since it never tracked what had
  /// already been shown.
  List<int> mantraShuffleOrder;
  int mantraShuffleCursor;
  String? mantraLastShownDay;

  String themeMode;
  bool skipWeekends;

  /// Which of [kAccentPalettes] (theme.dart) the user picked for the app's
  /// accent color — 'gold' is the original look and stays the default.
  String themeAccentId;

  /// Which of [kFontFamilies] / [kFontScales] (theme.dart) the user picked
  /// for body text readability — 'inter'/'default' are the original look.
  String fontFamilyId;
  String fontScaleId;

  /// Which [kHomePageSections] key opens first when the app launches.
  /// 'productivity' (the original behavior) is the default.
  String defaultPageKey;

  /// Chosen interval, in seconds, for the exercise interval bell timer.
  int exerciseBellIntervalSeconds;

  /// Wallet / spending tracker — user-customizable category headers (each
  /// with its own customizable sub-headers) and the logged expenses
  /// against them, each tagged Need or Want.
  List<SpendCategory> spendCategories;
  List<SpendEntry> spendEntries;

  /// User-set spending budget for the wallet tracker — null until set. Period
  /// is 'monthly' or 'weekly'; `spentInCurrentBudgetPeriod` (Store) sums
  /// entries against whichever window is chosen.
  double? spendBudgetAmount;
  String spendBudgetPeriod;

  /// Savings & investments logged from the wallet section — separate running
  /// totals per [kSavingsTypes], not part of the Need/Want spend split.
  List<SavingsEntry> savingsEntries;

  /// People the user is intentionally staying in touch with, for the
  /// Relationships & Connection section's check-in tracker.
  List<RelationshipContact> relationshipContacts;

  /// The collaborative shared vision board this device last created or
  /// joined, if any — cached locally so re-opening the screen doesn't
  /// require re-entering the code every time.
  String? sharedBoardCode;
  String? sharedBoardTitle;

  bool onboardingComplete;
  String userName;
  List<String> focusAreas;
  String dailyTimeCommitment;
  String preset;
  List<ModuleConfig> modules;

  List<Script> scripts;
  Map<String, JournalEntry> journalByDay;
  List<VisionItem> visionItems;

  String? pinHash;
  bool biometricEnabled;

  /// Day (`dayKey` string) the morning mood check-in was last shown, so it
  /// asks at most once per day. `moodByDay` holds what was picked.
  String? lastMoodPromptDay;
  Map<String, String> moodByDay;

  /// Day the evening reflection popup was last shown/dismissed, so it also
  /// asks at most once per day rather than nagging every time home opens.
  String? lastEveningPromptDay;

  /// Standalone goal lists, separate from the daily task list — surfaced via
  /// the three floating quick-launch buttons on the Productivity section.
  List<Task> weeklyGoals;
  List<Task> monthlyGoals;

  /// Which cartoon character greets the user on open, chosen during setup.
  String avatarGender;

  /// Vision board's default tile shape — used for any tile that hasn't set
  /// its own individual shape.
  String visionBoardShape;

  /// Name of the layout last applied from the 25-template gallery, purely
  /// informational (shown as "Currently: <name>" in the picker).
  String? visionBoardLayoutName;

  /// Board-wide background texture/theme — one of [kVisionBackgrounds].
  String visionBoardBackground;

  /// Finance & Money, Health & Body, Mindset & Growth and Relationships &
  /// Connection are simple goal checklists, same shape as weekly/monthly
  /// goals, each its own swipeable home card.
  List<Task> financeGoals;
  List<Task> healthGoals;
  List<Task> mindsetGoals;
  List<Task> relationshipsGoals;

  /// Free-text notes the user can add to the organized mind map, one per
  /// period tab ('day' | 'week' | 'month').
  Map<String, String> mindMapNotes;

  /// Short colorful sticky notes pinned onto the mind map, several per
  /// period tab — a lighter, more visual complement to the single
  /// paragraph note above.
  Map<String, List<MindMapStickyNote>> mindMapStickyNotes;

  /// Which content shows in the Android home-screen widget.
  bool widgetShowHabits;
  bool widgetShowPriorities;
  bool widgetShowMantra;

  /// Which specific habits appear in the widget's checklist — empty means
  /// "all of them" (the widget itself still caps at 5 for space). Lets
  /// someone with a long habit list pick just the ones they want glanceable
  /// on the home screen instead of always getting the first five.
  List<String> widgetHabitIds;

  /// Whether the one-time "swipe for more" hint on the home screen has
  /// already been shown.
  bool hasSeenSwipeHint;

  /// Finance & Money's Goal Roadmap tool (dream goal → monthly milestones)
  /// and the last income entered into the budget calculator — null/none
  /// until the user sets one up. The split defaults to the classic 50/30/20
  /// but the user can drag it to whatever they like, adding up to 100.
  FinanceRoadmap? financeRoadmap;
  double? financeBudgetIncome;
  double financeBudgetNeedsPct;
  double financeBudgetWantsPct;
  double financeBudgetSavingsPct;

  /// Tracks which budget-threshold alert (0, 80, or 100) has already fired
  /// for the current calendar month, keyed by a "yyyy-M" string — so
  /// crossing 80% only notifies once, and the whole thing resets the moment
  /// a new month starts.
  String? spendAlertMonthKey;
  int spendAlertLevel;

  /// The newest release version the user has already dismissed the update
  /// banner for — so dismissing it is remembered across launches, but a
  /// version newer than this still shows a fresh banner.
  String? dismissedUpdateVersion;

  /// Whether the Dashboard's "sign in to back up" banner has been dismissed.
  /// Only remembered once the user actually dismisses it — signing in and
  /// back out again shows it once more, since that's a fresh reason to sync.
  bool signInBannerDismissed;

  /// Mindset & Growth tools: user-written reframe pairs (supplementing the
  /// built-in reference list), and per-day logs for the Stress Bucket and
  /// Daily DOSE checklists, keyed by `dayKey` date string.
  List<Reframe> customReframes;
  Map<String, List<String>> stressBucketFills;
  Map<String, List<String>> stressBucketEmpties;
  Map<String, List<String>> doseByDay;

  /// Nutrition & Insights: quick-add meal log — see [NutritionEntry].
  List<NutritionEntry> nutritionEntries;

  /// In-app mindset-coach conversation transcript — see [CoachMessage].
  List<CoachMessage> coachMessages;

  AppState({
    required this.tasksByDay,
    required this.habits,
    required this.reminders,
    this.keyDates = const [],
    required this.mantraSeed,
    List<int>? mantraShuffleOrder,
    this.mantraShuffleCursor = 0,
    this.mantraLastShownDay,
    required this.themeMode,
    this.themeAccentId = 'gold',
    this.fontFamilyId = 'inter',
    this.fontScaleId = 'default',
    this.defaultPageKey = 'productivity',
    this.exerciseBellIntervalSeconds = 60,
    List<SpendCategory>? spendCategories,
    this.spendEntries = const [],
    this.spendBudgetAmount,
    this.spendBudgetPeriod = 'monthly',
    this.savingsEntries = const [],
    this.relationshipContacts = const [],
    this.sharedBoardCode,
    this.sharedBoardTitle,
    required this.skipWeekends,
    required this.onboardingComplete,
    required this.userName,
    required this.focusAreas,
    required this.dailyTimeCommitment,
    required this.preset,
    required this.modules,
    required this.scripts,
    required this.journalByDay,
    required this.visionItems,
    required this.pinHash,
    required this.biometricEnabled,
    required this.lastMoodPromptDay,
    required this.moodByDay,
    required this.lastEveningPromptDay,
    required this.weeklyGoals,
    required this.monthlyGoals,
    required this.avatarGender,
    required this.visionBoardShape,
    this.visionBoardLayoutName,
    this.visionBoardBackground = 'default',
    required this.financeGoals,
    required this.healthGoals,
    required this.mindsetGoals,
    required this.relationshipsGoals,
    required this.mindMapNotes,
    Map<String, List<MindMapStickyNote>>? mindMapStickyNotes,
    required this.widgetShowHabits,
    required this.widgetShowPriorities,
    required this.widgetShowMantra,
    required this.widgetHabitIds,
    required this.hasSeenSwipeHint,
    this.financeRoadmap,
    this.financeBudgetIncome,
    this.financeBudgetNeedsPct = 50,
    this.financeBudgetWantsPct = 30,
    this.financeBudgetSavingsPct = 20,
    this.spendAlertMonthKey,
    this.spendAlertLevel = 0,
    this.dismissedUpdateVersion,
    this.signInBannerDismissed = false,
    required this.customReframes,
    required this.stressBucketFills,
    required this.stressBucketEmpties,
    required this.doseByDay,
    List<NutritionEntry>? nutritionEntries,
    List<CoachMessage>? coachMessages,
  })  : mindMapStickyNotes = mindMapStickyNotes ?? <String, List<MindMapStickyNote>>{},
        spendCategories = spendCategories ?? defaultSpendCategories(),
        mantraShuffleOrder = mantraShuffleOrder ?? <int>[],
        nutritionEntries = nutritionEntries ?? <NutritionEntry>[],
        coachMessages = coachMessages ?? <CoachMessage>[];

  static AppState initial() => AppState(
        tasksByDay: <String, List<Task>>{},
        habits: defaultHabits(),
        reminders: [
          ReminderSetting(
              id: 'mantra',
              title: 'Mantra of the day',
              enabled: true,
              hour: 7,
              minute: 30),
          ReminderSetting(
              id: 'midday',
              title: 'Midday task check',
              enabled: true,
              hour: 13,
              minute: 0),
          ReminderSetting(
              id: 'evening',
              title: 'Evening close',
              enabled: true,
              hour: 21,
              minute: 0),
          ReminderSetting(
              id: 'spendWeekly',
              title: 'Weekly spending summary (Sundays)',
              enabled: true,
              hour: 19,
              minute: 0),
          ReminderSetting(
              id: 'spendMonthly',
              title: 'Monthly spending summary (1st of month)',
              enabled: true,
              hour: 9,
              minute: 0),
          ReminderSetting(
              id: 'spendAlerts',
              title: 'Budget threshold alerts (80% / 100% spent)',
              enabled: true,
              hour: 0,
              minute: 0),
        ],
        mantraSeed: DateTime.now().millisecondsSinceEpoch % 997,
        themeMode: 'system',
        skipWeekends: false,
        onboardingComplete: false,
        userName: '',
        focusAreas: <String>[],
        dailyTimeCommitment: '',
        preset: kPresetBalance,
        modules: [for (final id in kAllModuleIds) ModuleConfig(id: id)],
        scripts: <Script>[],
        journalByDay: <String, JournalEntry>{},
        visionItems: <VisionItem>[],
        pinHash: null,
        biometricEnabled: false,
        lastMoodPromptDay: null,
        moodByDay: <String, String>{},
        lastEveningPromptDay: null,
        weeklyGoals: <Task>[],
        monthlyGoals: <Task>[],
        avatarGender: 'girl',
        visionBoardShape: 'square',
        visionBoardLayoutName: null,
        visionBoardBackground: 'default',
        financeGoals: <Task>[],
        healthGoals: <Task>[],
        mindsetGoals: <Task>[],
        relationshipsGoals: <Task>[],
        mindMapNotes: <String, String>{},
        widgetShowHabits: true,
        widgetShowPriorities: true,
        widgetShowMantra: true,
        widgetHabitIds: <String>[],
        hasSeenSwipeHint: false,
        financeRoadmap: null,
        financeBudgetIncome: null,
        spendBudgetAmount: null,
        spendBudgetPeriod: 'monthly',
        savingsEntries: <SavingsEntry>[],
        relationshipContacts: <RelationshipContact>[],
        customReframes: <Reframe>[],
        stressBucketFills: <String, List<String>>{},
        stressBucketEmpties: <String, List<String>>{},
        doseByDay: <String, List<String>>{},
      );

  Map<String, dynamic> toJson() => {
        'tasksByDay': tasksByDay.map((key, value) =>
            MapEntry(key, value.map((t) => t.toJson()).toList())),
        'habits': habits.map((h) => h.toJson()).toList(),
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'keyDates': keyDates.map((k) => k.toJson()).toList(),
        'mantraSeed': mantraSeed,
        'mantraShuffleOrder': mantraShuffleOrder,
        'mantraShuffleCursor': mantraShuffleCursor,
        'mantraLastShownDay': mantraLastShownDay,
        'themeMode': themeMode,
        'themeAccentId': themeAccentId,
        'fontFamilyId': fontFamilyId,
        'fontScaleId': fontScaleId,
        'defaultPageKey': defaultPageKey,
        'exerciseBellIntervalSeconds': exerciseBellIntervalSeconds,
        'spendCategories': spendCategories.map((c) => c.toJson()).toList(),
        'spendEntries': spendEntries.map((e) => e.toJson()).toList(),
        'spendBudgetAmount': spendBudgetAmount,
        'spendBudgetPeriod': spendBudgetPeriod,
        'savingsEntries': savingsEntries.map((e) => e.toJson()).toList(),
        'relationshipContacts': relationshipContacts.map((c) => c.toJson()).toList(),
        'sharedBoardCode': sharedBoardCode,
        'sharedBoardTitle': sharedBoardTitle,
        'skipWeekends': skipWeekends,
        'onboardingComplete': onboardingComplete,
        'userName': userName,
        'focusAreas': focusAreas,
        'dailyTimeCommitment': dailyTimeCommitment,
        'preset': preset,
        'modules': modules.map((m) => m.toJson()).toList(),
        'scripts': scripts.map((s) => s.toJson()).toList(),
        'journalByDay':
            journalByDay.map((key, value) => MapEntry(key, value.toJson())),
        'visionItems': visionItems.map((v) => v.toJson()).toList(),
        'pinHash': pinHash,
        'biometricEnabled': biometricEnabled,
        'lastMoodPromptDay': lastMoodPromptDay,
        'moodByDay': moodByDay,
        'lastEveningPromptDay': lastEveningPromptDay,
        'weeklyGoals': weeklyGoals.map((t) => t.toJson()).toList(),
        'monthlyGoals': monthlyGoals.map((t) => t.toJson()).toList(),
        'avatarGender': avatarGender,
        'visionBoardShape': visionBoardShape,
        'visionBoardLayoutName': visionBoardLayoutName,
        'visionBoardBackground': visionBoardBackground,
        'financeGoals': financeGoals.map((t) => t.toJson()).toList(),
        'healthGoals': healthGoals.map((t) => t.toJson()).toList(),
        'mindsetGoals': mindsetGoals.map((t) => t.toJson()).toList(),
        'relationshipsGoals': relationshipsGoals.map((t) => t.toJson()).toList(),
        'mindMapNotes': mindMapNotes,
        'mindMapStickyNotes': mindMapStickyNotes.map(
            (key, value) => MapEntry(key, value.map((n) => n.toJson()).toList())),
        'widgetShowHabits': widgetShowHabits,
        'widgetShowPriorities': widgetShowPriorities,
        'widgetShowMantra': widgetShowMantra,
        'widgetHabitIds': widgetHabitIds,
        'hasSeenSwipeHint': hasSeenSwipeHint,
        'financeRoadmap': financeRoadmap?.toJson(),
        'financeBudgetIncome': financeBudgetIncome,
        'financeBudgetNeedsPct': financeBudgetNeedsPct,
        'financeBudgetWantsPct': financeBudgetWantsPct,
        'financeBudgetSavingsPct': financeBudgetSavingsPct,
        'spendAlertMonthKey': spendAlertMonthKey,
        'spendAlertLevel': spendAlertLevel,
        'dismissedUpdateVersion': dismissedUpdateVersion,
        'signInBannerDismissed': signInBannerDismissed,
        'customReframes': customReframes.map((r) => r.toJson()).toList(),
        'stressBucketFills': stressBucketFills,
        'stressBucketEmpties': stressBucketEmpties,
        'doseByDay': doseByDay,
        'nutritionEntries': nutritionEntries.map((e) => e.toJson()).toList(),
        'coachMessages': coachMessages.map((m) => m.toJson()).toList(),
      };

  static AppState fromJson(Map<String, dynamic> json) {
    final state = initial();

    final rawTasks = json['tasksByDay'];
    if (rawTasks is Map) {
      final parsed = <String, List<Task>>{};
      rawTasks.forEach((key, value) {
        if (value is List) {
          parsed[key.toString()] = value
              .whereType<Map<String, dynamic>>()
              .map(Task.fromJson)
              .toList();
        }
      });
      state.tasksByDay = parsed;
    }

    final rawHabits = json['habits'];
    if (rawHabits is List) {
      state.habits = rawHabits
          .whereType<Map<String, dynamic>>()
          .map(Habit.fromJson)
          .toList();
    }

    final rawReminders = json['reminders'];
    if (rawReminders is List) {
      for (final entry in rawReminders.whereType<Map<String, dynamic>>()) {
        final match = state.reminders
            .where((r) => r.id == (entry['id'] ?? '').toString())
            .toList();
        if (match.isEmpty) continue;
        final reminder = match.first;
        final enabled = entry['enabled'];
        if (enabled is bool) reminder.enabled = enabled;
        final hour = entry['hour'];
        if (hour is int) reminder.hour = hour;
        final minute = entry['minute'];
        if (minute is int) reminder.minute = minute;
      }
    }

    final rawKeyDates = json['keyDates'];
    if (rawKeyDates is List) {
      state.keyDates = rawKeyDates
          .whereType<Map<String, dynamic>>()
          .map(KeyDate.fromJson)
          .whereType<KeyDate>()
          .toList();
    }

    if (json['mantraSeed'] is int) state.mantraSeed = json['mantraSeed'] as int;
    final rawShuffle = json['mantraShuffleOrder'];
    if (rawShuffle is List) {
      state.mantraShuffleOrder = rawShuffle.whereType<int>().toList();
    }
    if (json['mantraShuffleCursor'] is int) {
      state.mantraShuffleCursor = json['mantraShuffleCursor'] as int;
    }
    if (json['mantraLastShownDay'] is String) {
      state.mantraLastShownDay = json['mantraLastShownDay'] as String;
    }
    if (json['themeMode'] is String) {
      state.themeMode = json['themeMode'] as String;
    }
    if (json['themeAccentId'] is String &&
        kAccentPalettes.any((p) => p.id == json['themeAccentId'])) {
      state.themeAccentId = json['themeAccentId'] as String;
    }
    if (json['fontFamilyId'] is String &&
        kFontFamilies.any((f) => f.id == json['fontFamilyId'])) {
      state.fontFamilyId = json['fontFamilyId'] as String;
    }
    if (json['fontScaleId'] is String &&
        kFontScales.any((s) => s.id == json['fontScaleId'])) {
      state.fontScaleId = json['fontScaleId'] as String;
    }
    if (json['defaultPageKey'] is String &&
        kHomePageSections.any((s) => s.key == json['defaultPageKey'])) {
      state.defaultPageKey = json['defaultPageKey'] as String;
    }
    final rawInterval = json['exerciseBellIntervalSeconds'];
    if (rawInterval is int && rawInterval > 0) {
      state.exerciseBellIntervalSeconds = rawInterval;
    }
    final rawSpendCategories = json['spendCategories'];
    if (rawSpendCategories is List) {
      final parsed = rawSpendCategories
          .whereType<Map<String, dynamic>>()
          .map(SpendCategory.fromJson)
          .whereType<SpendCategory>()
          .toList();
      if (parsed.isNotEmpty) state.spendCategories = parsed;
    }
    final rawSpendEntries = json['spendEntries'];
    if (rawSpendEntries is List) {
      state.spendEntries = rawSpendEntries
          .whereType<Map<String, dynamic>>()
          .map(SpendEntry.fromJson)
          .whereType<SpendEntry>()
          .toList();
    }
    if (json['spendBudgetAmount'] is num) {
      state.spendBudgetAmount = (json['spendBudgetAmount'] as num).toDouble();
    }
    if (json['spendBudgetPeriod'] is String &&
        (json['spendBudgetPeriod'] == 'monthly' || json['spendBudgetPeriod'] == 'weekly')) {
      state.spendBudgetPeriod = json['spendBudgetPeriod'] as String;
    }
    final rawSavings = json['savingsEntries'];
    if (rawSavings is List) {
      state.savingsEntries = rawSavings
          .whereType<Map<String, dynamic>>()
          .map(SavingsEntry.fromJson)
          .whereType<SavingsEntry>()
          .toList();
    }
    final rawContacts = json['relationshipContacts'];
    if (rawContacts is List) {
      state.relationshipContacts = rawContacts
          .whereType<Map<String, dynamic>>()
          .map(RelationshipContact.fromJson)
          .whereType<RelationshipContact>()
          .toList();
    }
    if (json['sharedBoardCode'] is String) {
      state.sharedBoardCode = json['sharedBoardCode'] as String;
    }
    if (json['sharedBoardTitle'] is String) {
      state.sharedBoardTitle = json['sharedBoardTitle'] as String;
    }
    if (json['skipWeekends'] is bool) {
      state.skipWeekends = json['skipWeekends'] as bool;
    }

    if (json['onboardingComplete'] is bool) {
      state.onboardingComplete = json['onboardingComplete'] as bool;
    }
    if (json['userName'] is String) state.userName = json['userName'] as String;
    final rawFocus = json['focusAreas'];
    if (rawFocus is List) {
      state.focusAreas = rawFocus.map((e) => e.toString()).toList();
    }
    if (json['dailyTimeCommitment'] is String) {
      state.dailyTimeCommitment = json['dailyTimeCommitment'] as String;
    }
    if (json['preset'] is String) state.preset = json['preset'] as String;

    final rawModules = json['modules'];
    if (rawModules is List && rawModules.isNotEmpty) {
      final parsed = rawModules
          .whereType<Map<String, dynamic>>()
          .map(ModuleConfig.fromJson)
          .where((m) => kAllModuleIds.contains(m.id))
          .toList();
      // Keep every known module even if an old backup predates it.
      for (final id in kAllModuleIds) {
        if (!parsed.any((m) => m.id == id)) parsed.add(ModuleConfig(id: id));
      }
      state.modules = parsed;
    }

    final rawScripts = json['scripts'];
    if (rawScripts is List) {
      state.scripts = rawScripts
          .whereType<Map<String, dynamic>>()
          .map(Script.fromJson)
          .toList();
    }

    final rawJournal = json['journalByDay'];
    if (rawJournal is Map) {
      final parsed = <String, JournalEntry>{};
      rawJournal.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          parsed[key.toString()] = JournalEntry.fromJson(value);
        }
      });
      state.journalByDay = parsed;
    }

    final rawVision = json['visionItems'];
    if (rawVision is List) {
      state.visionItems = rawVision
          .whereType<Map<String, dynamic>>()
          .map(VisionItem.fromJson)
          .toList();
    }

    if (json['pinHash'] is String) state.pinHash = json['pinHash'] as String;
    if (json['biometricEnabled'] is bool) {
      state.biometricEnabled = json['biometricEnabled'] as bool;
    }
    if (json['lastMoodPromptDay'] is String) {
      state.lastMoodPromptDay = json['lastMoodPromptDay'] as String;
    }
    final rawMood = json['moodByDay'];
    if (rawMood is Map) {
      state.moodByDay = rawMood.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (json['lastEveningPromptDay'] is String) {
      state.lastEveningPromptDay = json['lastEveningPromptDay'] as String;
    }

    final rawWeekly = json['weeklyGoals'];
    if (rawWeekly is List) {
      state.weeklyGoals =
          rawWeekly.whereType<Map<String, dynamic>>().map(Task.fromJson).toList();
    }
    final rawMonthly = json['monthlyGoals'];
    if (rawMonthly is List) {
      state.monthlyGoals =
          rawMonthly.whereType<Map<String, dynamic>>().map(Task.fromJson).toList();
    }
    if (json['avatarGender'] is String) {
      state.avatarGender = json['avatarGender'] as String;
    }
    if (json['visionBoardShape'] is String &&
        kVisionShapes.contains(json['visionBoardShape'])) {
      state.visionBoardShape = json['visionBoardShape'] as String;
    }
    if (json['visionBoardBackground'] is String &&
        kVisionBackgrounds.contains(json['visionBoardBackground'])) {
      state.visionBoardBackground = json['visionBoardBackground'] as String;
    }
    if (json['visionBoardLayoutName'] is String) {
      state.visionBoardLayoutName = json['visionBoardLayoutName'] as String;
    }

    final rawFinance = json['financeGoals'];
    if (rawFinance is List) {
      state.financeGoals =
          rawFinance.whereType<Map<String, dynamic>>().map(Task.fromJson).toList();
    }
    final rawHealth = json['healthGoals'];
    if (rawHealth is List) {
      state.healthGoals =
          rawHealth.whereType<Map<String, dynamic>>().map(Task.fromJson).toList();
    }
    final rawMindset = json['mindsetGoals'];
    if (rawMindset is List) {
      state.mindsetGoals =
          rawMindset.whereType<Map<String, dynamic>>().map(Task.fromJson).toList();
    }
    final rawRelationships = json['relationshipsGoals'];
    if (rawRelationships is List) {
      state.relationshipsGoals =
          rawRelationships.whereType<Map<String, dynamic>>().map(Task.fromJson).toList();
    }
    final rawMindMap = json['mindMapNotes'];
    if (rawMindMap is Map) {
      state.mindMapNotes = rawMindMap.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    final rawSticky = json['mindMapStickyNotes'];
    if (rawSticky is Map) {
      state.mindMapStickyNotes = rawSticky.map((k, v) {
        final notes = v is List
            ? v
                .whereType<Map<String, dynamic>>()
                .map(MindMapStickyNote.fromJson)
                .whereType<MindMapStickyNote>()
                .toList()
            : <MindMapStickyNote>[];
        return MapEntry(k.toString(), notes);
      });
    }
    if (json['widgetShowHabits'] is bool) {
      state.widgetShowHabits = json['widgetShowHabits'] as bool;
    }
    if (json['widgetShowPriorities'] is bool) {
      state.widgetShowPriorities = json['widgetShowPriorities'] as bool;
    }
    if (json['widgetShowMantra'] is bool) {
      state.widgetShowMantra = json['widgetShowMantra'] as bool;
    }
    final rawWidgetHabitIds = json['widgetHabitIds'];
    if (rawWidgetHabitIds is List) {
      state.widgetHabitIds = rawWidgetHabitIds.map((e) => e.toString()).toList();
    }
    if (json['hasSeenSwipeHint'] is bool) {
      state.hasSeenSwipeHint = json['hasSeenSwipeHint'] as bool;
    }

    final rawRoadmap = json['financeRoadmap'];
    if (rawRoadmap is Map<String, dynamic>) {
      state.financeRoadmap = FinanceRoadmap.fromJson(rawRoadmap);
    }
    if (json['financeBudgetIncome'] is num) {
      state.financeBudgetIncome = (json['financeBudgetIncome'] as num).toDouble();
    }
    if (json['financeBudgetNeedsPct'] is num) {
      state.financeBudgetNeedsPct = (json['financeBudgetNeedsPct'] as num).toDouble();
    }
    if (json['financeBudgetWantsPct'] is num) {
      state.financeBudgetWantsPct = (json['financeBudgetWantsPct'] as num).toDouble();
    }
    if (json['spendAlertMonthKey'] is String) {
      state.spendAlertMonthKey = json['spendAlertMonthKey'] as String;
    }
    if (json['spendAlertLevel'] is int) {
      state.spendAlertLevel = json['spendAlertLevel'] as int;
    }
    if (json['dismissedUpdateVersion'] is String) {
      state.dismissedUpdateVersion = json['dismissedUpdateVersion'] as String;
    }
    if (json['signInBannerDismissed'] is bool) {
      state.signInBannerDismissed = json['signInBannerDismissed'] as bool;
    }
    if (json['financeBudgetSavingsPct'] is num) {
      state.financeBudgetSavingsPct = (json['financeBudgetSavingsPct'] as num).toDouble();
    }
    final rawReframes = json['customReframes'];
    if (rawReframes is List) {
      state.customReframes = rawReframes
          .whereType<Map<String, dynamic>>()
          .map(Reframe.fromJson)
          .toList();
    }
    final rawFills = json['stressBucketFills'];
    if (rawFills is Map) {
      state.stressBucketFills = rawFills.map((k, v) =>
          MapEntry(k.toString(), (v is List) ? v.map((e) => e.toString()).toList() : <String>[]));
    }
    final rawEmpties = json['stressBucketEmpties'];
    if (rawEmpties is Map) {
      state.stressBucketEmpties = rawEmpties.map((k, v) =>
          MapEntry(k.toString(), (v is List) ? v.map((e) => e.toString()).toList() : <String>[]));
    }
    final rawDose = json['doseByDay'];
    if (rawDose is Map) {
      state.doseByDay = rawDose.map((k, v) =>
          MapEntry(k.toString(), (v is List) ? v.map((e) => e.toString()).toList() : <String>[]));
    }
    final rawNutrition = json['nutritionEntries'];
    if (rawNutrition is List) {
      state.nutritionEntries = rawNutrition
          .whereType<Map<String, dynamic>>()
          .map(NutritionEntry.fromJson)
          .whereType<NutritionEntry>()
          .toList();
    }
    final rawCoach = json['coachMessages'];
    if (rawCoach is List) {
      state.coachMessages = rawCoach
          .whereType<Map<String, dynamic>>()
          .map(CoachMessage.fromJson)
          .whereType<CoachMessage>()
          .toList();
    }

    return state;
  }
}
