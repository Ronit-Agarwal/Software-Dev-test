import 'dart:math';
import 'package:flutter/material.dart';

/// Extension methods for [BuildContext].
///
/// These extensions provide convenient shortcuts for common operations
/// like getting theme, size, and media query properties.
extension BuildContextExtensions on BuildContext {
  /// Gets the current theme.
  ThemeData get theme => Theme.of(this);

  /// Gets the current text theme.
  TextTheme get textTheme => theme.textTheme;

  /// Gets the current color scheme.
  ColorScheme get colors => theme.colorScheme;

  /// Gets the screen size.
  Size get screenSize => MediaQuery.of(this).size;

  /// Gets the screen width.
  double get screenWidth => screenSize.width;

  /// Gets the screen height.
  double get screenHeight => screenSize.height;

  /// Gets the orientation of the screen.
  Orientation get orientation => MediaQuery.of(this).orientation;

  /// Gets the device pixel ratio.
  double get pixelRatio => MediaQuery.of(this).devicePixelRatio;

  /// Gets the text scale factor.
  double get textScaleFactor => MediaQuery.of(this).textScaleFactor;

  /// Gets the padding for the system UI (notch, status bar, etc.).
  EdgeInsets get padding => MediaQuery.of(this).padding;

  /// Gets the view insets (keyboard, etc.).
  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;

  /// Checks if the device is in landscape orientation.
  bool get isLandscape => orientation == Orientation.landscape;

  /// Checks if the device is in portrait orientation.
  bool get isPortrait => orientation == Orientation.portrait;

  /// Checks if the screen is small (less than 600dp).
  bool get isSmallScreen => screenWidth < 600;

  /// Checks if the screen is medium (600dp - 840dp).
  bool get isMediumScreen => screenWidth >= 600 && screenWidth < 840;

  /// Checks if the screen is large (840dp or more).
  bool get isLargeScreen => screenWidth >= 840;

  /// Checks if the device is a mobile device.
  bool get isMobile => screenWidth < 840;

  /// Checks if the device is a tablet or desktop.
  bool get isTabletOrDesktop => screenWidth >= 840;

  /// Gets the adaptive padding based on screen size.
  EdgeInsets get adaptivePadding {
    if (isLargeScreen) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    } else if (isMediumScreen) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
  }
}

/// Extension methods for [String].
extension StringExtensions on String? {
  /// Returns true if the string is null or empty.
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Returns true if the string is not null and not empty.
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;

  /// Returns the string or a default value if null.
  String orDefault(String defaultValue) => this ?? defaultValue;

  /// Capitalizes the first letter of the string.
  String capitalize() {
    if (this == null || this!.isEmpty) return this ?? '';
    return '${this![0].toUpperCase()}${this!.substring(1).toLowerCase()}';
  }

  /// Capitalizes the first letter of each word.
  String capitalizeWords() {
    if (this == null || this!.isEmpty) return this ?? '';
    return this!
        .split(' ')
        .map((word) => word.capitalize())
        .join(' ');
  }
}

/// Extension methods for [List].
extension ListExtensions<T> on List<T> {
  /// Returns a new list with the first occurrence of [item] removed.
  List<T> removeFirst(T item) {
    final copy = List<T>.from(this);
    copy.remove(item);
    return copy;
  }

  /// Returns the element at [index] or null if out of bounds.
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// Splits the list into chunks of [size].
  List<List<T>> chunk(int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, min(i + size, length)));
    }
    return chunks;
  }
}

/// Extension methods for [num].
extension NumExtensions on num {
  /// Converts the number to a duration in milliseconds.
  Duration get ms => Duration(milliseconds: toInt());

  /// Converts the number to a duration in seconds.
  Duration get sec => Duration(seconds: toInt());

  /// Converts the number to a duration in minutes.
  Duration get min => Duration(minutes: toInt());

  /// Clamps the number between [min] and [max].
  num clamp(num min, num max) => this < min ? min : (this > max ? max : this);

  /// Returns true if the number is within [min] and [max].
  bool inRange(num min, num max) => this >= min && this <= max;
}

/// Extension methods for [DateTime].
extension DateTimeExtensions on DateTime {
  /// Returns a formatted date string.
  String format([String pattern = 'MM/dd/yyyy']) {
    // Simple formatting - in production, use intl package
    return '$month/$day/$year';
  }

  /// Returns a formatted time string.
  String timeFormat([String pattern = 'HH:mm']) {
    return '$hour:${minute.toString().padLeft(2, '0')}';
  }

  /// Returns true if this date is today.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Returns true if this date is yesterday.
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  /// Returns a relative time string (e.g., "2 hours ago").
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} minutes ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return format();
  }
}

/// Extension methods for [Color].
extension ColorExtensions on Color {
  /// Returns the color with the specified opacity.
  Color withOpacity(double opacity) => withAlpha((opacity * 255).toInt());

  /// Returns the contrasting text color (black or white).
  Color get contrastingText {
    final luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Extension methods for [IconData].
extension IconDataExtensions on IconData {
  /// Creates an Icon widget from this data.
  Icon icon({
    double size = 24,
    Color? color,
  }) =>
      Icon(this, size: size, color: color);
}

/// Extension for accessibility-related operations.
extension AccessibilityExtensions on Widget {
  /// Wraps the widget with a semantic label.
  Widget withSemanticLabel(String label) {
    return Semantics(
      label: label,
      child: this,
    );
  }

  /// Wraps the widget with a button semantic.
  Widget asButton({
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: this,
        ),
      ),
    );
  }
}
