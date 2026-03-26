import 'package:flutter/material.dart';

/// Responsive design utilities for consistent sizing across devices
class ResponsiveUtils {
  /// Get safe area padding for the current device
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  /// Get safe area inset values
  static SafeAreaValues getSafeAreaValues(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return SafeAreaValues(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  /// Check if device is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if device is in portrait orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Get adaptive vertical padding based on orientation
  static double getVerticalPadding(BuildContext context) {
    if (isLandscape(context)) {
      return 12.0; // Reduced padding for landscape
    }
    return 16.0; // Standard padding for portrait
  }

  /// Get adaptive horizontal padding based on screen width
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 16.0;
    if (width < 900) return 24.0;
    return 32.0; // Large screens get more padding
  }

  /// Get number of columns for grid based on screen width
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 500) return 1;
    if (width < 800) return 2;
    if (width < 1200) return 3;
    return 4;
  }

  /// Check if screen is small (mobile)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Check if screen is medium (tablet)
  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  /// Check if screen is large (desktop)
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  /// Get adaptive font size based on screen width
  static double getAdaptiveFontSize(BuildContext context,
      {double smallScreen = 14.0, double mediumScreen = 16.0, double largeScreen = 18.0}) {
    if (isSmallScreen(context)) return smallScreen;
    if (isMediumScreen(context)) return mediumScreen;
    return largeScreen;
  }

  /// Get the system text scale for accessibility
  static double getTextScale(BuildContext context) {
    return MediaQuery.of(context).textScaleFactor;
  }

  /// Check if system has high contrast enabled
  static bool hasHighContrast(BuildContext context) {
    return MediaQuery.of(context).highContrast;
  }
}

/// Data class for safe area values
class SafeAreaValues {
  final double top;
  final double bottom;
  final double left;
  final double right;

  SafeAreaValues({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  /// Check if device has a notch or safe area insets
  bool get hasNotch => top > 20 || bottom > 20;
}
