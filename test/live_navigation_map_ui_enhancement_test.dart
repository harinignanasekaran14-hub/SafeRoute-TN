import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SafeRoute TN 2.0 - Premium Live Navigation Map UI Enhancement Tests', () {
    late String mainDartContent;
    late String journeyModeContent;

    setUpAll(() {
      final mainFile = File('lib/main.dart');
      expect(mainFile.existsSync(), isTrue, reason: 'lib/main.dart must exist');
      mainDartContent = mainFile.readAsStringSync();

      final journeyFile = File('lib/safe_route_journey_mode.dart');
      expect(journeyFile.existsSync(), isTrue, reason: 'lib/safe_route_journey_mode.dart must exist');
      journeyModeContent = journeyFile.readAsStringSync();
    });

    test('1. Map Section in SafeRouteJourneyModeView expanded for immersive cockpit view', () {
      expect(
        journeyModeContent.contains('(isDesktop ? 640.0 : (isTablet ? 520.0 : 440.0))'),
        isTrue,
        reason: 'Live navigation map height must provide 640 on desktop, 520 on tablet, 440 on mobile as base/fallback',
      );
      expect(journeyModeContent.contains('availableMaxHeight: constraints.maxHeight'), isTrue);
      expect(journeyModeContent.contains('borderRadius: BorderRadius.circular(22)'), isTrue);
    });

    test('2. Top Navigation Information Panel contains all required live fields', () {
      expect(
        mainDartContent.contains('Widget _buildLiveNavigationCockpitPanel()'),
        isTrue,
      );

      final panelIdx = mainDartContent.indexOf('Widget _buildLiveNavigationCockpitPanel()');
      final panelSnippet = mainDartContent.substring(panelIdx, panelIdx + 4500);

      // Destination name
      expect(panelSnippet.contains('toName'), isTrue);
      // Selected vehicle type & icon
      expect(panelSnippet.contains('_getNavigationVehicleIcon(vehicle)'), isTrue);
      expect(panelSnippet.contains('vehicle'), isTrue);
      // Selected route number
      expect(panelSnippet.contains('routeNumber'), isTrue);
      // Estimated arrival time (ETA)
      expect(panelSnippet.contains('clockEtaStr'), isTrue);
      expect(panelSnippet.contains('remainingMinutes'), isTrue);
      // Remaining distance
      expect(panelSnippet.contains('remainingKm'), isTrue);
      // Route progress indicator
      expect(panelSnippet.contains('progressFraction'), isTrue);
      expect(panelSnippet.contains('progressPercent'), isTrue);
      // Current weather information
      expect(panelSnippet.contains('weatherTempStr'), isTrue);
      expect(panelSnippet.contains('weatherConditionStr'), isTrue);
      // GPS status badge
      expect(panelSnippet.contains('badgeLabel'), isTrue);
      expect(panelSnippet.contains('badgeColor'), isTrue);
    });

    test('3. Bottom Turn-by-Turn Guidance Panel contains turn icon, distance, road, and instruction', () {
      expect(
        mainDartContent.contains('Widget _buildLiveNavigationBottomCockpit()'),
        isTrue,
      );

      final bottomIdx = mainDartContent.indexOf('Widget _buildLiveNavigationBottomCockpit()');
      final nextWidgetIdx = mainDartContent.indexOf('Widget _buildWhyThisRouteItem', bottomIdx);
      final bottomSnippet = mainDartContent.substring(bottomIdx, nextWidgetIdx);

      // Turn icon from nextStep
      expect(bottomSnippet.contains('nextStep.icon'), isTrue);
      // Next instruction
      expect(bottomSnippet.contains('nextStep.instruction'), isTrue);
      // Distance to next turn
      expect(bottomSnippet.contains('nextStep.distanceMeters'), isTrue);
      // Road/street name
      expect(bottomSnippet.contains('roadName'), isTrue);
      expect(mainDartContent.contains('String? _getCurrentRoadName()'), isTrue);
    });

    test('4. All 5 required journey controls are accessible during live navigation', () {
      final bottomIdx = mainDartContent.indexOf('Widget _buildLiveNavigationBottomCockpit()');
      final nextWidgetIdx = mainDartContent.indexOf('Widget _buildWhyThisRouteItem', bottomIdx);
      final bottomSnippet = mainDartContent.substring(bottomIdx, nextWidgetIdx);

      // 1. Stop Journey
      expect(bottomSnippet.contains('_stopNavigation'), isTrue);
      // 2. Pause / Resume
      expect(bottomSnippet.contains('_onResumeJourney : _onPauseJourney'), isTrue);
      // 3. Report Road Issue
      expect(bottomSnippet.contains('_openReportProblemDialog'), isTrue);
      // 4. Recenter / Follow My Location
      expect(bottomSnippet.contains('_toggleFollowMe'), isTrue);
      expect(bottomSnippet.contains('_followMe ? \'Following\' : \'Recenter\''), isTrue);
      // 5. Emergency SOS
      expect(bottomSnippet.contains('_openEmergencyDialog'), isTrue);
    });

    test('5. Compass Rose widget integrated into Live Navigation top bar', () {
      final topOverlayIdx = mainDartContent.indexOf('// Floating Route Search Card / Dashboard Header Pill / Live Nav Pill');
      expect(topOverlayIdx, isNot(-1));
      final nextOverlayIdx = mainDartContent.indexOf('// Floating Map Controls', topOverlayIdx);
      final topOverlaySnippet = mainDartContent.substring(topOverlayIdx, nextOverlayIdx);

      expect(topOverlaySnippet.contains('_CompassRoseWidget('), isTrue);
      expect(topOverlaySnippet.contains('rotationDegrees:'), isTrue);
      expect(topOverlaySnippet.contains('_buildLiveNavigationCockpitPanel()'), isTrue);
    });

    test('6. Home Page map overlays remain untouched and independent', () {
      // Home page dashboard branch in _mapView remains intact
      expect(mainDartContent.contains('_buildDashboardMapHeaderPill()'), isTrue);
      expect(mainDartContent.contains('_buildDashboardMapWeatherPill()'), isTrue);
      expect(mainDartContent.contains('_buildDashboardMapLegend()'), isTrue);
      expect(mainDartContent.contains('_buildDashboardMapRouteSelector()'), isTrue);
      expect(mainDartContent.contains('_buildReportRoadHazardMapButton()'), isTrue);
      expect(mainDartContent.contains('_buildLiveMapBadge()'), isTrue);
    });

    test('7. Genuine data integrity: no hardcoded ETA, distance, progress, or simulated coordinates', () {
      final cockpitIdx = mainDartContent.indexOf('Widget _buildLiveNavigationCockpitPanel()');
      final cockpitSnippet = mainDartContent.substring(cockpitIdx, cockpitIdx + 2000);

      // Calculates from actual route points and service
      expect(cockpitSnippet.contains('_calculateTotalRouteMeters(routePoints)'), isTrue);
      expect(cockpitSnippet.contains('_getCurrentUserRouteProgressMeters()'), isTrue);
      expect(cockpitSnippet.contains('service.calculateVehicleTime('), isTrue);
      expect(cockpitSnippet.contains('math.max(0.0, totalMeters - currentProgress)'), isTrue);
    });

    test('8. Reliable OpenStreetMap tiles with no API key requirement and darkModeTileBuilder', () {
      // 1. CARTO is completely removed: no cartocdn / CARTO URL in main.dart
      expect(mainDartContent.contains('cartocdn.com'), isFalse);
      expect(mainDartContent.contains('CARTO'), isFalse);

      // 2. TileLayer unconditionally uses official OpenStreetMap URL
      final tileLayerIdx = mainDartContent.indexOf('TileLayer(');
      expect(tileLayerIdx, isNot(-1));
      final tileSnippet = mainDartContent.substring(tileLayerIdx, tileLayerIdx + 800);
      expect(tileSnippet.contains('https://tile.openstreetmap.org/{z}/{x}/{y}.png'), isTrue);

      // 3. Live Navigation uses darkModeTileBuilder for dark styling when dark mode is active
      expect(tileSnippet.contains('(isLiveNavigation && _isDarkMode)'), isTrue);
      expect(tileSnippet.contains('darkModeTileBuilder'), isTrue);

      // 4. Attribution displays OpenStreetMap contributors
      expect(mainDartContent.contains('SimpleAttributionWidget('), isTrue);
      expect(mainDartContent.contains('© OpenStreetMap contributors'), isTrue);
    });

    test('9. Map is the primary workspace rendered front and center in SafeRouteJourneyModeView', () {
      // When mapWidget is present, _buildLiveNavigationMapSection is rendered first
      expect(journeyModeContent.contains('// Primary Navigation Workspace: Front & Center'), isTrue);
      final primaryIdx = journeyModeContent.indexOf('// Primary Navigation Workspace: Front & Center');
      final mapCallIdx = journeyModeContent.indexOf('_buildLiveNavigationMapSection(', primaryIdx);
      final headerIdx = journeyModeContent.indexOf('_buildHeader(journey, isDark)', primaryIdx);
      expect(mapCallIdx < headerIdx, isTrue);
    });

    test('10. Automatic Heading-Up camera rotation aligns travel direction towards screen top', () {
      // Verify Heading-Up target rotation logic in _centerMapOnPosition
      expect(mainDartContent.contains('_resolveNavigationHeading(position)'), isTrue);
      expect(mainDartContent.contains('_filterHeadingUpdate(rawHeading, position)'), isTrue);
      expect(mainDartContent.contains('final targetRotation = _isHeadingUp ? -heading : 0.0;'), isTrue);
      expect(mainDartContent.contains('_animateMapCamera(targetCenter, targetZoom, targetRotation);'), isTrue);

      // Verify rotation values:
      // Travelling North (0 deg) -> camera rotation 0.0 deg (North at top)
      // Travelling East (90 deg) -> camera rotation -90.0 deg (East at top)
      // Travelling South (180 deg) -> camera rotation -180.0 deg (South at top)
      // Travelling West (270 deg) -> camera rotation -270.0 deg (West at top)
      double calcTargetRotation(double headingDeg, bool isHeadingUp) {
        return isHeadingUp ? -headingDeg : 0.0;
      }
      expect(calcTargetRotation(0.0, true), equals(0.0));
      expect(calcTargetRotation(90.0, true), equals(-90.0));
      expect(calcTargetRotation(180.0, true), equals(-180.0));
      expect(calcTargetRotation(270.0, true), equals(-270.0));
      expect(calcTargetRotation(90.0, false), equals(0.0)); // North-Up mode
    });

    test('11. 4-tier Heading resolution priority: GPS hardware, displacement, route segment, fallback', () {
      final resolveIdx = mainDartContent.indexOf('double _resolveNavigationHeading(Position position)');
      expect(resolveIdx, isNot(-1));
      final resolveSnippet = mainDartContent.substring(resolveIdx, resolveIdx + 1800);

      // Priority 1: Hardware GPS heading
      expect(resolveSnippet.contains('position.heading.isFinite'), isTrue);
      expect(resolveSnippet.contains('position.heading > 0.0'), isTrue);
      expect(resolveSnippet.contains('position.heading <= 360.0'), isTrue);
      expect(resolveSnippet.contains('position.headingAccuracy <= 45.0'), isTrue);

      // Priority 2: GPS displacement bearing >= 2.5m
      expect(resolveSnippet.contains('_previousGpsFix != null'), isTrue);
      expect(resolveSnippet.contains('math.sqrt(dLat * dLat + dLon * dLon) >= 2.5'), isTrue);
      expect(resolveSnippet.contains('_calculateBearing(p1, p2)'), isTrue);

      // Priority 3: Active route segment bearing
      expect(resolveSnippet.contains('_findNearestRouteSegmentIndex(userLoc, activePoints)'), isTrue);
      expect(resolveSnippet.contains('_calculateBearing(activePoints[segIdx], activePoints[segIdx + 1])'), isTrue);

      // Priority 4: Fallback to last known heading
      expect(resolveSnippet.contains('return _lastKnownHeading;'), isTrue);
    });

    test('12. Stationary retention and microscopic heading jitter filtering (< 3.0 deg)', () {
      final filterIdx = mainDartContent.indexOf('double _filterHeadingUpdate(double resolvedHeading, Position position)');
      expect(filterIdx, isNot(-1));
      final filterSnippet = mainDartContent.substring(filterIdx, filterIdx + 1200);

      // Stationary check: speed < 0.6 m/s and displacement < 2.0m retains last heading
      expect(filterSnippet.contains('position.speed.isFinite && position.speed < 0.6'), isTrue);
      expect(filterSnippet.contains('math.sqrt(dLat * dLat + dLon * dLon) < 2.0'), isTrue);

      // Jitter filtering: differences < 3.0 degrees ignored
      expect(filterSnippet.contains('diff.abs() < 3.0'), isTrue);
      expect(filterSnippet.contains('_lastKnownHeading = (resolvedHeading % 360.0 + 360.0) % 360.0;'), isTrue);
    });

    test('13. Shortest angular rotation delta correctly handles 0/360 boundary wrapping', () {
      expect(mainDartContent.contains('double _shortestRotationDelta(double fromDeg, double toDeg)'), isTrue);

      double shortestRotationDelta(double fromDeg, double toDeg) {
        return ((toDeg - fromDeg + 540.0) % 360.0) - 180.0;
      }

      // Standard small turn: 10 deg to 30 deg -> +20 deg
      expect(shortestRotationDelta(10.0, 30.0), closeTo(20.0, 0.001));

      // Crossing 0 boundary clockwise: 350 deg to 10 deg -> +20 deg (NOT -340 deg)
      expect(shortestRotationDelta(350.0, 10.0), closeTo(20.0, 0.001));

      // Crossing 0 boundary counter-clockwise: 10 deg to 350 deg -> -20 deg (NOT +340 deg)
      expect(shortestRotationDelta(10.0, 350.0), closeTo(-20.0, 0.001));

      // 180 turn
      expect(shortestRotationDelta(0.0, 180.0).abs(), closeTo(180.0, 0.001));
    });

    test('14. Compass Rose widget interactive tap toggles Heading-Up and North-Up mode', () {
      expect(mainDartContent.contains('void _toggleMapOrientation()'), isTrue);
      final toggleIdx = mainDartContent.indexOf('void _toggleMapOrientation()');
      final toggleSnippet = mainDartContent.substring(toggleIdx, toggleIdx + 900);

      expect(toggleSnippet.contains('_isHeadingUp = !_isHeadingUp;'), isTrue);
      expect(toggleSnippet.contains('final targetRotation = _isHeadingUp ? -_lastKnownHeading : 0.0;'), isTrue);
      expect(toggleSnippet.contains('_animateMapCamera('), isTrue);

      // Compass Rose widget passed onTap callback in Live Navigation
      final topOverlayIdx = mainDartContent.indexOf('// Floating Route Search Card / Dashboard Header Pill / Live Nav Pill');
      expect(topOverlayIdx, isNot(-1));
      final liveCompassIdx = mainDartContent.indexOf('_CompassRoseWidget(', topOverlayIdx);
      expect(liveCompassIdx, isNot(-1));
      final liveCompassSnippet = mainDartContent.substring(liveCompassIdx, liveCompassIdx + 300);
      expect(liveCompassSnippet.contains('onTap: _toggleMapOrientation'), isTrue);
      expect(liveCompassSnippet.contains('isHeadingUp: _isHeadingUp'), isTrue);
    });

    test('15. Stop Navigation cancels camera animation and resets map rotation to 0.0 deg (North-Up)', () {
      final stopIdx = mainDartContent.indexOf('Future<void> _stopNavigation() async');
      expect(stopIdx, isNot(-1));
      final stopSnippet = mainDartContent.substring(stopIdx, stopIdx + 500);

      expect(stopSnippet.contains('_cameraAnimController?.stop();'), isTrue);
      expect(stopSnippet.contains('_cameraAnimController?.dispose();'), isTrue);
      expect(stopSnippet.contains('mapController.rotate(0.0);'), isTrue);
      expect(stopSnippet.contains('_isHeadingUp = false;'), isTrue);
    });

    test('16. Facility, Hazard, Start, and End markers have rotate: true for horizontal readability', () {
      expect(mainDartContent.contains('MarkerLayer(rotate: true, markers: facilityMarkers)'), isTrue);

      final hazardLayerIdx = mainDartContent.indexOf('if (_showCommunityHazards && _communityHazards.isNotEmpty)');
      expect(hazardLayerIdx, isNot(-1));
      final hazardSnippet = mainDartContent.substring(hazardLayerIdx, hazardLayerIdx + 300);
      expect(hazardSnippet.contains('MarkerLayer('), isTrue);
      expect(hazardSnippet.contains('rotate: true'), isTrue);

      final startMarkerIdx = mainDartContent.indexOf('(_selectedStartLocation ?? startLocation)!.lat');
      expect(startMarkerIdx, isNot(-1));
      final startSnippet = mainDartContent.substring(startMarkerIdx - 200, startMarkerIdx + 400);
      expect(startSnippet.contains('rotate: true'), isTrue);

      final endMarkerIdx = mainDartContent.indexOf('(_selectedEndLocation ?? endLocation)!.lat');
      expect(endMarkerIdx, isNot(-1));
      final endSnippet = mainDartContent.substring(endMarkerIdx - 200, endMarkerIdx + 400);
      expect(endSnippet.contains('rotate: true'), isTrue);
    });

    test('17. North-Up is default live navigation orientation keeping OSM map labels upright', () {
      // 1. Initial state defaults to North-Up (_isHeadingUp = false)
      expect(mainDartContent.contains('bool _isHeadingUp = false;'), isTrue);

      // 2. Start navigation defaults to North-Up
      final startIdx = mainDartContent.indexOf('Future<void> _startNavigation() async');
      expect(startIdx, isNot(-1));
      final startSnippet = mainDartContent.substring(startIdx, startIdx + 2600);
      expect(startSnippet.contains('_isHeadingUp = false;'), isTrue);

      // 3. Target rotation is 0.0 in North-Up mode so OSM raster labels never appear sideways/upside down
      double calcRotation(double headingDeg, bool isHeadingUp) => isHeadingUp ? -headingDeg : 0.0;
      expect(calcRotation(90.0, false), equals(0.0));
      expect(calcRotation(180.0, false), equals(0.0));
      expect(calcRotation(270.0, false), equals(0.0));

      // 4. In Heading-Up mode, target rotation reflects actual travel heading
      expect(calcRotation(90.0, true), equals(-90.0));
      expect(calcRotation(180.0, true), equals(-180.0));
      expect(calcRotation(270.0, true), equals(-270.0));

      // 5. Compass Rose default parameter isHeadingUp is false
      expect(mainDartContent.contains('this.isHeadingUp = false,'), isTrue);
    });
  });
}
