import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/personal_safety_profile.dart';
import 'package:saferoute_tn/smart_route_risk_forecast.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to create mock RouteEvaluation
  RouteEvaluation createMockEvaluation({
    required double? score,
    double accidentScore = 80,
    double roadScore = 75,
    double trafficScore = 80,
    double weatherScore = 85,
    double? lightingScore,
    double accessibilityScore = 70,
    int blackspotsDetected = 0,
    List<OsmRoadSegment>? roadSegments,
    TrafficAssessment? traffic,
    WeatherData? weather,
    double distanceKm = 42.0,
    double durationSeconds = 3300,
    int routeIndex = 0,
  }) {
    final factors = [
      SafetyFactor(
        title: 'Accident Risk',
        icon: Icons.shield_rounded,
        score: accidentScore,
        weight: 0.35,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Road Condition',
        icon: Icons.add_road_rounded,
        score: roadScore,
        weight: 0.25,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Traffic',
        icon: Icons.traffic_rounded,
        score: trafficScore,
        weight: 0.15,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Weather',
        icon: Icons.cloud_rounded,
        score: weatherScore,
        weight: 0.10,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Lighting',
        icon: Icons.lightbulb_rounded,
        score: lightingScore,
        weight: 0.08,
        relevant: lightingScore != null,
        unavailableReason: lightingScore == null
            ? 'Not evaluated for day travel'
            : null,
      ),
      SafetyFactor(
        title: 'Accessibility',
        icon: Icons.accessible_rounded,
        score: accessibilityScore,
        weight: 0.07,
        relevant: true,
      ),
    ];

    return RouteEvaluation(
      route: RouteResult(
        points: const [LatLng(11.0168, 76.9558), LatLng(10.6609, 77.0048)],
        distance: distanceKm,
        duration: durationSeconds,
        routeIndex: routeIndex,
      ),
      roadSegments: roadSegments ?? const [],
      safety: PersonalizedSafetyResult(
        score: score,
        factors: factors,
        activeFactors: factors.where((f) => f.relevant).toList(),
      ),
      weather: weather ??
          WeatherData(
            temperature: 28.5,
            windSpeed: 12.0,
            precipitation: 0.0,
            weatherCode: 0,
          ),
      blackspots: BlackspotRouteAssessment(
        clearSampleScore: null,
        detectedBlackspots: blackspotsDetected,
        successfulSamples: 5,
        segmentsChecked: 5,
        verifiedRecordCount: blackspotsDetected,
        segmentResults: const [],
        unavailableReason: null,
      ),
      traffic: traffic ??
          const TrafficAssessment(
            source: 'TomTom',
            status: 'Low Traffic',
            meanSpeedRatio: 0.95,
            sampleCount: 10,
            matchedSamples: 10,
            coveragePercent: 100,
            roadClosure: false,
          ),
    );
  }

  group('Smart Route Risk Forecast — 14 Mandatory Specification Tests', () {
    // 1. Low-risk route
    test('1. Low-risk route: score >= 75 is classified as LOW RISK', () {
      final eval = createMockEvaluation(score: 85.0);
      final forecast = SmartRiskForecastEngine.evaluate(
        evaluation: eval,
        vehicle: 'Car',
        travelTime: 'Day',
      );

      expect(forecast.overallLevel, RouteRiskLevel.low);
      expect(forecast.overallLevel.title(false), 'LOW RISK');
      expect(forecast.overallLevel.color, NeonTheme.safeGreen);

      final checkpoints = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: eval,
        totalDistanceKm: 42.0,
        totalDurationMinutes: 50.0,
      );
      expect(checkpoints.first.riskLevel, RouteRiskLevel.low);
      expect(checkpoints.first.primaryReason, contains('clear'));
    });

    // 2. Moderate-risk route
    test('2. Moderate-risk route: score 60-74 is classified as MODERATE RISK', () {
      final eval = createMockEvaluation(score: 68.0);
      final forecast = SmartRiskForecastEngine.evaluate(
        evaluation: eval,
        vehicle: 'Car',
        travelTime: 'Day',
      );

      expect(forecast.overallLevel, RouteRiskLevel.moderate);
      expect(forecast.overallLevel.title(false), 'MODERATE RISK');
      expect(forecast.overallLevel.color, NeonTheme.neonAmber);
    });

    // 3. Unavailable evidence
    test('3. Unavailable evidence: returns UNAVAILABLE without guessing scores', () {
      final unavLevel = RouteRiskLevel.fromScore(null, allowUnavailable: true);
      expect(unavLevel, RouteRiskLevel.unavailable);
      expect(unavLevel.title(false), 'UNAVAILABLE');
      expect(unavLevel.title(true), 'கிடைக்கவில்லை');

      final checkpoints = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: null,
        totalDistanceKm: 30.0,
        totalDurationMinutes: 40.0,
      );
      expect(checkpoints.every((c) => c.riskLevel == RouteRiskLevel.unavailable), isTrue);
      expect(checkpoints.every((c) => c.riskScore == null), isTrue);
      expect(checkpoints.first.primaryReason, contains('Insufficient evidence'));
    });

    // 4. Missing traffic
    test('4. Missing traffic: marked unavailable without inventing congestion values', () {
      final eval = createMockEvaluation(
        score: 75.0,
        traffic: const TrafficAssessment(
          source: 'Unavailable',
          status: 'Traffic data unavailable',
          meanSpeedRatio: 0.0,
          sampleCount: 0,
          matchedSamples: 0,
          coveragePercent: 0,
          roadClosure: false,
        ),
      );

      final checkpoints = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: eval,
        totalDistanceKm: 50.0,
        totalDurationMinutes: 60.0,
      );

      expect(checkpoints.first.unavailableFactors, contains('Traffic unavailable'));
      expect(checkpoints.first.verifiedFactors.any((f) => f.contains('Real-time traffic')), isFalse);
    });

    // 5. Missing lighting
    test('5. Missing lighting: marked unavailable for day travel without fabrication', () {
      final eval = createMockEvaluation(score: 80.0, lightingScore: null);
      final checkpoints = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: eval,
        totalDistanceKm: 40.0,
        totalDurationMinutes: 50.0,
        travelTime: 'Day',
      );

      expect(checkpoints.first.unavailableFactors, contains('Lighting unavailable'));
      expect(checkpoints.first.verifiedFactors.contains('Lighting coverage'), isFalse);
    });

    // 6. Short trip (< 20 km)
    test('6. Short trip (< 20 km): compact checkpoint layout is generated', () {
      final eval = createMockEvaluation(score: 82.0, distanceKm: 14.5, durationSeconds: 1500);
      expect(classifyTrip(14.5, 25.0), TripContextType.short);

      final checkpoints = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: eval,
        totalDistanceKm: 14.5,
        totalDurationMinutes: 25.0,
        originName: 'Gandhipuram',
        destinationName: 'RS Puram',
      );

      expect(checkpoints.length, equals(3));
      expect(checkpoints.first.label, 'Start');
      expect(checkpoints[1].label, contains('km'));
      expect(checkpoints.last.label, 'End');
    });

    // 7. Long trip (>= 60 km)
    test('7. Long trip (>= 60 km): expanded corridor checkpoints are generated', () {
      final eval = createMockEvaluation(score: 90.0, distanceKm: 441.4, durationSeconds: 20000);
      expect(classifyTrip(441.4, 330.0), TripContextType.long);

      final checkpoints = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: eval,
        totalDistanceKm: 441.4,
        totalDurationMinutes: 330.0,
        originName: 'Erode',
        destinationName: 'Chennai',
      );

      expect(checkpoints.length, equals(5));
      expect(checkpoints.first.label, 'Start');
      expect(checkpoints.last.label, 'End');
    });

    // 8. Women safety profile
    test('8. Women safety profile: adapts weights and flags night lighting sensitivity', () {
      final profile = PersonalSafetyProfile(
        safetyMode: 'Women Safety',
        accessibilityPreference: 'Standard',
      );

      final resultDay = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 80.0,
        trafficScore: 80.0,
        weatherScore: 90.0,
        lightingScore: null,
        accessibilityScore: 70.0,
        travelTime: 'Day',
        profile: profile,
      );
      expect(resultDay.score, isNotNull);

      // Night travel with Women Safety increases lighting weight
      final resultNight = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 80.0,
        trafficScore: 80.0,
        weatherScore: 90.0,
        lightingScore: 90.0,
        accessibilityScore: 70.0,
        travelTime: 'Night',
        profile: profile,
      );
      final lightingFactor = resultNight.factors.firstWhere((f) => f.title == 'Lighting');
      expect(lightingFactor.weight, closeTo(0.30, 0.001));
    });

    // 9. Senior-friendly profile
    test('9. Senior-friendly profile: prioritizes road smoothness and accessibility', () {
      final profile = PersonalSafetyProfile(
        safetyMode: 'Senior Friendly',
        accessibilityPreference: 'Prefer accessible routes',
      );

      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 80.0,
        trafficScore: 80.0,
        weatherScore: 90.0,
        lightingScore: null,
        accessibilityScore: 85.0,
        travelTime: 'Day',
        profile: profile,
      );

      final roadFactor = result.factors.firstWhere((f) => f.title == 'Road Condition');
      final accFactor = result.factors.firstWhere((f) => f.title == 'Accessibility');
      expect(roadFactor.weight, greaterThan(0.24));
      expect(accFactor.weight, greaterThan(0.14));
    });

    // 10. Family safety profile
    test('10. Family safety profile: prioritizes accident exposure and weather stability', () {
      final profile = PersonalSafetyProfile(
        safetyMode: 'Family Safety',
        accessibilityPreference: 'Standard',
      );

      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 80.0,
        trafficScore: 80.0,
        weatherScore: 90.0,
        lightingScore: null,
        accessibilityScore: 70.0,
        travelTime: 'Day',
        profile: profile,
      );

      final accidentFactor = result.factors.firstWhere((f) => f.title == 'Accident Risk');
      final weatherFactor = result.factors.firstWhere((f) => f.title == 'Weather');
      expect(accidentFactor.weight, greaterThan(0.34));
      expect(weatherFactor.weight, greaterThan(0.14));
    });

    // 11. Route 1 forecast
    test('11. Route 1 forecast: calculates forecast specifically for Route 1 metrics', () {
      final evalRoute1 = createMockEvaluation(
        score: 90.0,
        distanceKm: 441.4,
        durationSeconds: 20000,
        routeIndex: 0,
      );

      final checkpoints = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: evalRoute1,
        totalDistanceKm: 441.4,
        totalDurationMinutes: 330.0,
        originName: 'Erode',
        destinationName: 'Chennai',
      );

      expect(checkpoints.length, equals(5));
      expect(checkpoints.first.riskScore, equals(90.0));
      expect(checkpoints.first.riskLevel, equals(RouteRiskLevel.low));
    });

    // 12. Route 2 forecast
    test('12. Route 2 forecast: calculates forecast specifically for Route 2 metrics', () {
      final evalRoute2 = createMockEvaluation(
        score: 60.0,
        distanceKm: 464.0,
        durationSeconds: 22000,
        blackspotsDetected: 2,
        routeIndex: 1,
      );

      final checkpoints = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: evalRoute2,
        totalDistanceKm: 464.0,
        totalDurationMinutes: 370.0,
        originName: 'Erode',
        destinationName: 'Chennai',
      );

      expect(checkpoints.length, equals(5));
      // Mid-corridor should detect blackspots and register moderate/elevated caution
      final hazardZone = checkpoints.firstWhere((c) => c.sublabel == 'High Risk Zone');
      expect(hazardZone.riskLevel, isNot(RouteRiskLevel.low));
      expect(hazardZone.primaryReason, contains('blackspot'));
    });

    // 13. No random values (Deterministic test)
    test('13. No random values: repeated evaluations return 100% deterministic identical outputs', () {
      final eval = createMockEvaluation(score: 77.5, distanceKm: 85.0, durationSeconds: 5400);

      final firstRun = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: eval,
        totalDistanceKm: 85.0,
        totalDurationMinutes: 90.0,
      );

      for (int i = 0; i < 100; i++) {
        final repeatedRun = SmartRiskForecastEngine.generateCheckpoints(
          evaluation: eval,
          totalDistanceKm: 85.0,
          totalDurationMinutes: 90.0,
        );

        expect(repeatedRun.length, equals(firstRun.length));
        for (int j = 0; j < firstRun.length; j++) {
          expect(repeatedRun[j].riskLevel, equals(firstRun[j].riskLevel));
          expect(repeatedRun[j].riskScore, equals(firstRun[j].riskScore));
          expect(repeatedRun[j].primaryReason, equals(firstRun[j].primaryReason));
        }
      }
    });

    // 14. Insufficient evidence handling
    test('14. Insufficient evidence handling: scores are never fabricated when evidence is null', () {
      final evalNoScore = createMockEvaluation(score: null);

      final checkpoints = SmartRiskForecastEngine.generateCheckpoints(
        evaluation: evalNoScore,
        totalDistanceKm: 50.0,
        totalDurationMinutes: 60.0,
      );

      expect(checkpoints.every((c) => c.riskScore == null), isTrue);
      expect(checkpoints.every((c) => c.riskLevel == RouteRiskLevel.unavailable), isTrue);
      expect(checkpoints.first.primaryReason, contains('Insufficient evidence'));
    });
  });

  group('English & Tamil Localization Tests', () {
    test('English strings are accurate and non-empty', () {
      expect(RiskForecastLocalization.title(false), 'Smart Route Risk Forecast');
      expect(RiskForecastLocalization.overallRouteRisk(false), 'Overall Route Risk');
      expect(RouteRiskLevel.low.title(false), 'LOW RISK');
      expect(RouteRiskLevel.moderate.title(false), 'MODERATE RISK');
      expect(RouteRiskLevel.elevated.title(false), 'ELEVATED RISK');
      expect(RouteRiskLevel.high.title(false), 'HIGH RISK');
      expect(RouteRiskLevel.unavailable.title(false), 'UNAVAILABLE');
    });

    test('Tamil strings are accurate and non-empty', () {
      expect(RiskForecastLocalization.title(true), 'ஸ்மார்ட் பாதை ஆபத்து கணிப்பு');
      expect(RiskForecastLocalization.overallRouteRisk(true), 'மொத்த பாதை ஆபத்து');
      expect(RouteRiskLevel.low.title(true), 'குறைந்த ஆபத்து');
      expect(RouteRiskLevel.moderate.title(true), 'மிதமான ஆபத்து');
      expect(RouteRiskLevel.elevated.title(true), 'அதிகரித்த ஆபத்து');
      expect(RouteRiskLevel.high.title(true), 'அதிக ஆபத்து');
      expect(RouteRiskLevel.unavailable.title(true), 'கிடைக்கவில்லை');
    });
  });

  group('SmartRouteRiskForecastDialog Widget Tests', () {
    testWidgets(
      'Renders active route details, risk card, factors and trend cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final eval = createMockEvaluation(score: 82.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SmartRouteRiskForecastDialog(
                isDarkMode: true,
                routeOrigin: 'Coimbatore',
                routeDestination: 'Pollachi',
                vehicleMode: 'Car',
                travelTimeMode: 'Day',
                distanceKm: 42.0,
                durationMinutes: 55.0,
                safetyScore: 82.0,
                routeEvaluation: eval,
                formatDurationFn: (mins) => '${mins.round()}m',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Smart Route Risk Forecast'), findsOneWidget);
        expect(find.text('Coimbatore → Pollachi'), findsOneWidget);
        expect(find.text('42.0 km'), findsOneWidget);
        expect(find.text('55m'), findsOneWidget);
        expect(find.text('82 / 100'), findsWidgets);

        expect(find.text('LOW RISK'), findsWidgets);
        expect(find.text('OVERALL ROUTE RISK'), findsOneWidget);
        expect(find.text('Risk Factors'), findsOneWidget);
      },
    );

    testWidgets('Renders no-route state when route is not loaded', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRouteRiskForecastDialog(
              isDarkMode: true,
              routeOrigin: null,
              routeDestination: null,
              formatDurationFn: (mins) => '${mins.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No active route'), findsOneWidget);
      expect(
        find.text(
          'Plan a route to see route-specific emergency and risk context.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Toggles language to Tamil and back to English', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final eval = createMockEvaluation(score: 72.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartRouteRiskForecastDialog(
              isDarkMode: true,
              routeOrigin: 'Madurai',
              routeDestination: 'Dindigul',
              safetyScore: 72.0,
              routeEvaluation: eval,
              formatDurationFn: (mins) => '${mins.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Smart Route Risk Forecast'), findsOneWidget);

      final translateBtn = find.text('English');
      expect(translateBtn, findsOneWidget);
      await tester.tap(translateBtn);
      await tester.pumpAndSettle();

      expect(find.text('ஸ்மார்ட் பாதை ஆபத்து கணிப்பு'), findsOneWidget);
      expect(find.text('மொத்த பாதை ஆபத்து'), findsOneWidget);
      expect(find.text('மிதமான ஆபத்து'), findsOneWidget);

      final tamilBtn = find.text('தமிழ்');
      expect(tamilBtn, findsOneWidget);
      await tester.tap(tamilBtn);
      await tester.pumpAndSettle();

      expect(find.text('Smart Route Risk Forecast'), findsOneWidget);
    });
  });
}
