import 'package:flutter/material.dart';

import 'models.dart';

/// A life area a vision-board tile can belong to.
class VisionArea {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const VisionArea(this.key, this.label, this.icon, this.color);
}

const List<VisionArea> kVisionAreas = [
  VisionArea('career', 'Career', Icons.work_outline, Color(0xFF3F7DD8)),
  VisionArea('wealth', 'Wealth', Icons.savings_outlined, Color(0xFF2E9E6B)),
  VisionArea('health', 'Health', Icons.favorite_border, Color(0xFFE5566D)),
  VisionArea('love', 'Love & family', Icons.diversity_1_outlined, Color(0xFFD9558F)),
  VisionArea('growth', 'Growth', Icons.auto_stories_outlined, Color(0xFF8A5CD6)),
  VisionArea('travel', 'Travel', Icons.flight_takeoff, Color(0xFF1FA2B8)),
  VisionArea('home', 'Home', Icons.home_outlined, Color(0xFFC98A2B)),
  VisionArea('joy', 'Joy', Icons.celebration_outlined, Color(0xFFE08A1E)),
];

VisionArea? visionAreaFor(String key) {
  for (final a in kVisionAreas) {
    if (a.key == key) return a;
  }
  return null;
}

/// Whole days from today until the tile's target date (negative if past), or
/// null when no valid date is set.
int? visionDaysLeft(VisionItem item) {
  if (item.targetDate.isEmpty) return null;
  final target = DateTime.tryParse(item.targetDate);
  if (target == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(target.year, target.month, target.day);
  return day.difference(today).inDays;
}

String visionCountdownLabel(VisionItem item) {
  final days = visionDaysLeft(item);
  if (days == null) return '';
  if (days > 1) return '$days days';
  if (days == 1) return 'Tomorrow';
  if (days == 0) return 'Today';
  return 'Past due';
}

String formatVisionDate(String key) {
  final d = DateTime.tryParse(key);
  if (d == null) return '';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// A ready-made set of tiles to start a board from.
class VisionTemplate {
  final String name;
  final String blurb;
  final List<(String caption, String area, String affirmation)> tiles;
  const VisionTemplate(this.name, this.blurb, this.tiles);
}

const List<VisionTemplate> kVisionTemplates = [
  VisionTemplate('Dream life starter', 'One tile for each area of life', [
    ('A career that lights me up', 'career',
        'I do meaningful work and I am valued for it.'),
    ('Financial freedom', 'wealth',
        'Money comes to me easily and I use it wisely.'),
    ('A strong, energetic body', 'health',
        'I care for my body and it carries me well.'),
    ('Deep, loving relationships', 'love',
        'I give and receive love with ease.'),
    ('Always learning', 'growth',
        'Every day I become a little wiser and braver.'),
    ('Places I will see', 'travel', 'The world is open to me.'),
    ('A home that feels like peace', 'home',
        'My home is calm, warm and full of life.'),
    ('Play, laughter and rest', 'joy',
        'I make room for joy every single day.'),
  ]),
  VisionTemplate('This year, one by one', 'Five focused intentions', [
    ('My word for the year', 'growth', 'I live my word in small ways each day.'),
    ('The one big goal', 'career', 'I take one clear step toward it every day.'),
    ('The habit I will master', 'health', 'I show up for my habit, even on slow days.'),
    ('What I am ready to let go of', 'joy', 'I release what no longer serves me.'),
    ('What I want more of', 'love', 'I welcome more of what I love.'),
  ]),
  VisionTemplate('Health and glow', 'Body, mind and energy', [
    ('Morning movement', 'health', 'I start my day by moving and I feel alive.'),
    ('Nourishing food', 'health', 'I choose food that makes me feel strong.'),
    ('Deep, easy sleep', 'health', 'I rest fully and wake up refreshed.'),
    ('A calm mind', 'growth', 'I breathe, I settle, I return to the present.'),
    ('Confidence in my skin', 'joy', 'I am at home in myself.'),
  ]),
  VisionTemplate('Career and wealth', 'Work, money and impact', [
    ('The role I am growing into', 'career', 'I grow into bigger responsibilities with confidence.'),
    ('Income goal', 'wealth', 'My income grows as the value I give grows.'),
    ('Savings and security', 'wealth', 'I build security month after month.'),
    ('A skill to master', 'growth', 'I practise deliberately and I improve.'),
    ('People I want to work with', 'career', 'The right people find me and I find them.'),
  ]),
];
