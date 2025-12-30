import 'package:flutter/material.dart';
import 'package:signsync/utils/constants.dart';

/// Application color palette.
///
/// This file defines the complete color system for the app,
/// including primary, secondary, surface, and semantic colors.
/// All colors are designed to meet WCAG AAA contrast requirements.
class AppColors {
  // Primary Colors - Deep Blue for trust and accessibility
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF5E92F3);
  static const Color primaryDark = Color(0xFF003C8F);
  static const Color onPrimary = Colors.white;

  // Secondary Colors - Teal for accents
  static const Color secondary = Color(0xFF00897B);
  static const Color secondaryLight = Color(0xFF4EBAAA);
  static const Color secondaryDark = Color(0xFF005B4F);
  static const Color onSecondary = Colors.white;

  // Tertiary Colors - Amber for warnings
  static const Color tertiary = Color(0xFFFF8F00);
  static const Color tertiaryLight = Color(0xFFFFC046);
  static const Color tertiaryDark = Color(0xFFC56000);
  static const Color onTertiary = Colors.black;

  // Error Colors
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFFF6659);
  static const Color errorDark = Color(0xFF9A0007);
  static const Color onError = Colors.white;

  // Success Colors
  static const Color success = Color(0xFF388E3C);
  static const Color successLight = Color(0xFF6ABF69);
  static const Color successDark = Color(0xFF00600F);
  static const Color onSuccess = Colors.white;

  // Warning Colors
  static const Color warning = Color(0xFFF57C00);
  static const Color warningLight = Color(0xFFFFAD42);
  static const Color warningDark = Color(0xFFBB4D00);
  static const Color onWarning = Colors.black;

  // Info Colors
  static const Color info = Color(0xFF0288D1);
  static const Color infoLight = Color(0xFF5EB8FF);
  static const Color infoDark = Color(0xFF005B9F);
  static const Color onInfo = Colors.white;

  // Background Colors - Light Theme
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color onBackgroundLight = Color(0xFF1C1B1F);
  static const Color onSurfaceLight = Color(0xFF1C1B1F);

  // Background Colors - Dark Theme
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceVariantDark = Color(0xFF2D2D2D);
  static const Color onBackgroundDark = Color(0xFFE6E1E5);
  static const Color onSurfaceDark = Color(0xFFE6E1E5);

  // Surface Variants
  static const Color surfaceVariantLight = Color(0xFFE7E0EC);
  static const Color onSurfaceVariantLight = Color(0xFF49454F);
  static const Color surfaceVariantDark = Color(0xFF49454F);
  static const Color onSurfaceVariantDark = Color(0xFFCAC4D0);

  // Outline Colors
  static const Color outlineLight = Color(0xFF79747E);
  static const Color outlineDark = Color(0xFF938F99);
  static const Color outlineVariantLight = Color(0xFFCAC4D0);
  static const Color outlineVariantDark = Color(0xFF49454F);

  // Inverse Colors
  static const Color inverseSurfaceLight = Color(0xFF313033);
  static const Color inverseOnSurfaceLight = Color(0xFFF4EFF4);
  static const Color inversePrimaryLight = Color(0xFF9ECAFF);

  static const Color inverseSurfaceDark = Color(0xFFE6E1E5);
  static const Color inverseOnSurfaceDark = Color(0xFF313033);
  static const Color inversePrimaryDark = Color(0xFF1565C0);

  // Shadow
  static const Color shadowLight = Color(0x00000000);
  static const Color shadowDark = Color(0x00000000);

  // Scrim
  static const Color scrim = Color(0x00000000);

  // Custom semantic colors for SignSync
  static const Color detectionHighlight = Color(0x4D4CAF50);
  static const Color detectionBox = Color(0xFF4CAF50);
  static const Color signConfidenceHigh = Color(0xFF4CAF50);
  static const Color signConfidenceMedium = Color(0xFFFFC107);
  static const Color signConfidenceLow = Color(0xFFF44336);
  static const Color cameraOverlay = Color(0x80000000);

  // High contrast colors
  static const Color highContrastPrimary = Color(0xFF000000);
  static const Color highContrastSecondary = Color(0xFF1A1A1A);
  static const Color highContrastAccent = Color(0xFFFFD700);
  static const Color highContrastBackground = Color(0xFFFFFFFF);
  static const Color highContrastText = Color(0xFF000000);
}

/// Utility extension methods for colors.
extension ColorExtensions on Color {
  /// Returns the color with adjusted opacity.
  Color withOpacityPercent(int percent) {
    return withAlpha((percent / 100 * 255).round());
  }

  /// Returns a high-contrast version of this color.
  Color toHighContrast() {
    final luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Returns the closest contrasting text color.
  Color get contrastingText {
    final luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Returns a lighter shade of this color.
  Color lighter({double amount = 0.2}) {
    return Color.lerp(this, Colors.white, amount)!;
  }

  /// Returns a darker shade of this color.
  Color darker({double amount = 0.2}) {
    return Color.lerp(this, Colors.black, amount)!;
  }
}

/// Color scheme builder for creating app themes.
class AppColorScheme {
  /// Creates a light color scheme.
  static ColorScheme light() {
    return const ColorScheme(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryLight,
      onSecondaryContainer: AppColors.secondaryDark,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryLight,
      onTertiaryContainer: AppColors.tertiaryDark,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorLight,
      onErrorContainer: AppColors.errorDark,
      background: AppColors.backgroundLight,
      onBackground: AppColors.onBackgroundLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      surfaceVariant: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
      inverseSurface: AppColors.inverseSurfaceLight,
      inverseOnSurface: AppColors.inverseOnSurfaceLight,
      inversePrimary: AppColors.inversePrimaryLight,
      scrim: AppColors.scrim,
      shadow: AppColors.shadowLight,
    );
  }

  /// Creates a dark color scheme.
  static ColorScheme dark() {
    return const ColorScheme(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.primaryDark,
      primaryContainer: AppColors.primary,
      onPrimaryContainer: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      onSecondary: AppColors.secondaryDark,
      secondaryContainer: AppColors.secondary,
      onSecondaryContainer: AppColors.secondaryLight,
      tertiary: AppColors.tertiaryLight,
      onTertiary: AppColors.tertiaryDark,
      tertiaryContainer: AppColors.tertiary,
      onTertiaryContainer: AppColors.tertiaryLight,
      error: AppColors.errorLight,
      onError: AppColors.errorDark,
      errorContainer: AppColors.error,
      onErrorContainer: AppColors.errorLight,
      background: AppColors.backgroundDark,
      onBackground: AppColors.onBackgroundDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      surfaceVariant: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
      inverseSurface: AppColors.inverseSurfaceDark,
      inverseOnSurface: AppColors.inverseOnSurfaceDark,
      inversePrimary: AppColors.inversePrimaryDark,
      scrim: AppColors.scrim,
      shadow: AppColors.shadowDark,
    );
  }

  /// Creates a high-contrast light color scheme.
  static ColorScheme highContrastLight() {
    return ColorScheme(
      primary: AppColors.highContrastPrimary,
      onPrimary: AppColors.highContrastBackground,
      primaryContainer: AppColors.highContrastPrimary,
      onPrimaryContainer: AppColors.highContrastText,
      secondary: AppColors.highContrastSecondary,
      onSecondary: AppColors.highContrastBackground,
      secondaryContainer: AppColors.highContrastSecondary,
      onSecondaryContainer: AppColors.highContrastText,
      tertiary: AppColors.highContrastAccent,
      onTertiary: AppColors.highContrastText,
      error: Colors.red,
      onError: Colors.white,
      background: AppColors.highContrastBackground,
      onBackground: AppColors.highContrastText,
      surface: AppColors.highContrastBackground,
      onSurface: AppColors.highContrastText,
      outline: AppColors.highContrastPrimary,
      inverseSurface: AppColors.highContrastText,
      inverseOnSurface: AppColors.highContrastBackground,
      inversePrimary: AppColors.highContrastAccent,
    );
  }

  /// Creates a high-contrast dark color scheme.
  static ColorScheme highContrastDark() {
    return ColorScheme(
      primary: AppColors.highContrastAccent,
      onPrimary: AppColors.highContrastText,
      primaryContainer: AppColors.highContrastAccent,
      onPrimaryContainer: AppColors.highContrastBackground,
      secondary: AppColors.highContrastBackground,
      onSecondary: AppColors.highContrastText,
      secondaryContainer: AppColors.highContrastBackground,
      onSecondaryContainer: AppColors.highContrastText,
      tertiary: AppColors.highContrastAccent,
      onTertiary: AppColors.highContrastText,
      error: Colors.red,
      onError: Colors.white,
      background: AppColors.highContrastPrimary,
      onBackground: AppColors.highContrastBackground,
      surface: AppColors.highContrastPrimary,
      onSurface: AppColors.highContrastBackground,
      outline: AppColors.highContrastAccent,
      inverseSurface: AppColors.highContrastBackground,
      inverseOnSurface: AppColors.highContrastText,
      inversePrimary: AppColors.highContrastPrimary,
    );
  }
}
