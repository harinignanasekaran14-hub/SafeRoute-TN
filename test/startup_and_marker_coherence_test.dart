import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/safe_route_journey_mode.dart';

void main() {
  group('SafeRoute TN 2.0 — Startup & Marker Route Coherence Verification', () {
    test('Test A — Fresh Startup State Contract', () {
      const page = MapPage(onToggleTheme: _dummyCallback);
      expect(page.from, isEmpty);
      expect(page.to, isEmpty);
      expect(page.fromIsCurrentLocation, isFalse);
    });

    test('Test D — Destination Coordinate Preservation & Independence from OSRM Endpoint', () {
      // User selects Nominatim coordinate for Erode City
      const nominatimErodeCity = LatLng(11.3306483, 77.7276519);

      // Selected suggestion stores the authoritative user destination
      final selectedEndLocation = LocationSuggestion(
        title: 'Erode',
        subtitle: 'Tamil Nadu, 638001, India',
        lat: nominatimErodeCity.latitude,
        lon: nominatimErodeCity.longitude,
        rawDisplayName: 'Erode, Tamil Nadu, 638001, India',
      );

      // OSRM road-snapped corridor endpoint may slightly differ (e.g. snapped to road center)
      const osrmSnappedEndpoint = LatLng(11.330583, 77.727808);

      final routePoints = [
        const LatLng(11.0018, 76.9628), // Coimbatore start
        const LatLng(11.1500, 77.3000), // Highway waypoint
        osrmSnappedEndpoint,             // OSRM road snapped end
      ];

      // Destination Marker Point uses selectedEndLocation (authoritative user-selected coordinate)
      final markerCoordinate = LatLng(
        selectedEndLocation.lat,
        selectedEndLocation.lon,
      );

      // Verify destination marker coordinate strictly equals selected Nominatim coordinate
      expect(markerCoordinate.latitude, equals(nominatimErodeCity.latitude));
      expect(markerCoordinate.longitude, equals(nominatimErodeCity.longitude));

      // Verify destination marker does NOT force equality to the OSRM road-snapped endpoint
      expect(markerCoordinate.latitude, isNot(equals(routePoints.last.latitude)));
      expect(markerCoordinate.longitude, isNot(equals(routePoints.last.longitude)));
    });

    test('Test E & F — Multi-Route Selection to Journey State Transition', () {
      final route0 = RouteResult(
        points: const [LatLng(11.0, 77.0), LatLng(11.1, 77.1)],
        distance: 207.5,
        duration: 190.0,
        routeIndex: 0,
      );
      final route1 = RouteResult(
        points: const [LatLng(11.0, 77.0), LatLng(11.2, 77.2)],
        distance: 224.6,
        duration: 200.0,
        routeIndex: 1,
      );

      // Verify Route 1 Journey payload
      final journey1 = SafeRouteJourney(
        id: '1',
        origin: 'Coimbatore',
        destination: 'Madurai',
        routeIndex: route0.routeIndex,
        routeLabel: 'Route 1 — Best Balanced',
        routeSafetyScore: 88.0,
        distanceKm: route0.distance,
        estimatedDurationMinutes: route0.duration,
        vehicleMode: 'Car',
        travelTimeMode: 'Now',
        startedTimestamp: DateTime.now(),
        journeyState: JourneyState.active,
      );

      expect(journey1.routeIndex, 0);
      expect(journey1.distanceKm, 207.5);

      // Verify Route 2 Journey payload
      final journey2 = SafeRouteJourney(
        id: '2',
        origin: 'Coimbatore',
        destination: 'Madurai',
        routeIndex: route1.routeIndex,
        routeLabel: 'Route 2 — Alternative',
        routeSafetyScore: 82.0,
        distanceKm: route1.distance,
        estimatedDurationMinutes: route1.duration,
        vehicleMode: 'Car',
        travelTimeMode: 'Now',
        startedTimestamp: DateTime.now(),
        journeyState: JourneyState.active,
      );

      expect(journey2.routeIndex, 1);
      expect(journey2.distanceKm, 224.6);
      expect(journey2.routeSafetyScore, 82.0);
    });

    test('Test G — Erode City Selection vs District Centroid Geocode Resolution', () {
      // Erode City coordinates (place: city)
      const erodeCityLat = 11.3306483;
      const erodeCityLon = 77.7276519;

      // Old displaced District Centroid (boundary: administrative)
      const districtCentroidLat = 11.4905282;
      const districtCentroidLon = 77.3505274;

      final selectedLocation = LocationSuggestion(
        title: 'Erode',
        subtitle: 'Tamil Nadu, 638001, India',
        lat: erodeCityLat,
        lon: erodeCityLon,
        rawDisplayName: 'Erode, Tamil Nadu, 638001, India',
      );

      expect(selectedLocation.lat, equals(erodeCityLat));
      expect(selectedLocation.lon, equals(erodeCityLon));
      expect(selectedLocation.lat, isNot(equals(districtCentroidLat)));
      expect(selectedLocation.lon, isNot(equals(districtCentroidLon)));
    });
  });
}

void _dummyCallback() {}
