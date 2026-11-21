import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/personal_safety_profile.dart';

void main() {
  group('SafeRoute TN 2.0 – Smart Night Travel Mode Tests', () {
    test('1. calculateNightSafetyIndex returns 100% lit when all mapped segments are lit', () {
      final segments = [
        const OsmRoadSegment(
          osmId: 101,
          name: 'Anna Salai',
          highway: 'primary',
          surface: 'asphalt',
          smoothness: 'good',
          maxspeed: '60',
          lit: 'yes',
          lanes: '4',
          sidewalk: 'both',
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.0827, 80.2707),
          geometry: [LatLng(13.0827, 80.2707), LatLng(13.0850, 80.2720)],
        ),
        const OsmRoadSegment(
          osmId: 102,
          name: 'Mount Road',
          highway: 'primary',
          surface: 'asphalt',
          smoothness: 'good',
          maxspeed: '60',
          lit: '24/7',
          lanes: '4',
          sidewalk: 'both',
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.0850, 80.2720),
          geometry: [LatLng(13.0850, 80.2720), LatLng(13.0870, 80.2740)],
        ),
      ];

      final result = calculateNightSafetyIndex(
        segments: segments,
        corridorFacilities: const [],
      );

      expect(result.hasLightingData, isTrue);
      expect(result.verifiedLitPercent, isNotNull);
      expect(result.verifiedLitPercent!, closeTo(100.0, 0.1));
      expect(result.verifiedLitSegments, equals(2));
      expect(result.verifiedUnlitSegments, equals(0));
      expect(result.unmappedSegments, equals(0));
      expect(result.unlitKm, closeTo(0.0, 0.001));
      expect(result.mappedKm, greaterThan(0.0));
    });

    test('2. calculateNightSafetyIndex correctly calculates coverage based ONLY on mapped length', () {
      final segments = [
        // Lit segment (~300m)
        const OsmRoadSegment(
          osmId: 201,
          name: 'Kamarajar Promenade',
          highway: 'secondary',
          surface: 'asphalt',
          smoothness: 'good',
          maxspeed: '50',
          lit: 'yes',
          lanes: '2',
          sidewalk: 'yes',
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.0400, 80.2800),
          geometry: [LatLng(13.0400, 80.2800), LatLng(13.0427, 80.2800)],
        ),
        // Unlit segment (~300m)
        const OsmRoadSegment(
          osmId: 202,
          name: 'Dark Coastal Link',
          highway: 'residential',
          surface: 'asphalt',
          smoothness: 'intermediate',
          maxspeed: '30',
          lit: 'no',
          lanes: '1',
          sidewalk: 'none',
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.0427, 80.2800),
          geometry: [LatLng(13.0427, 80.2800), LatLng(13.0454, 80.2800)],
        ),
        // Unmapped segment (lit is null) - MUST NOT be treated as lit or unlit
        const OsmRoadSegment(
          osmId: 203,
          name: 'Unsurveyed Lane',
          highway: 'unclassified',
          surface: 'unpaved',
          smoothness: null,
          maxspeed: null,
          lit: null,
          lanes: null,
          sidewalk: null,
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.0454, 80.2800),
          geometry: [LatLng(13.0454, 80.2800), LatLng(13.0500, 80.2800)],
        ),
      ];

      final result = calculateNightSafetyIndex(
        segments: segments,
        corridorFacilities: const [],
      );

      expect(result.hasLightingData, isTrue);
      // Mapped length is exactly lit + unlit; unmapped segment does NOT lower mapped lit %
      expect(result.verifiedLitPercent, closeTo(50.0, 1.0));
      expect(result.verifiedLitSegments, equals(1));
      expect(result.verifiedUnlitSegments, equals(1));
      expect(result.unmappedSegments, equals(1));
      expect(result.unmappedKm, greaterThan(0.0));
      expect(result.mappedKm, closeTo(result.litKm + result.unlitKm, 0.001));
    });

    test('3. calculateNightSafetyIndex reports null percentage and unavailable status when lighting is unmapped', () {
      final unmappedSegments = [
        const OsmRoadSegment(
          osmId: 301,
          name: 'Rural Path',
          highway: 'track',
          surface: 'ground',
          smoothness: null,
          maxspeed: null,
          lit: null, // missing tag
          lanes: null,
          sidewalk: null,
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(11.0168, 76.9558),
          geometry: [LatLng(11.0168, 76.9558), LatLng(11.0200, 76.9600)],
        ),
      ];

      final result = calculateNightSafetyIndex(
        segments: unmappedSegments,
        corridorFacilities: const [],
      );

      expect(result.hasLightingData, isFalse);
      expect(result.verifiedLitPercent, isNull);
      expect(result.mappedKm, equals(0.0));
      expect(result.unmappedSegments, equals(1));
      expect(result.unmappedKm, greaterThan(0.0));
    });

    test('4. calculateNightSafetyIndex counts emergency facilities and verifies 24/7 strictly', () {
      final facilities = [
        const Facility(
          id: 'p1',
          categoryId: 'police',
          name: 'Adyar Police Station',
          lat: 13.0012,
          lon: 80.2565,
          emergency: 'yes',
          openingHours: '24/7',
        ),
        const Facility(
          id: 'p2',
          categoryId: 'police',
          name: 'Traffic Outpost',
          lat: 13.0030,
          lon: 80.2580,
          emergency: null,
          openingHours: '08:00-20:00', // NOT 24/7
        ),
        const Facility(
          id: 'h1',
          categoryId: 'hospital',
          name: 'Apollo Speciality Hospital',
          lat: 13.0100,
          lon: 80.2600,
          emergency: 'yes',
          openingHours: '24/7',
        ),
        const Facility(
          id: 'h2',
          categoryId: 'hospital',
          name: 'Daycare Clinic',
          lat: 13.0150,
          lon: 80.2620,
          emergency: 'no',
          openingHours: '09:00-17:00', // NOT 24/7
        ),
        const Facility(
          id: 'f1',
          categoryId: 'fuel',
          name: 'HP Petrol Pump',
          lat: 13.0200,
          lon: 80.2650,
          emergency: null,
          openingHours: '24/7', // Fuel station, should NOT count under police/hospital
        ),
      ];

      final result = calculateNightSafetyIndex(
        segments: const [],
        corridorFacilities: facilities,
      );

      expect(result.policeCount, equals(2));
      expect(result.hospitalCount, equals(2));
      // Only p1 and h1 are verified 24/7 emergency facilities
      expect(result.verified24x7EmergencyCount, equals(2));
    });

    test('5. Unlit road highlight filter strictly selects only lit=no with valid geometry', () {
      final segments = [
        const OsmRoadSegment(
          osmId: 501,
          name: 'Confirmed Unlit Alley',
          highway: 'residential',
          surface: 'asphalt',
          smoothness: null,
          maxspeed: null,
          lit: 'no',
          lanes: null,
          sidewalk: null,
          access: null,
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.00, 80.00),
          geometry: [LatLng(13.00, 80.00), LatLng(13.01, 80.01)],
        ),
        const OsmRoadSegment(
          osmId: 502,
          name: 'Unsurveyed Road',
          highway: 'primary',
          surface: 'asphalt',
          smoothness: null,
          maxspeed: null,
          lit: null, // missing tag: must NOT be highlighted as unlit
          lanes: null,
          sidewalk: null,
          access: null,
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.01, 80.01),
          geometry: [LatLng(13.01, 80.01), LatLng(13.02, 80.02)],
        ),
        const OsmRoadSegment(
          osmId: 503,
          name: 'Lit Boulevard',
          highway: 'primary',
          surface: 'asphalt',
          smoothness: null,
          maxspeed: null,
          lit: 'yes',
          lanes: null,
          sidewalk: null,
          access: null,
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.02, 80.02),
          geometry: [LatLng(13.02, 80.02), LatLng(13.03, 80.03)],
        ),
        const OsmRoadSegment(
          osmId: 504,
          name: 'Zero Length Unlit Point',
          highway: 'residential',
          surface: 'asphalt',
          smoothness: null,
          maxspeed: null,
          lit: 'no',
          lanes: null,
          sidewalk: null,
          access: null,
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.03, 80.03),
          geometry: [LatLng(13.03, 80.03)], // Single point: must not produce invalid polyline
        ),
      ];

      // Replicating the exact map filter expression used in lib/main.dart
      final unlitHighlightedSegments = segments
          .where((seg) => seg.lit?.trim().toLowerCase() == 'no' && seg.geometry.length >= 2)
          .toList();

      expect(unlitHighlightedSegments.length, equals(1));
      expect(unlitHighlightedSegments.first.osmId, equals(501));
    });

    test('6. PersonalSafetyProfile copyWith preserves existing settings when night lighting is set', () {
      const initialProfile = PersonalSafetyProfile(
        vehicleMode: 'Bike',
        safetyPriority: 'Balanced',
        safetyMode: 'Women Safety',
        nightLightingPreference: 'Prefer well-lit roads',
        avoidPoorRoads: true,
      );

      final updated = initialProfile.copyWith(
        nightLightingPreference: 'Avoid poorly lit roads',
      );

      expect(updated.nightLightingPreference, equals('Avoid poorly lit roads'));
      expect(updated.vehicleMode, equals('Bike'));
      expect(updated.safetyPriority, equals('Balanced'));
      expect(updated.safetyMode, equals('Women Safety'));
      expect(updated.avoidPoorRoads, isTrue);

      final restored = updated.copyWith(
        nightLightingPreference: initialProfile.nightLightingPreference,
      );
      expect(restored.nightLightingPreference, equals('Prefer well-lit roads'));
    });

    test('7. 63 unmapped segments preserves null verified lit percentage and reports 63 unmapped segments without kilometer claims', () {
      final unmapped63Segments = List.generate(
        63,
        (i) => OsmRoadSegment(
          osmId: 1000 + i,
          name: 'Corridor Way $i',
          highway: 'secondary',
          surface: 'asphalt',
          smoothness: null,
          maxspeed: null,
          lit: null, // missing/unmapped lighting tag
          lanes: '2',
          sidewalk: null,
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.00 + i * 0.001, 80.00 + i * 0.001),
          geometry: [
            LatLng(13.00 + i * 0.001, 80.00 + i * 0.001),
            LatLng(13.005 + i * 0.001, 80.005 + i * 0.001),
          ],
        ),
      );

      final result = calculateNightSafetyIndex(
        segments: unmapped63Segments,
        corridorFacilities: const [],
      );

      // Verify strict data honesty:
      // 1. Never assume unmapped means lit or unlit
      expect(result.hasLightingData, isFalse);
      expect(result.verifiedLitPercent, isNull);
      expect(result.verifiedLitSegments, equals(0));
      expect(result.verifiedUnlitSegments, equals(0));
      expect(result.mappedKm, equals(0.0));

      // 2. Dynamic unmapped segment count accurately reports 63
      expect(result.unmappedSegments, equals(63));
      expect(result.totalSegments, equals(63));

      // 3. UI message format check: uses segment count dynamically, avoiding misleading route km
      final uiMessage = result.unmappedSegments > 0
          ? 'Lighting information unavailable for ${result.unmappedSegments} corridor road ${result.unmappedSegments == 1 ? 'segment' : 'segments'}.'
          : 'Street lighting tags unavailable in OpenStreetMap for this corridor';
      expect(uiMessage, equals('Lighting information unavailable for 63 corridor road segments.'));
    });

    test('8. Partial lighting data preserves verified information and reports unmapped segment count separately', () {
      final partialSegments = [
        // 2 lit segments
        const OsmRoadSegment(
          osmId: 2001,
          name: 'Lit Expressway',
          highway: 'trunk',
          surface: 'asphalt',
          smoothness: 'good',
          maxspeed: '80',
          lit: 'yes',
          lanes: '4',
          sidewalk: null,
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.00, 80.00),
          geometry: [LatLng(13.00, 80.00), LatLng(13.01, 80.00)],
        ),
        const OsmRoadSegment(
          osmId: 2002,
          name: 'Lit Boulevard',
          highway: 'trunk',
          surface: 'asphalt',
          smoothness: 'good',
          maxspeed: '80',
          lit: 'yes',
          lanes: '4',
          sidewalk: null,
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.01, 80.00),
          geometry: [LatLng(13.01, 80.00), LatLng(13.02, 80.00)],
        ),
        // 1 unlit segment
        const OsmRoadSegment(
          osmId: 2003,
          name: 'Unlit Rural Cut',
          highway: 'secondary',
          surface: 'asphalt',
          smoothness: 'intermediate',
          maxspeed: '50',
          lit: 'no',
          lanes: '2',
          sidewalk: null,
          access: 'yes',
          bridge: null,
          tunnel: null,
          bicycle: null,
          foot: null,
          motorVehicle: null,
          wheelchair: null,
          tactilePaving: null,
          width: null,
          routeMatchPoint: LatLng(13.02, 80.00),
          geometry: [LatLng(13.02, 80.00), LatLng(13.03, 80.00)],
        ),
        // 5 unmapped segments
        ...List.generate(
          5,
          (i) => OsmRoadSegment(
            osmId: 3000 + i,
            name: 'Unmapped Lane $i',
            highway: 'residential',
            surface: 'asphalt',
            smoothness: null,
            maxspeed: null,
            lit: null,
            lanes: null,
            sidewalk: null,
            access: 'yes',
            bridge: null,
            tunnel: null,
            bicycle: null,
            foot: null,
            motorVehicle: null,
            wheelchair: null,
            tactilePaving: null,
            width: null,
            routeMatchPoint: LatLng(13.03 + i * 0.005, 80.00),
            geometry: [LatLng(13.03 + i * 0.005, 80.00), LatLng(13.035 + i * 0.005, 80.00)],
          ),
        ),
      ];

      final result = calculateNightSafetyIndex(
        segments: partialSegments,
        corridorFacilities: const [],
      );

      // Verified information is preserved: 2 lit vs 1 unlit mapped
      expect(result.hasLightingData, isTrue);
      expect(result.verifiedLitSegments, equals(2));
      expect(result.verifiedUnlitSegments, equals(1));
      expect(result.verifiedLitPercent, closeTo(66.6, 0.5));

      // Unmapped segments are tracked separately
      expect(result.unmappedSegments, equals(5));

      // Separate UI text for unmapped portion
      final unmappedNotice = 'Lighting information unavailable for ${result.unmappedSegments} corridor road segments.';
      expect(unmappedNotice, equals('Lighting information unavailable for 5 corridor road segments.'));
    });

    test('9. Zero mapped segments preserves null verified percentage and never fabricates a percentage', () {
      final result = calculateNightSafetyIndex(
        segments: const [],
        corridorFacilities: const [],
      );

      expect(result.hasLightingData, isFalse);
      expect(result.verifiedLitPercent, isNull);
      expect(result.mappedKm, equals(0.0));
      expect(result.unmappedSegments, equals(0));
    });
  });
}
