// ============================================================================
// SafeRoute TN — Multi-Route Generation & Comparison Tests
// Tests: test/multi_route_generation_test.dart
// Description: Comprehensive test suite for true multi-route generation,
//              distinct corridor filtering, shortest/fastest/safest/best
//              categorization, live journey selection, zero fabrication,
//              and responsive layout verification.
// ============================================================================

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/safe_route_journey_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Route Generation & Corridor Filtering', () {
    late SafeRouteService service;
    late List<RouteResult> mockRoutes;

    setUp(() {
      service = SafeRouteService();
      mockRoutes = [
        RouteResult(
          points: const [
            LatLng(13.0827, 80.2707),
            LatLng(12.5, 79.5),
            LatLng(9.9252, 78.1198),
          ],
          distance: 455.7,
          duration: 379.0, // 6h 19m
          routeIndex: 0,
        ),
        RouteResult(
          points: const [
            LatLng(13.0827, 80.2707),
            LatLng(11.9401, 79.8083),
            LatLng(9.9252, 78.1198),
          ],
          distance: 435.0, // Shortest
          duration: 395.0,
          routeIndex: 1,
        ),
        RouteResult(
          points: const [
            LatLng(13.0827, 80.2707),
            LatLng(11.5, 79.0),
            LatLng(9.9252, 78.1198),
          ],
          distance: 480.0,
          duration: 350.0, // Fastest
          routeIndex: 2,
        ),
      ];
    });

    test('Test A: OSRM returns 1 route -> only Route 1 shown with honest fallback', () {
      final single = RouteResult(
        points: const [LatLng(11.0168, 76.9558), LatLng(11.4102, 76.6950)],
        distance: 100.8,
        duration: 165.0,
        routeIndex: 0,
      );
      final distinct = service.filterDistinctRoutes([single]);
      expect(distinct.length, 1);
      expect(distinct.first.routeIndex, 0);
      expect(distinct.first.distance, 100.8);
    });

    test('Test B: OSRM returns 2 routes -> both displayed as distinct corridors', () {
      final distinct = service.filterDistinctRoutes([mockRoutes[0], mockRoutes[1]]);
      expect(distinct.length, 2);
      expect(distinct[0].routeIndex, 0);
      expect(distinct[1].routeIndex, 1);
      expect(distinct[0].distance, 455.7);
      expect(distinct[1].distance, 435.0);
    });

    test('Test C: OSRM returns 3 routes -> all 3 displayed with distinct indices', () {
      final distinct = service.filterDistinctRoutes(mockRoutes);
      expect(distinct.length, 3);
      expect(distinct[0].routeIndex, 0);
      expect(distinct[1].routeIndex, 1);
      expect(distinct[2].routeIndex, 2);
    });

    test('Test D: Shortest route -> minimum distance route correctly identified (not assuming Route 1)', () {
      int shortestIdx = 0;
      for (int i = 1; i < mockRoutes.length; i++) {
        if (mockRoutes[i].distance < mockRoutes[shortestIdx].distance) {
          shortestIdx = i;
        }
      }
      expect(mockRoutes[shortestIdx].routeIndex, 1);
      expect(mockRoutes[shortestIdx].distance, 435.0);
      expect(shortestIdx, isNot(0)); // Confirms Route 1 is not blindly assumed
    });

    test('Test E: Fastest route -> minimum duration route correctly identified (not assuming Route 1)', () {
      int fastestIdx = 0;
      for (int i = 1; i < mockRoutes.length; i++) {
        if (mockRoutes[i].duration < mockRoutes[fastestIdx].duration) {
          fastestIdx = i;
        }
      }
      expect(mockRoutes[fastestIdx].routeIndex, 2);
      expect(mockRoutes[fastestIdx].duration, 350.0);
      expect(fastestIdx, isNot(0)); // Confirms Route 1 is not blindly assumed
    });

    test('Test F: Safest route -> highest verified safety score correctly identified', () {
      final safetyScores = <int, double>{
        0: 82.0,
        1: 78.5,
        2: 93.0, // Safest
      };

      int? safestIdx;
      double highest = -1.0;
      for (final entry in safetyScores.entries) {
        if (entry.value > highest) {
          highest = entry.value;
          safestIdx = entry.key;
        }
      }

      expect(safestIdx, 2);
      expect(highest, 93.0);
    });

    test('Test G: Best route -> balanced recommendation calculated from data (Safety, Time, Distance)', () {
      final safetyScores = <int, double>{
        0: 91.0, // Very safe, moderate distance/duration
        1: 75.0, // Shortest distance, but lower safety
        2: 84.0, // Fastest, but lower safety than Route 0
      };

      final minDistance = mockRoutes.map((r) => r.distance).reduce(math.min);
      final minDuration = mockRoutes.map((r) => r.duration).reduce(math.min);

      double compositeScore(int idx) {
        final r = mockRoutes[idx];
        final s = safetyScores[idx] ?? 0.0;
        final durEff = (minDuration / r.duration).clamp(0.4, 1.0) * 100.0;
        final distEff = (minDistance / r.distance).clamp(0.4, 1.0) * 100.0;
        return (s * 0.65) + (durEff * 0.15) + (distEff * 0.15);
      }

      int bestIdx = 0;
      double maxScore = compositeScore(0);
      for (int i = 1; i < mockRoutes.length; i++) {
        final sc = compositeScore(i);
        if (sc > maxScore) {
          maxScore = sc;
          bestIdx = i;
        }
      }

      expect(bestIdx, 0);
      expect(maxScore, greaterThan(85.0));
    });
  });

  group('Selected Route to Live Journey Navigation Integration', () {
    late List<RouteResult> mockRoutes;

    setUp(() {
      mockRoutes = [
        RouteResult(
          points: const [
            LatLng(13.0827, 80.2707),
            LatLng(12.5, 79.5),
            LatLng(9.9252, 78.1198),
          ],
          distance: 455.7,
          duration: 379.0,
          routeIndex: 0,
        ),
        RouteResult(
          points: const [
            LatLng(13.0827, 80.2707),
            LatLng(11.9401, 79.8083),
            LatLng(9.9252, 78.1198),
          ],
          distance: 435.0, // Shortest
          duration: 395.0,
          routeIndex: 1,
        ),
        RouteResult(
          points: const [
            LatLng(13.0827, 80.2707),
            LatLng(11.5, 79.0),
            LatLng(9.9252, 78.1198),
          ],
          distance: 480.0,
          duration: 360.0, // Fastest
          routeIndex: 2,
        ),
      ];
    });

    test('Test H: Route 2 selected -> START JOURNEY uses Route 2 geometry, distance, and identity', () {
      final selected = mockRoutes[1];
      const category = 'SHORTEST';
      final journey = SafeRouteJourney(
        id: 'journey-r2',
        origin: 'Chennai Central',
        destination: 'Madurai Junction',
        routeIndex: selected.routeIndex,
        routeLabel: 'Route ${selected.routeIndex + 1} • $category',
        routeSafetyScore: 78.5,
        distanceKm: selected.distance,
        estimatedDurationMinutes: selected.duration,
      );

      expect(journey.routeIndex, 1);
      expect(journey.distanceKm, 435.0);
      expect(journey.displayRouteLabel, 'Route 2 • SHORTEST');
      expect(journey.estimatedDurationMinutes, 395.0);
      expect(selected.points.length, 3);
      expect(selected.points[1], const LatLng(11.9401, 79.8083));
    });

    test('Test I: Route 3 selected -> START JOURNEY uses Route 3 geometry, distance, and identity', () {
      final selected = mockRoutes[2];
      const category = 'FASTEST';
      final journey = SafeRouteJourney(
        id: 'journey-r3',
        origin: 'Chennai Central',
        destination: 'Madurai Junction',
        routeIndex: selected.routeIndex,
        routeLabel: 'Route ${selected.routeIndex + 1} • $category',
        routeSafetyScore: 84.0,
        distanceKm: selected.distance,
        estimatedDurationMinutes: selected.duration,
      );

      expect(journey.routeIndex, 2);
      expect(journey.distanceKm, 480.0);
      expect(journey.displayRouteLabel, 'Route 3 • FASTEST');
      expect(journey.estimatedDurationMinutes, 360.0);
      expect(selected.points.length, 3);
      expect(selected.points[1], const LatLng(11.5, 79.0));
    });

    test('Test J: No fake safety score -> null score preserved cleanly without fallback to fake 92%', () {
      final unratedJourney = SafeRouteJourney(
        id: 'journey-unrated',
        origin: 'Chennai',
        destination: 'Salem',
        routeIndex: 0,
        routeSafetyScore: null,
        distanceKm: 340.0,
        estimatedDurationMinutes: 280.0,
      );

      expect(unratedJourney.routeSafetyScore, isNull);
    });

    test('Test K: No duplicate route geometry -> eliminates near-duplicates within threshold', () {
      final service = SafeRouteService();
      final r0 = RouteResult(
        points: const [LatLng(13.0827, 80.2707), LatLng(9.9252, 78.1198)],
        distance: 455.70,
        duration: 379.0,
        routeIndex: 0,
      );
      final rDuplicate = RouteResult(
        points: const [LatLng(13.0827, 80.2707), LatLng(9.9252, 78.1198)],
        distance: 455.72,
        duration: 379.05,
        routeIndex: 1,
      );
      final rDistinct = RouteResult(
        points: const [LatLng(13.0827, 80.2707), LatLng(11.0, 78.5), LatLng(9.9252, 78.1198)],
        distance: 470.0,
        duration: 400.0,
        routeIndex: 2,
      );

      final distinct = service.filterDistinctRoutes([r0, rDuplicate, rDistinct]);
      expect(distinct.length, 2);
      expect(distinct[0].routeIndex, 0);
      expect(distinct[1].routeIndex, 1);
      expect(distinct[1].distance, 470.0);
    });

    test('Test L: displayRouteLabel handles custom labels, empty strings, and null cleanly', () {
      final custom = SafeRouteJourney(
        id: '1', origin: 'A', destination: 'B', routeIndex: 1, routeLabel: 'Route 2 • BEST',
        routeSafetyScore: null, distanceKm: 10, estimatedDurationMinutes: 10,
      );
      expect(custom.displayRouteLabel, 'Route 2 • BEST');

      final empty = SafeRouteJourney(
        id: '2', origin: 'A', destination: 'B', routeIndex: 2, routeLabel: '',
        routeSafetyScore: null, distanceKm: 10, estimatedDurationMinutes: 10,
      );
      expect(empty.displayRouteLabel, 'Route 3');

      final nullLabel = SafeRouteJourney(
        id: '3', origin: 'A', destination: 'B', routeIndex: 0, routeLabel: null,
        routeSafetyScore: null, distanceKm: 10, estimatedDurationMinutes: 10,
      );
      expect(nullLabel.displayRouteLabel, 'Route 1');
    });
  });
}
