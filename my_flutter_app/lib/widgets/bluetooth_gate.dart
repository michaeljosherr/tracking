import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/bluetooth_status_provider.dart';
import 'package:provider/provider.dart';

/// App-wide guard that blocks interaction with [child] whenever Bluetooth is
/// unavailable/off and prompts the user to enable it.
///
/// Intended to be wrapped around the entire `MaterialApp.router` content so it
/// overlays every screen in the app.
class BluetoothGate extends StatelessWidget {
  const BluetoothGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothStatusProvider>(
      builder: (context, bt, _) {
        final blocked = bt.status != BluetoothGateStatus.on &&
            bt.status != BluetoothGateStatus.checking;

        return Stack(
          children: [
            child,
            if (blocked)
              Positioned.fill(
                child: _BluetoothBlockerOverlay(status: bt.status),
              ),
          ],
        );
      },
    );
  }
}

class _BluetoothBlockerOverlay extends StatelessWidget {
  const _BluetoothBlockerOverlay({required this.status});

  final BluetoothGateStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (title, body, canEnable) = switch (status) {
      BluetoothGateStatus.unsupported => (
          'Bluetooth not available',
          "This device doesn't support Bluetooth, so the app can't connect to hubs or trackers.",
          false,
        ),
      BluetoothGateStatus.unauthorized => (
          'Bluetooth permission needed',
          'Allow Bluetooth access in system settings so the app can find and connect to your hub.',
          false,
        ),
      BluetoothGateStatus.off => (
          'Turn on Bluetooth',
          'This app needs Bluetooth to connect to your hubs and trackers. Please enable Bluetooth to continue.',
          true,
        ),
      BluetoothGateStatus.turningOn => (
          'Turning on Bluetooth…',
          'Hang tight — Bluetooth is starting up.',
          false,
        ),
      BluetoothGateStatus.checking || BluetoothGateStatus.on => (
          '',
          '',
          false,
        ),
    };

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primary.withValues(alpha: 0.2),
                              cs.primary.withValues(alpha: 0.08),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: status == BluetoothGateStatus.turningOn
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: cs.primary,
                                ),
                              )
                            : Icon(
                                status == BluetoothGateStatus.unsupported
                                    ? LucideIcons.bluetoothOff
                                    : LucideIcons.bluetooth,
                                size: 34,
                                color: cs.primary,
                              ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      _BluetoothActionRow(
                        status: status,
                        canEnable: canEnable,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BluetoothActionRow extends StatelessWidget {
  const _BluetoothActionRow({
    required this.status,
    required this.canEnable,
  });

  final BluetoothGateStatus status;
  final bool canEnable;

  @override
  Widget build(BuildContext context) {
    final bt = context.read<BluetoothStatusProvider>();

    if (status == BluetoothGateStatus.turningOn) {
      return const SizedBox.shrink();
    }

    if (status == BluetoothGateStatus.off && canEnable && bt.canRequestTurnOn) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => bt.requestTurnOn(),
          icon: const Icon(LucideIcons.bluetooth, size: 18),
          label: const Text('Turn on Bluetooth'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    final helperText = Platform.isIOS
        ? 'Open Settings › Bluetooth to enable.'
        : 'Open system settings to enable Bluetooth.';

    return Text(
      helperText,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
      textAlign: TextAlign.center,
    );
  }
}
