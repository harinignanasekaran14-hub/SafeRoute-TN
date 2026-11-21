// ============================================================================
// SafeRoute TN — SafeRoute Journey Mode Tests
// File: test/safe_route_journey_mode_test.dart
// Description: Comprehensive test suite for SafeRoute Journey Mode covering:
//  1. SafeRouteJourney Model & Defaults
//  2. JourneyState Enum, Labels, Colors & Icons
//  3. Initial State (NotStarted)
//  4. State Transitions (Start -> Active -> Pause -> Resume -> End / Cancel)
//  5. Elapsed Duration & Estimated Duration Calculations
//  6. Safety Score & Rating Evaluation (Reused - No Separate Engine)
//  7. JSON Serialization & Deserialization
//  8. Missing Optional Context (Zero Fabrication - Strictly Nullable)
//  9. SharedPreferences Storage (Key: saferoute_journey_history)
//  10. History Retrieval & Chronological Order
//  11. Single Journey Deletion & Clear All History
//  12. Corrupt / Empty Storage Resilience
//  13. Strict Route Context Reuse (Origin, Destination, Score, Distance)
//  14. Traffic Handling (Real Congestion or Unavailable - No Fabrication)
//  15. Weather Handling (Real Weather or Unavailable)
//  16. Risk Forecast Integration (Real Risk or Unavailable)
//  17. Zero Background GPS & Route Progress Privacy Notice
//  18. Quick Action Triggers (Emergency, Nearby Places, Report Problem)
//  19. Full Bilingual Support (English & தமிழ் Localization)
//  20. JourneySummaryDialog Widget Verification
//  21. SafeRouteJourneyModeView Empty & Active State Rendering
//  22. Responsive Layout Adaptations (Desktop, Tablet, Mobile)
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/safe_route_journey_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. SafeRouteJourney Model & Defaults', () {
    test(
      'creates journey instance with specified values and correct defaults',
      () {
        final journey = SafeRouteJourney(
          id: 'journey-001',
          origin: 'Chennai Central',
          destination: 'Marina Beach',
          routeIndex: 0,
          routeSafetyScore: 88.5,
          distanceKm: 4.2,
          estimatedDurationMinutes: 15.0,
        );

        expect(journey.id, 'journey-001');
        expect(journey.origin, 'Chennai Central');
        expect(journey.destination, 'Marina Beach');
        expect(journey.routeIndex, 0);
        expect(journey.routeSafetyScore, 88.5);
        expect(journey.distanceKm, 4.2);
        expect(journey.estimatedDurationMinutes, 15.0);
        expect(journey.vehicleMode, 'Car');
        expect(journey.travelTimeMode, 'Day');
        expect(journey.journeyState, JourneyState.notStarted);
        expect(journey.startedTimestamp, isNull);
        expect(journey.endedTimestamp, isNull);
        expect(journey.trafficStatus, isNull);
        expect(journey.weatherScore, isNull);
        expect(journey.weatherCondition, isNull);
        expect(journey.weatherTemperature, isNull);
        expect(journey.riskLevel, isNull);
        expect(journey.riskExplanation, isNull);
        expect(journey.roadReportsSubmitted, 0);
        expect(journey.nearbyPlacesViewed, 0);
      },
    );
  });

  group('2. JourneyState Enum, Labels, Colors & Icons', () {
    test('provides English and Tamil labels for all 5 states', () {
      expect(JourneyState.notStarted.label(false), 'Not Started');
      expect(JourneyState.notStarted.label(true), 'தொடங்கப்படவில்லை');

      expect(JourneyState.active.label(false), 'Active');
      expect(JourneyState.active.label(true), 'செயலில் உள்ளது');

      expect(JourneyState.paused.label(false), 'Paused');
      expect(JourneyState.paused.label(true), 'இடைநிறுத்தப்பட்டது');

      expect(JourneyState.completed.label(false), 'Completed');
      expect(JourneyState.completed.label(true), 'முடிந்தது');

      expect(JourneyState.cancelled.label(false), 'Cancelled');
      expect(JourneyState.cancelled.label(true), 'ரத்து செய்யப்பட்டது');
    });

    test('provides valid distinct colors and icons for each state', () {
      for (final state in JourneyState.values) {
        expect(state.color, isA<Color>());
        expect(state.icon, isA<IconData>());
      }
    });
  });

  group('3. Initial State (NotStarted)', () {
    test('flags active, paused and finished correctly on notStarted state', () {
      const journey = SafeRouteJourney(
        id: 'j-init',
        origin: 'Salem',
        destination: 'Yercaud',
        routeIndex: 0,
        routeSafetyScore: 72.0,
        distanceKm: 30.5,
        estimatedDurationMinutes: 45.0,
      );

      expect(journey.isActive, isFalse);
      expect(journey.isPaused, isFalse);
      expect(journey.isFinished, isFalse);
      expect(journey.elapsedDuration, isNull);
    });
  });

  group(
    '4. State Transitions (Start -> Active -> Pause -> Resume -> End / Cancel)',
    () {
      test('transitions through states deterministically via copyWith', () {
        final start = DateTime(2026, 10, 14, 10, 0);
        var journey = SafeRouteJourney(
          id: 'j-trans',
          origin: 'Madurai',
          destination: 'Dindigul',
          routeIndex: 1,
          routeSafetyScore: 80.0,
          distanceKm: 65.0,
          estimatedDurationMinutes: 70.0,
        );

        // Start
        journey = journey.copyWith(
          journeyState: JourneyState.active,
          startedTimestamp: start,
        );
        expect(journey.isActive, isTrue);
        expect(journey.isPaused, isFalse);
        expect(journey.isFinished, isFalse);

        // Pause
        journey = journey.copyWith(journeyState: JourneyState.paused);
        expect(journey.isActive, isFalse);
        expect(journey.isPaused, isTrue);

        // Resume
        journey = journey.copyWith(journeyState: JourneyState.active);
        expect(journey.isActive, isTrue);
        expect(journey.isPaused, isFalse);

        // End
        final end = start.add(const Duration(minutes: 68));
        journey = journey.copyWith(
          journeyState: JourneyState.completed,
          endedTimestamp: end,
        );
        expect(journey.isActive, isFalse);
        expect(journey.isFinished, isTrue);
        expect(journey.endedTimestamp, end);

        // Cancel variant
        final cancelled = journey.copyWith(
          journeyState: JourneyState.cancelled,
          endedTimestamp: end,
        );
        expect(cancelled.isFinished, isTrue);
        expect(cancelled.journeyState, JourneyState.cancelled);
      });
    },
  );

  group('5. Elapsed Duration & Estimated Duration Calculations', () {
    test('formats estimated travel duration accurately', () {
      const j1 = SafeRouteJourney(
        id: 'd1',
        origin: 'A',
        destination: 'B',
        routeIndex: 0,
        routeSafetyScore: 80,
        distanceKm: 10,
        estimatedDurationMinutes: 45,
      );
      expect(j1.formattedEstimatedDuration, '45 min');

      const j2 = SafeRouteJourney(
        id: 'd2',
        origin: 'A',
        destination: 'B',
        routeIndex: 0,
        routeSafetyScore: 80,
        distanceKm: 100,
        estimatedDurationMinutes: 135,
      );
      expect(j2.formattedEstimatedDuration, '2h 15m');
    });

    test(
      'formats elapsed travel duration based on started and ended timestamps',
      () {
        final start = DateTime(2026, 10, 14, 8, 0);
        final end = DateTime(2026, 10, 14, 9, 25);
        final j = SafeRouteJourney(
          id: 'd3',
          origin: 'A',
          destination: 'B',
          routeIndex: 0,
          routeSafetyScore: 80,
          distanceKm: 80,
          estimatedDurationMinutes: 90,
          startedTimestamp: start,
          endedTimestamp: end,
          journeyState: JourneyState.completed,
        );

        expect(j.formattedElapsedDuration, '1h 25m');
      },
    );
  });

  group('6. Safety Score & Rating Evaluation', () {
    test('evaluates safety ratings matching project thresholds', () {
      SafeRouteJourney createWithScore(double score) => SafeRouteJourney(
        id: 's',
        origin: 'A',
        destination: 'B',
        routeIndex: 0,
        routeSafetyScore: score,
        distanceKm: 10,
        estimatedDurationMinutes: 15,
      );

      expect(createWithScore(85).safetyRating(false), 'Excellent');
      expect(createWithScore(85).safetyRating(true), 'மிகச் சிறந்தது');
      expect(createWithScore(85).safetyRatingColor, NeonTheme.safeGreen);

      expect(createWithScore(70).safetyRating(false), 'Good');
      expect(createWithScore(70).safetyRating(true), 'நல்லது');
      expect(createWithScore(70).safetyRatingColor, NeonTheme.neonCyan);

      expect(createWithScore(55).safetyRating(false), 'Moderate');
      expect(createWithScore(55).safetyRating(true), 'நடுத்தரமானது');
      expect(createWithScore(55).safetyRatingColor, NeonTheme.neonAmber);

      expect(createWithScore(40).safetyRating(false), 'Risky');
      expect(createWithScore(40).safetyRating(true), 'ஆபத்தானது');
      expect(createWithScore(40).safetyRatingColor, NeonTheme.dangerRed);
    });
  });

  group('7. JSON Serialization & Deserialization', () {
    test('roundtrips complete journey model through JSON cleanly', () {
      final original = SafeRouteJourney(
        id: 'roundtrip-1',
        origin: 'Coimbatore Airport',
        destination: 'Gandhipuram',
        routeIndex: 2,
        routeSafetyScore: 91.2,
        distanceKm: 11.4,
        estimatedDurationMinutes: 28.0,
        vehicleMode: 'Two-Wheeler',
        travelTimeMode: 'Night',
        startedTimestamp: DateTime(2026, 10, 14, 20, 15),
        endedTimestamp: DateTime(2026, 10, 14, 20, 45),
        journeyState: JourneyState.completed,
        trafficStatus: 'Moderate Congestion',
        weatherScore: 82.0,
        weatherCondition: 'Clear',
        weatherTemperature: '26°C',
        riskLevel: 'low',
        riskExplanation: 'Well illuminated route',
        roadReportsSubmitted: 2,
        nearbyPlacesViewed: 8,
      );

      final json = original.toJson();
      final parsed = SafeRouteJourney.fromJson(json);

      expect(parsed.id, original.id);
      expect(parsed.origin, original.origin);
      expect(parsed.destination, original.destination);
      expect(parsed.routeIndex, original.routeIndex);
      expect(parsed.routeSafetyScore, original.routeSafetyScore);
      expect(parsed.distanceKm, original.distanceKm);
      expect(
        parsed.estimatedDurationMinutes,
        original.estimatedDurationMinutes,
      );
      expect(parsed.vehicleMode, original.vehicleMode);
      expect(parsed.travelTimeMode, original.travelTimeMode);
      expect(parsed.startedTimestamp, original.startedTimestamp);
      expect(parsed.endedTimestamp, original.endedTimestamp);
      expect(parsed.journeyState, original.journeyState);
      expect(parsed.trafficStatus, original.trafficStatus);
      expect(parsed.weatherScore, original.weatherScore);
      expect(parsed.weatherCondition, original.weatherCondition);
      expect(parsed.weatherTemperature, original.weatherTemperature);
      expect(parsed.riskLevel, original.riskLevel);
      expect(parsed.riskExplanation, original.riskExplanation);
      expect(parsed.roadReportsSubmitted, original.roadReportsSubmitted);
      expect(parsed.nearbyPlacesViewed, original.nearbyPlacesViewed);
    });
  });

  group(
    '8. Missing Optional Context (Zero Fabrication - Strictly Nullable)',
    () {
      test('preserves null values when optional context is missing', () {
        final minimalJson = {
          'id': 'min-1',
          'origin': 'Tirunelveli',
          'destination': 'Kanyakumari',
          'route_index': 0,
          'route_safety_score': 82.0,
          'distanceKm': 85.0,
          'estimated_duration_minutes': 90.0,
        };

        final parsed = SafeRouteJourney.fromJson(minimalJson);
        expect(parsed.trafficStatus, isNull);
        expect(parsed.weatherScore, isNull);
        expect(parsed.weatherCondition, isNull);
        expect(parsed.weatherTemperature, isNull);
        expect(parsed.riskLevel, isNull);
        expect(parsed.riskExplanation, isNull);
        expect(parsed.roadReportsSubmitted, 0);
        expect(parsed.nearbyPlacesViewed, 0);
      });
    },
  );

  group('9. SharedPreferences Storage', () {
    test('persists journey under key saferoute_journey_history', () async {
      final journey = SafeRouteJourney(
        id: 'pref-save-1',
        origin: 'Tiruchirappalli',
        destination: 'Thanjavur',
        routeIndex: 0,
        routeSafetyScore: 84.0,
        distanceKm: 55.0,
        estimatedDurationMinutes: 60.0,
        startedTimestamp: DateTime.now(),
        endedTimestamp: DateTime.now().add(const Duration(minutes: 58)),
        journeyState: JourneyState.completed,
      );

      await JourneyHistoryService.saveJourney(journey);

      final prefs = await SharedPreferences.getInstance();
      final storedRaw = prefs.getString(JourneyHistoryService.storageKey);
      expect(storedRaw, isNotNull);

      final decoded = jsonDecode(storedRaw!) as List;
      expect(decoded.length, 1);
      expect(decoded.first['id'], 'pref-save-1');
      expect(decoded.first['origin'], 'Tiruchirappalli');
    });
  });

  group('10. History Retrieval & Chronological Order', () {
    test('loads history and places newest completed journeys first', () async {
      final j1 = SafeRouteJourney(
        id: 'hist-1',
        origin: 'A',
        destination: 'B',
        routeIndex: 0,
        routeSafetyScore: 75,
        distanceKm: 10,
        estimatedDurationMinutes: 15,
        startedTimestamp: DateTime(2026, 10, 10, 9, 0),
        journeyState: JourneyState.completed,
      );

      final j2 = SafeRouteJourney(
        id: 'hist-2',
        origin: 'C',
        destination: 'D',
        routeIndex: 0,
        routeSafetyScore: 85,
        distanceKm: 20,
        estimatedDurationMinutes: 30,
        startedTimestamp: DateTime(2026, 10, 12, 14, 0),
        journeyState: JourneyState.completed,
      );

      await JourneyHistoryService.saveJourney(j1);
      await JourneyHistoryService.saveJourney(j2);

      final history = await JourneyHistoryService.loadHistory();
      expect(history.length, 2);
      expect(history.first.id, 'hist-2');
      expect(history.last.id, 'hist-1');
    });
  });

  group('11. Single Journey Deletion & Clear All History', () {
    test('deletes individual journey and clears entire history', () async {
      final j1 = SafeRouteJourney(
        id: 'del-1',
        origin: 'A',
        destination: 'B',
        routeIndex: 0,
        routeSafetyScore: 70,
        distanceKm: 10,
        estimatedDurationMinutes: 15,
        journeyState: JourneyState.completed,
      );
      final j2 = SafeRouteJourney(
        id: 'del-2',
        origin: 'C',
        destination: 'D',
        routeIndex: 0,
        routeSafetyScore: 80,
        distanceKm: 20,
        estimatedDurationMinutes: 30,
        journeyState: JourneyState.completed,
      );

      await JourneyHistoryService.saveJourney(j1);
      await JourneyHistoryService.saveJourney(j2);

      var list = await JourneyHistoryService.loadHistory();
      expect(list.length, 2);

      // Delete del-1
      await JourneyHistoryService.deleteJourney('del-1');
      list = await JourneyHistoryService.loadHistory();
      expect(list.length, 1);
      expect(list.first.id, 'del-2');

      // Clear all
      await JourneyHistoryService.clearHistory();
      list = await JourneyHistoryService.loadHistory();
      expect(list.isEmpty, isTrue);
    });
  });

  group('12. Corrupt / Empty Storage Resilience', () {
    test('handles empty or malformed json safely without throwing', () async {
      final prefs = await SharedPreferences.getInstance();

      // Corrupt string
      await prefs.setString(
        JourneyHistoryService.storageKey,
        'not-a-valid-json',
      );
      var list = await JourneyHistoryService.loadHistory();
      expect(list, isEmpty);

      // Non-list JSON
      await prefs.setString(
        JourneyHistoryService.storageKey,
        jsonEncode({'error': true}),
      );
      list = await JourneyHistoryService.loadHistory();
      expect(list, isEmpty);
    });
  });

  group('13. Strict Route Context Reuse', () {
    test('captures and holds existing route parameters faithfully', () {
      const origin = 'Vellore Fort';
      const destination = 'VIT University';
      const score = 89.4;
      const dist = 6.8;
      const duration = 18.0;

      final journey = SafeRouteJourney(
        id: 'route-capture',
        origin: origin,
        destination: destination,
        routeIndex: 1,
        routeSafetyScore: score,
        distanceKm: dist,
        estimatedDurationMinutes: duration,
        vehicleMode: 'Car',
        travelTimeMode: 'Day',
        journeyState: JourneyState.active,
      );

      expect(journey.origin, origin);
      expect(journey.destination, destination);
      expect(journey.routeSafetyScore, score);
      expect(journey.distanceKm, dist);
      expect(journey.estimatedDurationMinutes, duration);
    });
  });

  group('14. Traffic Handling (Real Congestion or Unavailable)', () {
    test(
      'distinguishes between available real traffic and unavailable traffic',
      () {
        final withTraffic = SafeRouteJourney(
          id: 't-1',
          origin: 'A',
          destination: 'B',
          routeIndex: 0,
          routeSafetyScore: 80,
          distanceKm: 10,
          estimatedDurationMinutes: 15,
          trafficStatus: 'Heavy Congestion',
        );
        expect(withTraffic.trafficStatus, 'Heavy Congestion');

        final withoutTraffic = SafeRouteJourney(
          id: 't-2',
          origin: 'A',
          destination: 'B',
          routeIndex: 0,
          routeSafetyScore: 80,
          distanceKm: 10,
          estimatedDurationMinutes: 15,
          trafficStatus: null,
        );
        expect(withoutTraffic.trafficStatus, isNull);
      },
    );
  });

  group('15. Weather Handling (Real Weather or Unavailable)', () {
    test('distinguishes between real weather data and null weather', () {
      final withWeather = SafeRouteJourney(
        id: 'w-1',
        origin: 'A',
        destination: 'B',
        routeIndex: 0,
        routeSafetyScore: 80,
        distanceKm: 10,
        estimatedDurationMinutes: 15,
        weatherScore: 78.0,
        weatherCondition: 'Rainy',
        weatherTemperature: '24°C',
      );
      expect(withWeather.weatherScore, 78.0);
      expect(withWeather.weatherCondition, 'Rainy');
      expect(withWeather.weatherTemperature, '24°C');

      final withoutWeather = SafeRouteJourney(
        id: 'w-2',
        origin: 'A',
        destination: 'B',
        routeIndex: 0,
        routeSafetyScore: 80,
        distanceKm: 10,
        estimatedDurationMinutes: 15,
      );
      expect(withoutWeather.weatherScore, isNull);
      expect(withoutWeather.weatherCondition, isNull);
      expect(withoutWeather.weatherTemperature, isNull);
    });
  });

  group('16. Risk Forecast Integration', () {
    test('holds real risk assessment values or remains gracefully null', () {
      final withRisk = SafeRouteJourney(
        id: 'r-1',
        origin: 'A',
        destination: 'B',
        routeIndex: 0,
        routeSafetyScore: 80,
        distanceKm: 10,
        estimatedDurationMinutes: 15,
        riskLevel: 'moderate',
        riskExplanation: 'Pothole hazards detected near bypass',
      );
      expect(withRisk.riskLevel, 'moderate');
      expect(withRisk.riskExplanation, contains('Pothole hazards'));

      final withoutRisk = SafeRouteJourney(
        id: 'r-2',
        origin: 'A',
        destination: 'B',
        routeIndex: 0,
        routeSafetyScore: 80,
        distanceKm: 10,
        estimatedDurationMinutes: 15,
      );
      expect(withoutRisk.riskLevel, isNull);
      expect(withoutRisk.riskExplanation, isNull);
    });
  });

  group('17. Zero Background GPS & Route Progress Privacy Notice', () {
    test('confirms privacy notice text in English and Tamil', () {
      expect(
        SafeRouteJourneyLocalization.privacyDisclosure(false),
        contains('Zero Background GPS'),
      );
      expect(
        SafeRouteJourneyLocalization.privacyDisclosure(true),
        contains('பூஜ்ஜிய பின்னணி ஜிபிஎஸ்'),
      );
    });
  });

  group('18. Quick Action Triggers', () {
    testWidgets(
      'triggers callbacks for emergency, nearby places and report road',
      (tester) async {
        bool emergencyTriggered = false;
        String? nearbyCategory;
        bool reportProblemTriggered = false;

        final journey = SafeRouteJourney(
          id: 'callbacks-test',
          origin: 'Chennai',
          destination: 'Tambaram',
          routeIndex: 0,
          routeSafetyScore: 82.0,
          distanceKm: 28.0,
          estimatedDurationMinutes: 45.0,
          startedTimestamp: DateTime.now(),
          journeyState: JourneyState.active,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeRouteJourneyModeView(
                isDarkMode: true,
                activeJourney: journey,
                onOpenEmergency: () => emergencyTriggered = true,
                onOpenNearbyPlaces: (cat) => nearbyCategory = cat,
                onReportRoadProblem: () => reportProblemTriggered = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find Emergency Quick Button
        final emergencyBtn = find.text('Open Emergency Assistance');
        expect(emergencyBtn, findsOneWidget);
        await tester.ensureVisible(emergencyBtn);
        await tester.tap(emergencyBtn);
        expect(emergencyTriggered, isTrue);

        // Find Report Road Problem Quick Button
        final reportBtn = find.widgetWithText(
          OutlinedButton,
          'Report Road Problem',
        );
        expect(reportBtn, findsOneWidget);
        await tester.ensureVisible(reportBtn);
        await tester.tap(reportBtn);
        expect(reportProblemTriggered, isTrue);

        // Find Nearby Hospital Quick Button
        final hospitalBtn = find.text('🏥 Hospital');
        expect(hospitalBtn, findsOneWidget);
        await tester.ensureVisible(hospitalBtn);
        await tester.tap(hospitalBtn);
        expect(nearbyCategory, 'hospital');
      },
    );
  });

  group('19. Full Bilingual Support (English & தமிழ் Localization)', () {
    test('checks critical localized strings for both languages', () {
      expect(
        SafeRouteJourneyLocalization.title(false),
        '🛡️ SafeRoute Journey',
      );
      expect(
        SafeRouteJourneyLocalization.title(true),
        '🛡️ SafeRoute பயண பாதுகாப்பு',
      );

      expect(
        SafeRouteJourneyLocalization.startJourney(false),
        '🚗 Start Journey',
      );
      expect(
        SafeRouteJourneyLocalization.startJourney(true),
        '🚗 பயணத்தைத் தொடங்கு',
      );

      expect(SafeRouteJourneyLocalization.pauseJourney(false), 'Pause Journey');
      expect(
        SafeRouteJourneyLocalization.pauseJourney(true),
        'பயணத்தை இடைநிறுத்து',
      );

      expect(
        SafeRouteJourneyLocalization.resumeJourney(false),
        'Resume Journey',
      );
      expect(SafeRouteJourneyLocalization.resumeJourney(true), 'பயணத்தை தொடரு');

      expect(SafeRouteJourneyLocalization.endJourney(false), 'End Journey');
      expect(SafeRouteJourneyLocalization.endJourney(true), 'பயணத்தை முடி');

      expect(SafeRouteJourneyLocalization.unavailable(false), 'Unavailable');
      expect(SafeRouteJourneyLocalization.unavailable(true), 'தகவல் இல்லை');
    });
  });

  group('20. JourneySummaryDialog Widget Verification', () {
    testWidgets('renders completed journey summary dialog with real metrics', (
      tester,
    ) async {
      final journey = SafeRouteJourney(
        id: 'dialog-test',
        origin: 'Erode',
        destination: 'Tiruppur',
        routeIndex: 0,
        routeSafetyScore: 86.5,
        distanceKm: 52.0,
        estimatedDurationMinutes: 65.0,
        startedTimestamp: DateTime(2026, 10, 14, 11, 0),
        endedTimestamp: DateTime(2026, 10, 14, 12, 8),
        journeyState: JourneyState.completed,
        trafficStatus: 'Light Congestion',
        weatherCondition: 'Clear',
        weatherTemperature: '29°C',
        riskLevel: 'low',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JourneySummaryDialog(journey: journey, isDarkMode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Erode'), findsOneWidget);
      expect(find.text('Tiruppur'), findsOneWidget);
      expect(find.text('87'), findsOneWidget); // 86.5 rounded
      expect(find.text('52.0 km'), findsOneWidget);
      expect(find.text('1h 8m'), findsOneWidget);
      expect(find.text('Light Congestion'), findsOneWidget);
      expect(find.text('Clear (29°C)'), findsOneWidget);
      expect(find.text('LOW'), findsOneWidget);
    });

    testWidgets(
      'renders fallback "Unavailable" when traffic or weather is null in summary',
      (tester) async {
        final journey = SafeRouteJourney(
          id: 'dialog-test-null',
          origin: 'Thoothukudi',
          destination: 'Tirunelveli',
          routeIndex: 0,
          routeSafetyScore: 78.0,
          distanceKm: 48.0,
          estimatedDurationMinutes: 55.0,
          startedTimestamp: DateTime.now(),
          endedTimestamp: DateTime.now().add(const Duration(minutes: 50)),
          journeyState: JourneyState.completed,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JourneySummaryDialog(journey: journey, isDarkMode: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unavailable'), findsWidgets);
      },
    );
  });

  group('21. SafeRouteJourneyModeView Empty & Active State Rendering', () {
    testWidgets('renders empty state when activeJourney is null', (
      tester,
    ) async {
      bool planRouteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeRouteJourneyModeView(
              isDarkMode: true,
              activeJourney: null,
              onPlanRoute: () => planRouteCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Active Journey'), findsOneWidget);
      expect(find.text('Plan a Route'), findsOneWidget);

      await tester.tap(find.text('Plan a Route'));
      expect(planRouteCalled, isTrue);
    });

    testWidgets('renders active state with route summary and control buttons', (
      tester,
    ) async {
      bool pauseCalled = false;
      bool endCalled = false;

      final journey = SafeRouteJourney(
        id: 'active-view-test',
        origin: 'Dharmapuri',
        destination: 'Krishnagiri',
        routeIndex: 0,
        routeSafetyScore: 81.0,
        distanceKm: 45.0,
        estimatedDurationMinutes: 50.0,
        startedTimestamp: DateTime.now(),
        journeyState: JourneyState.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeRouteJourneyModeView(
              isDarkMode: true,
              activeJourney: journey,
              onPauseJourney: () => pauseCalled = true,
              onEndJourney: () => endCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dharmapuri'), findsOneWidget);
      expect(find.text('Krishnagiri'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);

      // Find pause button
      final pauseBtn = find.textContaining('Pause Journey');
      expect(pauseBtn, findsOneWidget);
      await tester.tap(pauseBtn);
      expect(pauseCalled, isTrue);

      // Find end button
      final endBtn = find.textContaining('End Journey');
      expect(endBtn, findsOneWidget);
      await tester.tap(endBtn);
      await tester.pumpAndSettle();

      // Confirm in dialog
      final confirmEndBtn = find
          .widgetWithText(ElevatedButton, 'End Journey')
          .last;
      await tester.tap(confirmEndBtn);
      expect(endCalled, isTrue);
    });
  });

  group('22. Responsive Layout Adaptations', () {
    testWidgets(
      'adapts smoothly across desktop, tablet and mobile constraints',
      (tester) async {
        final journey = SafeRouteJourney(
          id: 'resp-test',
          origin: 'Ooty',
          destination: 'Coonoor',
          routeIndex: 0,
          routeSafetyScore: 79.0,
          distanceKm: 19.5,
          estimatedDurationMinutes: 40.0,
          startedTimestamp: DateTime.now(),
          journeyState: JourneyState.active,
        );

        // Mobile: 400 x 800
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeRouteJourneyModeView(
                isDarkMode: true,
                activeJourney: journey,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ooty'), findsOneWidget);

        // Tablet: 768 x 1024
        tester.view.physicalSize = const Size(768, 1024);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeRouteJourneyModeView(
                isDarkMode: true,
                activeJourney: journey,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ooty'), findsOneWidget);

        // Desktop: 1280 x 900
        tester.view.physicalSize = const Size(1280, 900);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeRouteJourneyModeView(
                isDarkMode: true,
                activeJourney: journey,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ooty'), findsOneWidget);
      },
    );

    testWidgets('renders large map section, live metrics strip, and GPS progress', (
      tester,
    ) async {
      final journey = SafeRouteJourney(
        id: 'live-nav-test',
        origin: 'Coimbatore',
        destination: 'Ooty',
        routeIndex: 0,
        routeSafetyScore: 92.0,
        distanceKm: 100.8,
        estimatedDurationMinutes: 165.0,
        startedTimestamp: DateTime.now(),
        journeyState: JourneyState.active,
      );

      final mockMapWidget = Container(
        key: const ValueKey('live_nav_map_mock'),
        child: const Text('MOCK_NAVIGATION_MAP'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeRouteJourneyModeView(
              isDarkMode: true,
              activeJourney: journey,
              mapWidget: mockMapWidget,
              isNavigationActive: true,
              navigationStatus: 'On Route',
              distanceRemainingKm: 85.4,
              traveledKm: 15.4,
              progressPercent: 15,
              etaMinutes: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('live_nav_map_mock')), findsOneWidget);
      expect(find.text('MOCK_NAVIGATION_MAP'), findsOneWidget);
      expect(find.text('85.4 km'), findsWidgets);
      expect(find.text('140 min'), findsOneWidget);
      expect(find.text('92%'), findsWidgets);
      expect(find.text('On Route'), findsWidgets);
    });
  });
}
