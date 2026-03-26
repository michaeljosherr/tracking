import 'package:flutter/material.dart';

/// Responsive design helper for handling different screen sizes and orientations
class ResponsiveHelper {
  final BuildContext context;

  ResponsiveHelper(this.context);

  /// Get screen size
  Size get screenSize => MediaQuery.of(context).size;

  /// Get screen width
  double get screenWidth => screenSize.width;

  /// Get screen height
  double get screenHeight => screenSize.height;

  /// Get device padding (safe area)
  EdgeInsets get devicePadding => MediaQuery.of(context).padding;

  /// Get device view insets (keyboard, etc)
  EdgeInsets get viewInsets => MediaQuery.of(context).viewInsets;

  /// Check if device is in landscape
  bool get isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Check if device is in portrait
  bool get isPortrait =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  /// Check if device is mobile (width < 600)
  bool get isMobile => screenWidth < 600;

  /// Check if device is tablet (width >= 600 && width < 1024)
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;

  /// Check if device is desktop (width >= 1024)
  bool get isDesktop => screenWidth >= 1024;

  /// Get responsive value based on screen size
  T responsiveValue<T>({
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    if (isMobile) return mobile;
    if (isTablet) return tablet;
    return desktop;
  }

  /// Get responsive padding
  EdgeInsets responsivePadding({
    double mobile = 16,
    double tablet = 24,
    double desktop = 32,
  }) {
    final value = responsiveValue(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
    return EdgeInsets.all(value);
  }

  /// Get responsive horizontal padding
  EdgeInsets responsiveHorizontalPadding({
    double mobile = 16,
    double tablet = 24,
    double desktop = 32,
  }) {
    final value = responsiveValue(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
    return EdgeInsets.symmetric(horizontal: value);
  }

  /// Get responsive font size
  double responsiveFontSize({
    double mobile = 14,
    double tablet = 16,
    double desktop = 18,
  }) {
    return responsiveValue(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// Get responsive spacing
  double responsiveSpacing({
    double mobile = 8,
    double tablet = 12,
    double desktop = 16,
  }) {
    return responsiveValue(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// Get responsive grid columns
  int responsiveGridColumns() {
    if (isMobile) return 1;
    if (isTablet) return 2;
    return 3;
  }

  /// Get text scale factor (for system text scaling)
  double get textScaleFactor => MediaQuery.of(context).textScaleFactor;

  /// Scale value by text scale factor
  double scaleByTextFactor(double value) {
    return value * textScaleFactor;
  }

  /// Check if user prefers reduced motion
  bool get prefersReducedMotion =>
      MediaQuery.of(context).disableAnimations;

  /// Get optimal animation duration based on user preferences
  Duration getAnimationDuration(Duration defaultDuration) {
    if (prefersReducedMotion) {
      return defaultDuration ~/ 2;
    }
    return defaultDuration;
  }

  /// Check if device is in high contrast mode
  bool get isHighContrast =>
      MediaQuery.of(context).highContrast;
}

/// Widget extension for easier responsive access
extension ResponsiveContext on BuildContext {
  ResponsiveHelper get responsive => ResponsiveHelper(this);
}
