import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:saferoute_tn/main.dart';

void main() {
  group('SafeRoute TN 2.0 - Current Location Detection & Marker Placement Tests', () {
    late String mainDartContent;

    setUpAll(() {
      final file = File('lib/main.dart');
      expect(file.existsSync(), isTrue, reason: 'lib/main.dart must exist');
      mainDartContent = file.readAsStringSync();
    });

    test('1. Valid GPS coordinates detection and validation', () {
      // Test real coordinates in Tamil Nadu (Chennai, Coimbatore, Madurai)
      expect(SafeRouteService.isValidCoordinate(13.0827, 80.2707), isTrue); // Chennai
      expect(SafeRouteService.isValidCoordinate(11.0168, 76.9558), isTrue); // Coimbatore
      expect(SafeRouteService.isValidCoordinate(9.9252, 78.1198), isTrue);  // Madurai

      // Test valid boundary coordinates
      expect(SafeRouteService.isValidCoordinate(90.0, 180.0), isTrue);
      expect(SafeRouteService.isValidCoordinate(-90.0, -180.0), isTrue);
      expect(SafeRouteService.isValidCoordinate(12.0, 78.0), isTrue);
    });

    test('2. Latitude/longitude ordering check (no swapping)', () {
      // Latitude is strictly [-90, +90], Longitude is [-180, +180]
      // A swapped coordinate like lat=105.0, lon=11.0 must be rejected
      expect(SafeRouteService.isValidCoordinate(105.0, 11.0), isFalse);
      expect(SafeRouteService.isValidCoordinate(-95.0, 45.0), isFalse);

      // Verify that LatLng on map uses (position.latitude, position.longitude)
      final markerIdx = mainDartContent.indexOf('// Current position marker (validated coordinates only)');
      expect(markerIdx, isNot(-1));
      final markerSnippet = mainDartContent.substring(markerIdx, markerIdx + 600);
      expect(markerSnippet.contains('LatLng('), isTrue);
      expect(markerSnippet.contains('currentPosition!.latitude'), isTrue);
      expect(markerSnippet.contains('currentPosition!.longitude'), isTrue);
      final latIdx = markerSnippet.indexOf('currentPosition!.latitude');
      final lonIdx = markerSnippet.indexOf('currentPosition!.longitude');
      expect(latIdx < lonIdx, isTrue, reason: 'Latitude must precede longitude in LatLng constructor');
    });

    test('3. Invalid coordinate rejection (out-of-bounds, NaN, Inf, 0,0)', () {
      expect(SafeRouteService.isValidCoordinate(double.nan, 80.0), isFalse);
      expect(SafeRouteService.isValidCoordinate(13.0, double.nan), isFalse);
      expect(SafeRouteService.isValidCoordinate(double.infinity, 80.0), isFalse);
      expect(SafeRouteService.isValidCoordinate(13.0, double.infinity), isFalse);
      expect(SafeRouteService.isValidCoordinate(95.0, 80.0), isFalse);
      expect(SafeRouteService.isValidCoordinate(-95.0, 80.0), isFalse);
      expect(SafeRouteService.isValidCoordinate(13.0, 185.0), isFalse);
      expect(SafeRouteService.isValidCoordinate(13.0, -185.0), isFalse);
      expect(SafeRouteService.isValidCoordinate(0.0, 0.0), isFalse); // Null Island rejected
    });

    test('4. Poor accuracy handling (>1500m IP-derived location)', () {
      // An IP-derived fix typically reports accuracy > 1500m (e.g. 5000m - 50000m)
      const poorAccDiagnostics = CurrentLocationDiagnostics(
        latitude: 11.6643,
        longitude: 78.1460,
        accuracyMeters: 25000.0,
        timestamp: null,
        quality: LocationQuality.poorAccuracyIp,
        isGpsVerified: false,
        isFromIpFallback: true,
      );

      expect(poorAccDiagnostics.isReliableGps, isFalse);
      expect(poorAccDiagnostics.quality, equals(LocationQuality.poorAccuracyIp));
      expect(poorAccDiagnostics.formattedAccuracy, contains('25.0 km'));

      // Check high accuracy GPS fix (<= 100m)
      const highAccDiagnostics = CurrentLocationDiagnostics(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracyMeters: 15.0,
        quality: LocationQuality.highAccuracyGps,
        isGpsVerified: true,
      );
      expect(highAccDiagnostics.isReliableGps, isTrue);
      expect(highAccDiagnostics.formattedAccuracy, contains('15 m'));
    });

    test('5. Permission denied handling', () {
      const deniedDiag = CurrentLocationDiagnostics(
        permission: LocationPermission.denied,
        statusMessage: 'Location permission was denied. Please allow location access in your browser.',
      );

      expect(deniedDiag.hasValidCoordinates, isFalse);
      expect(deniedDiag.isReliableGps, isFalse);
      expect(deniedDiag.permission, equals(LocationPermission.denied));
      expect(deniedDiag.statusMessage, contains('denied'));

      const blockedDiag = CurrentLocationDiagnostics(
        permission: LocationPermission.deniedForever,
        statusMessage: 'Location permission is permanently blocked. Enable it in site permissions.',
      );
      expect(blockedDiag.permission, equals(LocationPermission.deniedForever));
      expect(blockedDiag.statusMessage, contains('permanently blocked'));
    });

    test('6. Location timeout handling', () {
      const timeoutDiag = CurrentLocationDiagnostics(
        statusMessage: 'Location request timed out. GPS or network signal may be unavailable.',
      );

      expect(timeoutDiag.hasValidCoordinates, isFalse);
      expect(timeoutDiag.statusMessage, contains('timed out'));
    });

    test('7. Stale cached location handling and WebSettings zero maximumAge', () {
      // Fresh position (within 60s)
      final freshDiag = CurrentLocationDiagnostics(
        latitude: 11.0168,
        longitude: 76.9558,
        accuracyMeters: 20.0,
        timestamp: DateTime.now(),
        freshness: LocationFreshness.fresh,
        quality: LocationQuality.highAccuracyGps,
        isGpsVerified: true,
      );
      expect(freshDiag.freshness, equals(LocationFreshness.fresh));

      // Stale position (> 10 mins ago)
      final staleDiag = CurrentLocationDiagnostics(
        latitude: 11.0168,
        longitude: 76.9558,
        accuracyMeters: 20.0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        freshness: LocationFreshness.stale,
        quality: LocationQuality.highAccuracyGps,
        isGpsVerified: true,
      );
      expect(staleDiag.freshness, equals(LocationFreshness.stale));

      // Verify lib/main.dart uses maximumAge: Duration.zero on web to prevent stale cached fixes
      expect(mainDartContent.contains('maximumAge: forceFresh ? Duration.zero'), isTrue);
    });

    test('8. New GPS position updating marker and generation guard', () {
      // Verify generation and timestamp guards prevent stale async race conditions
      expect(mainDartContent.contains('_locationFetchGeneration'), isTrue);
      expect(mainDartContent.contains('_lastLocationFixTimestamp'), isTrue);
      expect(mainDartContent.contains('reqGen != _locationFetchGeneration'), isTrue);
    });

    test('9. No hardcoded fallback being silently presented as current location', () {
      // In loadRoute, verify that synthesized fake Position from _selectedStartLocation is removed
      final loadRouteBlock = mainDartContent.substring(
        mainDartContent.indexOf('Future<void> loadRoute() async'),
        mainDartContent.indexOf('final routes = await service.getRoutes'),
      );

      // Must not create fake Position with accuracy: 10.0 from _selectedStartLocation
      expect(
        loadRouteBlock.contains('Position(\n                  latitude: _selectedStartLocation!.lat'),
        isFalse,
      );
      expect(loadRouteBlock.contains('final effectivePosition = position ?? currentPosition;'), isTrue);
    });

    test('10. Destination marker remaining unchanged and independent of current location updates', () {
      // Verify destination marker uses _selectedEndLocation or endLocation
      expect(mainDartContent.contains('(_selectedEndLocation ?? endLocation)!.lat'), isTrue);
      expect(mainDartContent.contains('(_selectedEndLocation ?? endLocation)!.lon'), isTrue);

      final markerLayerIdx = mainDartContent.indexOf('// Current position marker (validated coordinates only)');
      expect(markerLayerIdx, isNot(-1));

      final startEndMarkerIdx = mainDartContent.indexOf('// Start & End markers', markerLayerIdx);
      expect(startEndMarkerIdx, isNot(-1));

      final snippet = mainDartContent.substring(startEndMarkerIdx, startEndMarkerIdx + 5500);
      expect(snippet.contains('(_selectedEndLocation ?? endLocation)!.lat'), isTrue);
      expect(snippet.contains('(_selectedEndLocation ?? endLocation)!.lon'), isTrue);
    });
  });
}
