import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:provider/provider.dart';

/// Card representing a single hub instance with its trackers.
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
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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

  Future<void> _renameHub(
    BuildContext context,
    TrackerProvider provider,
  ) async {
    final controller = TextEditingController(text: displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename hub'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Hub name',
            hintText: 'Enter a hub name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (newName == null || !context.mounted) return;

    final cleaned = newName.trim();
    if (cleaned.isEmpty || cleaned == displayName) return;

    await provider.renameHub(hubBleId, cleaned);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hub renamed to $cleaned'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyId(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: hubBleId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hub ID copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.read<TrackerProvider>();
    final summary = provider.getHubStatusSummary(hubBleId);
    final connectionStatus = provider.getHubUiConnectionStatus(hubBleId);
    final hasTrackers = trackerCount > 0;
    final isConnecting = connectionStatus == HubConnectionStatus.connecting;
    final isConnected = connectionStatus == HubConnectionStatus.connected;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;
    final bool headerShowConnectingLoader;

    if (!hasTrackers) {
      // No tags registered — do not use "Disconnected" (that reads like dead hardware).
      if (isConnecting) {
        statusColor = theme.colorScheme.primary;
        statusLabel = 'Connecting to hub...';
        statusIcon = LucideIcons.loader;
        headerShowConnectingLoader = true;
      } else if (isConnected) {
        statusColor = const Color(0xFF0D9488);
        statusLabel = 'Ready — add tags';
        statusIcon = LucideIcons.radioTower;
        headerShowConnectingLoader = false;
      } else {
        statusColor = theme.colorScheme.primary;
        statusLabel = 'No trackers yet';
        statusIcon = LucideIcons.tags;
        headerShowConnectingLoader = false;
      }
    } else if (isConnected) {
      statusColor = const Color(0xFF16A34A);
      statusLabel = 'Connected';
      statusIcon = LucideIcons.badgeCheck;
      headerShowConnectingLoader = false;
    } else if (isConnecting) {
      statusColor = theme.colorScheme.primary;
      statusLabel = 'Connecting...';
      statusIcon = LucideIcons.loader;
      headerShowConnectingLoader = true;
    } else {
      statusColor = const Color(0xFFEA580C);
      statusLabel = 'Disconnected';
      statusIcon = LucideIcons.circleOff;
      headerShowConnectingLoader = false;
    }

    final borderColor =
        statusColor.withValues(alpha: isDark ? 0.35 : 0.25);

    return Material(
      color: theme.cardColor,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Main card surface with gradient + uniform border.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.cardColor,
                  Color.alphaBlend(
                    statusColor.withValues(alpha: isDark ? 0.08 : 0.05),
                    theme.cardColor,
                  ),
                ],
              ),
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: () {
                context.push('/hub/${Uri.encodeComponent(hubBleId)}');
              },
              // Extra left padding so content clears the accent strip.
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Header(
                      displayName: displayName,
                      hubBleId: hubBleId,
                      statusColor: statusColor,
                      statusIcon: statusIcon,
                      statusLabel: statusLabel,
                      isConnecting: headerShowConnectingLoader,
                      onCopy: () => _copyId(context),
                      onRename: () => _renameHub(context, provider),
                      onRemove: () => _confirmRemoveHub(context, provider),
                    ),
                    const SizedBox(height: 14),
                    _TrackerStatsRow(
                      summary: summary,
                      hasTrackers: hasTrackers,
                    ),
                    const SizedBox(height: 12),
                    _Footer(
                      connectedLabel: _formatConnectedTime(),
                      trackerCount: trackerCount,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Left accent strip, painted on top of the card edge.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      statusColor,
                      statusColor.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.displayName,
    required this.hubBleId,
    required this.statusColor,
    required this.statusIcon,
    required this.statusLabel,
    required this.isConnecting,
    required this.onCopy,
    required this.onRename,
    required this.onRemove,
  });

  final String displayName;
  final String hubBleId;
  final Color statusColor;
  final IconData statusIcon;
  final String statusLabel;
  final bool isConnecting;
  final VoidCallback onCopy;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar / hero icon chip
        Stack(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor.withValues(alpha: 0.22),
                    statusColor.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                LucideIcons.radioTower,
                color: statusColor,
                size: 22,
              ),
            ),
            // Live status pip in the corner.
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  border: Border.all(
                    color: theme.cardColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Title block + status pill
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _StatusPill(
                      color: statusColor,
                      icon: statusIcon,
                      label: statusLabel,
                      isConnecting: isConnecting,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.copy,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          hubBleId.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Single overflow menu replaces the cluttered rename/trash duo.
        PopupMenuButton<String>(
          tooltip: 'Hub actions',
          position: PopupMenuPosition.under,
          icon: Icon(
            LucideIcons.ellipsisVertical,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onSelected: (value) {
            switch (value) {
              case 'rename':
                onRename();
                break;
              case 'copy':
                onCopy();
                break;
              case 'remove':
                onRemove();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'rename',
              child: Row(
                children: [
                  Icon(
                    LucideIcons.pencilLine,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  const Text('Rename'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'copy',
              child: Row(
                children: [
                  Icon(
                    LucideIcons.copy,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  const Text('Copy ID'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'remove',
              child: Row(
                children: [
                  Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Remove',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.color,
    required this.icon,
    required this.label,
    required this.isConnecting,
  });

  final Color color;
  final IconData icon;
  final String label;
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          if (isConnecting)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerStatsRow extends StatelessWidget {
  const _TrackerStatsRow({
    required this.summary,
    required this.hasTrackers,
  });

  final ({int connected, int outOfRange, int disconnected}) summary;
  final bool hasTrackers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!hasTrackers) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.packageOpen,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Text(
              'No trackers yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final tileWidth = (constraints.maxWidth - spacing * 2) / 3;
        final stats = [
          _StatDef(
            icon: LucideIcons.wifi,
            count: summary.connected,
            label: 'Connected',
            color: const Color(0xFF16A34A),
          ),
          _StatDef(
            icon: LucideIcons.mapPinOff,
            count: summary.outOfRange,
            label: 'Out of range',
            color: const Color(0xFFEA580C),
          ),
          _StatDef(
            icon: LucideIcons.wifiOff,
            count: summary.disconnected,
            label: 'Disconnected',
            color: const Color(0xFFDC2626),
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final s in stats)
              SizedBox(
                width: tileWidth,
                child: _TrackerStatChip(def: s),
              ),
          ],
        );
      },
    );
  }
}

class _StatDef {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatDef({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });
}

class _TrackerStatChip extends StatelessWidget {
  const _TrackerStatChip({required this.def});
  final _StatDef def;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = def.count > 0;
    final iconColor = isActive
        ? def.color
        : theme.colorScheme.onSurfaceVariant;
    final countColor = isActive
        ? def.color
        : theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? def.color.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? def.color.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(def.icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                def.count.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: countColor,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            def.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.connectedLabel,
    required this.trackerCount,
  });

  final String connectedLabel;
  final int trackerCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          LucideIcons.clock,
          size: 13,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Seen $connectedLabel',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.radio,
                size: 11,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '$trackerCount tracker${trackerCount == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          LucideIcons.chevronRight,
          size: 16,
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }
}
