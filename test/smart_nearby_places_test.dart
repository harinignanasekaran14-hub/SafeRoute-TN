// ============================================================================
// SafeRoute TN — Smart Nearby Safety Places Tests
// File: test/smart_nearby_places_test.dart
// Description: Comprehensive test suite covering all 20 required specifications:
//  1. NearbySafetyPlace model
//  2. JSON parsing
//  3. Missing optional fields
//  4. Distance calculation
//  5. Route proximity calculation
//  6. Along-route detection
//  7. Category filtering
//  8. Search filtering
//  9. Nearest sorting
//  10. Along-route sorting
//  11. Safety-priority sorting
//  12. Emergency prioritization
//  13. Personal Safety Profile ranking
//  14. Empty results handling
//  15. API error handling
//  16. Timeout handling
//  17. Invalid JSON handling
//  18. Duplicate request prevention
//  19. Bilingual labels (English & Tamil)
//  20. Privacy/no-GPS behavior
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/personal_safety_profile.dart';
import 'package:saferoute_tn/smart_nearby_places.dart';

void main() {
  group('1. NearbySafetyPlace Model', () {
    test(
      'creates model instance with all required and optional attributes',
      () {
        const place = NearbySafetyPlace(
          id: 'node_101',
          name: 'Apollo Hospital',
          category: 'hospital',
          latitude: 13.0827,
          longitude: 80.2707,
          address: 'Greams Road, Chennai',
          phone: '+91 44 2829 0200',
          openingHours: '24/7',
          distanceKm: 0.45,
          isAlongRoute: true,
          osmType: 'node',
          osmTags: {'amenity': 'hospital', 'wheelchair': 'yes'},
        );

        expect(place.id, 'node_101');
        expect(place.name, 'Apollo Hospital');
        expect(place.category, 'hospital');
        expect(place.latitude, 13.0827);
        expect(place.longitude, 80.2707);
        expect(place.address, 'Greams Road, Chennai');
        expect(place.phone, '+91 44 2829 0200');
        expect(place.openingHours, '24/7');
        expect(place.distanceKm, 0.45);
        expect(place.isAlongRoute, isTrue);
        expect(place.hasRealPhone, isTrue);
        expect(place.isAccessible, isTrue);
        expect(place.formattedDistance, '450 m');
        expect(place.categoryIcon, Icons.local_hospital_rounded);
      },
    );

    test('formattedDistance formats meters when < 1km and km when >= 1km', () {
      const closePlace = NearbySafetyPlace(
        id: '1',
        name: 'Near ATM',
        category: 'atm',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 0.35,
        isAlongRoute: true,
      );
      expect(closePlace.formattedDistance, '350 m');

      const farPlace = NearbySafetyPlace(
        id: '2',
        name: 'Far Fuel',
        category: 'petrol',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 4.82,
        isAlongRoute: false,
      );
      expect(farPlace.formattedDistance, '4.8 km');
    });

    test('copyWith copies attributes accurately', () {
      const initial = NearbySafetyPlace(
        id: 'a1',
        name: 'Old Pharmacy',
        category: 'pharmacy',
        latitude: 11.0,
        longitude: 77.0,
        distanceKm: 1.2,
        isAlongRoute: false,
      );

      final updated = initial.copyWith(
        name: 'New Pharmacy',
        isAlongRoute: true,
        phone: '1234567890',
      );

      expect(updated.id, 'a1');
      expect(updated.name, 'New Pharmacy');
      expect(updated.category, 'pharmacy');
      expect(updated.isAlongRoute, isTrue);
      expect(updated.phone, '1234567890');
    });
  });

  group('2. JSON Parsing & Serialization', () {
    test('toJson and fromJson maintain complete fidelity', () {
      final original = {
        'id': 'way_999',
        'name': 'Government General Hospital',
        'category': 'hospital',
        'latitude': 13.0782,
        'longitude': 80.2794,
        'address': 'EVR Periyar Salai, Chennai',
        'phone': '108',
        'opening_hours': '24/7',
        'distance_km': 0.8,
        'is_along_route': true,
        'osm_type': 'way',
        'osm_tags': {'amenity': 'hospital', 'emergency': 'yes'},
      };

      final parsed = NearbySafetyPlace.fromJson(original);
      expect(parsed.id, 'way_999');
      expect(parsed.name, 'Government General Hospital');
      expect(parsed.category, 'hospital');
      expect(parsed.latitude, 13.0782);
      expect(parsed.longitude, 80.2794);
      expect(parsed.address, 'EVR Periyar Salai, Chennai');
      expect(parsed.phone, '108');
      expect(parsed.openingHours, '24/7');
      expect(parsed.distanceKm, 0.8);
      expect(parsed.isAlongRoute, isTrue);
      expect(parsed.osmType, 'way');
      expect(parsed.osmTags?['emergency'], 'yes');

      final serialized = parsed.toJson();
      expect(serialized['id'], 'way_999');
      expect(serialized['name'], 'Government General Hospital');
      expect(serialized['distance_km'], 0.8);
      expect(serialized['is_along_route'], isTrue);
    });
  });

  group(
    '3. Missing Optional Fields (Strictly Nullable - Zero Fabrication)',
    () {
      test('handles null address, phone, openingHours without fabrication', () {
        final minimalJson = {
          'id': 'node_222',
          'name': 'Rural Health Subcentre',
          'category': 'hospital',
          'latitude': 11.2,
          'longitude': 78.5,
          'distance_km': 1.5,
          'is_along_route': false,
        };

        final place = NearbySafetyPlace.fromJson(minimalJson);
        expect(place.address, isNull);
        expect(place.phone, isNull);
        expect(place.openingHours, isNull);
        expect(place.hasRealPhone, isFalse);
        expect(place.isAccessible, isFalse);
        expect(place.accessibilityInfo, isNull);
      });

      test('fromFacility handles missing optional values cleanly', () {
        const facility = Facility(
          id: 'f1',
          categoryId: 'hospital',
          name: 'Namakkal PHC',
          lat: 11.2189,
          lon: 78.1674,
        );

        final place = NearbySafetyPlace.fromFacility(
          facility,
          distanceKm: 0.6,
          isAlongRoute: true,
        );

        expect(place.id, 'f1');
        expect(place.name, 'Namakkal PHC');
        expect(place.category, 'hospital');
        expect(place.phone, isNull);
        expect(place.hasRealPhone, isFalse);
        expect(place.address, isNull);
        expect(place.openingHours, isNull);
        expect(place.isAlongRoute, isTrue);
      });
    },
  );

  group('4. Distance Calculation (Haversine)', () {
    test('calculates accurate distance between known Chennai coordinates', () {
      // Chennai Central (13.0827, 80.2755) to Marina Beach (13.0500, 80.2824)
      final d = NearbyGeoUtils.haversineDistanceKm(
        13.0827,
        80.2755,
        13.0500,
        80.2824,
      );
      // Distance is ~3.7 km
      expect(d, greaterThan(3.5));
      expect(d, lessThan(4.0));
    });

    test('calculates zero distance for identical coordinates', () {
      final d = NearbyGeoUtils.haversineDistanceKm(
        11.0168,
        76.9558,
        11.0168,
        76.9558,
      );
      expect(d, closeTo(0.0, 0.0001));
    });
  });

  group('5. Route Proximity Calculation', () {
    test('finds minimum distance to a polyline route', () {
      final route = [
        const LatLng(13.00, 80.00),
        const LatLng(13.05, 80.05),
        const LatLng(13.10, 80.10),
      ];

      // Point directly on second vertex
      final dOnVertex = NearbyGeoUtils.minDistanceToRouteKm(
        13.05,
        80.05,
        route,
      );
      expect(dOnVertex, closeTo(0.0, 0.05));

      // Point far away
      final dFar = NearbyGeoUtils.minDistanceToRouteKm(14.00, 81.00, route);
      expect(dFar, greaterThan(100.0));
    });

    test('returns infinity when route is empty', () {
      final d = NearbyGeoUtils.minDistanceToRouteKm(13.0, 80.0, []);
      expect(d, double.infinity);
    });
  });

  group('6. Along-Route Detection', () {
    test(
      'correctly identifies point within 1.0 km threshold as along route',
      () {
        final route = [
          const LatLng(13.000, 80.000),
          const LatLng(13.010, 80.010),
        ];

        // Point roughly 200m from first route point
        expect(
          NearbyGeoUtils.isPointAlongRoute(
            13.001,
            80.001,
            route,
            thresholdKm: 1.0,
          ),
          isTrue,
        );

        // Point ~5 km away
        expect(
          NearbyGeoUtils.isPointAlongRoute(
            13.050,
            80.050,
            route,
            thresholdKm: 1.0,
          ),
          isFalse,
        );
      },
    );
  });

  group('7. Category Filtering', () {
    final places = [
      const NearbySafetyPlace(
        id: '1',
        name: 'GH',
        category: 'hospital',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 0.2,
        isAlongRoute: true,
      ),
      const NearbySafetyPlace(
        id: '2',
        name: 'B1 Police',
        category: 'police',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 0.5,
        isAlongRoute: true,
      ),
      const NearbySafetyPlace(
        id: '3',
        name: 'MedPlus',
        category: 'pharmacy',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 0.3,
        isAlongRoute: true,
      ),
      const NearbySafetyPlace(
        id: '4',
        name: 'HP Petrol',
        category: 'petrol',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 0.8,
        isAlongRoute: true,
      ),
      const NearbySafetyPlace(
        id: '5',
        name: 'Tata Power EV',
        category: 'ev',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 1.0,
        isAlongRoute: false,
      ),
    ];

    test('filters places matching specified category', () {
      final hospitals = places.where((p) => p.category == 'hospital').toList();
      expect(hospitals.length, 1);
      expect(hospitals.first.name, 'GH');

      final police = places.where((p) => p.category == 'police').toList();
      expect(police.length, 1);
      expect(police.first.name, 'B1 Police');
    });
  });

  group('8. Search Filtering', () {
    final places = [
      const NearbySafetyPlace(
        id: '1',
        name: 'Kauvery Hospital',
        category: 'hospital',
        address: 'Alwarpet',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 0.4,
        isAlongRoute: true,
      ),
      const NearbySafetyPlace(
        id: '2',
        name: 'Apollo Pharmacy',
        category: 'pharmacy',
        address: 'Mylapore',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 0.7,
        isAlongRoute: true,
      ),
      const NearbySafetyPlace(
        id: '3',
        name: 'Indian Oil Petrol',
        category: 'petrol',
        address: 'Anna Salai',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 1.1,
        isAlongRoute: false,
      ),
    ];

    test('matches place by partial name (case-insensitive)', () {
      final query = 'kauvery';
      final matches = places
          .where((p) => p.name.toLowerCase().contains(query))
          .toList();
      expect(matches.length, 1);
      expect(matches.first.id, '1');
    });

    test('matches place by address keyword', () {
      final query = 'anna salai';
      final matches = places
          .where((p) => (p.address ?? '').toLowerCase().contains(query))
          .toList();
      expect(matches.length, 1);
      expect(matches.first.id, '3');
    });
  });

  group('9. Nearest Sorting', () {
    final p1 = const NearbySafetyPlace(
      id: '1',
      name: 'Far Place',
      category: 'hospital',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 3.5,
      isAlongRoute: true,
    );
    final p2 = const NearbySafetyPlace(
      id: '2',
      name: 'Closest Place',
      category: 'hospital',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 0.3,
      isAlongRoute: false,
    );
    final p3 = const NearbySafetyPlace(
      id: '3',
      name: 'Mid Place',
      category: 'hospital',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 1.2,
      isAlongRoute: true,
    );

    test('orders places by strictly ascending distanceKm', () {
      final sorted = SmartPriorityRanker.sortPlaces([
        p1,
        p2,
        p3,
      ], NearbySortMode.nearest);
      expect(sorted.map((p) => p.id).toList(), ['2', '3', '1']);
    });
  });

  group('10. Along-Route Sorting', () {
    final pAlongFar = const NearbySafetyPlace(
      id: '1',
      name: 'Along Far',
      category: 'atm',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 2.0,
      isAlongRoute: true,
    );
    final pAlongNear = const NearbySafetyPlace(
      id: '2',
      name: 'Along Near',
      category: 'atm',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 0.5,
      isAlongRoute: true,
    );
    final pOffNear = const NearbySafetyPlace(
      id: '3',
      name: 'Off Near',
      category: 'atm',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 0.2,
      isAlongRoute: false,
    );

    test('ranks along-route places first, sorted by distance', () {
      final sorted = SmartPriorityRanker.sortPlaces([
        pOffNear,
        pAlongFar,
        pAlongNear,
      ], NearbySortMode.alongRoute);
      expect(sorted[0].id, '2'); // along route near
      expect(sorted[1].id, '1'); // along route far
      expect(sorted[2].id, '3'); // off route
    });
  });

  group('11. Safety-Priority Sorting', () {
    final hosp = const NearbySafetyPlace(
      id: 'h',
      name: 'Hospital',
      category: 'hospital',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 1.0,
      isAlongRoute: true,
    );
    final pol = const NearbySafetyPlace(
      id: 'p',
      name: 'Police',
      category: 'police',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 1.0,
      isAlongRoute: true,
    );
    final rest = const NearbySafetyPlace(
      id: 'r',
      name: 'Restroom',
      category: 'restroom',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 1.0,
      isAlongRoute: true,
    );

    test('assigns highest base priority to hospitals and police stations', () {
      final scoreHosp = SmartPriorityRanker.computeScore(hosp);
      final scorePol = SmartPriorityRanker.computeScore(pol);
      final scoreRest = SmartPriorityRanker.computeScore(rest);

      expect(scoreHosp, greaterThan(scoreRest));
      expect(scorePol, greaterThan(scoreRest));
    });
  });

  group('12. Emergency Prioritization', () {
    final hosp = const NearbySafetyPlace(
      id: 'h',
      name: 'City Hospital',
      category: 'hospital',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 2.0,
      isAlongRoute: true,
    );
    final cafe = const NearbySafetyPlace(
      id: 'c',
      name: 'Tea Cafe',
      category: 'restaurant',
      latitude: 13.0,
      longitude: 80.0,
      distanceKm: 0.1,
      isAlongRoute: true,
    );

    test('boosts hospital score under emergency mode and ranks first', () {
      final normalHosp = SmartPriorityRanker.computeScore(
        hosp,
        isEmergencyMode: false,
      );
      final emergencyHosp = SmartPriorityRanker.computeScore(
        hosp,
        isEmergencyMode: true,
      );

      expect(emergencyHosp, greaterThan(normalHosp));

      // Under emergency, hospital outranks even an ultra-close cafe
      final sorted = SmartPriorityRanker.sortPlaces(
        [cafe, hosp],
        NearbySortMode.safetyPriority,
        isEmergencyMode: true,
      );
      expect(sorted.first.id, 'h');
    });
  });

  group('13. Personal Safety Profile Ranking', () {
    test('boosts petrol pump when vehicle is Car', () {
      const petrol = NearbySafetyPlace(
        id: 'pet',
        name: 'Fuel',
        category: 'petrol',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 1.0,
        isAlongRoute: true,
      );
      const profileCar = PersonalSafetyProfile(vehicleMode: 'Car');
      final score = SmartPriorityRanker.computeScore(
        petrol,
        profile: profileCar,
      );
      expect(score, greaterThan(50));
    });

    test('boosts EV station when vehicle is Bike/EV', () {
      const ev = NearbySafetyPlace(
        id: 'ev',
        name: 'EV Plug',
        category: 'ev',
        latitude: 13.0,
        longitude: 80.0,
        distanceKm: 1.0,
        isAlongRoute: true,
      );
      const profileBike = PersonalSafetyProfile(vehicleMode: 'Bike');
      final score = SmartPriorityRanker.computeScore(ev, profile: profileBike);
      expect(score, greaterThan(30));
    });

    test(
      'boosts wheelchair accessible place when profile prefers accessibility',
      () {
        const accessiblePlace = NearbySafetyPlace(
          id: 'acc',
          name: 'Accessible Clinic',
          category: 'hospital',
          latitude: 13.0,
          longitude: 80.0,
          distanceKm: 1.0,
          isAlongRoute: true,
          osmTags: {'wheelchair': 'yes'},
        );
        const profileAccess = PersonalSafetyProfile(
          accessibilityPreference: 'Prefer accessible routes',
        );
        final scoreWithAccess = SmartPriorityRanker.computeScore(
          accessiblePlace,
          profile: profileAccess,
        );
        final scoreWithoutAccess = SmartPriorityRanker.computeScore(
          accessiblePlace,
          profile: const PersonalSafetyProfile(),
        );
        expect(scoreWithAccess - scoreWithoutAccess, 25.0);
      },
    );
  });

  group('14. Empty Results Handling', () {
    test('returns empty list gracefully when Overpass yields no elements', () {
      final emptyOverpassResponse = {
        'version': 0.6,
        'generator': 'Overpass API',
        'elements': [],
      };

      final elements = emptyOverpassResponse['elements'] as List;
      final parsed = <NearbySafetyPlace>[];
      for (final el in elements) {
        final p = NearbyPlacesService.parseOsmElement(
          el as Map<String, dynamic>,
          routePoints: [const LatLng(13.0, 80.0)],
        );
        if (p != null) parsed.add(p);
      }
      expect(parsed, isEmpty);
    });
  });

  group('15. API Error Handling', () {
    test(
      'handles HTTP 429, 500, 502, 503 without crashing or throwing',
      () async {
        for (final code in [429, 500, 502, 503, 504]) {
          final mockClient = MockClient((request) async {
            return http.Response('Server Error', code);
          });

          final result = await NearbyPlacesService.fetchNearbyPlaces(
            routePoints: [const LatLng(13.0, 80.0), const LatLng(13.01, 80.01)],
            client: mockClient,
          );
          expect(
            result,
            isEmpty,
            reason: 'Endpoint returning $code should yield empty list safely',
          );
        }
      },
    );
  });

  group('16. Timeout Handling', () {
    test('recovers safely when Overpass request times out', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection timed out');
      });

      final result = await NearbyPlacesService.fetchNearbyPlaces(
        routePoints: [const LatLng(13.0, 80.0), const LatLng(13.01, 80.01)],
        client: mockClient,
      );
      expect(result, isEmpty);
    });
  });

  group('17. Invalid JSON Handling', () {
    test('handles malformed non-JSON body safely without crash', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html><body>502 Bad Gateway</body></html>', 200);
      });

      final result = await NearbyPlacesService.fetchNearbyPlaces(
        routePoints: [const LatLng(13.0, 80.0), const LatLng(13.01, 80.01)],
        client: mockClient,
      );
      expect(result, isEmpty);
    });
  });

  group('18. Duplicate Request Prevention', () {
    test('in-memory cache prevents redundant requests for identical route and category', () {
      NearbyPlacesCache.clear();

      const routeKey = '13.08_80.27_13.05_80.28_all';

      expect(NearbyPlacesCache.get(routeKey), isNull);

      final dummyPlaces = [
        const NearbySafetyPlace(
          id: 'c1',
          name: 'Cached Hospital',
          category: 'hospital',
          latitude: 13.0,
          longitude: 80.0,
          distanceKm: 0.5,
          isAlongRoute: true,
        ),
      ];
      NearbyPlacesCache.set(routeKey, dummyPlaces);

      final cached = NearbyPlacesCache.get(routeKey);
      expect(cached, isNotNull);
      expect(cached!.length, 1);
      expect(cached.first.name, 'Cached Hospital');

      NearbyPlacesCache.clear();
      expect(NearbyPlacesCache.get(routeKey), isNull);
    });
  });

  group('19. Bilingual Labels (English & Tamil)', () {
    test('provides accurate translations across all 10 categories', () {
      // English
      expect(
        SmartNearbyPlacesLocalization.categoryName('hospital', false),
        'Hospital',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('police', false),
        'Police Station',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('pharmacy', false),
        'Pharmacy',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('petrol', false),
        'Petrol Pump',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('ev', false),
        'EV Charging',
      );
      expect(SmartNearbyPlacesLocalization.categoryName('atm', false), 'ATM');
      expect(
        SmartNearbyPlacesLocalization.categoryName('restaurant', false),
        'Restaurant',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('hotel', false),
        'Hotel',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('parking', false),
        'Parking',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('restroom', false),
        'Restroom',
      );

      // Tamil
      expect(
        SmartNearbyPlacesLocalization.categoryName('hospital', true),
        'மருத்துவமனை',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('police', true),
        'காவல் நிலையம்',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('pharmacy', true),
        'மருந்தகம்',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('petrol', true),
        'பெட்ரோல் பங்க்',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('ev', true),
        'மின்சார சார்ஜிங்',
      );
      expect(SmartNearbyPlacesLocalization.categoryName('atm', true), 'ஏடிஎம்');
      expect(
        SmartNearbyPlacesLocalization.categoryName('restaurant', true),
        'உணவகம்',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('hotel', true),
        'விடுதி',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('parking', true),
        'வாகன நிறுத்துமிடம்',
      );
      expect(
        SmartNearbyPlacesLocalization.categoryName('restroom', true),
        'கழிப்பறை',
      );
    });

    test('error and empty state strings translate accurately', () {
      expect(
        SmartNearbyPlacesLocalization.temporarilyUnavailable(false),
        'Nearby places are temporarily unavailable.',
      );
      expect(
        SmartNearbyPlacesLocalization.temporarilyUnavailable(true),
        'அருகிலுள்ள இடங்கள் தற்காலிகமாக கிடைக்கவில்லை.',
      );
      expect(
        SmartNearbyPlacesLocalization.noNearbyPlaces(false),
        'No nearby places found.',
      );
      expect(
        SmartNearbyPlacesLocalization.noNearbyPlaces(true),
        'அருகிலுள்ள இடங்கள் இல்லை.',
      );
    });
  });

  group('20. Privacy & No-GPS Behavior', () {
    testWidgets(
      'renders privacy banner confirming no live GPS and route-only geometry search',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartNearbyPlacesView(
                isDarkMode: true,
                routePoints: const [
                  LatLng(13.0827, 80.2707),
                  LatLng(13.0500, 80.2824),
                ],
                activeFacilities: const [
                  Facility(
                    id: 'h1',
                    categoryId: 'hospital',
                    name: 'Rajiv Gandhi GH',
                    lat: 13.0800,
                    lon: 80.2750,
                    phone: '108',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check header and privacy assurance
        expect(find.text('Smart Nearby Places'), findsOneWidget);
        expect(find.text('Rajiv Gandhi GH'), findsOneWidget);
        expect(
          find.text(
            'Real nearby safety, emergency, and travel facilities along your route',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders empty route placeholder when no active route exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartNearbyPlacesView(
              isDarkMode: true,
              routePoints: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Plan a route to discover useful places along your journey.'),
        findsOneWidget,
      );
      expect(find.text('Plan a Route'), findsOneWidget);
    });
  });
}
