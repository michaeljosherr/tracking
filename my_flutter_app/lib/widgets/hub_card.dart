import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:provider/provider.dart';

/// Card representing a single hub instance with its trackers
class HubCard extends StatelessWidget {
  final String hubBleId;
  final String displayName;
  final DateTime connectedAt;
  final int trackerCount;

  const HubCard({
    super.key,
    required this.hubBleId,
    required this.displayName,
    required this.connectedAt,
    required this.trackerCount,
  });

  String _formatConnectedTime() {
    final now = DateTime.now();
    final diff = now.difference(connectedAt);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Future<void> _confirmRemoveHub(
    BuildContext context,
    TrackerProvider provider,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove hub?'),
        content: const Text(
          'This removes the hub card and deletes all trackers registered to this hub on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    await provider.removeHubConnection(hubBleId);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$displayName removed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<TrackerProvider>();
    final summary = provider.getHubStatusSummary(hubBleId);
    final connectionStatus = provider.getHubConnectionStatus(hubBleId);
    final hasTrackers = trackerCount > 0;
    final allConnected = summary.disconnected == 0 && summary.outOfRange == 0 && summary.connected > 0;
    final isConnecting = connectionStatus == HubConnectionStatus.connecting;
    final isConnected = connectionStatus == HubConnectionStatus.connected;
    final statusColor = isConnected
        ? const Color(0xFF16A34A)
        : isConnecting
            ? theme.colorScheme.primary
            : hasTrackers
                ? const Color(0xFFEA580C)
                : const Color(0xFFDC2626);
    final statusLabel = isConnected
        ? 'Connected'
        : isConnecting
            ? 'Connecting...'
            : 'Disconnected';

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push('/hub/${Uri.encodeComponent(hubBleId)}');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Hub name + status indicator
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: allConnected && hasTrackers && isConnected
                          ? const Color(0xFF16A34A)
                          : statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hubBleId.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove hub',
                    onPressed: () => _confirmRemoveHub(context, provider),
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: isConnecting
                          ? CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: theme.colorScheme.primary,
                            )
                          : Icon(
                              isConnected
                                  ? LucideIcons.badgeCheck
                                  : LucideIcons.circleOff,
                              size: 16,
                              color: statusColor,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Tracker summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: hasTrackers
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _TrackerStat(
                            count: summary.connected,
                            label: 'Connected',
                            color: const Color(0xFF16A34A),
                          ),
                          _TrackerStat(
                            count: summary.outOfRange,
                            label: 'Out of range',
                            color: const Color(0xFFEA580C),
                          ),
                          _TrackerStat(
                            count: summary.disconnected,
                            label: 'Disconnected',
                            color: const Color(0xFFDC2626),
                          ),
                        ],
                      )
                    : Center(
                        child: Text(
                          'No trackers yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 10),

              // Footer: Connected time
              Row(
                children: [
                  Icon(
                    LucideIcons.clock,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connected ${_formatConnectedTime()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$trackerCount tracker${trackerCount != 1 ? 's' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackerStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _TrackerStat({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          count.toString(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
