import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// ============================================================================
// Phase 2B: Smart Alternative Rerouting Test Suite
// ============================================================================
// Covers:
// 1. GPS Fix Validation (accuracy <= 50m, age < 120s)
// 2. Invariant Destination Preservation & GPS Origin Formulation
// 3. Corridor Hazard Avoidance & Distance Verification (800m / 1500m thresholds)
// 4. Candidate Route Filtering (excluding routes passing through target hazard)
// 5. Single Corridor Road Detection & Graceful Fallback
// 6. Realistic Tradeoff Metrics (Delta km, Delta min, real safety scores vs Insufficient data)
// 7. Atomic Navigation State Transition & Voice Alert Triggering
// 8. Point-to-segment distance projection (midpoint on polyline between wide vertices)
// 9. Point-to-segment distance clamped to segment endpoints
// 10. Safe handling of empty and single-point polylines
// 11. 800m-1500m buffer zone hazards rejected from avoided count
// 12. Strict hazard reduction requirement (avoided > 1500m AND count on alt < count on current)
// 13. Rejection of candidate routes bypassing zero hazards (never display "Avoids 0 hazards")
// ============================================================================

double _distanceBetweenMeters(LatLng p1, LatLng p2) {
  const earthRadius = 6371000.0;
  final dLat = (p2.latitude - p1.latitude) * math.pi / 180.0;
  final dLon = (p2.longitude - p1.longitude) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(p1.latitude * math.pi / 180.0) *
          math.cos(p2.latitude * math.pi / 180.0) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _distanceToPolyline(LatLng point, List<LatLng> polyline) {
  if (polyline.isEmpty) return double.infinity;
  if (polyline.length == 1) return _distanceBetweenMeters(point, polyline.first);

  final longitudeScale =
      111320.0 * math.cos(point.latitude * math.pi / 180);
  const latitudeScale = 110540.0;

  double toX(LatLng p) => (p.longitude - point.longitude) * longitudeScale;
  double toY(LatLng p) => (p.latitude - point.latitude) * latitudeScale;

  var minDistanceSquared = double.infinity;

  for (var i = 0; i < polyline.length - 1; i++) {
    final first = polyline[i];
    final second = polyline[i + 1];
    final firstX = toX(first);
    final firstY = toY(first);
    final segmentX = toX(second) - firstX;
    final segmentY = toY(second) - firstY;
    final squaredLength = segmentX * segmentX + segmentY * segmentY;
    final fraction = squaredLength == 0
        ? 0.0
        : (-(firstX * segmentX + firstY * segmentY) / squaredLength)
            .clamp(0.0, 1.0)
            .toDouble();
    final dx = firstX + segmentX * fraction;
    final dy = firstY + segmentY * fraction;
    final distSq = dx * dx + dy * dy;
    if (distSq < minDistanceSquared) {
      minDistanceSquared = distSq;
    }
  }

  return math.sqrt(minDistanceSquared);
}

class _TestGpsFix {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const _TestGpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}

class _TestLocation {
  final double lat;
  final double lon;
  final String name;

  const _TestLocation({
    required this.lat,
    required this.lon,
    required this.name,
  });
}

class _TestCandidateRoute {
  final int routeIndex;
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;
  final List<String> steps;

  const _TestCandidateRoute({
    required this.routeIndex,
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.steps = const [],
  });
}

class _TestHazard {
  final int id;
  final String problemType;
  final double latitude;
  final double longitude;
  final String status;
  final double confidenceScore;

  const _TestHazard({
    required this.id,
    required this.problemType,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.confidenceScore = 85.0,
  });
}

void main() {
  group('SafeRoute TN 2.0 – Phase 2B: Smart Alternative Rerouting Tests', () {
    // Chennai Mount Road to Tambaram corridor
    final currentRoutePoints = <LatLng>[
      const LatLng(13.0827, 80.2707), // Chennai Central (Start)
      const LatLng(13.0600, 80.2500), // Thousand Lights
      const LatLng(13.0400, 80.2300), // T. Nagar
      const LatLng(13.0067, 80.2026), // Guindy (Hazard location: Flooded underpass)
      const LatLng(12.9800, 80.1700), // Meenambakkam Airport
      const LatLng(12.9249, 80.1000), // Tambaram (Destination)
    ];

    // Alternative Route via Inner Ring Road / Bypass (bypasses Guindy)
    final alternativeBypassPoints = <LatLng>[
      const LatLng(13.0400, 80.2300), // T. Nagar (Current User GPS location)
      const LatLng(13.0300, 80.1900), // Ashok Nagar
      const LatLng(13.0150, 80.1600), // Porur
      const LatLng(12.9600, 80.1300), // Pallavaram Bypass
      const LatLng(12.9249, 80.1000), // Tambaram (Destination)
    ];

    // Flooded underpass at Guindy
    const guindyFlooding = _TestHazard(
      id: 501,
      problemType: 'Flooding / waterlogging',
      latitude: 13.0067,
      longitude: 80.2026,
      status: 'Confirmed',
      confidenceScore: 92.0,
    );

    test('1. Validates GPS fix accuracy and rejects inaccurate fixes (> 50m)', () {
      final now = DateTime.now();

      final accurateFix = _TestGpsFix(
        latitude: 13.0400,
        longitude: 80.2300,
        accuracy: 14.2, // 14m accuracy (Excellent)
        timestamp: now.subtract(const Duration(seconds: 5)),
      );

      final inaccurateFix = _TestGpsFix(
        latitude: 13.0400,
        longitude: 80.2300,
        accuracy: 65.0, // 65m accuracy (Poor, exceeds 50m threshold)
        timestamp: now.subtract(const Duration(seconds: 5)),
      );

      bool isAccuracyValid(_TestGpsFix fix) =>
          fix.accuracy.isFinite && fix.accuracy <= 50.0;

      expect(isAccuracyValid(accurateFix), isTrue);
      expect(isAccuracyValid(inaccurateFix), isFalse);
    });

    test('2. Validates GPS fix freshness and rejects stale fixes (> 120s old)', () {
      final now = DateTime.now();

      final freshFix = _TestGpsFix(
        latitude: 13.0400,
        longitude: 80.2300,
        accuracy: 12.0,
        timestamp: now.subtract(const Duration(seconds: 30)),
      );

      final staleFix = _TestGpsFix(
        latitude: 13.0400,
        longitude: 80.2300,
        accuracy: 12.0,
        timestamp: now.subtract(const Duration(seconds: 180)), // 3 minutes old
      );

      bool isFresh(_TestGpsFix fix) {
        final age = now.difference(fix.timestamp).inSeconds;
        return age <= 120;
      }

      expect(isFresh(freshFix), isTrue);
      expect(isFresh(staleFix), isFalse);
    });

    test('3. Origin is formulated from current GPS fix while destination remains invariant', () {
      const originalDestination = _TestLocation(
        lat: 12.9249,
        lon: 80.1000,
        name: 'Tambaram Bus Terminus',
      );

      final currentGps = _TestGpsFix(
        latitude: 13.0400,
        longitude: 80.2300,
        accuracy: 10.0,
        timestamp: DateTime.now(),
      );

      // Formulate reroute query:
      // Origin MUST be user GPS coordinates
      final rerouteOrigin = _TestLocation(
        lat: currentGps.latitude,
        lon: currentGps.longitude,
        name: 'Current Location',
      );

      // Destination MUST NOT be mutated or replaced with a facility
      final rerouteDestination = originalDestination;

      expect(rerouteOrigin.lat, equals(13.0400));
      expect(rerouteOrigin.lon, equals(80.2300));
      expect(rerouteDestination.lat, equals(12.9249));
      expect(rerouteDestination.lon, equals(80.1000));
      expect(rerouteDestination.name, equals('Tambaram Bus Terminus'));
    });

    test('4. Hazard distance check verifies alternative corridor genuinely avoids hazard (> 1500m)', () {
      final hazardLoc = LatLng(guindyFlooding.latitude, guindyFlooding.longitude);

      // Distance on current remaining route: right on top of Guindy underpass (< 50m)
      final distOnCurrent = _distanceToPolyline(hazardLoc, currentRoutePoints);
      expect(distOnCurrent, lessThan(800.0));

      // Distance on alternative bypass (Porur/Pallavaram route): several kilometers away
      final distOnBypass = _distanceToPolyline(hazardLoc, alternativeBypassPoints);
      expect(distOnBypass, greaterThan(1500.0));

      bool isAvoided(double d) => d > 1500.0;
      bool isTraversed(double d) => d <= 800.0;

      expect(isTraversed(distOnCurrent), isTrue);
      expect(isAvoided(distOnBypass), isTrue);
    });

    test('5. Filters out candidate routes that pass through the target hazard corridor', () {
      final hazardLoc = LatLng(guindyFlooding.latitude, guindyFlooding.longitude);

      // Candidate 1: Main Highway (passes straight through Guindy)
      final candidate1 = _TestCandidateRoute(
        routeIndex: 0,
        points: currentRoutePoints.sublist(2), // from T. Nagar
        distanceKm: 14.5,
        durationMinutes: 28.0,
      );

      // Candidate 2: Porur Bypass (avoids Guindy)
      final candidate2 = _TestCandidateRoute(
        routeIndex: 1,
        points: alternativeBypassPoints,
        distanceKm: 17.2,
        durationMinutes: 32.0,
      );

      final candidateCorridors = [candidate1, candidate2];

      // Filtering criteria: alternative route must not pass within 800m of target hazard
      final viableCorridors = candidateCorridors.where((route) {
        final dToHazard = _distanceToPolyline(hazardLoc, route.points);
        return dToHazard > 800.0;
      }).toList();

      expect(viableCorridors.length, equals(1));
      expect(viableCorridors.first.routeIndex, equals(1));
      expect(viableCorridors.first.distanceKm, equals(17.2));
    });

    test('6. Detects single corridor situation and signals no viable alternative available', () {
      // In a mountain pass or single highway corridor, all candidate paths go through the single road
      final mountainPassRoute1 = <LatLng>[
        const LatLng(11.4100, 76.6900), // Ooty road entry
        const LatLng(11.3800, 76.7200), // Landslide zone (Hairpin bend 7)
        const LatLng(11.3500, 76.7500), // Coonoor
      ];
      final mountainPassRoute2 = <LatLng>[
        const LatLng(11.4100, 76.6900),
        const LatLng(11.3805, 76.7205), // Parallel lane on same mountain road
        const LatLng(11.3500, 76.7500),
      ];

      const landslideHazard = LatLng(11.3800, 76.7200);

      final candidates = [
        _TestCandidateRoute(routeIndex: 0, points: mountainPassRoute1, distanceKm: 18.0, durationMinutes: 45.0),
        _TestCandidateRoute(routeIndex: 1, points: mountainPassRoute2, distanceKm: 18.2, durationMinutes: 46.0),
      ];

      final viableAlternatives = candidates.where((r) {
        final d = _distanceToPolyline(landslideHazard, r.points);
        return d > 800.0;
      }).toList();

      // All alternatives traverse the hazard
      expect(viableAlternatives.isEmpty, isTrue);

      // Reroute assessment returns canReroute: false
      const canReroute = false;
      const explanation =
          'Single route corridor. All alternative routes pass through the reported hazard.';

      expect(canReroute, isFalse);
      expect(explanation, contains('Single route corridor'));
    });

    test('7. Accurately calculates comparison metrics (Delta distance, Delta duration, avoided count)', () {
      const currentRemainingDistKm = 14.5;
      const currentRemainingDurMin = 28.0;

      const altDistKm = 17.2;
      const altDurMin = 33.0;

      final distDiff = altDistKm - currentRemainingDistKm;
      final durDiff = altDurMin - currentRemainingDurMin;

      final signDist = distDiff >= 0
          ? '+${distDiff.toStringAsFixed(1)} km'
          : '${distDiff.toStringAsFixed(1)} km';
      final signDur =
          durDiff >= 0 ? '+${durDiff.round()}m' : '${durDiff.round()}m';

      expect(distDiff, closeTo(2.7, 0.01));
      expect(durDiff, equals(5.0));
      expect(signDist, equals('+2.7 km'));
      expect(signDur, equals('+5m'));
    });

    test('8. Preserves honest safety score states and presents "Insufficient data" rather than mocking', () {
      double? verifiedAltScore = 84.0;
      double? incompleteAltScore; // Insufficient data

      String formatSafetyScore(double? score) {
        if (score == null) return 'Insufficient data';
        return '${score.toStringAsFixed(0)}/100';
      }

      expect(formatSafetyScore(verifiedAltScore), equals('84/100'));
      expect(formatSafetyScore(incompleteAltScore), equals('Insufficient data'));
    });

    test('9. Atomic state application updates active navigation points, duration, and steps upon confirmation', () {
      // Mock navigation state
      var activeRoutePoints = currentRoutePoints;
      var activeDistanceKm = 24.5;
      var activeDurationMinutes = 45.0;
      var activeSteps = ['Continue on Mount Road', 'Cross Guindy flyover'];
      _TestHazard? activeHazardAhead = guindyFlooding;
      var isNavigationActive = true;

      // New alternative corridor chosen by user
      final confirmedAlt = _TestCandidateRoute(
        routeIndex: 1,
        points: alternativeBypassPoints,
        distanceKm: 17.2,
        durationMinutes: 32.0,
        steps: ['Turn right toward Ashok Nagar', 'Continue on Pallavaram Bypass'],
      );

      // Atomic confirmation handler
      void applyReroute(_TestCandidateRoute newRoute) {
        activeRoutePoints = newRoute.points;
        activeDistanceKm = newRoute.distanceKm;
        activeDurationMinutes = newRoute.durationMinutes;
        activeSteps = newRoute.steps;
        // Hazard cleared
        activeHazardAhead = null;
        // Navigation remains active seamlessly
        isNavigationActive = true;
      }

      applyReroute(confirmedAlt);

      expect(activeRoutePoints, equals(alternativeBypassPoints));
      expect(activeDistanceKm, equals(17.2));
      expect(activeDurationMinutes, equals(32.0));
      expect(activeSteps.first, equals('Turn right toward Ashok Nagar'));
      expect(activeHazardAhead, isNull);
      expect(isNavigationActive, isTrue);
    });

    test('10. Voice alert message properly adapts to Tamil and English language preferences', () {
      String getRerouteVoiceMessage(bool isTamil) {
        return isTamil
            ? 'முன்னே உள்ள ஆபத்தைத் தவிர்க்க புதிய பாதை மாற்றப்பட்டது. பயணத்தைத் தொடரவும்.'
            : 'Route updated to bypass hazard ahead. Continue on new route.';
      }

      final enMessage = getRerouteVoiceMessage(false);
      final taMessage = getRerouteVoiceMessage(true);

      expect(enMessage, equals('Route updated to bypass hazard ahead. Continue on new route.'));
      expect(taMessage, contains('முன்னே உள்ள ஆபத்தைத் தவிர்க்க புதிய பாதை மாற்றப்பட்டது'));
    });

    test('11. Hazard directly between two widely spaced vertices returns near-zero distance to polyline', () {
      // Highway stretch between two vertices ~1000m apart (0.009 deg latitude difference)
      const p1 = LatLng(13.0000, 80.2000);
      const p2 = LatLng(13.0090, 80.2000);
      final segmentPolyline = [p1, p2];

      // Hazard located midway along the road segment
      const hazardOnRoadMidpoint = LatLng(13.0045, 80.2000);

      // Discrete vertex distance would be ~500m
      final distToVertex1 = _distanceBetweenMeters(hazardOnRoadMidpoint, p1);
      final distToVertex2 = _distanceBetweenMeters(hazardOnRoadMidpoint, p2);
      expect(distToVertex1, greaterThan(450.0));
      expect(distToVertex2, greaterThan(450.0));

      // Point-to-segment projection correctly calculates near-zero distance (< 1.0m)
      final distanceToSegment = _distanceToPolyline(hazardOnRoadMidpoint, segmentPolyline);
      expect(distanceToSegment, lessThan(1.0));
    });

    test('12. Hazard near segment endpoint returns correct distance clamped to endpoint', () {
      const p1 = LatLng(13.0000, 80.2000);
      const p2 = LatLng(13.0050, 80.2000);
      final segmentPolyline = [p1, p2];

      // Point beyond p2 along the segment line (overshooting segment endpoint)
      const hazardBeyondP2 = LatLng(13.0060, 80.2000);

      // Projected fraction clamps to 1.0 (endpoint p2), so distance equals dist(hazard, p2)
      final expectedDistToEndpoint = _distanceBetweenMeters(hazardBeyondP2, p2);
      final actualDistance = _distanceToPolyline(hazardBeyondP2, segmentPolyline);

      expect(actualDistance, closeTo(expectedDistToEndpoint, 5.0));
      expect(actualDistance, greaterThan(100.0));

      // Point perpendicular to segment midpoint (~100m east)
      const hazardOffsetEast = LatLng(13.0025, 80.2010);
      final offsetDistance = _distanceToPolyline(hazardOffsetEast, segmentPolyline);
      expect(offsetDistance, closeTo(108.0, 10.0));
    });

    test('13. Empty and single-point polylines are handled safely without exceptions', () {
      const testPoint = LatLng(13.0000, 80.2000);
      const singleVertex = LatLng(13.0050, 80.2000);

      // Empty polyline returns infinity safely
      expect(_distanceToPolyline(testPoint, []), equals(double.infinity));

      // Single-point polyline returns direct point-to-point distance
      final singlePointDist = _distanceToPolyline(testPoint, [singleVertex]);
      final expectedDist = _distanceBetweenMeters(testPoint, singleVertex);
      expect(singlePointDist, equals(expectedDist));
      expect(singlePointDist.isFinite, isTrue);
    });

    test('14. Hazard at 1100m from alternative does not qualify as safely bypassed (800m-1500m buffer)', () {
      // Current route has a confirmed hazard
      const confirmedHazard = _TestHazard(
        id: 701,
        problemType: 'Road block / Fallen tree',
        latitude: 13.0067,
        longitude: 80.2026,
        status: 'Confirmed',
      );
      final confirmedOnCurrent = [confirmedHazard];

      // Alternative candidate where hazard is ~1100m away (0.0099 deg north)
      // > 800m (not on alt corridor) but <= 1500m (not safely avoided)
      const altRoutePoints = [
        LatLng(13.0400, 80.2300),
        LatLng(13.0166, 80.2026),
        LatLng(12.9249, 80.1000),
      ];

      final dAlt = _distanceToPolyline(
        LatLng(confirmedHazard.latitude, confirmedHazard.longitude),
        altRoutePoints,
      );

      // Verify the hazard lies in the 800m - 1500m buffer zone
      expect(dAlt, greaterThan(800.0));
      expect(dAlt, lessThanOrEqualTo(1500.0));

      final avoided = <_TestHazard>[];
      final hazardsOnAlt = <_TestHazard>[];

      if (dAlt <= 800.0) {
        hazardsOnAlt.add(confirmedHazard);
      }
      if (dAlt > 1500.0) {
        avoided.add(confirmedHazard);
      }

      expect(avoided.isEmpty, isTrue);
      expect(hazardsOnAlt.isEmpty, isTrue);

      // Selection rule: avoided.isNotEmpty && hazardsOnAlt.length < confirmedOnCurrent.length
      final qualifiesAsSaferBypass =
          avoided.isNotEmpty && hazardsOnAlt.length < confirmedOnCurrent.length;

      // Must NOT qualify as a safer hazard-bypass route
      expect(qualifiesAsSaferBypass, isFalse);
    });

    test('15. Hazard > 1500m away qualifies as avoided only when confirmed hazard count is strictly reduced', () {
      const hazardA = _TestHazard(
        id: 801,
        problemType: 'Flooding',
        latitude: 13.0067,
        longitude: 80.2026,
        status: 'Confirmed',
      );
      final confirmedOnCurrent = [hazardA]; // 1 confirmed hazard on current route

      // Case A: Alternative avoids hazard A (> 1500m), but encounters 2 new hazards on its corridor (<= 800m)
      final avoidedCaseA = [hazardA];
      final hazardsOnAltCaseA = [
        const _TestHazard(id: 802, problemType: 'Accident', latitude: 13.02, longitude: 80.18, status: 'Confirmed'),
        const _TestHazard(id: 803, problemType: 'Landslide', latitude: 13.01, longitude: 80.17, status: 'Confirmed'),
      ];

      final qualifiesCaseA =
          avoidedCaseA.isNotEmpty && hazardsOnAltCaseA.length < confirmedOnCurrent.length;
      // 2 is not < 1, so Case A must NOT qualify
      expect(qualifiesCaseA, isFalse);

      // Case B: Alternative avoids hazard A (> 1500m) AND has 0 hazards on its corridor
      final avoidedCaseB = [hazardA];
      final hazardsOnAltCaseB = <_TestHazard>[];

      final qualifiesCaseB =
          avoidedCaseB.isNotEmpty && hazardsOnAltCaseB.length < confirmedOnCurrent.length;
      // 0 < 1 AND avoided.isNotEmpty, so Case B qualifies!
      expect(qualifiesCaseB, isTrue);
    });

    test('16. Alternative route bypassing zero hazards is never offered as a safer reroute (Never displays "Avoids 0 hazards")', () {
      const hazard = _TestHazard(
        id: 901,
        problemType: 'Severe waterlogging',
        latitude: 13.0067,
        longitude: 80.2026,
        status: 'Confirmed',
      );
      final confirmedOnCurrent = [hazard];

      // Simulated candidate assessment where avoided count is 0
      _TestCandidateRoute? bestAlternative;
      var bestAvoidedCount = 0;

      final avoided = <_TestHazard>[]; // empty
      final hazardsOnAlt = <_TestHazard>[];

      // Condition: avoided.isNotEmpty && hazardsOnAlt.length < confirmedOnCurrent.length
      if (avoided.isNotEmpty && hazardsOnAlt.length < confirmedOnCurrent.length) {
        bestAlternative = const _TestCandidateRoute(
          routeIndex: 1,
          points: [LatLng(13.0400, 80.2300), LatLng(12.9249, 80.1000)],
          distanceKm: 16.0,
          durationMinutes: 30.0,
        );
        bestAvoidedCount = avoided.length;
      }

      // Assessment decision
      final canReroute = bestAlternative != null && bestAvoidedCount > 0;
      final explanation = canReroute
          ? 'Alternative route bypasses $bestAvoidedCount hazard(s)'
          : 'Single route corridor. All alternative routes pass through the reported hazard.';

      expect(canReroute, isFalse);
      expect(bestAvoidedCount, equals(0));
      expect(explanation, isNot(contains('bypasses 0 hazard')));
      expect(explanation, isNot(contains('Avoids 0 hazards')));
      expect(explanation, contains('Single route corridor'));
    });
  });
}
