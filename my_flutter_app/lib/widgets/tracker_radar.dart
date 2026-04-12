import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/models/mock_data.dart';

/// BLE does not provide compass bearing; rings show estimated distance only.
/// Blip angle is stable per tracker (hash) so the UI does not jump between frames.
class TrackerRadarPanel extends StatefulWidget {
  const TrackerRadarPanel({super.key, required this.tracker});

  final Tracker tracker;

  @override
  State<TrackerRadarPanel> createState() => _TrackerRadarPanelState();
}

class _TrackerRadarPanelState extends State<TrackerRadarPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.scanSearch, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Proximity radar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Distance from RSSI · direction is illustrative (no compass)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(constraints.maxWidth, 280.0);
              return Center(
                child: AnimatedBuilder(
                  animation: _sweepController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(size, size),
                      painter: _TrackerRadarPainter(
                        tracker: widget.tracker,
                        sweepRadians: _sweepController.value * 2 * math.pi,
                        isDark: isDark,
                        primary: theme.colorScheme.primary,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _LegendRow(tracker: widget.tracker, theme: theme),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.tracker, required this.theme});

  final Tracker tracker;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final dist = tracker.distance;
    final distLabel = dist != null ? '${dist.toStringAsFixed(1)} m est.' : '—';
    final live = tracker.status == TrackerStatus.connected;

    return Row(
      children: [
        _dot(theme.colorScheme.primary, live ? 1.0 : 0.35),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            live
                ? 'Tracker $distLabel · ${tracker.signalStrength}% signal'
                : 'No live signal — last estimate $distLabel',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }

  static Widget _dot(Color c, double opacity) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.35 * opacity),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _TrackerRadarPainter extends CustomPainter {
  _TrackerRadarPainter({
    required this.tracker,
    required this.sweepRadians,
    required this.isDark,
    required this.primary,
  });

  final Tracker tracker;
  final double sweepRadians;
  final bool isDark;
  final Color primary;

  static const double _maxRingMeters = 12.0;

  double _stableBearingRadians() {
    final key = tracker.serialNumber ?? tracker.id;
    final h = key.hashCode;
    final t = (h.abs() % 10000) / 10000.0;
    return t * 2 * math.pi;
  }

  /// Normalized radius in [0.12, 1.0] where 1.0 is outer ring.
  double _normalizedRadius() {
    if (tracker.distance != null && tracker.distance! > 0) {
      final d = tracker.distance!.clamp(0.05, _maxRingMeters);
      return (d / _maxRingMeters).clamp(0.12, 1.0);
    }
    // Stronger signal → closer to center
    final s = tracker.signalStrength.clamp(1, 100);
    return (1.0 - (s / 100.0) * 0.88).clamp(0.12, 1.0);
  }

  double _blipOpacity() {
    switch (tracker.status) {
      case TrackerStatus.connected:
        return 1.0;
      case TrackerStatus.outOfRange:
        return 0.55;
      case TrackerStatus.disconnected:
        return 0.3;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2 - 8;

    final base = isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF);
    final ringColor = primary.withValues(alpha: isDark ? 0.22 : 0.18);
    final gridColor = primary.withValues(alpha: isDark ? 0.12 : 0.1);

    // Background disc
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        c,
        maxR,
        [
          base,
          isDark ? const Color(0xFF020617) : const Color(0xFFDBEAFE),
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(c, maxR, bgPaint);

    // Crosshair
    final crossPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - maxR, c.dy), Offset(c.dx + maxR, c.dy), crossPaint);
    canvas.drawLine(Offset(c.dx, c.dy - maxR), Offset(c.dx, c.dy + maxR), crossPaint);

    // Rings at 4m, 8m, 12m
    for (var i = 1; i <= 3; i++) {
      final r = maxR * (i / 3);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ringColor,
      );
    }

    // Sweep wedge
    const sweepHalf = math.pi / 5;
    final path = Path()..moveTo(c.dx, c.dy);
    for (double a = -sweepHalf; a <= sweepHalf; a += 0.08) {
      final ang = sweepRadians + a;
      final p = Offset(
        c.dx + maxR * math.sin(ang),
        c.dy - maxR * math.cos(ang),
      );
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          c,
          Offset(c.dx + maxR * math.sin(sweepRadians), c.dy - maxR * math.cos(sweepRadians)),
          [
            primary.withValues(alpha: 0.0),
            primary.withValues(alpha: 0.22),
          ],
        ),
    );

    // Center (you)
    canvas.drawCircle(
      c,
      6,
      Paint()..color = isDark ? Colors.white70 : Colors.white,
    );
    canvas.drawCircle(
      c,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = primary.withValues(alpha: 0.6),
    );

    // Blip
    final bearing = _stableBearingRadians();
    final nr = _normalizedRadius();
    final pulse = 1.0 + 0.08 * math.sin(sweepRadians * 3);
    final br = maxR * nr * pulse;
    final blip = Offset(
      c.dx + br * math.sin(bearing),
      c.dy - br * math.cos(bearing),
    );
    final opacity = _blipOpacity();

    final glow = Paint()
      ..color = primary.withValues(alpha: 0.25 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(blip, 14, glow);

    canvas.drawCircle(
      blip,
      8,
      Paint()..color = primary.withValues(alpha: opacity),
    );
    canvas.drawCircle(
      blip,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.85 * opacity),
    );

    // Ring labels (4m, 8m, 12m)
    final labelStyle = TextStyle(
      fontSize: 10,
      color: primary.withValues(alpha: isDark ? 0.55 : 0.65),
      fontWeight: FontWeight.w500,
    );
    _drawLabel(canvas, '${(_maxRingMeters / 3).round()}m', Offset(c.dx + 4, c.dy - maxR / 3 + 2), labelStyle);
    _drawLabel(canvas, '${(_maxRingMeters * 2 / 3).round()}m', Offset(c.dx + 4, c.dy - 2 * maxR / 3 + 2), labelStyle);
    _drawLabel(canvas, '${_maxRingMeters.round()}m', Offset(c.dx + 4, c.dy - maxR + 2), labelStyle);
  }

  void _drawLabel(Canvas canvas, String text, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _TrackerRadarPainter oldDelegate) {
    final o = oldDelegate.tracker;
    return oldDelegate.sweepRadians != sweepRadians ||
        oldDelegate.isDark != isDark ||
        o.distance != tracker.distance ||
        o.signalStrength != tracker.signalStrength ||
        o.status != tracker.status ||
        o.serialNumber != tracker.serialNumber ||
        o.id != tracker.id;
  }
}
