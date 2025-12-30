import 'package:flutter/material.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Typography system for the application.
///
/// This file defines the text styles used throughout the app,
/// ensuring consistent typography with proper scaling support.
class AppTypography {
  // Font family
  static const String fontFamily = 'Inter';
  static const String fontFamilyFallback = 'Roboto';

  // Font sizes - following Material Design type scale
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;

  // Line heights
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.75;

  // Letter spacing
  static const double letterSpacingTight = -0.02;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.02;

  /// Creates the text theme for the app.
  static TextTheme textTheme({
    bool isHighContrast = false,
  }) {
    final base = isHighContrast ? ThemeData.dark() : ThemeData.light();
    final baseTextTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: [fontFamilyFallback],
    );

    return TextTheme(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: letterSpacingTight,
        height: lineHeightTight,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: letterSpacingTight,
        height: lineHeightTight,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: letterSpacingTight,
        height: lineHeightTight,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacingTight,
        height: lineHeightNormal,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacingTight,
        height: lineHeightNormal,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacingTight,
        height: lineHeightNormal,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacingNormal,
        height: lineHeightNormal,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacingNormal,
        height: lineHeightNormal,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: letterSpacingNormal,
        height: lineHeightNormal,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: letterSpacingNormal,
        height: lineHeightRelaxed,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: letterSpacingNormal,
        height: lineHeightRelaxed,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: letterSpacingNormal,
        height: lineHeightRelaxed,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: letterSpacingWide,
        height: lineHeightNormal,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: letterSpacingWide,
        height: lineHeightNormal,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: letterSpacingWide,
        height: lineHeightNormal,
      ),
    );
  }

  /// Creates a large display text style.
  static TextStyle displayLarge({
    Color? color,
    bool isHighContrast = false,
  }) {
    return TextStyle(
      fontSize: displayLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: letterSpacingTight,
      height: lineHeightTight,
      color: color ?? _getTextColor(isHighContrast),
    );
  }

  /// Creates a headline text style.
  static TextStyle headlineLarge({
    Color? color,
    bool isHighContrast = false,
  }) {
    return TextStyle(
      fontSize: headlineLarge,
      fontWeight: FontWeight.w700,
      letterSpacing: letterSpacingTight,
      height: lineHeightNormal,
      color: color ?? _getTextColor(isHighContrast),
    );
  }

  /// Creates a title text style.
  static TextStyle titleLarge({
    Color? color,
    bool isHighContrast = false,
  }) {
    return TextStyle(
      fontSize: titleLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color ?? _getTextColor(isHighContrast),
    );
  }

  /// Creates a body text style.
  static TextStyle bodyLarge({
    Color? color,
    bool isHighContrast = false,
  }) {
    return TextStyle(
      fontSize: bodyLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: letterSpacingNormal,
      height: lineHeightRelaxed,
      color: color ?? _getTextColor(isHighContrast),
    );
  }

  /// Creates a label text style.
  static TextStyle labelLarge({
    Color? color,
    bool isHighContrast = false,
  }) {
    return TextStyle(
      fontSize: labelLarge,
      fontWeight: FontWeight.w500,
      letterSpacing: letterSpacingWide,
      height: lineHeightNormal,
      color: color ?? _getTextColor(isHighContrast),
    );
  }

  /// Gets the default text color based on contrast mode.
  static Color _getTextColor(bool isHighContrast) {
    return isHighContrast ? Colors.black : null;
  }
}

/// Utility class for responsive text sizing.
class ResponsiveTypography {
  /// Scales text size based on screen width.
  static double scaleTextSize(
    double baseSize,
    BuildContext context, {
    double minScale = 0.8,
    double maxScale = 1.2,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 400).clamp(minScale, maxScale);
    return baseSize * scale;
  }

  /// Creates a responsive headline style.
  static TextStyle responsiveHeadline(
    BuildContext context, {
    Color? color,
    bool isHighContrast = false,
  }) {
    return AppTypography.headlineLarge(
      color: color,
      isHighContrast: isHighContrast,
    ).copyWith(
      fontSize: scaleTextSize(AppTypography.headlineLarge, context),
    );
  }

  /// Creates a responsive body style.
  static TextStyle responsiveBody(
    BuildContext context, {
    Color? color,
    bool isHighContrast = false,
  }) {
    return AppTypography.bodyLarge(
      color: color,
      isHighContrast: isHighContrast,
    ).copyWith(
      fontSize: scaleTextSize(AppTypography.bodyLarge, context),
    );
  }
}

/// Utility class for accessibility text sizing.
class AccessibleTypography {
  /// Creates a text style with minimum accessible size.
  static TextStyle accessibleBody({
    Color? color,
    double minSize = 14.0,
  }) {
    return AppTypography.bodyMedium(
      color: color,
    ).copyWith(fontSize: minSize);
  }

  /// Creates a heading with minimum accessible size.
  static TextStyle accessibleHeading({
    Color? color,
    double minSize = 20.0,
  }) {
    return AppTypography.titleLarge(
      color: color,
    ).copyWith(fontSize: minSize);
  }

  /// Gets the minimum text scale factor for accessibility.
  static double getMinScaleFactor() => 0.8;

  /// Gets the maximum text scale factor for accessibility.
  static double getMaxScaleFactor() => 2.0;

  /// Creates a text style that respects user text scale preferences.
  static TextStyle scalable({
    required TextStyle baseStyle,
    required BuildContext context,
    double minFontSize = 10.0,
    double maxFontSize = double.infinity,
  }) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final scaledSize = baseStyle.fontSize! * textScaleFactor;

    return baseStyle.copyWith(
      fontSize: scaledSize.clamp(minFontSize, maxFontSize),
    );
  }
}
