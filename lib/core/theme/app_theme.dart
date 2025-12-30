import 'package:flutter/material.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/core/theme/typography.dart';
import 'package:signsync/utils/constants.dart';

/// Main theme configuration for the application.
///
/// This file defines both light and dark themes with proper
/// accessibility support and consistent styling.
class AppTheme {
  /// Light theme configuration.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorScheme.light(),
      textTheme: AppTypography.textTheme(),
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: [AppTypography.fontFamilyFallback],

      // Component themes
      appBarTheme: _appBarTheme(Brightness.light),
      bottomNavigationBarTheme: _bottomNavigationBarTheme(Brightness.light),
      elevatedButtonTheme: _elevatedButtonTheme(Brightness.light),
      outlinedButtonTheme: _outlinedButtonTheme(Brightness.light),
      textButtonTheme: _textButtonTheme(Brightness.light),
      inputDecorationTheme: _inputDecorationTheme(Brightness.light),
      cardTheme: _cardTheme(Brightness.light),
      dialogTheme: _dialogTheme(Brightness.light),
      snackBarTheme: _snackBarTheme(Brightness.light),
      floatingActionButtonTheme: _floatingActionButtonTheme(Brightness.light),
      navigationBarTheme: _navigationBarTheme(Brightness.light),
      drawerTheme: _drawerTheme(Brightness.light),

      // Additional settings
      visualDensity: VisualDensity.standard,
      applyElevationOverlayColor: true,
      defaultIconTheme: const IconThemeData(size: AppConstants.iconSizeMd),
    );
  }

  /// Dark theme configuration.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorScheme.dark(),
      textTheme: AppTypography.textTheme(isHighContrast: false),
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: [AppTypography.fontFamilyFallback],

      // Component themes
      appBarTheme: _appBarTheme(Brightness.dark),
      bottomNavigationBarTheme: _bottomNavigationBarTheme(Brightness.dark),
      elevatedButtonTheme: _elevatedButtonTheme(Brightness.dark),
      outlinedButtonTheme: _outlinedButtonTheme(Brightness.dark),
      textButtonTheme: _textButtonTheme(Brightness.dark),
      inputDecorationTheme: _inputDecorationTheme(Brightness.dark),
      cardTheme: _cardTheme(Brightness.dark),
      dialogTheme: _dialogTheme(Brightness.dark),
      snackBarTheme: _snackBarTheme(Brightness.dark),
      floatingActionButtonTheme: _floatingActionButtonTheme(Brightness.dark),
      navigationBarTheme: _navigationBarTheme(Brightness.dark),
      drawerTheme: _drawerTheme(Brightness.dark),

      // Additional settings
      visualDensity: VisualDensity.standard,
      applyElevationOverlayColor: true,
      defaultIconTheme: const IconThemeData(size: AppConstants.iconSizeMd),
    );
  }

  /// High-contrast light theme for accessibility.
  static ThemeData get highContrastLightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorScheme.highContrastLight(),
      textTheme: AppTypography.textTheme(isHighContrast: true),
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: [AppTypography.fontFamilyFallback],
      // High contrast specific overrides
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  /// High-contrast dark theme for accessibility.
  static ThemeData get highContrastDarkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColorScheme.highContrastDark(),
      textTheme: AppTypography.textTheme(isHighContrast: true),
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: [AppTypography.fontFamilyFallback],
      // High contrast specific overrides
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  // App Bar Theme
  static AppBarTheme _appBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppBarTheme(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      foregroundColor: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTypography.titleLarge(
        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
      ),
      iconTheme: IconThemeData(
        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
      ),
    );
  }

  // Bottom Navigation Bar Theme
  static BottomNavigationBarThemeData _bottomNavigationBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BottomNavigationBarThemeData(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      selectedItemColor: isDark ? AppColors.primaryLight : AppColors.primary,
      unselectedItemColor: isDark
          ? AppColors.onSurfaceVariantDark
          : AppColors.onSurfaceVariantLight,
      selectedLabelStyle: AppTypography.labelSmall,
      unselectedLabelStyle: AppTypography.labelSmall,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    );
  }

  // Elevated Button Theme
  static ElevatedButtonThemeData _elevatedButtonTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(AppConstants.minTouchTarget, AppConstants.recommendedTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingLg,
          vertical: AppConstants.spacingSm,
        ),
        textStyle: AppTypography.labelLarge(
          color: isDark ? AppColors.onPrimary : AppColors.onPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        elevation: 2,
      ),
    );
  }

  // Outlined Button Theme
  static OutlinedButtonThemeData _outlinedButtonTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(AppConstants.minTouchTarget, AppConstants.recommendedTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingLg,
          vertical: AppConstants.spacingSm,
        ),
        textStyle: AppTypography.labelLarge(
          color: isDark ? AppColors.primaryLight : AppColors.primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        side: BorderSide(
          color: isDark ? AppColors.primaryLight : AppColors.primary,
          width: 1.5,
        ),
      ),
    );
  }

  // Text Button Theme
  static TextButtonThemeData _textButtonTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(AppConstants.minTouchTarget, AppConstants.recommendedTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        textStyle: AppTypography.labelLarge(
          color: isDark ? AppColors.primaryLight : AppColors.primary,
        ),
      ),
    );
  }

  // Input Decoration Theme
  static InputDecorationTheme _inputDecorationTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        borderSide: BorderSide(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        borderSide: BorderSide(
          color: isDark ? AppColors.outlineVariantDark : AppColors.outlineVariantLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        borderSide: BorderSide(
          color: isDark ? AppColors.primaryLight : AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      hintStyle: AppTypography.bodyMedium(
        color: isDark ? AppColors.onSurfaceVariantDark.withOpacity(0.7) : AppColors.onSurfaceVariantLight.withOpacity(0.7),
      ),
      labelStyle: AppTypography.bodyMedium(
        color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
      ),
    );
  }

  // Card Theme
  static CardTheme _cardTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return CardTheme(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceTintColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
    );
  }

  // Dialog Theme
  static DialogTheme _dialogTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return DialogTheme(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceTintColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      ),
      titleTextStyle: AppTypography.titleLarge(
        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
      ),
      contentTextStyle: AppTypography.bodyMedium(
        color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
      ),
    );
  }

  // Snack Bar Theme
  static SnackBarThemeData _snackBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SnackBarThemeData(
      backgroundColor: isDark ? AppColors.inverseSurfaceDark : AppColors.inverseSurfaceLight,
      contentTextStyle: AppTypography.bodyMedium(
        color: isDark ? AppColors.inverseOnSurfaceDark : AppColors.inverseOnSurfaceLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      behavior: SnackBarBehavior.fixed,
    );
  }

  // Floating Action Button Theme
  static FloatingActionButtonThemeData _floatingActionButtonTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return FloatingActionButtonThemeData(
      backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
      foregroundColor: isDark ? AppColors.primaryDark : AppColors.onPrimary,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
    );
  }

  // Navigation Bar Theme
  static NavigationBarThemeData _navigationBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return NavigationBarThemeData(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      indicatorColor: isDark ? AppColors.primaryContainer : AppColors.primaryContainer,
      labelTextStyle: MaterialStateProperty.all(AppTypography.labelSmall),
    );
  }

  // Drawer Theme
  static DrawerThemeData _drawerTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return DrawerThemeData(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      scrimColor: AppColors.scrim,
      width: 280,
    );
  }
}

/// Extension to easily access theme properties.
extension ThemeExtensions on ThemeData {
  /// Gets the app colors from the current theme.
  AppColors get appColors => AppColors();

  /// Gets the app typography from the current theme.
  AppTypography get appTypography => AppTypography();
}
