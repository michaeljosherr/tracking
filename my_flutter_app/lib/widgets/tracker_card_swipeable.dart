import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/models/mock_data.dart';

/// Enhanced tracker card with swipe-to-action functionality
class TrackerCardSwipeable extends StatefulWidget {
  final Tracker tracker;
  final VoidCallback? onRename;
  final VoidCallback? onRemove;

  const TrackerCardSwipeable({
    super.key,
    required this.tracker,
    this.onRename,
    this.onRemove,
  });

  @override
  State<TrackerCardSwipeable> createState() => _TrackerCardSwipeableState();
}

class _TrackerCardSwipeableState extends State<TrackerCardSwipeable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0;
  static const double _actionWidth = 80;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = details.delta.dx;
    });

    // Trigger action at threshold
    if (_dragOffset < -_actionWidth && !_controller.isAnimating) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset < -_actionWidth) {
      setState(() => _dragOffset = -_actionWidth);
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  void _executeAction(VoidCallback? callback) {
    HapticFeedback.lightImpact();
    callback?.call();
    setState(() => _dragOffset = 0);
  }

  Color _getStatusColor() {
    switch (widget.tracker.status) {
      case TrackerStatus.connected:
        return Colors.green.shade600;
      case TrackerStatus.outOfRange:
        return Colors.orange.shade600;
      case TrackerStatus.disconnected:
        return Colors.red.shade600;
    }
  }

  Color _getStatusBgColor() {
    switch (widget.tracker.status) {
      case TrackerStatus.connected:
        return Colors.green.shade50;
      case TrackerStatus.outOfRange:
        return Colors.orange.shade50;
      case TrackerStatus.disconnected:
        return Colors.red.shade50;
    }
  }

  String _getStatusText() {
    switch (widget.tracker.status) {
      case TrackerStatus.connected:
        return 'Connected';
      case TrackerStatus.outOfRange:
        return 'Out of Range';
      case TrackerStatus.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: Stack(
          children: [
            // Swipe action background
            if (_dragOffset < 0)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: (-_dragOffset).clamp(0, _actionWidth * 2).toDouble(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if ((-_dragOffset).clamp(0, _actionWidth).toDouble() > 30)
                        GestureDetector(
                          onTap: () => _executeAction(widget.onRemove),
                          child: Container(
                            width: _actionWidth,
                            color: Colors.red.shade600,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.trash2,
                                    color: Colors.white, size: 20),
                                SizedBox(height: 4),
                                Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            // Main card content
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/tracker/${widget.tracker.id}');
                },
                splashColor: const Color(0xFF2563EB).withOpacity(0.1),
                highlightColor: const Color(0xFF2563EB).withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.tracker.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusBgColor(),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _getStatusText(),
                                        style: TextStyle(
                                          color: _getStatusColor(),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${widget.tracker.deviceId}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.signalHigh,
                                  size: 14,
                                  color: widget.tracker.signalStrength >= 70
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.tracker.signalStrength}%',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.tracker.batteryLevel != null)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.battery,
                                    size: 14,
                                    color: widget.tracker.batteryLevel! >= 60
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.tracker.batteryLevel}%',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_dragOffset == 0)
                        Text(
                          'Swipe left to remove',
                          style:
                              const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
