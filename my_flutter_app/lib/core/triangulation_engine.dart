import 'dart:math' as math;

/// Python-style triangulation helper used by radar views.
class TriangulationEngine {
  TriangulationEngine({
    Map<String, ({double x, double y})>? hubPositions,
    this.angleOffsetRad = 0.0,
    this.enableTriangulation = true,
  }) : _hubPositions =
           hubPositions ?? {'hub_0': (x: 0.0, y: 0.0)};

  final Map<String, ({double x, double y})> _hubPositions;
  final double angleOffsetRad;
  final bool enableTriangulation;

  void setHubPosition(String hubId, double x, double y) {
    _hubPositions[hubId] = (x: x, y: y);
  }

  ({double x, double y}) calculatePosition({
    required String serial,
    required Map<String, double> distances,
    int trackerIndex = 0,
    int totalTrackers = 1,
  }) {
    if (!enableTriangulation || distances.isEmpty) {
      return (x: 0.0, y: 0.0);
    }

    final hubIds = distances.keys.toList()..sort();
    final availableHubs = hubIds.where((id) => _hubPositions.containsKey(id)).toList();

    if (availableHubs.length >= 3) {
      final pos = _trilaterateMultiHub(availableHubs, distances);
      if (pos != null) return pos;
    }

    if (availableHubs.isNotEmpty) {
      final hubId = availableHubs.first;
      final hub = _hubPositions[hubId]!;
      final distance = distances[hubId] ?? 0.0;
      final angle = _estimateAngleFromSerial(serial, trackerIndex, totalTrackers);
      return (
        x: hub.x + distance * math.cos(angle),
        y: hub.y + distance * math.sin(angle),
      );
    }

    return (x: 0.0, y: 0.0);
  }

  double _estimateAngleFromSerial(String serial, int index, int totalCount) {
    final hashDeg = _stableSerialHash(serial) % 360;
    var baseAngle = hashDeg * math.pi / 180.0 + angleOffsetRad;
    if (totalCount > 1) {
      baseAngle += (index / totalCount) * 0.3;
    }
    return baseAngle % (2 * math.pi);
  }

  int _stableSerialHash(String input) {
    const int fnvOffset = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    var hash = fnvOffset;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7fffffff;
  }

  ({double x, double y})? _trilaterateMultiHub(
    List<String> hubIds,
    Map<String, double> distances,
  ) {
    final refId = hubIds.first;
    final refHub = _hubPositions[refId];
    if (refHub == null) return null;
    final refDist = distances[refId] ?? 0.0;

    final aRows = <({double a, double b})>[];
    final rhs = <double>[];

    for (final hubId in hubIds.skip(1).take(2)) {
      final hub = _hubPositions[hubId];
      if (hub == null) continue;
      final dist = distances[hubId] ?? 0.0;
      final dx = hub.x - refHub.x;
      final dy = hub.y - refHub.y;
      aRows.add((a: 2 * dx, b: 2 * dy));
      rhs.add(
        dist * dist -
            refDist * refDist +
            refHub.x * refHub.x -
            hub.x * hub.x +
            refHub.y * refHub.y -
            hub.y * hub.y,
      );
    }

    if (aRows.length < 2) return null;

    final a11 = aRows[0].a;
    final a12 = aRows[0].b;
    final a21 = aRows[1].a;
    final a22 = aRows[1].b;
    final b1 = rhs[0];
    final b2 = rhs[1];

    final det = a11 * a22 - a12 * a21;
    if (det.abs() < 1e-10) return null;

    final x = (b1 * a22 - b2 * a12) / det;
    final y = (a11 * b2 - a21 * b1) / det;
    return (x: x, y: y);
  }
}
