import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI — Why This Route? Explanation Engine Tests', () {
    late SafeRouteService service;

    setUp(() {
      service = SafeRouteService();
    });

    RouteResult createRoute({
      required int index,
      required double distanceKm,
      required double durationSeconds,
    }) {
      return RouteResult(
        points: [const LatLng(11.0168, 76.9558), const LatLng(9.9252, 78.1198)],
        distance: distanceKm,
        duration: durationSeconds,
        routeIndex: index,
      );
    }

    RouteEvaluation createEvaluation({
      required int index,
      required double distanceKm,
      required double durationSeconds,
      required double? safetyScore,
      required double? accidentScore,
      required double? roadConditionScore,
      required double? trafficScore,
      required double? weatherScore,
      required double? lightingScore,
      required double? accessibilityScore,
      bool isDay = true,
    }) {
      final factors = [
        SafetyFactor(
          title: 'Accident Risk',
          icon: Icons.shield_rounded,
          score: accidentScore,
          weight: 0.30,
          relevant: true,
          unavailableReason: accidentScore == null
              ? 'Accident data unavailable'
              : null,
        ),
        SafetyFactor(
          title: 'Road Condition',
          icon: Icons.add_road_rounded,
          score: roadConditionScore,
          weight: 0.20,
          relevant: true,
          unavailableReason: roadConditionScore == null
              ? 'Road data unavailable'
              : null,
        ),
        SafetyFactor(
          title: 'Traffic',
          icon: Icons.traffic_rounded,
          score: trafficScore,
          weight: 0.15,
          relevant: true,
          unavailableReason: trafficScore == null
              ? 'TomTom traffic data unavailable'
              : null,
        ),
        SafetyFactor(
          title: 'Weather',
          icon: Icons.cloud_rounded,
          score: weatherScore,
          weight: 0.10,
          relevant: true,
          unavailableReason: weatherScore == null
              ? 'Open-Meteo data unavailable'
              : null,
        ),
        SafetyFactor(
          title: 'Lighting',
          icon: Icons.lightbulb_rounded,
          score: isDay ? null : lightingScore,
          weight: isDay ? 0.0 : 0.10,
          relevant: !isDay,
          unavailableReason: isDay ? 'Not evaluated for day travel' : null,
        ),
        SafetyFactor(
          title: 'Accessibility',
          icon: Icons.accessible_rounded,
          score: accessibilityScore,
          weight: 0.15,
          relevant: true,
          unavailableReason: accessibilityScore == null
              ? 'Accessibility data unavailable'
              : null,
        ),
      ];

      return RouteEvaluation(
        route: createRoute(
          index: index,
          distanceKm: distanceKm,
          durationSeconds: durationSeconds,
        ),
        roadSegments: null,
        safety: PersonalizedSafetyResult(
          score: safetyScore,
          factors: factors,
          activeFactors: factors.where((f) => f.score != null).toList(),
        ),
        weather: null,
        blackspots: const BlackspotRouteAssessment(
          clearSampleScore: null,
          detectedBlackspots: 0,
          successfulSamples: 0,
          segmentsChecked: 0,
          verifiedRecordCount: 0,
          segmentResults: [],
          unavailableReason: null,
        ),
        traffic: null,
      );
    }

    test('Unavailable factors strictly state unavailable without claiming good or bad', () {
      final eval = createEvaluation(
        index: 0,
        distanceKm: 120.0,
        durationSeconds: 7200,
        safetyScore: 80.0,
        accidentScore: 85.0,
        roadConditionScore: 78.0,
        trafficScore: null, // Traffic offline / unavailable
        weatherScore: null, // Weather unavailable
        lightingScore: null,
        accessibilityScore: 75.0,
        isDay: true,
      );

      final analysis = RouteExplanationEngine.generate(
        targetEvaluation: eval,
        allEvaluations: {0: eval},
        origin: 'Coimbatore',
        destination: 'Madurai',
        vehicle: 'Car',
        travelTime: 'Day',
        priority: 'Safety First',
        service: service,
        formatDurationFn: (mins) => '${(mins ~/ 60)}h ${(mins % 60).round()}m',
      );

      // Verify 6 factors are present
      expect(analysis.factors.length, 6);

      // 1. Traffic unavailable must use EXACT requested phrasing
      final trafficFactor = analysis.factors.firstWhere(
        (f) => f.key == 'traffic',
      );
      expect(trafficFactor.isAvailable, isFalse);
      expect(trafficFactor.score, isNull);
      expect(
        trafficFactor.commentary,
        'Traffic data is currently unavailable, so it was not included in this explanation.',
      );

      // 2. Weather unavailable must state unavailable
      final weatherFactor = analysis.factors.firstWhere(
        (f) => f.key == 'weather',
      );
      expect(weatherFactor.isAvailable, isFalse);
      expect(weatherFactor.score, isNull);
      expect(
        weatherFactor.commentary,
        'Weather data is currently unavailable, so it was not included in this explanation.',
      );

      // 3. Daytime lighting must state daytime travel not evaluated
      final lightingFactor = analysis.factors.firstWhere(
        (f) => f.key == 'lighting',
      );
      expect(lightingFactor.isAvailable, isFalse);
      expect(
        lightingFactor.commentary,
        'Lighting conditions are not evaluated for daytime travel.',
      );

      // 4. Available factors have real calculated score and positive commentary
      final accFactor = analysis.factors.firstWhere((f) => f.key == 'accident');
      expect(accFactor.isAvailable, isTrue);
      expect(accFactor.score, 85.0);
      expect(
        accFactor.commentary,
        'This route has a relatively lower accident-risk score.',
      );
    });

    test('Multi-route comparison identifies safer vs faster trade-offs and highlights', () {
      final route1 = createEvaluation(
        index: 0,
        distanceKm: 210.0,
        durationSeconds: 15000, // 4h 10m
        safetyScore: 84.0,
        accidentScore: 88.0,
        roadConditionScore: 82.0,
        trafficScore: 80.0,
        weatherScore: 75.0,
        lightingScore: null,
        accessibilityScore: 70.0,
        isDay: true,
      );

      final route2 = createEvaluation(
        index: 1,
        distanceKm: 195.0,
        durationSeconds: 12000, // 3h 20m (faster, but lower safety)
        safetyScore: 72.0,
        accidentScore: 68.0,
        roadConditionScore: 65.0,
        trafficScore: 78.0,
        weatherScore: 75.0,
        lightingScore: null,
        accessibilityScore: 70.0,
        isDay: true,
      );

      final allEvals = {0: route1, 1: route2};

      // Analysis for Route 1 (Safest)
      final analysis1 = RouteExplanationEngine.generate(
        targetEvaluation: route1,
        allEvaluations: allEvals,
        origin: 'Coimbatore',
        destination: 'Madurai',
        vehicle: 'Car',
        travelTime: 'Day',
        priority: 'Safety First',
        service: service,
        formatDurationFn: (mins) => '${(mins ~/ 60)}h ${(mins % 60).round()}m',
      );

      expect(analysis1.recommendationBadge, 'Recommended for safety');
      expect(analysis1.positiveHighlights, contains('Safer (+12 pts)'));
      expect(analysis1.positiveHighlights, contains('Better road condition'));
      expect(analysis1.positiveHighlights, contains('Lower accident risk'));
      expect(
        analysis1.tradeOffHighlights,
        anyElement(contains('Slightly longer')),
      );
      expect(
        analysis1.comparativeNarrative,
        contains('Route 1 has a higher safety score than Route 2'),
      );
      expect(analysis1.comparativeNarrative, contains('Route 2 is faster'));

      // Analysis for Route 2 (Faster)
      final analysis2 = RouteExplanationEngine.generate(
        targetEvaluation: route2,
        allEvaluations: allEvals,
        origin: 'Coimbatore',
        destination: 'Madurai',
        vehicle: 'Car',
        travelTime: 'Day',
        priority: 'Safety First',
        service: service,
        formatDurationFn: (mins) => '${(mins ~/ 60)}h ${(mins % 60).round()}m',
      );

      expect(
        analysis2.recommendationBadge,
        'Consider Route 1 for better safety',
      );
      expect(
        analysis2.positiveHighlights,
        anyElement(contains('Faster route')),
      );
      expect(
        analysis2.tradeOffHighlights,
        anyElement(contains('Lower safety score')),
      );
      expect(analysis2.comparativeNarrative, contains('Route 2 is faster'));
      expect(
        analysis2.comparativeNarrative,
        contains('Route 1 provides a higher safety score'),
      );
    });

    test('Safety vs Time trade-off section correctly isolates safest and fastest routes', () {
      final route1 = createEvaluation(
        index: 0,
        distanceKm: 150.0,
        durationSeconds: 10000,
        safetyScore: 82.0,
        accidentScore: 80.0,
        roadConditionScore: 80.0,
        trafficScore: 80.0,
        weatherScore: 80.0,
        lightingScore: null,
        accessibilityScore: 80.0,
      );

      final route2 = createEvaluation(
        index: 1,
        distanceKm: 130.0,
        durationSeconds: 8000,
        safetyScore: 74.0,
        accidentScore: 70.0,
        roadConditionScore: 70.0,
        trafficScore: 70.0,
        weatherScore: 70.0,
        lightingScore: null,
        accessibilityScore: 70.0,
      );

      final analysis = RouteExplanationEngine.generate(
        targetEvaluation: route1,
        allEvaluations: {0: route1, 1: route2},
        origin: 'Coimbatore',
        destination: 'Salem',
        vehicle: 'Car',
        travelTime: 'Day',
        priority: 'Safety First',
        service: service,
        formatDurationFn: (mins) => '${(mins ~/ 60)}h ${(mins % 60).round()}m',
      );

      expect(analysis.safestRouteIndex, 0);
      expect(analysis.safestRouteScore, 82.0);
      expect(analysis.fastestRouteIndex, 1);
      expect(analysis.fastestRouteScore, 74.0);
      expect(analysis.safetyVsTimeNarrative, contains('Route 2 is faster'));
      expect(
        analysis.safetyVsTimeNarrative,
        contains('Route 1 provides the highest safety score'),
      );
    });

    test(
      'Similar safety scores trigger "Both routes have similar safety levels"',
      () {
        final route1 = createEvaluation(
          index: 0,
          distanceKm: 100.0,
          durationSeconds: 6000,
          safetyScore: 81.0,
          accidentScore: 80.0,
          roadConditionScore: 80.0,
          trafficScore: 80.0,
          weatherScore: 80.0,
          lightingScore: null,
          accessibilityScore: 80.0,
        );

        final route2 = createEvaluation(
          index: 1,
          distanceKm: 102.0,
          durationSeconds: 6100,
          safetyScore: 80.0,
          accidentScore: 80.0,
          roadConditionScore: 80.0,
          trafficScore: 80.0,
          weatherScore: 80.0,
          lightingScore: null,
          accessibilityScore: 80.0,
        );

        final analysis = RouteExplanationEngine.generate(
          targetEvaluation: route1,
          allEvaluations: {0: route1, 1: route2},
          origin: 'Trichy',
          destination: 'Thanjavur',
          vehicle: 'Car',
          travelTime: 'Day',
          priority: 'Safety First',
          service: service,
          formatDurationFn: (mins) =>
              '${(mins ~/ 60)}h ${(mins % 60).round()}m',
        );

        expect(
          analysis.recommendationBadge,
          'Both routes have similar safety levels',
        );
        expect(
          analysis.comparativeNarrative,
          contains('similar safety levels'),
        );
      },
    );

    test('Tamil translations are fully populated and valid', () {
      final route = createEvaluation(
        index: 0,
        distanceKm: 100.0,
        durationSeconds: 6000,
        safetyScore: 85.0,
        accidentScore: 85.0,
        roadConditionScore: 85.0,
        trafficScore: null,
        weatherScore: 85.0,
        lightingScore: null,
        accessibilityScore: 85.0,
      );

      final analysis = RouteExplanationEngine.generate(
        targetEvaluation: route,
        allEvaluations: {0: route},
        origin: 'Coimbatore',
        destination: 'Tiruppur',
        vehicle: 'Car',
        travelTime: 'Day',
        priority: 'Safety First',
        service: service,
        formatDurationFn: (mins) => '${(mins ~/ 60)}h ${(mins % 60).round()}m',
      );

      expect(
        analysis.tamilRecommendationBadge,
        'பாதுகாப்பிற்கு பரிந்துரைக்கப்படுகிறது',
      );
      expect(WhyThisRouteLocalization.title(true), 'இந்த வழி ஏன்?');
      expect(
        WhyThisRouteLocalization.factorTitle('accident', true),
        'விபத்து அபாயம்',
      );
      expect(
        WhyThisRouteLocalization.factorTitle('traffic', true),
        'போக்குவரத்து',
      );

      final trafficFactor = analysis.factors.firstWhere(
        (f) => f.key == 'traffic',
      );
      expect(
        trafficFactor.tamilCommentary,
        'போக்குவரத்து தரவு தற்போது கிடைக்கவில்லை, எனவே இது சேர்க்கப்படவில்லை.',
      );
    });
  });
}
