import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ExpandableTrackerCard extends StatefulWidget {
  final String name;
  final String deviceId;
  final String status;
  final double signalStrength;
  final double batteryLevel;
  final String? lastSeen;
  final VoidCallback? onPair;

  const ExpandableTrackerCard({
    super.key,
    required this.name,
    required this.deviceId,
    required this.status,
    required this.signalStrength,
    required this.batteryLevel,
    this.lastSeen,
    this.onPair,
  });

  @override
  State<ExpandableTrackerCard> createState() => _ExpandableTrackerCardState();
}

class _ExpandableTrackerCardState extends State<ExpandableTrackerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(parent: _expandController, curve: Curves.easeInOut);
    super.initState();
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (widget.status.toLowerCase()) {
      case 'available':
        statusColor = Colors.green;
        statusIcon = LucideIcons.radioTower;
        break;
      case 'unavailable':
        statusColor = Colors.red;
        statusIcon = LucideIcons.wifiOff;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.info_outline;
        break;
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(_isExpanded ? 0 : 12),
                bottomRight: Radius.circular(_isExpanded ? 0 : 12),
              ),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.deviceId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                // Signal & Battery Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.signalStrength > 70
                              ? LucideIcons.signalHigh
                              : widget.signalStrength > 40
                                  ? LucideIcons.signalMedium
                                  : LucideIcons.signalLow,
                          size: 16,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.signalStrength.toInt()}%',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          widget.batteryLevel > 30 ? LucideIcons.battery : LucideIcons.batteryWarning,
                          size: 16,
                          color: widget.batteryLevel > 30
                              ? const Color(0xFF2563EB)
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.batteryLevel.toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.batteryLevel > 30
                                ? const Color(0xFF64748B)
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Expand Icon
                RotationTransition(
                  turns: _expandAnimation,
                  child: Icon(
                    LucideIcons.chevronDown,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded Details
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(
                left: const BorderSide(color: Color(0xFFE2E8F0)),
                right: const BorderSide(color: Color(0xFFE2E8F0)),
                bottom: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Device ID Detail
                  _DetailRow(
                    label: 'Device ID',
                    value: widget.deviceId,
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 12),

                  // Status Detail
                  _DetailRow(
                    label: 'Status',
                    value: widget.status,
                    icon: LucideIcons.radioTower,
                  ),
                  const SizedBox(height: 12),

                  // Signal Strength Detail
                  _DetailRow(
                    label: 'Signal Strength',
                    value: '${widget.signalStrength.toInt()}%',
                    icon: LucideIcons.signalMedium,
                  ),
                  const SizedBox(height: 12),

                  // Battery Detail
                  _DetailRow(
                    label: 'Battery Level',
                    value: '${widget.batteryLevel.toInt()}%',
                    icon: LucideIcons.battery,
                  ),

                  if (widget.lastSeen != null) ...[
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Last Seen',
                      value: widget.lastSeen!,
                      icon: LucideIcons.clock,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(LucideIcons.info, size: 18),
                          label: const Text('Details'),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(LucideIcons.plus, size: 18),
                          label: const Text('Pair Device'),
                          onPressed: widget.onPair,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
