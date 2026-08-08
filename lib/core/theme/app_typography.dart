import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Poppins (geometric) for headings, Inter for body — strict hierarchy.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color primary, Color secondary) {
    const heading = GoogleFonts.poppins;
    const body = GoogleFonts.inter;

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
