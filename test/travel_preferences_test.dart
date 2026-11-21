// ============================================================================
// SafeRoute TN 2.0 — Travel Preferences UI & Integration Tests
// Tests: test/travel_preferences_test.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/safe_route_journey_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Travel Preferences UI & Model State Tests', () {
    testWidgets('1. Plan Your Safe Journey card renders Travel Preferences with default Car and Now', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SafeRouteTN());
      await tester.pump();

      // Check TRAVEL PREFERENCES label
      expect(find.text('TRAVEL PREFERENCES'), findsOneWidget);
      expect(find.text('VEHICLE'), findsOneWidget);
      expect(find.text('TRAVEL TIME'), findsOneWidget);

      // Check defaults
      expect(find.text('Car'), findsWidgets);
      expect(find.text('Now'), findsWidgets);
      expect(find.text('Search Safe Route'), findsOneWidget);
    });

    test('2. ETA Calculation accurately adapts to Vehicle mode (Car, Bike, Bus, Walk)', () {
      final service = SafeRouteService();
      const distance = 90.0; // km

      // Car at 45 km/h -> 2 hours (120 mins)
      expect(service.calculateVehicleTime(distance, 'Car'), closeTo(120.0, 0.1));

      // Bike at 40 km/h -> 2.25 hours (135 mins)
      expect(service.calculateVehicleTime(distance, 'Bike'), closeTo(135.0, 0.1));

      // Bus at 30 km/h -> 3 hours (180 mins)
      expect(service.calculateVehicleTime(distance, 'Bus'), closeTo(180.0, 0.1));

      // Walk at 5 km/h -> 18 hours (1080 mins)
      expect(service.calculateVehicleTime(distance, 'Walk'), closeTo(1080.0, 0.1));
    });

    test('3. Verification of Case A: Car + Now', () {
      final service = SafeRouteService();
      final duration = service.calculateVehicleTime(100.0, 'Car');
      expect(duration, closeTo(133.33, 0.1));

      final journey = SafeRouteJourney(
        id: 'case_a',
        origin: 'Coimbatore',
        destination: 'Ooty',
        routeIndex: 0,
        routeLabel: 'Route 1',
        routeSafetyScore: 88.0,
        distanceKm: 100.0,
        estimatedDurationMinutes: duration,
        vehicleMode: 'Car',
        travelTimeMode: 'Now',
        startedTimestamp: DateTime.now(),
        journeyState: JourneyState.active,
      );

      expect(journey.vehicleMode, 'Car');
      expect(journey.travelTimeMode, 'Now');
      expect(journey.estimatedDurationMinutes, closeTo(133.33, 0.1));
    });

    test('4. Verification of Case B: Bike + Evening', () {
      final service = SafeRouteService();
      final duration = service.calculateVehicleTime(100.0, 'Bike');
      expect(duration, closeTo(150.0, 0.1));

      final journey = SafeRouteJourney(
        id: 'case_b',
        origin: 'Madurai',
        destination: 'Theni',
        routeIndex: 1,
        routeLabel: 'Route 2',
        routeSafetyScore: 78.5,
        distanceKm: 100.0,
        estimatedDurationMinutes: duration,
        vehicleMode: 'Bike',
        travelTimeMode: 'Evening',
        startedTimestamp: DateTime.now(),
        journeyState: JourneyState.active,
      );

      expect(journey.vehicleMode, 'Bike');
      expect(journey.travelTimeMode, 'Evening');
      expect(journey.estimatedDurationMinutes, closeTo(150.0, 0.1));
    });

    test('5. Verification of Case C: Bus + Morning', () {
      final service = SafeRouteService();
      final duration = service.calculateVehicleTime(120.0, 'Bus');
      expect(duration, closeTo(240.0, 0.1));

      final journey = SafeRouteJourney(
        id: 'case_c',
        origin: 'Chennai',
        destination: 'Vellore',
        routeIndex: 0,
        routeLabel: 'Route 1',
        routeSafetyScore: 82.0,
        distanceKm: 120.0,
        estimatedDurationMinutes: duration,
        vehicleMode: 'Bus',
        travelTimeMode: 'Morning',
        startedTimestamp: DateTime.now(),
        journeyState: JourneyState.active,
      );

      expect(journey.vehicleMode, 'Bus');
      expect(journey.travelTimeMode, 'Morning');
      expect(journey.estimatedDurationMinutes, closeTo(240.0, 0.1));
    });

    test('6. Verification of Case D: Walk + Night', () {
      final service = SafeRouteService();
      final duration = service.calculateVehicleTime(10.0, 'Walk');
      expect(duration, closeTo(120.0, 0.1));

      final journey = SafeRouteJourney(
        id: 'case_d',
        origin: 'Salem',
        destination: 'Yercaud Foot',
        routeIndex: 2,
        routeLabel: 'Route 3',
        routeSafetyScore: 65.0,
        distanceKm: 10.0,
        estimatedDurationMinutes: duration,
        vehicleMode: 'Walk',
        travelTimeMode: 'Night',
        startedTimestamp: DateTime.now(),
        journeyState: JourneyState.active,
      );

      expect(journey.vehicleMode, 'Walk');
      expect(journey.travelTimeMode, 'Night');
      expect(journey.estimatedDurationMinutes, closeTo(120.0, 0.1));
    });

    testWidgets('7. Mobile responsive layout stacks Travel Preferences cleanly without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SafeRouteTN());
      await tester.pump();

      expect(find.text('TRAVEL PREFERENCES'), findsOneWidget);
      expect(find.text('VEHICLE'), findsOneWidget);
      expect(find.text('TRAVEL TIME'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Desktop layout displays Travel Preferences side-by-side cleanly without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SafeRouteTN());
      await tester.pump();

      expect(find.text('TRAVEL PREFERENCES'), findsOneWidget);
      expect(find.text('VEHICLE'), findsOneWidget);
      expect(find.text('TRAVEL TIME'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}