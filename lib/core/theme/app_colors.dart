import 'package:flutter/material.dart';

/// ClassTrack palette — soft lavender/purple design language.
///
/// Primary is a friendly medium purple used for buttons, selected states and
/// chart bars. Backgrounds are a very soft lavender, cards are white or a
/// lavender tint, and a near-navy "ink" is used for dark pills and the nav bar.
/// A warm peach accent is used sparingly for highlight number cards.
class AppColors {
  AppColors._();

  // Primary — friendly purple
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF8B7FEC);
  static const Color primaryDark = Color(0xFF5546C9);

  // Lavender surfaces / tints
  static const Color lavender = Color(0xFFEDEAFB); // soft card / header fill
  static const Color lavenderTint = Color(0xFFDED9F7); // deeper lavender chip
  static const Color lavenderSoft = Color(0xFFF3F1FC); // faint wash

  // Near-navy ink — dark pills, nav bar, dark buttons
  static const Color ink = Color(0xFF1B1C34);
  static const Color inkSoft = Color(0xFF2A2C4A);

  // Warm accents (highlight number cards, celebrations)
  static const Color peach = Color(0xFFF6D4B8);
  static const Color peachSoft = Color(0xFFFBE7D4);
  static const Color coral = Color(0xFFFB7185);
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentSoft = Color(0xFFFCD34D);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // Attendance status
  static const Color present = Color(0xFF22C55E);
  static const Color absent = Color(0xFFEF4444);
  static const Color cancelled = Color(0xFF94A3B8);
  static const Color unmarked = Color(0xFFCBD5E1);

  // Neutrals — light (lavender-tinted)
  static const Color lightBg = Color(0xFFF1EFFB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0EDFB);
  static const Color lightBorder = Color(0xFFE7E3F7);
  static const Color lightTextPrimary = Color(0xFF1B1C34);
  static const Color lightTextSecondary = Color(0xFF7B7A94);

  // Neutrals — dark
  static const Color darkBg = Color(0xFF14152A);
  static const Color darkSurface = Color(0xFF1E2039);
  static const Color darkSurfaceAlt = Color(0xFF272A47);
  static const Color darkBorder = Color(0xFF33365A);
  static const Color darkTextPrimary = Color(0xFFF1F0FA);
  static const Color darkTextSecondary = Color(0xFF9B9AB8);

  /// Soft shadow used on cards throughout the app.
  static List<BoxShadow> softShadow({double opacity = 0.08, double blur = 24}) =>
      [
        BoxShadow(
          color: primary.withOpacity(opacity),
          blurRadius: blur,
          offset: const Offset(0, 10),
        ),
      ];

  /// Palette offered to the user when picking a subject color tag.
  static const List<Color> subjectPalette = [
    Color(0xFF6C5CE7), // purple
    Color(0xFF8B7FEC), // light purple
    Color(0xFF0EA5E9), // sky
    Color(0xFF22C55E), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
    Color(0xFF64748B), // slate
  ];
}
