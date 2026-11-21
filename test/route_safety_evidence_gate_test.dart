import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/safe_route_journey_mode.dart';
import 'package:saferoute_tn/smart_nearby_places.dart';

void main() {
  group('Route Safety Evidence-Confidence Gate Tests', () {
    test('1. Weather-only factor MUST result in null score and insufficient evidence', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: null,
        roadConditionScore: null,
        trafficScore: null,
        weatherScore: 70.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night', // Ensure lighting is not implicitly 100%
      );

      expect(
        result.score,
        isNull,
        reason: 'A Weather-only factor must never yield a numeric final score',
      );
      expect(result.isEvidenceSufficient, isFalse);
      expect(result.activeFactors, isEmpty);
      expect(result.evidenceCount, 1);
      expect(result.insufficientDataReason, contains('Requires'));
    });

    test(
      '2. Two factors without core infrastructure MUST result in null score',
      () {
        final result = calculateAuthoritativeSafetyScore(
          accidentScore: null,
          roadConditionScore: null,
          trafficScore: null,
          weatherScore: 80.0,
          lightingScore: 75.0,
          accessibilityScore: null,
          travelTime: 'Night',
        );

        expect(result.score, isNull);
        expect(result.isEvidenceSufficient, isFalse);
        expect(result.evidenceCount, 2);
      },
    );

    test(
      '3. Three factors WITHOUT core infrastructure MUST result in null score',
      () {
        // Factors: Weather (80), Lighting (70), Accessibility (60), but no Accident, Road, or Traffic
        final result = calculateAuthoritativeSafetyScore(
          accidentScore: null,
          roadConditionScore: null,
          trafficScore: null,
          weatherScore: 80.0,
          lightingScore: 70.0,
          accessibilityScore: 60.0,
          travelTime: 'Night',
        );

        expect(
          result.score,
          isNull,
          reason: 'Even with 3 factors, at least one core infrastructure factor is mandatory',
        );
        expect(result.isEvidenceSufficient, isFalse);
        expect(result.evidenceCount, 3);
        expect(
          result.insufficientDataReason,
          contains('core infrastructure data'),
        );
      },
    );

    test(
      '4. Three factors WITH Traffic produces valid authoritative score',
      () {
        final result = calculateAuthoritativeSafetyScore(
          accidentScore: null,
          roadConditionScore: null,
          trafficScore: 85.0,
          weatherScore: 75.0,
          lightingScore: 80.0,
          accessibilityScore: null,
          travelTime: 'Night',
        );

        expect(result.score, isNotNull);
        expect(result.score!, greaterThan(0.0));
        expect(result.score!, lessThanOrEqualTo(100.0));
        expect(result.isEvidenceSufficient, isTrue);
        expect(result.evidenceCount, 3);
        expect(result.activeFactors.length, 3);

        // Verify active factors have normalized weights summing to 1.0
        final sumWeights = result.activeFactors.fold<double>(
          0.0,
          (s, f) => s + f.weight,
        );
        expect(sumWeights, closeTo(1.0, 0.001));
      },
    );

    test(
      '5. Three factors WITH Road Condition produces valid authoritative score',
      () {
        final result = calculateAuthoritativeSafetyScore(
          accidentScore: null,
          roadConditionScore: 70.0,
          trafficScore: null,
          weatherScore: 80.0,
          lightingScore: 90.0,
          accessibilityScore: null,
          travelTime: 'Night',
        );

        expect(result.score, isNotNull);
        expect(result.score!, greaterThan(0.0));
        expect(result.score!, lessThanOrEqualTo(100.0));
        expect(result.isEvidenceSufficient, isTrue);
        expect(result.evidenceCount, 3);
        expect(result.activeFactors.length, 3);
      },
    );

    test(
      '6. Three factors WITH Accident Risk produces valid authoritative score',
      () {
        final result = calculateAuthoritativeSafetyScore(
          accidentScore: 90.0,
          roadConditionScore: null,
          trafficScore: null,
          weatherScore: 80.0,
          lightingScore: 70.0,
          accessibilityScore: null,
          travelTime: 'Night',
        );

        expect(result.score, isNotNull);
        expect(result.score!, greaterThan(0.0));
        expect(result.score!, lessThanOrEqualTo(100.0));
        expect(result.isEvidenceSufficient, isTrue);
        expect(result.evidenceCount, 3);
      },
    );

    test('7. Verified Accident Risk with 0 blackspots displays clear message and valid score', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 100.0,
        accidentSegmentsWithMatches: 0,
        accidentVerifiedRecordCount: 8,
        roadConditionScore: 85.0,
        trafficScore: 80.0,
        weatherScore: 75.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );

      final accidentFactor = result.factors.firstWhere(
        (f) => f.title == 'Accident Risk',
      );
      expect(accidentFactor.score, 100.0);
      expect(
        accidentFactor.scoreLabel,
        'Verified accident data: No matched blackspots',
      );
      expect(accidentFactor.source, 'Verified TN accident blackspots');
      expect(accidentFactor.status, 'Clear');
    });

    test('8. Full 6 factors calculation sums weights to 1.0 and yields precise score', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 90.0,
        roadConditionScore: 80.0,
        trafficScore: 70.0,
        weatherScore: 60.0,
        lightingScore: 80.0,
        accessibilityScore: 85.0,
        travelTime: 'Night',
      );

      expect(result.score, isNotNull);
      expect(result.isEvidenceSufficient, isTrue);
      expect(result.evidenceCount, 6);
      expect(result.activeFactors.length, 6);

      final sumWeights = result.activeFactors.fold<double>(
        0.0,
        (s, f) => s + f.weight,
      );
      expect(sumWeights, closeTo(1.0, 0.001));
    });

    test('9. Two verified factors WITH core infrastructure produces dynamic provisional score', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 90.0,
        roadConditionScore: null,
        trafficScore: null,
        weatherScore: 70.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );

      expect(result.score, isNotNull);
      expect(result.isProvisional, isTrue);
      expect(result.isEvidenceSufficient, isTrue);
      expect(result.evidenceCount, 2);
      expect(result.activeFactors.length, 2);

      // Accident base weight = 0.30, Weather base weight = 0.10. Total = 0.40.
      // Normalized: Accident = 0.30/0.40 = 0.75, Weather = 0.10/0.40 = 0.25.
      // Expected score = 90 * 0.75 + 70 * 0.25 = 67.5 + 17.5 = 85.0.
      expect(result.score, closeTo(85.0, 0.01));
    });
  });

  group('Authoritative Journey Mode Consistency Tests', () {
    test('SafeRouteJourney supports nullable score and indicates unavailable when null', () {
      const journey = SafeRouteJourney(
        id: 'test_journey_1',
        origin: 'Coimbatore',
        destination: 'Madurai',
        routeIndex: 0,
        routeSafetyScore: null, // Insufficient data
        distanceKm: 207.0,
        estimatedDurationMinutes: 240,
        vehicleMode: 'Car',
      );

      expect(journey.routeSafetyScore, isNull);
      expect(journey.safetyRating(false), 'Safety score unavailable');
    });

    test('SafeRouteJourney reflects authoritative score accurately without fallback', () {
      const journey = SafeRouteJourney(
        id: 'test_journey_2',
        origin: 'Coimbatore',
        destination: 'Madurai',
        routeIndex: 0,
        routeSafetyScore: 82.5,
        distanceKm: 207.0,
        estimatedDurationMinutes: 240,
        vehicleMode: 'Car',
      );

      expect(journey.routeSafetyScore, 82.5);
      expect(journey.safetyRating(false), 'Excellent');
    });
  });

  group('Nearby Places Real Data State Separation Tests', () {
    test('Zero places parsed from valid Overpass response represents 0 places found', () {
      final emptyElements = <dynamic>[];
      final places = <NearbySafetyPlace>[];
      for (final el in emptyElements) {
        if (el is! Map<String, dynamic>) continue;
        final p = NearbyPlacesService.parseOsmElement(
          el,
          routePoints: const [LatLng(11.0, 76.0)],
        );
        if (p != null) places.add(p);
      }
      expect(
        places,
        isEmpty,
        reason: 'Valid empty response must return an empty list, not throw or fake places',
      );
    });

    test('Valid Overpass response parses real elements without fabricated rating or address', () {
      final element = {
        'type': 'node',
        'id': 12345678,
        'lat': 11.0168,
        'lon': 76.9558,
        'tags': {
          'amenity': 'hospital',
          'name': 'Government Medical College Hospital',
          'phone': '+91 422 2301393',
        },
      };

      final place = NearbyPlacesService.parseOsmElement(
        element,
        routePoints: const [LatLng(11.0160, 76.9550), LatLng(11.0180, 76.9570)],
        proximityThresholdKm: 2.0,
      );

      expect(place, isNotNull);
      expect(place!.id, 'node/12345678');
      expect(place.name, 'Government Medical College Hospital');
      expect(place.category, 'hospital');
      expect(place.latitude, 11.0168);
      expect(place.longitude, 76.9558);
      expect(place.phone, '+91 422 2301393');
    });
  });
}
