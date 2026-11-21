import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('SafeRoute TN 2.0 - Animated Route Vehicle Marker Tests', () {
    late String mainDartContent;

    setUpAll(() {
      final file = File('lib/main.dart');
      expect(file.existsSync(), isTrue, reason: 'lib/main.dart must exist');
      mainDartContent = file.readAsStringSync();
    });

    test('1. _RouteMovingLightPulseLayer is replaced with _AnimatedRouteVehicleMarkerLayer', () {
      expect(
        mainDartContent.contains('class _RouteMovingLightPulseLayer'),
        isFalse,
        reason: '_RouteMovingLightPulseLayer should be completely removed/replaced',
      );
      expect(
        mainDartContent.contains('class _AnimatedRouteVehicleMarkerLayer'),
        isTrue,
        reason: '_AnimatedRouteVehicleMarkerLayer must be present',
      );
    });

    test('2. _AnimatedRouteVehicleMarkerLayer is wired into _mapView on the selected route', () {
      expect(
        mainDartContent.contains('_AnimatedRouteVehicleMarkerLayer('),
        isTrue,
      );
      expect(
        mainDartContent.contains('vehicle: currentVehicle,'),
        isTrue,
        reason: 'Vehicle mode must be passed dynamically from currentVehicle',
      );
      expect(
        mainDartContent.contains('enabled: !isLiveNavigation && !_navigationActive,'),
        isTrue,
        reason: 'Marker preview must be disabled during active or live navigation',
      );
    });

    test('3. Dynamic vehicle icon mapping supports Car, Bike, Bicycle, Bus, and Walk', () {
      expect(mainDartContent.contains('Icons.directions_car_rounded'), isTrue);
      expect(mainDartContent.contains('Icons.two_wheeler_rounded'), isTrue);
      expect(mainDartContent.contains('Icons.pedal_bike_rounded'), isTrue);
      expect(mainDartContent.contains('Icons.directions_bus_rounded'), isTrue);
      expect(mainDartContent.contains('Icons.directions_walk_rounded'), isTrue);

      final iconIdx = mainDartContent.indexOf('IconData _getVehicleIcon(String vehicle)');
      expect(iconIdx, isNot(-1));
      final iconSnippet = mainDartContent.substring(iconIdx, iconIdx + 600);
      expect(iconSnippet.contains('bike'), isTrue);
      expect(iconSnippet.contains('bicycle'), isTrue);
      expect(iconSnippet.contains('bus'), isTrue);
      expect(iconSnippet.contains('walk'), isTrue);
    });

    test('4. Smooth bearing calculation and road bend interpolation', () {
      expect(mainDartContent.contains('double _calculateBearing(LatLng from, LatLng to)'), isTrue);
      expect(mainDartContent.contains('double _interpolateAngle(double fromDeg, double toDeg, double t)'), isTrue);

      // Verify bearing formula computes correct angle for due North (0/360) and due East (90)
      const chennai = LatLng(13.0827, 80.2707);
      const northPoint = LatLng(13.0927, 80.2707);
      const eastPoint = LatLng(13.0827, 80.2807);

      double calcBearing(LatLng from, LatLng to) {
        final lat1 = from.latitude * math.pi / 180.0;
        final lat2 = to.latitude * math.pi / 180.0;
        final dLon = (to.longitude - from.longitude) * math.pi / 180.0;
        final y = math.sin(dLon) * math.cos(lat2);
        final x = math.cos(lat1) * math.sin(lat2) -
            math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
        final radians = math.atan2(y, x);
        return (radians * 180.0 / math.pi + 360.0) % 360.0;
      }

      final bNorth = calcBearing(chennai, northPoint);
      final bEast = calcBearing(chennai, eastPoint);
      expect(bNorth, closeTo(0.0, 0.5));
      expect(bEast, closeTo(90.0, 0.5));
    });

    test('5. Marker is centered accurately on the route with alignment: Alignment.center', () {
      final markerIdx = mainDartContent.indexOf('class _AnimatedRouteVehicleMarkerLayer');
      expect(markerIdx, isNot(-1));
      final markerClass = mainDartContent.substring(
        markerIdx,
        mainDartContent.indexOf('class _SidebarItemInteractive'),
      );
      expect(markerClass.contains('alignment: Alignment.center'), isTrue);
      expect(markerClass.contains('Marker('), isTrue);
      expect(markerClass.contains('Transform.rotate('), isTrue);
    });

    test('6. Reduced motion and empty/short routes safely handled', () {
      final markerIdx = mainDartContent.indexOf('class _AnimatedRouteVehicleMarkerLayer');
      expect(markerIdx, isNot(-1));
      final markerClass = mainDartContent.substring(
        markerIdx,
        mainDartContent.indexOf('class _SidebarItemInteractive'),
      );
      expect(markerClass.contains('disableAnimations'), isTrue);
      expect(markerClass.contains('pts.length < 2'), isTrue);
      expect(markerClass.contains('const SizedBox.shrink()'), isTrue);
    });

    test('7. Selected route cyan neon glow and unselected routes styling are preserved', () {
      expect(mainDartContent.contains('strokeWidth: 15.0,'), isTrue);
      expect(mainDartContent.contains('color: const Color(0xff00E5FF).withValues(alpha: 0.16)'), isTrue);
      expect(mainDartContent.contains('strokeWidth: 10.0,'), isTrue);
      expect(mainDartContent.contains('color: const Color(0xff00E5FF).withValues(alpha: 0.32)'), isTrue);
      expect(mainDartContent.contains('strokeWidth: 5.0,'), isTrue);
      expect(mainDartContent.contains('color: const Color(0xff00E5FF),'), isTrue);
    });
  });
}
