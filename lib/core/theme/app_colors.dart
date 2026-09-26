import 'package:flutter/material.dart';

/// Warm, gallery-like palette shared across the whole app.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFFAF6F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1EAE0);
  static const Color canvas = Color(0xFFEFE6D8);

  static const Color ink = Color(0xFF241F1C);
  static const Color inkSoft = Color(0xFF6F6259);
  static const Color divider = Color(0xFFE7DDD0);

  static const Color clay = Color(0xFFBB5B3C);
  static const Color clayDark = Color(0xFF9A4930);
  static const Color gold = Color(0xFFC79A4B);
  static const Color amber = Color(0xFFEDA23B);

  static const Color success = Color(0xFF4C7A5E);
  static const Color error = Color(0xFFB3432D);

  // Deep navy used behind the Analysing screen.
  static const Color navy = Color(0xFF1E2438);
  static const Color navyDark = Color(0xFF14182A);

  // Soft pastel badges used behind onboarding icons and level cards.
  static const Color pastelYellow = Color(0xFFF6E3B4);
  static const Color pastelPink = Color(0xFFF3D6CE);
  static const Color pastelGreen = Color(0xFFDCF0E1);
  static const Color pastelBlue = Color(0xFFE0E1F7);
  static const Color pastelCoral = Color(0xFFF9DAD7);

  // More saturated versions of the pastels above, used behind level-card icons.
  static const Color iconGreen = Color(0xFF8FD3A3);
  static const Color iconBlue = Color(0xFFA7ABEF);
  static const Color iconCoral = Color(0xFFF0958E);

  // Teal accent used for suggested-question chips in Ask.
  static const Color teal = Color(0xFF3E7C91);
  static const Color pastelTeal = Color(0xFFDCEEF3);

  static const List<Color> frameGradient = [Color(0xFFD9C7A8), Color(0xFFB08C5E)];
}
