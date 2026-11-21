// ============================================================================
// SafeRoute TN — Safety Analytics Dashboard Unit & Widget Tests
// Module: test/safety_analytics_dashboard_test.dart
// Description: Comprehensive test suite for SafetyAnalyticsRecord,
//              SafetyAnalyticsStorage, SafetyAnalyticsSummary, localization,
//              and SafetyAnalyticsDashboardView.
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:latlong2/latlong.dart';

import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/personal_safety_profile.dart';
import 'package:saferoute_tn/safety_analytics_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper mock evaluation generator
  RouteEvaluation createMockEvaluation({
    double score = 84.0,
    String trafficStatus = 'Low Traffic',
  }) {
    final factors = [
      SafetyFactor(
        title: 'Accident Risk',
        icon: Icons.shield_rounded,
        score: 80.0,
        weight: 0.35,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Road Condition',
        icon: Icons.add_road_rounded,
        score: 75.0,
        weight: 0.25,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Traffic',
        icon: Icons.traffic_rounded,
        score: 90.0,
        weight: 0.15,
        relevant: true,
      ),
    ];

    return RouteEvaluation(
      route: RouteResult(
        points: const [LatLng(13.0827, 80.2707), LatLng(12.9249, 80.1000)],
        distance: 28.5,
        duration: 2100,
        routeIndex: 0,
      ),
      roadSegments: const [],
      safety: PersonalizedSafetyResult(
        score: score,
        factors: factors,
        activeFactors: factors,
      ),
      weather: null,
      blackspots: const BlackspotRouteAssessment(
        clearSampleScore: 82.0,
        detectedBlackspots: 0,
        successfulSamples: 5,
        segmentsChecked: 5,
        verifiedRecordCount: 0,
        segmentResults: [],
        unavailableReason: null,
      ),
      traffic: TrafficAssessment(
        source: 'tomtom',
        status: trafficStatus,
        meanSpeedRatio: 0.95,
        sampleCount: 10,
        matchedSamples: 10,
        coveragePercent: 100,
        roadClosure: false,
      ),
    );
  }

  group('Category 1: Empty Analytics State', () {
    test('Calculates empty summary when zero records exist', () {
      final summary = SafetyAnalyticsSummary.compute(
        records: [],
        timeFilter: 'All',
      );

      expect(summary.totalSavedRoutes, 0);
      expect(summary.averageSafetyScore, isNull);
      expect(summary.safestRoute, isNull);
      expect(summary.totalSavedDistanceKm, 0.0);
      expect(summary.averageDurationMinutes, isNull);
      expect(summary.lowestSafetyScore, isNull);
      expect(summary.highestSafetyScore, isNull);
      expect(summary.latestSafetyScore, isNull);
      expect(summary.recentSafetyScores, isEmpty);
      expect(summary.frequentRoutes, isEmpty);
      expect(summary.dominantTrafficStatus, isNull);
      expect(summary.averageWeatherScore, isNull);
    });

    testWidgets('Renders zero data empty state properly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      bool planClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAnalyticsDashboardView(
              isDarkMode: true,
              onPlanRoute: () {
                planClicked = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Your Safety Analytics will appear here'),
        findsOneWidget,
      );
      expect(
        find.text('Save routes to build your personal safety history.'),
        findsOneWidget,
      );
      expect(find.text('Plan a Route'), findsOneWidget);

      await tester.tap(find.text('Plan a Route'));
      await tester.pump();
      expect(planClicked, isTrue);
    });
  });

  group('Category 2: Save Analytics Record', () {
    test('Saves record locally to SharedPreferences key', () async {
      SharedPreferences.setMockInitialValues({});

      final record = SafetyAnalyticsRecord(
        id: 'rec_101',
        origin: 'Chennai',
        destination: 'Coimbatore',
        distanceKm: 504.0,
        durationMinutes: 480.0,
        safetyScore: 88.0,
        vehicleMode: 'Car',
        travelTimeMode: 'Day',
        createdAt: DateTime(2026, 10, 10, 9, 30),
        trafficStatus: 'Low Traffic',
        weatherScore: 92.0,
        accidentRiskScore: 85.0,
        roadConditionScore: 80.0,
      );

      final success = await SafetyAnalyticsStorage.saveRecord(record);
      expect(success, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final storedList = prefs.getStringList(SafetyAnalyticsStorage.storageKey);
      expect(storedList, isNotNull);
      expect(storedList!.length, 1);

      final decoded = jsonDecode(storedList.first) as Map<String, dynamic>;
      expect(decoded['id'], 'rec_101');
      expect(decoded['origin'], 'Chennai');
      expect(decoded['safety_score'], 88.0);
    });
  });

  group('Category 3: Load Analytics Records & Ingest Saved Trips', () {
    test(
      'Loads records and seamlessly ingests saved trips without duplication',
      () async {
        // Simulate existing saved trip in My Trips storage key
        final savedTripJson = jsonEncode({
          'id': 'trip_001',
          'origin': 'Madurai',
          'destination': 'Tirunelveli',
          'distance_km': 155.0,
          'duration_minutes': 140.0,
          'safety_score': 82.0,
          'vehicle_mode': 'Bike',
          'travel_time_mode': 'Day',
          'created_at': DateTime(2026, 10, 11, 10, 0).toIso8601String(),
        });

        // Simulate directly saved analytics record
        final analyticsRecordJson = jsonEncode({
          'id': 'rec_002',
          'origin': 'Salem',
          'destination': 'Erode',
          'distance_km': 65.0,
          'duration_minutes': 70.0,
          'safety_score': 90.0,
          'vehicle_mode': 'Car',
          'travel_time_mode': 'Day',
          'created_at': DateTime(2026, 10, 11, 12, 0).toIso8601String(),
        });

        SharedPreferences.setMockInitialValues({
          SafetyAnalyticsStorage.savedTripsKey: [savedTripJson],
          SafetyAnalyticsStorage.storageKey: [analyticsRecordJson],
        });

        final loaded = await SafetyAnalyticsStorage.loadRecords();
        expect(loaded.length, 2);
        expect(
          loaded.any((r) => r.id == 'trip_001' && r.origin == 'Madurai'),
          isTrue,
        );
        expect(
          loaded.any((r) => r.id == 'rec_002' && r.origin == 'Salem'),
          isTrue,
        );
      },
    );
  });

  group('Category 4: Average Safety Score', () {
    test('Calculates average only from records with valid safety scores', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'A',
          destination: 'B',
          distanceKm: 10,
          durationMinutes: 15,
          safetyScore: 80.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '2',
          origin: 'B',
          destination: 'C',
          distanceKm: 20,
          durationMinutes: 25,
          safetyScore: 90.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '3',
          origin: 'C',
          destination: 'D',
          distanceKm: 30,
          durationMinutes: 35,
          safetyScore: null, // missing score
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '4',
          origin: 'D',
          destination: 'E',
          distanceKm: 40,
          durationMinutes: 45,
          safetyScore: 70.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      // (80 + 90 + 70) / 3 = 80.0
      expect(summary.averageSafetyScore, 80.0);
    });
  });

  group('Category 5: Highest Safety Score', () {
    test('Accurately identifies the highest safety score', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'A',
          destination: 'B',
          distanceKm: 10,
          durationMinutes: 15,
          safetyScore: 72.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '2',
          origin: 'B',
          destination: 'C',
          distanceKm: 20,
          durationMinutes: 25,
          safetyScore: 94.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '3',
          origin: 'C',
          destination: 'D',
          distanceKm: 30,
          durationMinutes: 35,
          safetyScore: 85.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      expect(summary.highestSafetyScore, 94.0);
    });
  });

  group('Category 6: Lowest Safety Score', () {
    test('Accurately identifies the lowest safety score', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'A',
          destination: 'B',
          distanceKm: 10,
          durationMinutes: 15,
          safetyScore: 72.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '2',
          origin: 'B',
          destination: 'C',
          distanceKm: 20,
          durationMinutes: 25,
          safetyScore: 94.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      expect(summary.lowestSafetyScore, 72.0);
    });
  });

  group('Category 7: Total Saved Distance', () {
    test('Sums only real saved route distances', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'A',
          destination: 'B',
          distanceKm: 12.5,
          durationMinutes: 15,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '2',
          origin: 'B',
          destination: 'C',
          distanceKm: 45.0,
          durationMinutes: 40,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '3',
          origin: 'C',
          destination: 'D',
          distanceKm: 100.5,
          durationMinutes: 90,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      expect(summary.totalSavedDistanceKm, 158.0);
    });
  });

  group('Category 8: Average ETA', () {
    test('Averages durations only from valid records', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'A',
          destination: 'B',
          distanceKm: 20,
          durationMinutes: 30.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '2',
          origin: 'B',
          destination: 'C',
          distanceKm: 50,
          durationMinutes: 60.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '3',
          origin: 'C',
          destination: 'D',
          distanceKm: 80,
          durationMinutes: 90.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      // (30 + 60 + 90) / 3 = 60.0
      expect(summary.averageDurationMinutes, 60.0);
    });
  });

  group('Category 9: Weekly Filter', () {
    test('Filters records created within the last 7 days', () {
      final now = DateTime(2026, 10, 12, 12, 0);

      final records = [
        SafetyAnalyticsRecord(
          id: 'recent_1',
          origin: 'A',
          destination: 'B',
          distanceKm: 10,
          durationMinutes: 15,
          safetyScore: 85.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        SafetyAnalyticsRecord(
          id: 'recent_2',
          origin: 'B',
          destination: 'C',
          distanceKm: 20,
          durationMinutes: 25,
          safetyScore: 90.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: now.subtract(const Duration(days: 5)),
        ),
        SafetyAnalyticsRecord(
          id: 'old_1',
          origin: 'C',
          destination: 'D',
          distanceKm: 30,
          durationMinutes: 35,
          safetyScore: 70.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: now.subtract(const Duration(days: 12)),
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(
        records: records,
        timeFilter: 'Weekly',
        referenceTime: now,
      );

      expect(summary.totalSavedRoutes, 2);
      expect(summary.filteredRecords.any((r) => r.id == 'old_1'), isFalse);
    });
  });

  group('Category 10: Monthly Filter', () {
    test('Filters records created within the last 30 days', () {
      final now = DateTime(2026, 10, 12, 12, 0);

      final records = [
        SafetyAnalyticsRecord(
          id: 'month_1',
          origin: 'A',
          destination: 'B',
          distanceKm: 10,
          durationMinutes: 15,
          safetyScore: 85.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: now.subtract(const Duration(days: 15)),
        ),
        SafetyAnalyticsRecord(
          id: 'old_2',
          origin: 'C',
          destination: 'D',
          distanceKm: 30,
          durationMinutes: 35,
          safetyScore: 70.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: now.subtract(const Duration(days: 45)),
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(
        records: records,
        timeFilter: 'Monthly',
        referenceTime: now,
      );

      expect(summary.totalSavedRoutes, 1);
      expect(summary.filteredRecords.first.id, 'month_1');
    });
  });

  group('Category 11: Safest Route Section', () {
    test('Identifies safest route record with maximum safety score', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'Madurai',
          destination: 'Dindigul',
          distanceKm: 65,
          durationMinutes: 60,
          safetyScore: 81.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: 'safest',
          origin: 'Coimbatore',
          destination: 'Tiruppur',
          distanceKm: 55,
          durationMinutes: 50,
          safetyScore: 95.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      expect(summary.safestRoute?.id, 'safest');
      expect(summary.safestRoute?.safetyScore, 95.0);
      expect(summary.safestRoute?.origin, 'Coimbatore');
    });
  });

  group('Category 12: Duplicate/Frequent Route Calculation', () {
    test(
      'Groups duplicate origin and destination records and sorts by frequency',
      () {
        final records = [
          SafetyAnalyticsRecord(
            id: '1',
            origin: 'Chennai',
            destination: 'Salem',
            distanceKm: 340,
            durationMinutes: 300,
            vehicleMode: 'Car',
            travelTimeMode: 'Day',
            createdAt: DateTime.now(),
          ),
          SafetyAnalyticsRecord(
            id: '2',
            origin: 'Chennai',
            destination: 'Salem',
            distanceKm: 340,
            durationMinutes: 300,
            vehicleMode: 'Car',
            travelTimeMode: 'Day',
            createdAt: DateTime.now(),
          ),
          SafetyAnalyticsRecord(
            id: '3',
            origin: 'Chennai',
            destination: 'Salem',
            distanceKm: 340,
            durationMinutes: 300,
            vehicleMode: 'Car',
            travelTimeMode: 'Day',
            createdAt: DateTime.now(),
          ),
          SafetyAnalyticsRecord(
            id: '4',
            origin: 'Madurai',
            destination: 'Trichy',
            distanceKm: 135,
            durationMinutes: 120,
            vehicleMode: 'Car',
            travelTimeMode: 'Day',
            createdAt: DateTime.now(),
          ),
          SafetyAnalyticsRecord(
            id: '5',
            origin: 'Madurai',
            destination: 'Trichy',
            distanceKm: 135,
            durationMinutes: 120,
            vehicleMode: 'Car',
            travelTimeMode: 'Day',
            createdAt: DateTime.now(),
          ),
          SafetyAnalyticsRecord(
            id: '6',
            origin: 'Coimbatore',
            destination: 'Ooty',
            distanceKm: 85,
            durationMinutes: 150,
            vehicleMode: 'Car',
            travelTimeMode: 'Day',
            createdAt: DateTime.now(),
          ),
        ];

        final summary = SafetyAnalyticsSummary.compute(records: records);

        // Only routes with count >= 2 appear
        expect(summary.frequentRoutes.length, 2);
        expect(summary.frequentRoutes.first.key, 'Chennai → Salem');
        expect(summary.frequentRoutes.first.value, 3);
        expect(summary.frequentRoutes[1].key, 'Madurai → Trichy');
        expect(summary.frequentRoutes[1].value, 2);
      },
    );

    test('Does not fabricate frequent routes when no duplicates exist', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'Chennai',
          destination: 'Salem',
          distanceKm: 340,
          durationMinutes: 300,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
        SafetyAnalyticsRecord(
          id: '2',
          origin: 'Madurai',
          destination: 'Trichy',
          distanceKm: 135,
          durationMinutes: 120,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      expect(summary.frequentRoutes, isEmpty);
    });
  });

  group('Category 13: Missing Optional Data & JSON Round-Trip', () {
    test('Preserves nulls safely without creating fake fallback values', () {
      final record = SafetyAnalyticsRecord(
        id: 'sparse_1',
        origin: 'Theni',
        destination: 'Bodinayakanur',
        distanceKm: 16.0,
        durationMinutes: 25.0,
        safetyScore: null,
        vehicleMode: 'Bike',
        travelTimeMode: 'Night',
        createdAt: DateTime(2026, 10, 11, 20, 0),
      );

      final json = record.toJson();
      expect(json.containsKey('safety_score'), isFalse);
      expect(json.containsKey('traffic_status'), isFalse);
      expect(json.containsKey('weather_score'), isFalse);

      final restored = SafetyAnalyticsRecord.fromJson(json);
      expect(restored.id, 'sparse_1');
      expect(restored.safetyScore, isNull);
      expect(restored.trafficStatus, isNull);
      expect(restored.weatherScore, isNull);
      expect(restored.accidentRiskScore, isNull);
    });
  });

  group('Category 14: Traffic Unavailable Handling', () {
    test('Reports null dominant traffic when no traffic data recorded', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'A',
          destination: 'B',
          distanceKm: 10,
          durationMinutes: 15,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
          trafficStatus: null,
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      expect(summary.dominantTrafficStatus, isNull);
    });
  });

  group('Category 15: Weather Unavailable Handling', () {
    test('Reports null weather impact when no weather score available', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'A',
          destination: 'B',
          distanceKm: 10,
          durationMinutes: 15,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
          weatherScore: null,
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      expect(summary.averageWeatherScore, isNull);
    });
  });

  group('Category 16: Factor Unavailable Handling', () {
    test('Leaves factor average as null when factor was not evaluated', () {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'A',
          destination: 'B',
          distanceKm: 10,
          durationMinutes: 15,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
          accidentRiskScore: 82.0,
          roadConditionScore: null,
          lightingScore: null,
          accessibilityScore: null,
        ),
      ];

      final summary = SafetyAnalyticsSummary.compute(records: records);
      expect(summary.factorAverages['Accident Risk'], 82.0);
      expect(summary.factorAverages['Road Condition'], isNull);
      expect(summary.factorAverages['Lighting'], isNull);
      expect(summary.factorAverages['Accessibility'], isNull);
    });
  });

  group('Category 17: Tamil Labels & Toggle', () {
    test('Provides verified Tamil localization translations', () {
      expect(SafetyAnalyticsLocalization.title(true), 'பாதுகாப்பு பகுப்பாய்வு');
      expect(
        SafetyAnalyticsLocalization.savedRoutes(true),
        'சேமிக்கப்பட்ட வழிகள்',
      );
      expect(
        SafetyAnalyticsLocalization.averageSafetyScore(true),
        'சராசரி பாதுகாப்பு மதிப்பெண்',
      );
      expect(
        SafetyAnalyticsLocalization.safestRoute(true),
        'மிகவும் பாதுகாப்பான வழி',
      );
      expect(
        SafetyAnalyticsLocalization.safetyScoreTrend(true),
        'பாதுகாப்பு மதிப்பெண் போக்கு',
      );
      expect(
        SafetyAnalyticsLocalization.safetyFactors(true),
        'பாதுகாப்பு காரணிகள்',
      );
      expect(
        SafetyAnalyticsLocalization.trafficInsights(true),
        'போக்குவரத்து தகவல்கள்',
      );
      expect(SafetyAnalyticsLocalization.weatherImpact(true), 'வானிலை தாக்கம்');
      expect(SafetyAnalyticsLocalization.unavailable(true), 'தகவல் இல்லை');
      expect(
        SafetyAnalyticsLocalization.notEnoughHistory(true),
        'இன்னும் போதுமான வழி வரலாறு இல்லை.',
      );
      expect(
        SafetyAnalyticsLocalization.emptyStateTitle(true),
        'உங்கள் பாதுகாப்பு பகுப்பாய்வு இங்கே தோன்றும்',
      );
    });
  });

  group('Category 18: Personal Safety Profile Integration', () {
    testWidgets('Displays personalized safety insight matching user profile', (
      tester,
    ) async {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'Salem',
          destination: 'Namakkal',
          distanceKm: 50,
          durationMinutes: 45,
          safetyScore: 86.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
      ];
      SharedPreferences.setMockInitialValues({
        SafetyAnalyticsStorage.storageKey: [jsonEncode(records.first.toJson())],
      });

      const profile = PersonalSafetyProfile(
        vehicleMode: 'Car',
        safetyPriority: 'Safer Route',
        travelPurpose: 'Work',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafetyAnalyticsDashboardView(
              isDarkMode: true,
              personalProfile: profile,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Personalized Safety Insight'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your profile prioritizes safer routes even if travel time is longer.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Category 19: Risk Forecast Integration', () {
    testWidgets('Renders active route risk section and triggers callback', (
      tester,
    ) async {
      final records = [
        SafetyAnalyticsRecord(
          id: '1',
          origin: 'Trichy',
          destination: 'Thanjavur',
          distanceKm: 58,
          durationMinutes: 55,
          safetyScore: 84.0,
          vehicleMode: 'Car',
          travelTimeMode: 'Day',
          createdAt: DateTime.now(),
        ),
      ];
      SharedPreferences.setMockInitialValues({
        SafetyAnalyticsStorage.storageKey: [jsonEncode(records.first.toJson())],
      });

      final mockEval = createMockEvaluation(score: 84.0);
      bool riskForecastOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAnalyticsDashboardView(
              isDarkMode: true,
              activeRouteEvaluation: mockEval,
              onOpenRiskForecast: () {
                riskForecastOpened = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Current Route Risk'), findsOneWidget);
      expect(find.text('View Risk Forecast'), findsOneWidget);

      await tester.ensureVisible(find.text('View Risk Forecast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Risk Forecast'));
      await tester.pump();
      expect(riskForecastOpened, isTrue);
    });
  });

  group('Category 20: Why This Route Integration', () {
    testWidgets(
      'Renders AI Route Insight and triggers Why This Route callback',
      (tester) async {
        final records = [
          SafetyAnalyticsRecord(
            id: '1',
            origin: 'Trichy',
            destination: 'Thanjavur',
            distanceKm: 58,
            durationMinutes: 55,
            safetyScore: 84.0,
            vehicleMode: 'Car',
            travelTimeMode: 'Day',
            createdAt: DateTime.now(),
          ),
        ];
        SharedPreferences.setMockInitialValues({
          SafetyAnalyticsStorage.storageKey: [
            jsonEncode(records.first.toJson()),
          ],
        });

        final mockEval = createMockEvaluation(score: 84.0);
        bool whyThisRouteOpened = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafetyAnalyticsDashboardView(
                isDarkMode: true,
                activeRouteEvaluation: mockEval,
                onOpenWhyThisRoute: () {
                  whyThisRouteOpened = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Why This Route?'), findsOneWidget);

        await tester.ensureVisible(find.text('Why This Route?'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Why This Route?'));
        await tester.pump();
        expect(whyThisRouteOpened, isTrue);
      },
    );
  });
}
