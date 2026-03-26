import 'package:flutter/material.dart';

/// Accessibility helper for semantic labels and screen reader support
class AccessibilityHelper {
  /// Create semantic text for screen readers with icon
  static String semanticLabel({
    required String label,
    String? description,
  }) {
    if (description != null && description.isNotEmpty) {
      return '$label. $description';
    }
    return label;
  }

  /// Create semantic label for status indicators
  static String statusLabel({
    required String status,
    String? additionalInfo,
  }) {
    String label = 'Status: $status';
    if (additionalInfo != null) {
      label += ', $additionalInfo';
    }
    return label;
  }

  /// Create semantic label for numeric values
  static String numericLabel({
    required String label,
    required num value,
    String unit = '',
    int decimalPlaces = 0,
  }) {
    String formattedValue = decimalPlaces == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(decimalPlaces);
    return '$label: $formattedValue$unit';
  }

  /// Create semantic label for battery level
  static String batteryLabel(double percentage) {
    String status;
    if (percentage > 75) {
      status = 'Full';
    } else if (percentage > 50) {
      status = 'Good';
    } else if (percentage > 25) {
      status = 'Low';
    } else {
      status = 'Critical';
    }
    return 'Battery level: ${percentage.toInt()}% ($status)';
  }

  /// Create semantic label for signal strength
  static String signalLabel(double percentage) {
    String status;
    if (percentage > 70) {
      status = 'Strong';
    } else if (percentage > 40) {
      status = 'Fair';
    } else {
      status = 'Weak';
    }
    return 'Signal strength: ${percentage.toInt()}% ($status)';
  }

  /// Create semantic label for time information
  static String timeLabel(String label, DateTime time) {
    return '$label: ${time.toString().split('.')[0]}';
  }

  /// Create semantic label for actions
  static String actionLabel({
    required String action,
    required String target,
  }) {
    return '$action $target';
  }

  /// Create hint text for form fields with requirements
  static String fieldHintWithRequirements({
    required String hint,
    required bool required,
    String? minLength,
    String? pattern,
  }) {
    String text = hint;
    if (required) text += '. Required field';
    if (minLength != null) text += '. Minimum $minLength characters';
    if (pattern != null) text += '. Must match pattern: $pattern';
    return text;
  }
}

/// Semantic widget wrapper for better accessibility
class SemanticButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback onPressed;
  final Widget child;
  final bool enabled;

  const SemanticButton({
    super.key,
    required this.label,
    this.hint,
    required this.onPressed,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      onTap: enabled ? onPressed : null,
      label: label,
      hint: hint,
      child: child,
    );
  }
}

/// Semantic card for better screen reader support
class SemanticCard extends StatelessWidget {
  final String label;
  final String? description;
  final Widget child;
  final VoidCallback? onTap;

  const SemanticCard({
    super.key,
    required this.label,
    this.description,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      hint: description,
      button: onTap != null,
      onTap: onTap,
      child: child,
    );
  }
}

/// Semantic status indicator
class SemanticStatusIndicator extends StatelessWidget {
  final String status;
  final String detail;
  final IconData icon;
  final Color color;

  const SemanticStatusIndicator({
    super.key,
    required this.status,
    required this.detail,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AccessibilityHelper.statusLabel(
        status: status,
        additionalInfo: detail,
      ),
      child: Row(
        children: [
          Semantics(
            label: '$status indicator',
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: detail,
              child: Text(detail),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom tooltip with better semantics
class SemanticTooltip extends StatelessWidget {
  final String label;
  final String tooltip;
  final Widget child;

  const SemanticTooltip({
    super.key,
    required this.label,
    required this.tooltip,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: label,
        hint: tooltip,
        child: child,
      ),
    );
  }
}
