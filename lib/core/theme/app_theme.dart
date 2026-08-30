import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light({Color? accent}) {
    final primary = accent ?? AppColors.primary;
    final secondary =
        accent != null ? Color.lerp(accent, Colors.white, 0.25)! : AppColors.primaryLight;
    final scheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    );

    return _base(
      scheme: scheme,
      scaffoldBg: AppColors.lightBg,
      surface: AppColors.lightSurface,
      surfaceAlt: AppColors.lightSurfaceAlt,
      border: AppColors.lightBorder,
      textPrimary: AppColors.lightTextPrimary,
      textSecondary: AppColors.lightTextSecondary,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark({Color? accent}) {
    final primary =
        accent != null ? Color.lerp(accent, Colors.white, 0.15)! : AppColors.primaryLight;
    final secondary = accent ?? AppColors.primary;
    final scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    );

    return _base(
      scheme: scheme,
      scaffoldBg: AppColors.darkBg,
      surface: AppColors.darkSurface,
      surfaceAlt: AppColors.darkSurfaceAlt,
      border: AppColors.darkBorder,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color scaffoldBg,
    required Color surface,
    required Color surfaceAlt,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Brightness brightness,
  }) {
    final textTheme = AppTypography.textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      // Platform-adaptive spacing/hit-targets so controls feel native on both
      // compact Android phones and iOS.
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // NOTE: ZoomPageTransitionsBuilder snapshots each route with an
      // ImageFilter during navigation. On some devices (notably Android 14+/16)
      // that snapshotting throws a cascade of "RenderBox was not laid out"
      // errors and causes visible jank, and can leave a freshly-pushed screen
      // blank. FadeUpwards (Android) and Cupertino (iOS) don't snapshot, so
      // they avoid that class of bug while still looking clean.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: textTheme.titleLarge,
        // Keep the status-bar icons legible against the scaffold background
        // (dark icons on the light theme, light icons on the dark theme).
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
                .copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.light
                .copyWith(statusBarColor: Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      ),
      // Inputs read as crisp, self-contained controls on ANY background: a
      // 1px resting border defines the field even where the fill color matches
      // the surface behind it (e.g. the CMS content area), and a 1.6px primary
      // ring + coloured floating label make focus unmistakable.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        floatingLabelStyle: textTheme.bodyMedium
            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: border),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: AppColors.ink,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.primaryLight,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
      ),
      // Brand-consistent selection/cursor, spinners, tooltips and toggles so
      // every screen inherits the same look without per-widget styling.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: scheme.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: surfaceAlt,
        circularTrackColor: surfaceAlt,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: textTheme.labelMedium?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        waitDuration: const Duration(milliseconds: 400),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary.withValues(alpha: 0.45)
                : null),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: border, width: 1.6),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary : border),
      ),
    );
  }
}
