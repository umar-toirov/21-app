import 'package:flutter/material.dart';

/// Maps the icon key sent by the API for a challenge template to a glyph.
IconData challengeIcon(String key) => switch (key) {
      'stretch' => Icons.self_improvement_rounded,
      'weights' => Icons.fitness_center_rounded,
      'run' => Icons.directions_run_rounded,
      'water' => Icons.water_drop_rounded,
      'snow' => Icons.ac_unit_rounded,
      'food_off' => Icons.no_food_rounded,
      'apple' => Icons.eco_rounded,
      'kitchen' => Icons.soup_kitchen_rounded,
      'meditate' => Icons.spa_rounded,
      'breathe' => Icons.air_rounded,
      'gratitude' => Icons.volunteer_activism_rounded,
      'journal' => Icons.edit_note_rounded,
      'book' => Icons.menu_book_rounded,
      'language' => Icons.translate_rounded,
      'pencil' => Icons.edit_rounded,
      'code' => Icons.code_rounded,
      'timer' => Icons.timer_rounded,
      'target' => Icons.track_changes_rounded,
      'clean' => Icons.cleaning_services_rounded,
      'phone_off' => Icons.phonelink_erase_rounded,
      'moon' => Icons.bedtime_rounded,
      'alarm' => Icons.alarm_rounded,
      'pray' => Icons.mosque_rounded,
      'quran' => Icons.auto_stories_rounded,
      'heart' => Icons.favorite_rounded,
      'sparkle' => Icons.auto_awesome_rounded,
      'people' => Icons.groups_rounded,
      'money' => Icons.savings_rounded,
      _ => Icons.flag_rounded,
    };

/// Accent colour per category. Used as a soft tint, so it works in dark mode too.
Color challengeCategoryColor(String category) => switch (category) {
      'health' => const Color(0xFFF15A29),
      'food' => const Color(0xFF22C55E),
      'mind' => const Color(0xFF8B5CF6),
      'learn' => const Color(0xFF3B82F6),
      'focus' => const Color(0xFFF59E0B),
      'detox' => const Color(0xFFEC4899),
      'sleep' => const Color(0xFF6366F1),
      'faith' => const Color(0xFF14B8A6),
      'growth' => const Color(0xFFE11D48),
      _ => const Color(0xFFF15A29),
    };

Color difficultyColor(String difficulty) => switch (difficulty) {
      'easy' => const Color(0xFF22C55E),
      'hard' => const Color(0xFFEF4444),
      _ => const Color(0xFFF59E0B),
    };
