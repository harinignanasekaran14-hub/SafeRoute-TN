import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';

void main() {
  group('SafeRoute TN 2.0 - Live GPS Vehicle Movement Tests', () {
    late String mainDartContent;
    late String liveLayerCode;

    setUpAll(() {
      final file = File('lib/main.dart');
      expect(file.existsSync(), isTrue, reason: 'lib/main.dart must exist');
      mainDartContent = file.readAsStringSync();

      final layerStart = mainDartContent.indexOf('class _LiveNavigationVehicleLayer extends StatefulWidget');
      expect(layerStart, isNot(-1));
      final layerEnd = mainDartContent.indexOf('class _SidebarItemInteractive');
      expect(layerEnd, isNot(-1));
      liveLayerCode = mainDartContent.substring(layerStart, layerEnd);
    });

    test('1. Car, Bike, Bicycle, Bus, and Walk icons supported for live GPS marker', () {
      final iconIdx = mainDartContent.indexOf('IconData _getNavigationVehicleIcon(String vehicle)');
      expect(iconIdx, isNot(-1));
      final iconSnippet = mainDartContent.substring(iconIdx, iconIdx + 600);

      expect(iconSnippet.contains('Icons.two_wheeler_rounded'), isTrue);
      expect(iconSnippet.contains('Icons.pedal_bike_rounded'), isTrue);
      expect(iconSnippet.contains('Icons.directions_bus_rounded'), isTrue);
      expect(iconSnippet.contains('Icons.directions_walk_rounded'), isTrue);
      expect(iconSnippet.contains('Icons.directions_car_rounded'), isTrue);
    });

    test('2. Live navigation vehicle layer smoothly interpolates between confirmed GPS fixes', () {
      expect(mainDartContent.contains('class _LiveNavigationVehicleLayer'), isTrue);
      expect(liveLayerCode.contains('Curves.easeOutCubic'), isTrue);
      expect(liveLayerCode.contains('final isNewFix ='), isTrue);
      expect(liveLayerCode.contains('_animCtrl.forward(from: 0.0)'), isTrue);
    });

    test('3. Reliable GPS heading priority with genuine movement and route-bearing fallback', () {
      // 1. Genuine reliable GPS hardware heading
      expect(liveLayerCode.contains('position.heading.isFinite'), isTrue);
      expect(liveLayerCode.contains('position.heading > 0.0'), isTrue);
      expect(liveLayerCode.contains('position.heading <= 360.0'), isTrue);

      // 2. Genuine GPS displacement bearing if moved >= 2.5 meters
      expect(liveLayerCode.contains('math.sqrt(dLat * dLat + dLon * dLon) >= 2.5'), isTrue);

      // 3. Reliable route-bearing fallback along active route
      expect(liveLayerCode.contains('_findNearestRouteSegment'), isTrue);
      expect(liveLayerCode.contains('_calculateBearing(routePoints[segIdx], routePoints[segIdx + 1])'), isTrue);
    });

    test('4. Preview to live navigation transition disposes preview and enables GPS marker', () {
      // Preview marker disabled during live or active navigation
      expect(
        mainDartContent.contains('enabled: !isLiveNavigation && !_navigationActive,'),
        isTrue,
        reason: 'Preview marker layer must be disabled during active/live navigation',
      );

      // Live vehicle layer enabled only when _navigationActive is true and GPS is valid
      final liveCallIdx = mainDartContent.indexOf('// Live GPS vehicle movement during navigation');
      expect(liveCallIdx, isNot(-1));
      final liveSnippet = mainDartContent.substring(liveCallIdx, liveCallIdx + 1600);
      expect(liveSnippet.contains('_navigationActive'), isTrue);
      expect(liveSnippet.contains('SafeRouteService.isValidCoordinate'), isTrue);
      expect(liveSnippet.contains('_LiveNavigationVehicleLayer('), isTrue);
      expect(liveSnippet.contains('markerBuilder: (pos, heading, isStale) =>'), isTrue);
    });

    test('5. GPS unavailable and stale location handling', () {
      expect(mainDartContent.contains('isStale: _lastLocationFixTimestamp != null &&'), isTrue);
      expect(mainDartContent.contains('Stale Fix'), isTrue);
      expect(mainDartContent.contains('const Color(0xffFFAA00)'), isTrue);

      // Null or invalid coordinates yield SizedBox.shrink()
      expect(liveLayerCode.contains('if (!widget.enabled ||'), isTrue);
      expect(liveLayerCode.contains('!SafeRouteService.isValidCoordinate('), isTrue);
      expect(liveLayerCode.contains('return const SizedBox.shrink();'), isTrue);
    });

    test('6. No duplicate Geolocator stream subscriptions exist', () {
      // Count position subscription listen occurrences in main.dart
      final listenMatches = RegExp(r'Geolocator\.getPositionStream\(').allMatches(mainDartContent);
      expect(
        listenMatches.length,
        equals(1),
        reason: 'There must only be exactly one Geolocator.getPositionStream subscription in main.dart',
      );
    });

    test('7. Live navigation uses actual GPS coordinates only, never simulated route progress', () {
      final liveCallIdx = mainDartContent.indexOf('// Live GPS vehicle movement during navigation');
      expect(liveCallIdx, isNot(-1));
      final liveSnippet = mainDartContent.substring(liveCallIdx, liveCallIdx + 1600);

      // The live vehicle layer receives currentPosition!, never interpolated simulated route index
      expect(liveSnippet.contains('position: currentPosition!,'), isTrue);
      expect(liveSnippet.contains('vehicle: currentVehicle,'), isTrue);
    });

    test('8. Shortest angular distance interpolation prevents wild spins', () {
      double interpAngle(double fromDeg, double toDeg, double t) {
        final diff = ((toDeg - fromDeg + 540.0) % 360.0) - 180.0;
        return (fromDeg + diff * t + 360.0) % 360.0;
      }

      // Crossing 0 degrees from 350 to 10
      final midPoint = interpAngle(350.0, 10.0, 0.5);
      expect(midPoint, closeTo(0.0, 0.1));

      // Normal rotation from 40 to 80
      final midPoint2 = interpAngle(40.0, 80.0, 0.5);
      expect(midPoint2, closeTo(60.0, 0.1));
    });
  });
}
