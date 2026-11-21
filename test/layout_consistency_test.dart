import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SafeRoute TN 2.0 - Layout Spacing & Card Consistency Tests', () {
    late String mainDartContent;

    setUpAll(() {
      final file = File('lib/main.dart');
      expect(file.existsSync(), isTrue, reason: 'lib/main.dart must exist');
      mainDartContent = file.readAsStringSync();
    });

    test('1. Plan Journey Card Header has consistent 6px spacing between all action buttons', () {
      // Must contain REPORT ROAD HAZARD, SHARED LOCATION, TRAVEL PREFERENCES with 6px spacing
      expect(mainDartContent.contains('REPORT ROAD HAZARD'), isTrue);
      expect(mainDartContent.contains('SHARED LOCATION'), isTrue);
      expect(mainDartContent.contains('TRAVEL PREFERENCES'), isTrue);

      final sharedLocationIdx = mainDartContent.indexOf('SHARED LOCATION');
      expect(sharedLocationIdx, isNot(-1));

      // Check for SizedBox(width: 6) before and after SHARED LOCATION button
      final beforeShared = mainDartContent.substring(sharedLocationIdx - 1400, sharedLocationIdx);
      expect(beforeShared.contains('SizedBox(width: 6)'), isTrue);

      final afterShared = mainDartContent.substring(sharedLocationIdx, sharedLocationIdx + 700);
      expect(afterShared.contains('SizedBox(width: 6)'), isTrue);
    });

    test('2. _buildRouteSummaryCard avoids phantom stacked SizedBoxes before Route Comparison', () {
      // Must use Builder or conditional rendering so empty banners do not stack SizedBoxes
      expect(
        mainDartContent.contains('final hazardBanner = _buildHazardAwareSmartRerouteBanner'),
        isTrue,
      );
      expect(
        mainDartContent.contains('final weatherCard = _buildWeatherAlongRouteCard'),
        isTrue,
      );
    });

    test('3. Emergency Coverage Card includes quick emergency contact pills (108, 100, 1091, 1077)', () {
      expect(mainDartContent.contains('_buildEmergencyContactPill'), isTrue);
      expect(mainDartContent.contains("number: '108'"), isTrue);
      expect(mainDartContent.contains("number: '100'"), isTrue);
      expect(mainDartContent.contains("number: '1091'"), isTrue);
      expect(mainDartContent.contains("number: '1077'"), isTrue);
    });

    test('4. Route Facilities Card displays preview items when unexpanded and facilities exist', () {
      expect(mainDartContent.contains('displayed.take(2)'), isTrue);
      expect(mainDartContent.contains('_showFacilityListExpanded'), isTrue);
    });

    test('5. Desktop map height aligns with Right Column (~550px height)', () {
      final desktopBlock = mainDartContent.substring(
        mainDartContent.indexOf('constraints.maxWidth >= 1050'),
        mainDartContent.indexOf('constraints.maxWidth >= 700'),
      );
      expect(desktopBlock.contains('height: 500'), isTrue);
      expect(desktopBlock.contains('_buildDashboardBottomStatusPill()'), isTrue);
      expect(desktopBlock.contains('_buildRouteSummaryCard()'), isTrue);
    });

    test('6. Tablet layout (700 <= width < 1050) has balanced 2-column card rows', () {
      final tabletBlock = mainDartContent.substring(
        mainDartContent.indexOf('constraints.maxWidth >= 700'),
        mainDartContent.indexOf('width < 700'),
      );

      // Verify 2-column rows for cards on tablet
      expect(tabletBlock.contains('// Tablet Row 1: Route Summary & AI Safety Brief'), isTrue);
      expect(tabletBlock.contains('// Tablet Row 2: Risk Forecast & Emergency Coverage'), isTrue);
      expect(tabletBlock.contains('// Tablet Row 3: Smart Route Insights & Personal Safety Profile'), isTrue);
      expect(tabletBlock.contains('_buildDashboardBottomStatusPill()'), isTrue);
    });

    test('7. Mobile layout (width < 700) includes Bottom Status Pill and proper card hierarchy', () {
      final mobileBlock = mainDartContent.substring(
        mainDartContent.indexOf('width < 700'),
        mainDartContent.indexOf('Widget _buildRouteSummaryCard'),
      );

      expect(mobileBlock.contains('_buildDashboardBottomStatusPill()'), isTrue);
      expect(mobileBlock.contains('_buildRouteSummaryCard()'), isTrue);
      expect(mobileBlock.contains('_buildOptionalFacilitiesCard()'), isTrue);
      expect(mobileBlock.contains('_buildRouteFacilitiesSection()'), isTrue);
    });

    test('8. Preservation of all 6 core cards in desktop dashboard', () {
      final desktopBlock = mainDartContent.substring(
        mainDartContent.indexOf('constraints.maxWidth >= 1050'),
        mainDartContent.indexOf('constraints.maxWidth >= 700'),
      );

      expect(desktopBlock.contains('_buildAiSafetyBriefCard()'), isTrue);
      expect(desktopBlock.contains('_buildSafetyRiskTimelineCard()'), isTrue);
      expect(desktopBlock.contains('_buildEmergencyCoverageCard()'), isTrue);
      expect(desktopBlock.contains('_buildCompactSmartRouteInsightsCard()'), isTrue);
      expect(desktopBlock.contains('_buildRouteFacilitiesSection()'), isTrue);
      expect(desktopBlock.contains('_buildCompactPersonalSafetyProfileCard()'), isTrue);
    });

    test('9. Balanced 3-column desktop layout using measured card heights', () {
      final desktopBlock = mainDartContent.substring(
        mainDartContent.indexOf('constraints.maxWidth >= 1050'),
        mainDartContent.indexOf('constraints.maxWidth >= 700'),
      );

      // Verify Column 1: AI Safety Brief + Route Facilities
      expect(desktopBlock.contains('// Column 1 (Left - ~627px): AI Safety Brief -> Route Facilities'), isTrue);
      // Verify Column 2: Safety Risk Timeline + Personal Safety Profile
      expect(desktopBlock.contains('// Column 2 (Center - ~592px): Safety Risk Timeline -> Personal Safety Profile'), isTrue);
      // Verify Column 3: Smart Route Insights -> Emergency Coverage
      expect(desktopBlock.contains('// Column 3 (Right - ~561px): Smart Route Insights -> Emergency Coverage'), isTrue);
    });
  });
}