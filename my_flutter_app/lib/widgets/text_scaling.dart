import 'package:flutter/material.dart';

/// Text scaling utility for accessible text sizing
class TextScalingService {
  /// Get body text style with proper scaling
  static TextStyle bodyText(BuildContext context, {
    double baseFontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = const Color(0xFF64748B),
  }) {
    final textScale = MediaQuery.of(context).textScaleFactor;
    return TextStyle(
      fontSize: baseFontSize * textScale,
      fontWeight: fontWeight,
      color: color,
      height: 1.5,
    );
  }

  /// Get heading text style with proper scaling
  static TextStyle heading(BuildContext context, {
    double baseFontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color color = const Color(0xFF0F172A),
  }) {
    final textScale = MediaQuery.of(context).textScaleFactor;
    return TextStyle(
      fontSize: baseFontSize * textScale,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  /// Get subheading text style with proper scaling
  static TextStyle subheading(BuildContext context, {
    double baseFontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color color = const Color(0xFF0F172A),
  }) {
    final textScale = MediaQuery.of(context).textScaleFactor;
    return TextStyle(
      fontSize: baseFontSize * textScale,
      fontWeight: fontWeight,
      color: color,
      height: 1.4,
    );
  }

  /// Get caption text style with proper scaling
  static TextStyle caption(BuildContext context, {
    double baseFontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
    Color color = const Color(0xFF94A3B8),
  }) {
    final textScale = MediaQuery.of(context).textScaleFactor;
    return TextStyle(
      fontSize: baseFontSize * textScale,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  /// Get button text style with proper scaling
  static TextStyle button(BuildContext context, {
    double baseFontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color color = Colors.white,
  }) {
    final textScale = MediaQuery.of(context).textScaleFactor;
    return TextStyle(
      fontSize: baseFontSize * textScale,
      fontWeight: fontWeight,
      color: color,
    );
  }

  /// Check if text scaling is at accessibility level (>1.25)
  static bool isAccessibilityTextScaling(BuildContext context) {
    return MediaQuery.of(context).textScaleFactor > 1.25;
  }

  /// Get appropriate line count for text based on scaling
  static int getMaxLines(BuildContext context, {int normalLines = 2}) {
    if (isAccessibilityTextScaling(context)) {
      return normalLines + 1;
    }
    return normalLines;
  }
}

/// Custom text widget with automatic scaling
class ScalableText extends StatelessWidget {
  final String text;
  final double baseFontSize;
  final FontWeight fontWeight;
  final Color color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double lineHeight;

  const ScalableText(
    this.text, {
    super.key,
    this.baseFontSize = 14,
    this.fontWeight = FontWeight.normal,
    this.color = const Color(0xFF64748B),
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.lineHeight = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextScalingService.bodyText(
        context,
        baseFontSize: baseFontSize,
        fontWeight: fontWeight,
        color: color,
      ).copyWith(height: lineHeight),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Scalable heading widget
class ScalableHeading extends StatelessWidget {
  final String text;
  final double baseFontSize;
  final FontWeight fontWeight;
  final Color color;
  final TextAlign? textAlign;

  const ScalableHeading(
    this.text, {
    super.key,
    this.baseFontSize = 24,
    this.fontWeight = FontWeight.w700,
    this.color = const Color(0xFF0F172A),
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextScalingService.heading(
        context,
        baseFontSize: baseFontSize,
        fontWeight: fontWeight,
        color: color,
      ),
      textAlign: textAlign,
    );
  }
}

/// High contrast text for accessibility
class HighContrastText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final Widget Function(BuildContext, TextStyle)? builder;

  const HighContrastText(
    this.text, {
    super.key,
    this.baseStyle = const TextStyle(),
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final isHighContrast = MediaQuery.of(context).highContrast;

    TextStyle style = baseStyle;
    if (isHighContrast) {
      style = style.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );
    }

    if (builder != null) {
      return builder!(context, style);
    }

    return Text(text, style: style);
  }
}
