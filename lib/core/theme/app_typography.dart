import 'package:flutter/material.dart';

/// Poppins (geometric) for headings, Inter for body — strict hierarchy.
///
/// These are BUNDLED fonts (declared in pubspec.yaml), so they render on the
/// first frame with no network fetch — no launch reflow.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle heading({
      required double fontSize,
      required FontWeight fontWeight,
      Color? color,
      double? letterSpacing,
    }) =>
        TextStyle(
          fontFamily: 'Poppins',
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
        );

    TextStyle body({
      required double fontSize,
      required FontWeight fontWeight,
      Color? color,
    }) =>
        TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );

    return TextTheme(
      displaySmall: heading(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineMedium: heading(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.3,
      ),
      headlineSmall: heading(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: heading(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: heading(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: body(fontSize: 16, fontWeight: FontWeight.w400, color: primary),
      bodyMedium:
          body(fontSize: 14, fontWeight: FontWeight.w400, color: primary),
      bodySmall:
          body(fontSize: 12.5, fontWeight: FontWeight.w400, color: secondary),
      labelLarge:
          body(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelMedium:
          body(fontSize: 12, fontWeight: FontWeight.w500, color: secondary),
    );
  }
}
