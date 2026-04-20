import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/device_heading_listener.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:timeago/timeago.dart' as timeago;

// --- Geometry (aligned with tracker_radar.dart) ---

double _dynamicMaxRangeMeters(Tracker t) {
  final d = t.distance;
  if (d != null && d > 0) {
    return (d * 1.45).clamp(8.0, 48.0);
  }
  final s = t.signalStrength.clamp(1, 100);
  return (9.0 + (100 - s) * 0.33).clamp(9.0, 42.0);
}

double _northRadFromDeviceHeading(double? headingDeg) {
  final h = headingDeg ?? 0.0;
  return (360.0 - h) * math.pi / 180.0;
}

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

/// Normalized radius [0..1] for blip position; [displayMaxM] is the **visual** outer ring
/// (can be much smaller than the structural cap so nearby tags do not stack on one ring).
double _normalizedRadiusForBlip(Tracker t, double displayMaxM) {
  if (displayMaxM <= 0) return 0.45;
  if (t.distance != null && t.distance! > 0) {
    final d = t.distance!.clamp(0.05, displayMaxM * 1.02);
    return (d / displayMaxM).clamp(0.06, 1.0);
  }
  final s = t.signalStrength.clamp(1, 100);
  return (1.0 - (s / 100.0) * 0.88).clamp(0.12, 1.0);
}

/// Shrinks the labeled ring when all distances are short so dots spread instead of
/// stacking at the minimum radius on a 24–72 m scale.
double _computeDisplayRingMeters(List<Tracker> trackers, double structuralMax) {
  final dists = trackers
      .where((t) => t.distance != null && t.distance! > 0)
      .map((t) => t.distance!)
      .toList();
  if (dists.isEmpty) return structuralMax;
  final minD = dists.reduce(math.min);
  final maxD = dists.reduce(math.max);
  final spread = math.max(maxD * 1.5, math.max(minD * 7.0, 2.5));
  return math.min(structuralMax, spread).clamp(1.0, structuralMax);
}

double _blipOpacity(Tracker t) {
  switch (t.status) {
    case TrackerStatus.connected:
      return 1.0;
    case TrackerStatus.outOfRange:
      return 0.55;
    case TrackerStatus.disconnected:
      return 0.3;
  }
}

Duration _sweepDurationForList(List<Tracker> trackers) {
  if (trackers.isEmpty) return const Duration(milliseconds: 4000);
  final avg = trackers
          .map((t) => t.signalStrength.clamp(0, 100))
          .fold<int>(0, (a, b) => a + b) /
      trackers.length;
  final ms = (2350 + (100 - avg) * 28).round().clamp(2200, 5200);
  return Duration(milliseconds: ms);
}

Color _blipColor(int index, int total, Color primary, bool isDark) {
  if (total <= 1) return primary;
  final t = index / (total - 1);
  final h = 210.0 + t * 120.0;
  return HSLColor.fromAHSL(1, h, 0.72, isDark ? 0.62 : 0.48).toColor();
}

// =============================================================================
// Triangulation & Position Calculation
// =============================================================================

/// Calculate actual Cartesian positions of all trackers relative to phone (at origin).
/// Returns list of (tracker, bearingRad, pixelPosition in radar space) tuples.
/// Used for collision detection to ensure all trackers are visible on the radar.
List<({Tracker tracker, double bearing, Offset pixelPos})> _calculateTrackerPositions(
  List<Tracker> trackers,
  double? deviceHeadingDeg,
  double maxRingPixels,
  double displayRingMeters,
) {
  final result = <({Tracker tracker, double bearing, Offset pixelPos})>[];

  for (final t in trackers) {
    var bearing = _blipBearingRad(t, deviceHeadingDeg);
    final nr = _normalizedRadiusForBlip(t, displayRingMeters);
    final pixelDist = maxRingPixels * nr;
    final pixelPos = Offset(
      pixelDist * math.sin(bearing),
      -pixelDist * math.cos(bearing),
    );
    result.add((tracker: t, bearing: bearing, pixelPos: pixelPos));
  }

  return result;
}

/// Detect and resolve collisions between tracker blips.
/// Returns adjusted bearing offsets for each tracker to prevent overlaps.
/// Collision radius in pixels.
List<double> _resolveBlipCollisions(
  List<({Tracker tracker, double bearing, Offset pixelPos})> positions,
  double collisionRadiusPx,
) {
  final offsets = List<double>.filled(positions.length, 0.0);
  final n = positions.length;

  if (n <= 1) return offsets;

  // Simple iterative collision resolution:
  // For each pair of overlapping blips, apply opposing bearing offsets
  for (var iter = 0; iter < 3; iter++) {
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final pi = positions[i].pixelPos + Offset(
          positions[i].pixelPos.dx * offsets[i] * 0.05,
          positions[i].pixelPos.dy * offsets[i] * 0.05,
        );
        final pj = positions[j].pixelPos + Offset(
          positions[j].pixelPos.dx * offsets[j] * 0.05,
          positions[j].pixelPos.dy * offsets[j] * 0.05,
        );
        final dist = (pi - pj).distance;

        if (dist < collisionRadiusPx * 2.2) {
          // Blips overlap - apply repulsive force
          final separationNeeded = (collisionRadiusPx * 2.2 - dist) / collisionRadiusPx;
          offsets[i] -= separationNeeded * 0.08;
          offsets[j] += separationNeeded * 0.08;
        }
      }
    }
  }

  // Clamp offsets to reasonable range
  for (var i = 0; i < offsets.length; i++) {
    offsets[i] = offsets[i].clamp(-0.35, 0.35);
  }

  return offsets;
}

/// Single radar scope showing every registered [Tracker] as its own blip.
class AllTrackersRadarPanel extends StatefulWidget {
  const AllTrackersRadarPanel({super.key, required this.trackers});

  final List<Tracker> trackers;

  @override
  State<AllTrackersRadarPanel> createState() => _AllTrackersRadarPanelState();
}

class _AllTrackersRadarPanelState extends State<AllTrackersRadarPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: _sweepDurationForList(widget.trackers),
    )..repeat();

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DeviceHeadingStore.ensureStarted();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AllTrackersRadarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _sweepDurationForList(widget.trackers);
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
    final trackers = List<Tracker>.from(widget.trackers)
      ..sort((a, b) => a.name.compareTo(b.name));

    double structuralMax = 24.0;
    for (final t in trackers) {
      structuralMax = math.max(structuralMax, _dynamicMaxRangeMeters(t));
    }
    structuralMax = structuralMax.clamp(12.0, 72.0);
    final displayRing = _computeDisplayRingMeters(trackers, structuralMax);
    final scaleLabel = displayRing < 10
        ? displayRing.toStringAsFixed(1)
        : displayRing.round().toString();

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
                    'All trackers',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                deviceHeadingDeg != null
                    ? 'Each dot is one registered tracker · N/E/S/W = magnetic · ring scale ≈ $scaleLabel m (zooms in when tags are close)'
                    : 'Heading unavailable — N/E/S/W fixed to screen; move phone in a figure‑8 to calibrate.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final paintSize = math.min(constraints.maxWidth, 300.0);
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
                              painter: _MultiTrackerRadarPainter(
                                trackers: trackers,
                                sweepRadians:
                                    _sweepController.value * 2 * math.pi,
                                isDark: isDark,
                                primary: theme.colorScheme.primary,
                                displayRingMeters: displayRing,
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
              if (trackers.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < trackers.length; i++)
                      _LegendChip(
                        tracker: trackers[i],
                        color: _blipColor(
                          i,
                          trackers.length,
                          theme.colorScheme.primary,
                          isDark,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Tracker details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...[
                  for (var i = 0; i < trackers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AllTrackersRadarDetailCard(
                        tracker: trackers[i],
                        dotColor: _blipColor(
                          i,
                          trackers.length,
                          theme.colorScheme.primary,
                          isDark,
                        ),
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AllTrackersRadarDetailCard extends StatelessWidget {
  const _AllTrackersRadarDetailCard({
    required this.tracker,
    required this.dotColor,
  });

  final Tracker tracker;
  final Color dotColor;

  String _statusLabel(TrackerStatus s) {
    switch (s) {
      case TrackerStatus.connected:
        return 'Connected';
      case TrackerStatus.outOfRange:
        return 'Out of range';
      case TrackerStatus.disconnected:
        return 'Disconnected';
    }
  }

  Color _statusColor(TrackerStatus s) {
    switch (s) {
      case TrackerStatus.connected:
        return const Color(0xFF16A34A);
      case TrackerStatus.outOfRange:
        return const Color(0xFFEA580C);
      case TrackerStatus.disconnected:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dist = tracker.distance;
    final distStr =
        dist != null ? '${dist.toStringAsFixed(1)} m est.' : '—';

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/tracker/${tracker.id}'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tracker.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(tracker.status)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(tracker.status),
                      style: TextStyle(
                        color: _statusColor(tracker.status),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _detailLine(theme, 'Device ID', tracker.deviceId),
              if (tracker.serialNumber != null && tracker.serialNumber!.isNotEmpty)
                _detailLine(theme, 'Serial', tracker.serialNumber!),
              _detailLine(theme, 'Distance', distStr),
              _detailLine(
                theme,
                'Signal',
                '${tracker.signalStrength}%',
              ),
              if (tracker.rssi != null)
                _detailLine(theme, 'RSSI', '${tracker.rssi} dBm'),
              if (tracker.rssiFiltered != null)
                _detailLine(
                  theme,
                  'RSSI (filtered)',
                  '${tracker.rssiFiltered!.toStringAsFixed(1)} dBm',
                ),
              if (tracker.batteryLevel != null)
                _detailLine(theme, 'Battery', '${tracker.batteryLevel}%'),
              _detailLine(
                theme,
                'Last seen',
                timeago.format(tracker.lastSeen),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Open tracker',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: cs.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.tracker, required this.color});

  final Tracker tracker;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = tracker.distance;
    final dist = d != null ? '${d.toStringAsFixed(1)} m' : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            tracker.name,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            dist,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MultiTrackerRadarPainter extends CustomPainter {
  _MultiTrackerRadarPainter({
    required this.trackers,
    required this.sweepRadians,
    required this.isDark,
    required this.primary,
    required this.displayRingMeters,
    required this.deviceHeadingDeg,
  });

  final List<Tracker> trackers;
  final double sweepRadians;
  final bool isDark;
  final Color primary;
  /// Labeled outer ring distance (may be zoomed in when tags are close together).
  final double displayRingMeters;
  final double? deviceHeadingDeg;

  static String _formatRingM(double meters) {
    if (meters >= 10) return '${meters.round()}m';
    return '${meters.toStringAsFixed(1)}m';
  }

  void _drawLabel(Canvas canvas, String text, Offset at, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
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

    final n = trackers.length;
    final pulse = 1.0 + 0.06 * math.sin(sweepRadians * 3);
    final blipR = n > 4 ? 6.0 : 7.5;

    // Calculate positions and resolve collisions using triangulation
    final positions = _calculateTrackerPositions(
      trackers,
      deviceHeadingDeg,
      maxR,
      displayRingMeters,
    );
    final collisionOffsets = _resolveBlipCollisions(positions, blipR + 4.0);

    for (var i = 0; i < n; i++) {
      final t = trackers[i];
      final hueColor = _blipColor(i, n, primary, isDark);
      var bearing = _blipBearingRad(t, deviceHeadingDeg);
      
      // Apply collision offset to bearing for 3+ trackers
      bearing += collisionOffsets[i];
      
      final nr = _normalizedRadiusForBlip(t, displayRingMeters);
      final br = maxR * nr * pulse;
      final blip = Offset(
        c.dx + br * math.sin(bearing),
        c.dy - br * math.cos(bearing),
      );
      final opacity = _blipOpacity(t);

      final glow = Paint()
        ..color = hueColor.withValues(alpha: 0.22 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(blip, blipR + 6, glow);

      canvas.drawCircle(
        blip,
        blipR,
        Paint()..color = hueColor.withValues(alpha: opacity),
      );
      canvas.drawCircle(
        blip,
        blipR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.85 * opacity),
      );
    }

    final labelStyle = TextStyle(
      fontSize: 10,
      color: primary.withValues(alpha: isDark ? 0.55 : 0.65),
      fontWeight: FontWeight.w500,
    );
    final r1 = displayRingMeters / 3;
    final r2 = displayRingMeters * 2 / 3;
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
      _formatRingM(displayRingMeters),
      Offset(c.dx + 4, c.dy - maxR + 2),
      labelStyle,
    );
  }

  @override
  bool shouldRepaint(covariant _MultiTrackerRadarPainter oldDelegate) {
    if (oldDelegate.sweepRadians != sweepRadians ||
        oldDelegate.isDark != isDark ||
        oldDelegate.displayRingMeters != displayRingMeters ||
        oldDelegate.deviceHeadingDeg != deviceHeadingDeg) {
      return true;
    }
    if (oldDelegate.trackers.length != trackers.length) return true;
    for (var i = 0; i < trackers.length; i++) {
      final a = oldDelegate.trackers[i];
      final b = trackers[i];
      if (a.id != b.id ||
          a.distance != b.distance ||
          a.signalStrength != b.signalStrength ||
          a.status != b.status ||
          a.tagCompassBearingDeg != b.tagCompassBearingDeg) {
        return true;
      }
    }
    return false;
  }
}
