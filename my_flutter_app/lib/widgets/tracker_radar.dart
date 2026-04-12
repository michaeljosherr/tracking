import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/device_heading_listener.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:provider/provider.dart';

double _dynamicMaxRangeMeters(Tracker t) {
  final d = t.distance;
  if (d != null && d > 0) {
    return (d * 1.45).clamp(8.0, 48.0);
  }
  final s = t.signalStrength.clamp(1, 100);
  return (9.0 + (100 - s) * 0.33).clamp(9.0, 42.0);
}

/// Radians: 0 = screen up, clockwise positive. Where magnetic north sits relative to phone top.
double _northRadFromDeviceHeading(double? headingDeg) {
  final h = headingDeg ?? 0.0;
  return (360.0 - h) * math.pi / 180.0;
}

/// Blip angle (rad, 0 = screen up, CW): tag vs phone when calibrated; else stable hash.
double _blipBearingRad(Tracker tracker, double? deviceHeadingDeg) {
  final T = tracker.tagCompassBearingDeg;
  final H = deviceHeadingDeg;
  if (T != null && H != null) {
    var d = T - H;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return d * math.pi / 180.0;
  }
  final key = tracker.serialNumber ?? tracker.id;
  final h = key.hashCode;
  final t = (h.abs() % 10000) / 10000.0;
  return t * 2 * math.pi;
}

Duration _dynamicSweepDuration(Tracker t) {
  if (t.status == TrackerStatus.disconnected) {
    return const Duration(milliseconds: 6400);
  }
  if (t.status == TrackerStatus.outOfRange) {
    return const Duration(milliseconds: 5000);
  }
  final s = t.signalStrength.clamp(0, 100);
  final ms = (2350 + (100 - s) * 32).round().clamp(2200, 5600);
  return Duration(milliseconds: ms);
}

/// Magnetic N/E/S/W. Tag bearing is **auto-estimated** when the tag is very close / very strong
/// RSSI, then the blip tracks phone rotation via fused heading.
class TrackerRadarPanel extends StatefulWidget {
  const TrackerRadarPanel({super.key, required this.tracker});

  final Tracker tracker;

  @override
  State<TrackerRadarPanel> createState() => _TrackerRadarPanelState();
}

class _TrackerRadarPanelState extends State<TrackerRadarPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: _dynamicSweepDuration(widget.tracker),
    )..repeat();

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DeviceHeadingStore.ensureStarted();
      });
    }
  }

  @override
  void didUpdateWidget(covariant TrackerRadarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _dynamicSweepDuration(widget.tracker);
    if (_sweepController.duration != next) {
      _sweepController.duration = next;
      _sweepController.repeat();
    }
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
    final maxRange = _dynamicMaxRangeMeters(widget.tracker);

    return ValueListenableBuilder<double?>(
      valueListenable: DeviceHeadingStore.heading,
      builder: (context, deviceHeadingDeg, _) {
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
                  Icon(
                    LucideIcons.scanSearch,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
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
                deviceHeadingDeg != null
                    ? 'N/E/S/W = magnetic · distance from RSSI · tag bearing auto when very close / strong signal'
                    : 'Heading unavailable — hold phone steady or move in a figure‑8; N/E/S/W fixed to screen',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
              if (deviceHeadingDeg != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.tracker.tagCompassBearingDeg == null
                      ? 'Walk closer (~1 m) or until signal is very strong — direction locks automatically.'
                      : 'Blip uses locked tag bearing vs your compass — rotate the phone to aim at the tag.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final paintSize = math.min(constraints.maxWidth, 260.0);
                  final stage = paintSize * 1.22;
                  return Center(
                    child: SizedBox(
                      width: stage,
                      height: stage,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _sweepController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(paintSize, paintSize),
                              painter: _TrackerRadarPainter(
                                tracker: widget.tracker,
                                sweepRadians: _sweepController.value * 2 * math.pi,
                                isDark: isDark,
                                primary: theme.colorScheme.primary,
                                maxRingMeters: maxRange,
                                deviceHeadingDeg: deviceHeadingDeg,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (!kIsWeb)
                _RadarCalibrationBar(
                  tracker: widget.tracker,
                  deviceHeadingDeg: deviceHeadingDeg,
                ),
              const SizedBox(height: 12),
              _LegendRow(tracker: widget.tracker, theme: theme),
            ],
          ),
        );
      },
    );
  }
}

class _RadarCalibrationBar extends StatelessWidget {
  const _RadarCalibrationBar({
    required this.tracker,
    required this.deviceHeadingDeg,
  });

  final Tracker tracker;
  final double? deviceHeadingDeg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tracker.tagCompassBearingDeg != null)
          TextButton.icon(
            onPressed: () async {
              HapticFeedback.lightImpact();
              await context.read<TrackerProvider>().clearTrackerTagCompassBearing(tracker.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tag direction cleared — it will auto-lock again when very close.')),
              );
            },
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Clear tag direction'),
          ),
        if (deviceHeadingDeg == null)
          Padding(
            padding: EdgeInsets.only(top: tracker.tagCompassBearingDeg != null ? 4 : 0),
            child: Text(
              'Waiting for motion sensors — tilt away from flat, move in a figure‑8, or step away from strong magnets.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
      ],
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
    final ring = _dynamicMaxRangeMeters(tracker).round();
    final cal = tracker.tagCompassBearingDeg != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dot(theme.colorScheme.primary, live ? 1.0 : 0.35),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            live
                ? 'Tracker $distLabel · ${tracker.signalStrength}% · ~${ring}m scale'
                    '${cal ? ' · direction locked (auto)' : ''}'
                : 'No live signal — last $distLabel · ~${ring}m scale'
                    '${cal ? ' · direction locked (auto)' : ''}',
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
    required this.maxRingMeters,
    required this.deviceHeadingDeg,
  });

  final Tracker tracker;
  final double sweepRadians;
  final bool isDark;
  final Color primary;
  final double maxRingMeters;
  final double? deviceHeadingDeg;

  double _normalizedRadius() {
    if (tracker.distance != null && tracker.distance! > 0) {
      final d = tracker.distance!.clamp(0.05, maxRingMeters);
      return (d / maxRingMeters).clamp(0.12, 1.0);
    }
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

  static String _formatRingM(double meters) {
    if (meters >= 10) return '${meters.round()}m';
    return '${meters.toStringAsFixed(1)}m';
  }

  void _drawLabelCentered(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  void _drawCardinalsAndTicks(
    Canvas canvas,
    Offset c,
    double maxR,
    TextStyle letterStyle,
    Paint tickPaint,
    double northRad,
  ) {
    const labels = ['N', 'E', 'S', 'W'];
    for (var i = 0; i < 4; i++) {
      final a = northRad + i * math.pi / 2;
      final outer = Offset(
        c.dx + maxR * math.sin(a),
        c.dy - maxR * math.cos(a),
      );
      final inner = Offset(
        c.dx + (maxR - 7) * math.sin(a),
        c.dy - (maxR - 7) * math.cos(a),
      );
      canvas.drawLine(inner, outer, tickPaint);
      final labelR = maxR + 14;
      final pos = Offset(
        c.dx + labelR * math.sin(a),
        c.dy - labelR * math.cos(a),
      );
      _drawLabelCentered(canvas, labels[i], pos, letterStyle);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2 - 22;

    final base = isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF);
    final ringColor = primary.withValues(alpha: isDark ? 0.22 : 0.18);
    final gridColor = primary.withValues(alpha: isDark ? 0.12 : 0.1);

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

    final crossPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - maxR, c.dy), Offset(c.dx + maxR, c.dy), crossPaint);
    canvas.drawLine(Offset(c.dx, c.dy - maxR), Offset(c.dx, c.dy + maxR), crossPaint);

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

    final northRad = _northRadFromDeviceHeading(deviceHeadingDeg);

    final cardinalStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: primary.withValues(alpha: isDark ? 0.92 : 0.88),
    );
    final tickPaint = Paint()
      ..color = primary.withValues(alpha: isDark ? 0.45 : 0.4)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    _drawCardinalsAndTicks(
      canvas,
      c,
      maxR,
      cardinalStyle,
      tickPaint,
      northRad,
    );

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
          Offset(
            c.dx + maxR * math.sin(sweepRadians),
            c.dy - maxR * math.cos(sweepRadians),
          ),
          [
            primary.withValues(alpha: 0.0),
            primary.withValues(alpha: 0.22),
          ],
        ),
    );

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

    final bearing = _blipBearingRad(tracker, deviceHeadingDeg);
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

    final labelStyle = TextStyle(
      fontSize: 10,
      color: primary.withValues(alpha: isDark ? 0.55 : 0.65),
      fontWeight: FontWeight.w500,
    );
    final r1 = maxRingMeters / 3;
    final r2 = maxRingMeters * 2 / 3;
    _drawLabel(
      canvas,
      _formatRingM(r1),
      Offset(c.dx + 4, c.dy - maxR / 3 + 2),
      labelStyle,
    );
    _drawLabel(
      canvas,
      _formatRingM(r2),
      Offset(c.dx + 4, c.dy - 2 * maxR / 3 + 2),
      labelStyle,
    );
    _drawLabel(
      canvas,
      _formatRingM(maxRingMeters),
      Offset(c.dx + 4, c.dy - maxR + 2),
      labelStyle,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackerRadarPainter oldDelegate) {
    final o = oldDelegate.tracker;
    return oldDelegate.sweepRadians != sweepRadians ||
        oldDelegate.isDark != isDark ||
        oldDelegate.maxRingMeters != maxRingMeters ||
        oldDelegate.deviceHeadingDeg != deviceHeadingDeg ||
        o.distance != tracker.distance ||
        o.signalStrength != tracker.signalStrength ||
        o.status != tracker.status ||
        o.serialNumber != tracker.serialNumber ||
        o.id != tracker.id ||
        o.tagCompassBearingDeg != tracker.tagCompassBearingDeg;
  }
}
