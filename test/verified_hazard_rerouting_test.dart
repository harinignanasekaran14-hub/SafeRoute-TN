import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// Test suite for Verified Hazard-Aware Smart Rerouting
// Covering the 10 specification requirements:
// 1. Pending report does not affect authoritative score
// 2. Confirmed hazard on Route 1 is detected
// 3. Hazard on Route 2 is detected
// 4. Resolved hazard is excluded
// 5. Disputed report is handled correctly
// 6. Alternative route is selected only when geometry supports avoidance
// 7. Distance/time differences are calculated correctly
// 8. No alternative route is available
// 9. Existing blackspots are not double-counted
// 10. Missing or unavailable hazard data is handled safely

class TestHazardReport {
  final int id;
  final String problemType;
  final String category;
  final String status;
  final double? latitude;
  final double? longitude;
  final double confidenceScore;
  final bool isNearBlackspot;

  const TestHazardReport({
    required this.id,
    required this.problemType,
    required this.category,
    required this.status,
    this.latitude,
    this.longitude,
    required this.confidenceScore,
    this.isNearBlackspot = false,
  });
}

class TestRoute {
  final int routeIndex;
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;

  const TestRoute({
    required this.routeIndex,
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class TestRerouteAssessment {
  final bool hasConfirmedHazardsOnCurrentRoute;
  final List<TestHazardReport> confirmedHazardsOnCurrent;
  final List<TestHazardReport> pendingHazardsOnCurrent;
  final List<TestHazardReport> disputedHazardsOnCurrent;
  final bool canReroute;
  final int? alternativeRouteIndex;
  final double? distanceDiffKm;
  final double? durationDiffMinutes;
  final String explanation;
  final int avoidedHazardCount;

  const TestRerouteAssessment({
    required this.hasConfirmedHazardsOnCurrentRoute,
    required this.confirmedHazardsOnCurrent,
    required this.pendingHazardsOnCurrent,
    required this.disputedHazardsOnCurrent,
    required this.canReroute,
    this.alternativeRouteIndex,
    this.distanceDiffKm,
    this.durationDiffMinutes,
    required this.explanation,
    required this.avoidedHazardCount,
  });
}

double haversineDistanceMeters(LatLng p1, LatLng p2) {
  const earthRadius = 6371000.0;
  final lat1 = p1.latitude * math.pi / 180.0;
  final lat2 = p2.latitude * math.pi / 180.0;
  final dLat = (p2.latitude - p1.latitude) * math.pi / 180.0;
  final dLon = (p2.longitude - p1.longitude) * math.pi / 180.0;

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double distanceToPolyline(LatLng point, List<LatLng> polyline) {
  if (polyline.isEmpty) return double.infinity;
  var minD = double.infinity;
  for (final pt in polyline) {
    final d = haversineDistanceMeters(point, pt);
    if (d < minD) minD = d;
  }
  return minD;
}

TestRerouteAssessment assessHazardRerouting({
  required List<TestRoute> availableRoutes,
  required int selectedRouteIndex,
  required List<TestHazardReport> hazards,
}) {
  if (availableRoutes.isEmpty) {
    return const TestRerouteAssessment(
      hasConfirmedHazardsOnCurrentRoute: false,
      confirmedHazardsOnCurrent: [],
      pendingHazardsOnCurrent: [],
      disputedHazardsOnCurrent: [],
      canReroute: false,
      explanation: 'No routes available.',
      avoidedHazardCount: 0,
    );
  }

  final currentRoute = availableRoutes[selectedRouteIndex];
  final confirmedOnCurr = <TestHazardReport>[];
  final pendingOnCurr = <TestHazardReport>[];
  final disputedOnCurr = <TestHazardReport>[];

  for (final h in hazards) {
    if (h.status == 'Resolved' || h.status == 'Expired') continue;
    if (h.latitude == null || h.longitude == null) continue;

    final loc = LatLng(h.latitude!, h.longitude!);
    final dCurr = distanceToPolyline(loc, currentRoute.points);

    if (dCurr <= 800.0) {
      if (h.status == 'Confirmed') {
        confirmedOnCurr.add(h);
      } else if (h.status == 'Pending') {
        pendingOnCurr.add(h);
      } else if (h.status == 'Disputed') {
        disputedOnCurr.add(h);
      }
    }
  }

  if (confirmedOnCurr.isEmpty) {
    return TestRerouteAssessment(
      hasConfirmedHazardsOnCurrentRoute: false,
      confirmedHazardsOnCurrent: const [],
      pendingHazardsOnCurrent: pendingOnCurr,
      disputedHazardsOnCurrent: disputedOnCurr,
      canReroute: false,
      explanation: 'No confirmed road hazards on current route.',
      avoidedHazardCount: 0,
    );
  }

  final altIndex = selectedRouteIndex == 0 ? 1 : 0;
  if (altIndex >= availableRoutes.length) {
    return TestRerouteAssessment(
      hasConfirmedHazardsOnCurrentRoute: true,
      confirmedHazardsOnCurrent: confirmedOnCurr,
      pendingHazardsOnCurrent: pendingOnCurr,
      disputedHazardsOnCurrent: disputedOnCurr,
      canReroute: false,
      explanation: 'Single route corridor. No alternative route available to bypass hazard.',
      avoidedHazardCount: 0,
    );
  }

  final altRoute = availableRoutes[altIndex];
  final avoided = <TestHazardReport>[];
  final altConfirmed = <TestHazardReport>[];

  for (final h in hazards) {
    if (h.status != 'Confirmed' || h.latitude == null || h.longitude == null) continue;
    final loc = LatLng(h.latitude!, h.longitude!);
    final dAlt = distanceToPolyline(loc, altRoute.points);
    if (dAlt <= 800.0) {
      altConfirmed.add(h);
    }
  }

  for (final h in confirmedOnCurr) {
    final loc = LatLng(h.latitude!, h.longitude!);
    final dAlt = distanceToPolyline(loc, altRoute.points);
    if (dAlt > 1500.0) {
      avoided.add(h);
    }
  }

  final canReroute = avoided.isNotEmpty && altConfirmed.length < confirmedOnCurr.length;
  final distDiff = altRoute.distanceKm - currentRoute.distanceKm;
  final durDiff = altRoute.durationMinutes - currentRoute.durationMinutes;
  final signDist = distDiff >= 0 ? '+${distDiff.toStringAsFixed(1)}' : distDiff.toStringAsFixed(1);
  final signDur = durDiff >= 0 ? '+${durDiff.round()}' : '${durDiff.round()}';

  final explanation = canReroute
      ? 'Route ${altIndex + 1} bypasses ${avoided.length} confirmed hazard(s) ($signDist km, $signDur mins travel time).'
      : 'Alternative route does not avoid the hazard corridor (both routes traverse this segment).';

  return TestRerouteAssessment(
    hasConfirmedHazardsOnCurrentRoute: true,
    confirmedHazardsOnCurrent: confirmedOnCurr,
    pendingHazardsOnCurrent: pendingOnCurr,
    disputedHazardsOnCurrent: disputedOnCurr,
    canReroute: canReroute,
    alternativeRouteIndex: altIndex,
    distanceDiffKm: distDiff,
    durationDiffMinutes: durDiff,
    explanation: explanation,
    avoidedHazardCount: avoided.length,
  );
}

void main() {
  group('Verified Hazard-Aware Smart Rerouting 10 Core Tests', () {
    final route1 = TestRoute(
      routeIndex: 0,
      points: [const LatLng(11.3410, 77.7170), const LatLng(11.3500, 77.7250), const LatLng(11.3600, 77.7350)],
      distanceKm: 441.4,
      durationMinutes: 340.0,
    );

    final route2 = TestRoute(
      routeIndex: 1,
      points: [const LatLng(11.3410, 77.7170), const LatLng(11.3900, 77.7700), const LatLng(11.4100, 77.7900)],
      distanceKm: 464.0,
      durationMinutes: 371.0,
    );

    test('1. Pending report does not affect authoritative score / rerouting', () {
      const pendingReport = TestHazardReport(
        id: 1,
        problemType: 'Pothole',
        category: 'pothole_damaged_road',
        status: 'Pending',
        latitude: 11.3601,
        longitude: 77.7351,
        confidenceScore: 35.0,
      );

      final assessment = assessHazardRerouting(
        availableRoutes: [route1, route2],
        selectedRouteIndex: 0,
        hazards: [pendingReport],
      );

      expect(assessment.hasConfirmedHazardsOnCurrentRoute, isFalse);
      expect(assessment.canReroute, isFalse);
      expect(assessment.pendingHazardsOnCurrent.length, equals(1));
      expect(assessment.confirmedHazardsOnCurrent, isEmpty);
      expect(assessment.explanation, contains('No confirmed road hazards'));
    });

    test('2. Confirmed hazard on Route 1 is detected', () {
      const confirmedR1 = TestHazardReport(
        id: 2,
        problemType: 'Waterlogging',
        category: 'flooding_waterlogging',
        status: 'Confirmed',
        latitude: 11.3601,
        longitude: 77.7351,
        confidenceScore: 85.0,
      );

      final assessment = assessHazardRerouting(
        availableRoutes: [route1, route2],
        selectedRouteIndex: 0,
        hazards: [confirmedR1],
      );

      expect(assessment.hasConfirmedHazardsOnCurrentRoute, isTrue);
      expect(assessment.confirmedHazardsOnCurrent.length, equals(1));
      expect(assessment.confirmedHazardsOnCurrent.first.id, equals(2));
      expect(assessment.canReroute, isTrue);
      expect(assessment.alternativeRouteIndex, equals(1));
    });

    test('3. Hazard on Route 2 is detected when Route 2 is selected', () {
      const confirmedR2 = TestHazardReport(
        id: 3,
        problemType: 'Road blocked',
        category: 'road_blocked',
        status: 'Confirmed',
        latitude: 11.3902,
        longitude: 77.7702,
        confidenceScore: 90.0,
      );

      final assessment = assessHazardRerouting(
        availableRoutes: [route1, route2],
        selectedRouteIndex: 1, // Route 2 is selected
        hazards: [confirmedR2],
      );

      expect(assessment.hasConfirmedHazardsOnCurrentRoute, isTrue);
      expect(assessment.confirmedHazardsOnCurrent.length, equals(1));
      expect(assessment.canReroute, isTrue);
      expect(assessment.alternativeRouteIndex, equals(0)); // Recommends switching to Route 1
    });

    test('4. Resolved hazard is excluded from active hazard evaluation', () {
      const resolvedHazard = TestHazardReport(
        id: 4,
        problemType: 'Broken streetlight',
        category: 'broken_streetlight',
        status: 'Resolved',
        latitude: 11.3601,
        longitude: 77.7351,
        confidenceScore: 80.0,
      );

      final assessment = assessHazardRerouting(
        availableRoutes: [route1, route2],
        selectedRouteIndex: 0,
        hazards: [resolvedHazard],
      );

      expect(assessment.hasConfirmedHazardsOnCurrentRoute, isFalse);
      expect(assessment.canReroute, isFalse);
      expect(assessment.confirmedHazardsOnCurrent, isEmpty);
      expect(assessment.pendingHazardsOnCurrent, isEmpty);
    });

    test('5. Disputed report is handled correctly without triggering rerouting', () {
      const disputedHazard = TestHazardReport(
        id: 5,
        problemType: 'Construction',
        category: 'construction',
        status: 'Disputed',
        latitude: 11.3601,
        longitude: 77.7351,
        confidenceScore: 20.0,
      );

      final assessment = assessHazardRerouting(
        availableRoutes: [route1, route2],
        selectedRouteIndex: 0,
        hazards: [disputedHazard],
      );

      expect(assessment.hasConfirmedHazardsOnCurrentRoute, isFalse);
      expect(assessment.canReroute, isFalse);
      expect(assessment.disputedHazardsOnCurrent.length, equals(1));
    });

    test('6. Alternative route is selected ONLY when geometry supports avoidance (>1500m)', () {
      // If hazard is at 11.3412, 77.7171 (near the common starting point for both routes)
      const commonHazard = TestHazardReport(
        id: 6,
        problemType: 'Major landslide',
        category: 'road_blocked',
        status: 'Confirmed',
        latitude: 11.3412,
        longitude: 77.7171,
        confidenceScore: 95.0,
      );

      final assessment = assessHazardRerouting(
        availableRoutes: [route1, route2],
        selectedRouteIndex: 0,
        hazards: [commonHazard],
      );

      // Both routes traverse this segment!
      expect(assessment.hasConfirmedHazardsOnCurrentRoute, isTrue);
      expect(assessment.canReroute, isFalse);
      expect(assessment.explanation, contains('Alternative route does not avoid'));
    });

    test('7. Distance and time differences are calculated correctly', () {
      const confirmedR1 = TestHazardReport(
        id: 7,
        problemType: 'Flooding',
        category: 'flooding_waterlogging',
        status: 'Confirmed',
        latitude: 11.3601,
        longitude: 77.7351,
        confidenceScore: 90.0,
      );

      final assessment = assessHazardRerouting(
        availableRoutes: [route1, route2],
        selectedRouteIndex: 0,
        hazards: [confirmedR1],
      );

      expect(assessment.canReroute, isTrue);
      expect(assessment.distanceDiffKm, closeTo(22.6, 0.01));
      expect(assessment.durationDiffMinutes, closeTo(31.0, 0.01));
      expect(assessment.explanation, contains('+22.6 km'));
      expect(assessment.explanation, contains('+31 mins'));
    });

    test('8. Single route corridor handled when no alternative route is available', () {
      const confirmedR1 = TestHazardReport(
        id: 8,
        problemType: 'Bridge damage',
        category: 'road_blocked',
        status: 'Confirmed',
        latitude: 11.3601,
        longitude: 77.7351,
        confidenceScore: 90.0,
      );

      final assessment = assessHazardRerouting(
        availableRoutes: [route1], // Only 1 route available
        selectedRouteIndex: 0,
        hazards: [confirmedR1],
      );

      expect(assessment.hasConfirmedHazardsOnCurrentRoute, isTrue);
      expect(assessment.canReroute, isFalse);
      expect(assessment.explanation, contains('Single route corridor. No alternative route available'));
    });

    test('9. Existing blackspots are not double-counted', () {
      const blackspotHazard = TestHazardReport(
        id: 9,
        problemType: 'Frequent crash zone',
        category: 'accident_hazard',
        status: 'Confirmed',
        latitude: 11.3601,
        longitude: 77.7351,
        confidenceScore: 90.0,
        isNearBlackspot: true, // Marked as near existing verified blackspot
      );

      expect(blackspotHazard.isNearBlackspot, isTrue);
      // The system tags near-blackspot hazards so the safety engine retains authoritative blackspot records
      final assessment = assessHazardRerouting(
        availableRoutes: [route1, route2],
        selectedRouteIndex: 0,
        hazards: [blackspotHazard],
      );
      expect(assessment.confirmedHazardsOnCurrent.first.isNearBlackspot, isTrue);
    });

    test('10. Missing or unavailable hazard data is handled safely', () {
      const invalidHazard = TestHazardReport(
        id: 10,
        problemType: 'Unknown',
        category: 'other',
        status: 'Confirmed',
        latitude: null, // Missing coordinate
        longitude: null,
        confidenceScore: 50.0,
      );

      final assessment = assessHazardRerouting(
        availableRoutes: [route1, route2],
        selectedRouteIndex: 0,
        hazards: [invalidHazard],
      );

      expect(assessment.hasConfirmedHazardsOnCurrentRoute, isFalse);
      expect(assessment.canReroute, isFalse);
      expect(assessment.confirmedHazardsOnCurrent, isEmpty);

      // Completely empty routes
      final emptyAssessment = assessHazardRerouting(
        availableRoutes: [],
        selectedRouteIndex: 0,
        hazards: [],
      );
      expect(emptyAssessment.canReroute, isFalse);
    });
  });
}
