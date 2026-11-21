// ============================================================================
// SafeRoute TN — Smart Route Comparison Center Tests
// Tests: test/smart_route_comparison_test.dart
// Description: Comprehensive test suite for SmartRouteComparison model,
//              SmartRouteComparisonEngine, and SmartRouteComparisonView.
//              Covers all 20 required verification categories.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/personal_safety_profile.dart';
import 'package:saferoute_tn/smart_route_comparison.dart';
import 'package:saferoute_tn/smart_route_risk_forecast.dart';

void main() {
  // --------------------------------------------------------------------------
  // TEST FIXTURES & HELPERS
  // --------------------------------------------------------------------------

  RouteResult createTestRoute({
    required int index,
    required double distance,
    required double duration,
  }) {
    return RouteResult(
      points: [const LatLng(13.0827, 80.2707), const LatLng(13.0850, 80.2750)],
      distance: distance,
      duration: duration,
      routeIndex: index,
    );
  }

  RouteEvaluation createTestEvaluation({
    required RouteResult route,
    double? safetyScore = 88.0,
    double? trafficScore = 85.0,
    String trafficStatus = 'active',
    bool hasRoadSegments = true,
    bool hasWeather = true,
    bool hasBlackspots = true,
  }) {
    return RouteEvaluation(
      route: route,
      roadSegments: hasRoadSegments
          ? [
              const OsmRoadSegment(
                osmId: 101,
                name: 'Anna Salai',
                highway: 'primary',
                surface: 'asphalt',
                smoothness: 'good',
                maxspeed: '60',
                lit: 'yes',
                lanes: '4',
                sidewalk: 'both',
                access: 'yes',
                bridge: null,
                tunnel: null,
                bicycle: 'yes',
                foot: 'yes',
                motorVehicle: 'yes',
                wheelchair: 'yes',
                tactilePaving: 'yes',
                width: '14',
                routeMatchPoint: LatLng(13.0827, 80.2707),
                geometry: [LatLng(13.0827, 80.2707), LatLng(13.0850, 80.2750)],
              ),
            ]
          : null,
      safety: PersonalizedSafetyResult(
        score: safetyScore,
        factors: [
          SafetyFactor(
            title: 'Accident Risk',
            icon: Icons.shield,
            score: safetyScore != null ? (safetyScore - 3.0) : null,
            weight: 0.3,
          ),
          SafetyFactor(
            title: 'Road Condition',
            icon: Icons.add_road,
            score: safetyScore != null ? (safetyScore + 2.0) : null,
            weight: 0.2,
          ),
          SafetyFactor(
            title: 'Traffic',
            icon: Icons.traffic,
            score: trafficScore,
            weight: 0.15,
            status: trafficStatus,
          ),
          SafetyFactor(
            title: 'Weather',
            icon: Icons.cloud,
            score: hasWeather ? 90.0 : null,
            weight: 0.15,
          ),
          SafetyFactor(
            title: 'Lighting',
            icon: Icons.lightbulb,
            score: safetyScore != null ? 80.0 : null,
            weight: 0.1,
          ),
          SafetyFactor(
            title: 'Accessibility',
            icon: Icons.accessible,
            score: safetyScore != null ? 75.0 : null,
            weight: 0.1,
          ),
        ],
        activeFactors: [],
      ),
      weather: hasWeather
          ? WeatherData(
              temperature: 28.0,
              windSpeed: 10.0,
              precipitation: 0.0,
              weatherCode: 0,
            )
          : null,
      blackspots: BlackspotRouteAssessment(
        clearSampleScore: hasBlackspots ? 92.0 : null,
        detectedBlackspots: 0,
        successfulSamples: hasBlackspots ? 5 : 0,
        segmentsChecked: hasBlackspots ? 5 : 0,
        verifiedRecordCount: 0,
        segmentResults: const [],
        unavailableReason: hasBlackspots
            ? null
            : 'Blackspot dataset unavailable',
      ),
      traffic: TrafficAssessment(
        source: 'tomtom',
        status: trafficStatus,
        meanSpeedRatio: 0.9,
        sampleCount: 10,
        matchedSamples: 10,
        coveragePercent: 80,
        roadClosure: false,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // CATEGORY 1: ROUTE COMPARISON MODEL
  // --------------------------------------------------------------------------
  group('1. Route comparison model', () {
    test('instantiates with all properties and exposes helper getters', () {
      const comp = SmartRouteComparison(
        routeIndex: 0,
        routeLabel: 'Route 1',
        distanceKm: 207.5,
        durationMinutes: 277.0,
        safetyScore: 92.0,
        riskLevel: RouteRiskLevel.low,
        accidentRisk: 90.0,
        roadCondition: 88.0,
        traffic: 85.0,
        weather: 95.0,
        lighting: 80.0,
        accessibility: 75.0,
        evidenceAvailability: {
          'osm': true,
          'traffic': true,
          'weather': true,
          'blackspots': true,
        },
        preferenceMatch: 86.0,
        isRecommended: true,
      );

      expect(comp.routeIndex, 0);
      expect(comp.routeLabel, 'Route 1');
      expect(comp.distanceKm, 207.5);
      expect(comp.formattedDistance, '207.5 km');
      expect(comp.formattedEta, '4h 37m');
      expect(comp.hasSafetyScore, isTrue);
      expect(comp.safetyScoreDisplay, '92%');
      expect(comp.isRecommended, isTrue);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 2: DISTANCE COMPARISON
  // --------------------------------------------------------------------------
  group('2. Distance comparison', () {
    test('preserves exact route distances and formats correctly', () {
      final r1 = createTestRoute(index: 0, distance: 15.4, duration: 25.0);
      final r2 = createTestRoute(index: 1, distance: 18.2, duration: 22.0);

      final comparisons = SmartRouteComparisonEngine.compareRoutes(
        routes: [r1, r2],
        evaluations: {},
        profile: PersonalSafetyProfile.defaultProfile(),
      );

      expect(comparisons[0].distanceKm, 15.4);
      expect(comparisons[0].formattedDistance, '15.4 km');
      expect(comparisons[1].distanceKm, 18.2);
      expect(comparisons[1].formattedDistance, '18.2 km');
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 3: ETA COMPARISON
  // --------------------------------------------------------------------------
  group('3. ETA comparison', () {
    test('formats short and long durations properly', () {
      final r1 = createTestRoute(index: 0, distance: 10.0, duration: 45.0);
      final r2 = createTestRoute(index: 1, distance: 200.0, duration: 155.0);

      final comparisons = SmartRouteComparisonEngine.compareRoutes(
        routes: [r1, r2],
        evaluations: {},
        profile: PersonalSafetyProfile.defaultProfile(),
      );

      expect(comparisons[0].formattedEta, '45 m');
      expect(comparisons[1].formattedEta, '2h 35m');
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 4: SAFETY COMPARISON
  // --------------------------------------------------------------------------
  group('4. Safety comparison', () {
    test('compares safety scores and highlights the safer route', () {
      final r1 = createTestRoute(index: 0, distance: 15.0, duration: 30.0);
      final r2 = createTestRoute(index: 1, distance: 16.0, duration: 32.0);

      final ev1 = createTestEvaluation(route: r1, safetyScore: 82.0);
      final ev2 = createTestEvaluation(route: r2, safetyScore: 94.0);

      final comparisons = SmartRouteComparisonEngine.compareRoutes(
        routes: [r1, r2],
        evaluations: {0: ev1, 1: ev2},
        profile: const PersonalSafetyProfile(safetyPriority: 'Safer Route'),
      );

      expect(comparisons[0].safetyScore, 82.0);
      expect(comparisons[1].safetyScore, 94.0);
      // Under Safer Route priority, the higher safety score must be recommended
      expect(comparisons[1].isRecommended, isTrue);
      expect(comparisons[0].isRecommended, isFalse);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 5: RISK COMPARISON
  // --------------------------------------------------------------------------
  group('5. Risk comparison', () {
    test('derives RouteRiskLevel from SmartRiskForecastEngine', () {
      final r1 = createTestRoute(index: 0, distance: 10.0, duration: 20.0);
      final ev1 = createTestEvaluation(route: r1, safetyScore: 85.0);

      final comparisons = SmartRouteComparisonEngine.compareRoutes(
        routes: [r1],
        evaluations: {0: ev1},
        profile: PersonalSafetyProfile.defaultProfile(),
      );

      expect(comparisons[0].riskLevel, RouteRiskLevel.low);
      expect(comparisons[0].riskLevel?.title(false), 'LOW RISK');
      expect(comparisons[0].riskLevel?.title(true), 'குறைந்த ஆபத்து');
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 6: UNAVAILABLE FACTOR HANDLING
  // --------------------------------------------------------------------------
  group('6. Unavailable factor handling', () {
    test('sets null for missing factors and displays Unavailable or Traffic unavailable', () {
      final r1 = createTestRoute(index: 0, distance: 10.0, duration: 20.0);
      final ev1 = createTestEvaluation(
        route: r1,
        safetyScore: null,
        trafficScore: null,
        trafficStatus: 'Unavailable',
        hasWeather: false,
        hasBlackspots: false,
      );

      final comparisons = SmartRouteComparisonEngine.compareRoutes(
        routes: [r1],
        evaluations: {0: ev1},
        profile: PersonalSafetyProfile.defaultProfile(),
      );

      final comp = comparisons.first;
      expect(comp.safetyScore, isNull);
      expect(comp.safetyScoreDisplay, 'Unavailable');
      expect(comp.traffic, isNull);
      expect(
        comp.factorDisplay(comp.traffic, isTraffic: true),
        'Traffic unavailable',
      );
      expect(comp.factorDisplay(comp.weather), 'Unavailable');
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 7: NO FABRICATED FALLBACK VALUES
  // --------------------------------------------------------------------------
  group('7. No fabricated fallback values', () {
    test(
      'never fabricates 0 or 50 as a default score for missing evaluations',
      () {
        final r1 = createTestRoute(index: 0, distance: 10.0, duration: 20.0);

        // Route without evaluation
        final comparisons = SmartRouteComparisonEngine.compareRoutes(
          routes: [r1],
          evaluations: {},
          profile: PersonalSafetyProfile.defaultProfile(),
        );

        final comp = comparisons.first;
        expect(comp.safetyScore, isNull);
        expect(comp.riskLevel, isNull);
        expect(comp.traffic, isNull);
        expect(comp.weather, isNull);
        expect(comp.roadCondition, isNull);
        expect(comp.evidenceAvailability['traffic'], isFalse);
        expect(comp.evidenceAvailability['weather'], isFalse);
      },
    );
  });

  // --------------------------------------------------------------------------
  // CATEGORY 8: PREFERENCE MATCHING
  // --------------------------------------------------------------------------
  group('8. Preference matching', () {
    test(
      'calculates preference match percentage from PersonalSafetyProfile',
      () {
        final r1 = createTestRoute(index: 0, distance: 10.0, duration: 20.0);
        final ev1 = createTestEvaluation(route: r1, safetyScore: 88.0);

        final comparisons = SmartRouteComparisonEngine.compareRoutes(
          routes: [r1],
          evaluations: {0: ev1},
          profile: const PersonalSafetyProfile(
            vehicleMode: 'Car',
            safetyPriority: 'Safer Route',
          ),
        );

        expect(comparisons[0].preferenceMatch, isNotNull);
        expect(comparisons[0].preferenceMatch!, greaterThan(0));
        expect(comparisons[0].preferenceMatch!, lessThanOrEqualTo(100));
      },
    );
  });

  // --------------------------------------------------------------------------
  // CATEGORY 9: RECOMMENDED ROUTE SELECTION
  // --------------------------------------------------------------------------
  group('9. Recommended route selection', () {
    test('selects faster route when priority is Faster Route', () {
      final r1 = createTestRoute(index: 0, distance: 20.0, duration: 40.0);
      final r2 = createTestRoute(index: 1, distance: 25.0, duration: 25.0);

      final ev1 = createTestEvaluation(route: r1, safetyScore: 90.0);
      final ev2 = createTestEvaluation(route: r2, safetyScore: 80.0);

      final comparisons = SmartRouteComparisonEngine.compareRoutes(
        routes: [r1, r2],
        evaluations: {0: ev1, 1: ev2},
        profile: const PersonalSafetyProfile(safetyPriority: 'Faster Route'),
      );

      expect(comparisons[1].isRecommended, isTrue);
      expect(comparisons[0].isRecommended, isFalse);
    });

    test('selects safer route when priority is Safer Route', () {
      final r1 = createTestRoute(index: 0, distance: 20.0, duration: 40.0);
      final r2 = createTestRoute(index: 1, distance: 25.0, duration: 25.0);

      final ev1 = createTestEvaluation(route: r1, safetyScore: 95.0);
      final ev2 = createTestEvaluation(route: r2, safetyScore: 70.0);

      final comparisons = SmartRouteComparisonEngine.compareRoutes(
        routes: [r1, r2],
        evaluations: {0: ev1, 1: ev2},
        profile: const PersonalSafetyProfile(safetyPriority: 'Safer Route'),
      );

      expect(comparisons[0].isRecommended, isTrue);
      expect(comparisons[1].isRecommended, isFalse);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 10: SAFETY VS TIME TRADE-OFF
  // --------------------------------------------------------------------------
  group('10. Safety vs time trade-off', () {
    test('produces data-supported pros and cons for comparative routes', () {
      final r1 = createTestRoute(index: 0, distance: 15.0, duration: 20.0);
      final r2 = createTestRoute(index: 1, distance: 20.0, duration: 35.0);

      final ev1 = createTestEvaluation(route: r1, safetyScore: 85.0);
      final ev2 = createTestEvaluation(route: r2, safetyScore: 95.0);

      final comparisons = SmartRouteComparisonEngine.compareRoutes(
        routes: [r1, r2],
        evaluations: {0: ev1, 1: ev2},
        profile: PersonalSafetyProfile.defaultProfile(),
      );

      // Route 1 is faster & shorter
      expect(comparisons[0].pros.any((p) => p.contains('Fastest')), isTrue);
      expect(comparisons[0].pros.any((p) => p.contains('Shortest')), isTrue);

      // Route 2 has highest safety
      expect(
        comparisons[1].pros.any((p) => p.contains('Highest safety')),
        isTrue,
      );
      // Route 2 is longer in duration
      expect(
        comparisons[1].cons.any((c) => c.contains('longer travel time')),
        isTrue,
      );
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 11: EVIDENCE AVAILABILITY
  // --------------------------------------------------------------------------
  group('11. Evidence availability', () {
    test('correctly identifies active and inactive evidence sources', () {
      final r1 = createTestRoute(index: 0, distance: 10.0, duration: 20.0);
      final ev1 = createTestEvaluation(
        route: r1,
        hasRoadSegments: true,
        trafficStatus: 'active',
        hasWeather: true,
        hasBlackspots: false,
      );

      final evidence = SmartRouteComparisonEngine.checkEvidenceAvailability(
        ev1,
      );
      expect(evidence['osm'], isTrue);
      expect(evidence['traffic'], isTrue);
      expect(evidence['weather'], isTrue);
      expect(evidence['blackspots'], isFalse);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 12: MULTIPLE ROUTES
  // --------------------------------------------------------------------------
  group('12. Multiple routes', () {
    test('compares 3 routes simultaneously', () {
      final r1 = createTestRoute(index: 0, distance: 10.0, duration: 20.0);
      final r2 = createTestRoute(index: 1, distance: 12.0, duration: 22.0);
      final r3 = createTestRoute(index: 2, distance: 14.0, duration: 24.0);

      final evals = {
        0: createTestEvaluation(route: r1, safetyScore: 80.0),
        1: createTestEvaluation(route: r2, safetyScore: 88.0),
        2: createTestEvaluation(route: r3, safetyScore: 92.0),
      };

      final comparisons = SmartRouteComparisonEngine.compareRoutes(
        routes: [r1, r2, r3],
        evaluations: evals,
        profile: PersonalSafetyProfile.defaultProfile(),
      );

      expect(comparisons.length, 3);
      expect(comparisons.map((c) => c.routeLabel).toList(), [
        'Route 1',
        'Route 2',
        'Route 3',
      ]);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 13: SINGLE ROUTE
  // --------------------------------------------------------------------------
  group('13. Single route', () {
    testWidgets('renders single route notice without crashing', (tester) async {
      final r1 = createTestRoute(index: 0, distance: 10.0, duration: 20.0);
      final ev1 = createTestEvaluation(route: r1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRouteComparisonView(
              isDarkMode: true,
              routes: [r1],
              evaluations: {0: ev1},
              profile: PersonalSafetyProfile.defaultProfile(),
            ),
          ),
        ),
      );

      expect(find.text('Smart Route Comparison'), findsOneWidget);
      expect(find.textContaining('Only 1 route available'), findsOneWidget);
      expect(find.text('Route 1'), findsWidgets);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 14: NO ROUTE DATA
  // --------------------------------------------------------------------------
  group('14. No route data', () {
    testWidgets('renders clean placeholder when routes list is empty', (
      tester,
    ) async {
      bool planRouteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRouteComparisonView(
              isDarkMode: true,
              routes: const [],
              evaluations: const {},
              profile: PersonalSafetyProfile.defaultProfile(),
              onPlanRoute: () => planRouteCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('No Routes Available to Compare'), findsOneWidget);
      expect(find.text('Plan a Route'), findsOneWidget);

      await tester.tap(find.text('Plan a Route'));
      expect(planRouteCalled, isTrue);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 15: ENGLISH
  // --------------------------------------------------------------------------
  group('15. English localization', () {
    testWidgets(
      'displays English titles, badges, and recommendation narrative',
      (tester) async {
        final r1 = createTestRoute(index: 0, distance: 15.0, duration: 25.0);
        final ev1 = createTestEvaluation(route: r1, safetyScore: 90.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartRouteComparisonView(
                isDarkMode: true,
                isTamil: false,
                routes: [r1],
                evaluations: {0: ev1},
                profile: PersonalSafetyProfile.defaultProfile(),
              ),
            ),
          ),
        );

        expect(find.text('Smart Route Comparison'), findsOneWidget);
        expect(find.text('AI Route Recommendation'), findsOneWidget);
        expect(find.textContaining('Based on available data'), findsOneWidget);
        expect(find.text('Data Evidence'), findsOneWidget);
      },
    );
  });

  // --------------------------------------------------------------------------
  // CATEGORY 16: TAMIL
  // --------------------------------------------------------------------------
  group('16. Tamil localization', () {
    testWidgets('displays Tamil titles, badges, and recommendation narrative', (
      tester,
    ) async {
      final r1 = createTestRoute(index: 0, distance: 15.0, duration: 25.0);
      final ev1 = createTestEvaluation(route: r1, safetyScore: 90.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRouteComparisonView(
              isDarkMode: true,
              isTamil: true,
              routes: [r1],
              evaluations: {0: ev1},
              profile: PersonalSafetyProfile.defaultProfile(),
            ),
          ),
        ),
      );

      expect(find.text('ஸ்மார்ட் பாதை ஒப்பீடு'), findsOneWidget);
      expect(find.text('AI பாதை பரிந்துரை'), findsOneWidget);
      expect(
        find.textContaining('கிடைக்கக்கூடிய தரவுகளின் அடிப்படையில்'),
        findsOneWidget,
      );
      expect(find.text('தரவு சான்றுகள்'), findsOneWidget);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 17: MOBILE LAYOUT
  // --------------------------------------------------------------------------
  group('17. Mobile layout', () {
    testWidgets('renders cleanly at 400x800 without RenderFlex overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final r1 = createTestRoute(index: 0, distance: 12.0, duration: 22.0);
      final r2 = createTestRoute(index: 1, distance: 15.0, duration: 28.0);
      final evals = {
        0: createTestEvaluation(route: r1, safetyScore: 86.0),
        1: createTestEvaluation(route: r2, safetyScore: 92.0),
      };

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        // ignore: avoid_print
        print('DETAILS TO STRING: ${details.toString()}');
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRouteComparisonView(
              isDarkMode: true,
              routes: [r1, r2],
              evaluations: evals,
              profile: PersonalSafetyProfile.defaultProfile(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final err = tester.takeException();
      if (err != null && err is FlutterError) {
        for (final d in err.diagnostics) {
          // ignore: avoid_print
          print(d.toStringDeep());
        }
      }
      expect(err, isNull);
      expect(find.text('Route 1'), findsWidgets);
      expect(find.text('Route 2'), findsWidgets);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 18: DESKTOP LAYOUT
  // --------------------------------------------------------------------------
  group('18. Desktop layout', () {
    testWidgets('renders side-by-side table at 1366x768 without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final r1 = createTestRoute(index: 0, distance: 207.5, duration: 277.0);
      final r2 = createTestRoute(index: 1, distance: 220.0, duration: 260.0);
      final evals = {
        0: createTestEvaluation(route: r1, safetyScore: 92.0),
        1: createTestEvaluation(route: r2, safetyScore: 84.0),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRouteComparisonView(
              isDarkMode: true,
              routes: [r1, r2],
              evaluations: evals,
              profile: PersonalSafetyProfile.defaultProfile(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('METRICS'), findsOneWidget);
      expect(find.text('Distance'), findsWidgets);
      expect(find.text('ETA'), findsWidgets);
      expect(find.text('Safety Score'), findsWidgets);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 19: PRIVACY RULES
  // --------------------------------------------------------------------------
  group('19. Privacy rules', () {
    testWidgets('displays privacy banner with zero tracking guarantee', (
      tester,
    ) async {
      final r1 = createTestRoute(index: 0, distance: 10.0, duration: 20.0);
      final ev1 = createTestEvaluation(route: r1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRouteComparisonView(
              isDarkMode: true,
              routes: [r1],
              evaluations: {0: ev1},
              profile: PersonalSafetyProfile.defaultProfile(),
            ),
          ),
        ),
      );

      expect(find.textContaining('No continuous GPS tracking'), findsOneWidget);
      expect(find.textContaining('Zero location history'), findsOneWidget);
    });
  });

  // --------------------------------------------------------------------------
  // CATEGORY 20: EXISTING FEATURE INTEGRATION
  // --------------------------------------------------------------------------
  group('20. Existing feature integration', () {
    testWidgets('triggers callbacks for route selection and explanations', (
      tester,
    ) async {
      final r1 = createTestRoute(index: 0, distance: 12.0, duration: 22.0);
      final r2 = createTestRoute(index: 1, distance: 15.0, duration: 28.0);
      final evals = {
        0: createTestEvaluation(route: r1),
        1: createTestEvaluation(route: r2),
      };

      int? chosenRoute;
      int? whyRoute;
      int? whyMatchesRoute;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRouteComparisonView(
              isDarkMode: true,
              routes: [r1, r2],
              evaluations: evals,
              profile: PersonalSafetyProfile.defaultProfile(),
              selectedRouteIndex: 0,
              onSelectRoute: (idx) => chosenRoute = idx,
              onWhyThisRoute: (idx) => whyRoute = idx,
              onWhyThisRouteMatches: (idx) => whyMatchesRoute = idx,
            ),
          ),
        ),
      );

      // In desktop view (default size >= 900), find Choose Route button for Route 2
      final chooseBtn = find.text('Choose Route');
      expect(chooseBtn, findsOneWidget);
      await tester.tap(chooseBtn);
      expect(chosenRoute, 1);

      final whyBtns = find.text('Why this route?');
      expect(whyBtns, findsWidgets);
      await tester.tap(whyBtns.first);
      expect(whyRoute, 0);

      final whyMatchesBtns = find.text('Why this route matches you');
      expect(whyMatchesBtns, findsWidgets);
      await tester.tap(whyMatchesBtns.first);
      expect(whyMatchesRoute, 0);
    });
  });
}
