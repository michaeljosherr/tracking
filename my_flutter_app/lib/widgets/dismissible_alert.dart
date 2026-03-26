import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Dismissible alert card with smart positioning in lists
class DismissibleAlert extends StatefulWidget {
  final String title;
  final String? message;
  final AlertType type;
  final VoidCallback onDismissed;
  final VoidCallback? onActionPressed;
  final String? actionLabel;
  final Duration autoDismissDuration;
  final bool showCloseButton;

  const DismissibleAlert({
    super.key,
    required this.title,
    this.message,
    this.type = AlertType.info,
    required this.onDismissed,
    this.onActionPressed,
    this.actionLabel,
    this.autoDismissDuration = const Duration(seconds: 6),
    this.showCloseButton = true,
  });

  @override
  State<DismissibleAlert> createState() => _DismissibleAlertState();
}

enum AlertType {
  success,
  error,
  warning,
  info,
}

class _DismissibleAlertState extends State<DismissibleAlert>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _startAutoDismissTimer();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  void _startAutoDismissTimer() {
    Future.delayed(widget.autoDismissDuration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    await _animationController.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getAlertColors();

    return SlideTransition(
      position: _slideAnimation.drive(Tween<Offset>(
        begin: const Offset(-1.0, 0.0),
        end: Offset.zero,
      )),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Swipe right to dismiss
            if (details.velocity.pixelsPerSecond.dx > 100) {
              _dismiss();
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors['background'] as Color,
              border: Border.all(color: colors['border'] as Color),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: (colors['icon'] as Color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            colors['iconData'] as IconData,
                            color: colors['icon'] as Color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colors['text'] as Color,
                          ),
                        ),
                      ],
                    ),
                    if (widget.showCloseButton)
                      GestureDetector(
                        onTap: _dismiss,
                        child: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: colors['icon'] as Color,
                        ),
                      ),
                  ],
                ),
                // Message
                if (widget.message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.message!,
                    style: TextStyle(
                      fontSize: 13,
                      color: (colors['text'] as Color).withOpacity(0.7),
                    ),
                  ),
                ],
                // Action button
                if (widget.actionLabel != null &&
                    widget.onActionPressed != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onActionPressed!();
                        _dismiss();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors['actionBg'] as Color,
                        foregroundColor: colors['actionText'] as Color,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(widget.actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getAlertColors() {
    switch (widget.type) {
      case AlertType.success:
        return {
          'background': Colors.green.shade50,
          'border': Colors.green.shade200,
          'text': Colors.green.shade900,
          'icon': Colors.green.shade600,
          'iconData': LucideIcons.check,
          'actionBg': Colors.green.shade100,
          'actionText': Colors.green.shade700,
        };
      case AlertType.error:
        return {
          'background': Colors.red.shade50,
          'border': Colors.red.shade200,
          'text': Colors.red.shade900,
          'icon': Colors.red.shade600,
          'iconData': Icons.error_outline,
          'actionBg': Colors.red.shade100,
          'actionText': Colors.red.shade700,
        };
      case AlertType.warning:
        return {
          'background': Colors.amber.shade50,
          'border': Colors.amber.shade200,
          'text': Colors.amber.shade900,
          'icon': Colors.amber.shade600,
          'iconData': Icons.warning,
          'actionBg': Colors.amber.shade100,
          'actionText': Colors.amber.shade700,
        };
      case AlertType.info:
        return {
          'background': Colors.blue.shade50,
          'border': Colors.blue.shade200,
          'text': Colors.blue.shade900,
          'icon': Colors.blue.shade600,
          'iconData': Icons.info_outline,
          'actionBg': Colors.blue.shade100,
          'actionText': Colors.blue.shade700,
        };
    }
  }
}

/// Alert container for multiple dismissible alerts
class AlertContainer extends StatefulWidget {
  final List<AlertItem> alerts;
  final Duration fadeDuration;

  const AlertContainer({
    super.key,
    required this.alerts,
    this.fadeDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AlertContainer> createState() => _AlertContainerState();
}

class AlertItem {
  final String id;
  final String title;
  final String? message;
  final AlertType type;
  final VoidCallback? onAction;
  final String? actionLabel;

  AlertItem({
    required this.id,
    required this.title,
    this.message,
    this.type = AlertType.info,
    this.onAction,
    this.actionLabel,
  });
}

class _AlertContainerState extends State<AlertContainer> {
  late List<AlertItem> _displayedAlerts;

  @override
  void initState() {
    super.initState();
    _displayedAlerts = List.from(widget.alerts);
  }

  @override
  void didUpdateWidget(AlertContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Add new alerts that aren't already displayed
    for (var alert in widget.alerts) {
      if (!_displayedAlerts.any((a) => a.id == alert.id)) {
        _displayedAlerts.add(alert);
      }
    }
  }

  void _removeAlert(String id) {
    setState(() {
      _displayedAlerts.removeWhere((alert) => alert.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: _displayedAlerts.map((alert) {
          return DismissibleAlert(
            key: ValueKey(alert.id),
            title: alert.title,
            message: alert.message,
            type: alert.type,
            onDismissed: () => _removeAlert(alert.id),
            actionLabel: alert.actionLabel,
            onActionPressed: alert.onAction,
          );
        }).toList(),
      ),
    );
  }
}
