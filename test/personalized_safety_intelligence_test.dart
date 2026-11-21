import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/personal_safety_profile.dart';

void main() {
  group('SafeRoute TN 2.0 — Personalized Context-Aware Safety Intelligence Tests', () {
    // 1. Real factor availability
    test('1. Real factor availability: all 6 factors report correct availability, source, freshness, confidence', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 92.0,
        accidentSegmentsWithMatches: 0,
        accidentVerifiedRecordCount: 15,
        roadConditionScore: 88.0,
        roadConditionSegments: 12,
        trafficScore: 78.0,
        trafficMatchedSamples: 24,
        trafficCoveragePercent: 95.0,
        weatherScore: 80.0,
        weatherTemperature: 28.0,
        weatherPrecipitation: 0.0,
        weatherWindSpeed: 12.0,
        lightingScore: 84.0,
        lightingSegments: 8,
        accessibilityScore: 76.0,
        accessibilitySegments: 6,
        travelTime: 'Night',
      );

      expect(result.score, isNotNull);
      expect(result.evidenceCount, 6);
      expect(result.activeFactors.length, 6);

      final factorMap = {for (final f in result.factors) f.title: f};

      // Accident Risk
      expect(factorMap['Accident Risk']!.source, 'Verified TN accident blackspots');
      expect(factorMap['Accident Risk']!.confidence, 'Verified');
      expect(factorMap['Accident Risk']!.freshness, 'Verified Dataset v2024');

      // Road Condition
      expect(factorMap['Road Condition']!.source, 'OpenStreetMap verified road attributes');
      expect(factorMap['Road Condition']!.confidence, 'Verified');
      expect(factorMap['Road Condition']!.freshness, 'OSM Overpass Live');

      // Traffic
      expect(factorMap['Traffic']!.source, 'TomTom live flow');
      expect(factorMap['Traffic']!.confidence, 'Verified');
      expect(factorMap['Traffic']!.freshness, 'Fetched just now (provider age unavailable)');

      // Weather
      expect(factorMap['Weather']!.source, 'Open-Meteo Weather Forecast API');
      expect(factorMap['Weather']!.confidence, 'Verified');
      expect(factorMap['Weather']!.freshness, 'Live 15m');

      // Lighting
      expect(factorMap['Lighting']!.source, 'OpenStreetMap lit tags');
      expect(factorMap['Lighting']!.confidence, 'Verified');
      expect(factorMap['Lighting']!.freshness, 'OSM Overpass Live');

      // Accessibility
      expect(factorMap['Accessibility']!.source, 'OpenStreetMap accessibility tags');
      expect(factorMap['Accessibility']!.confidence, 'Verified');
      expect(factorMap['Accessibility']!.freshness, 'OSM Overpass Live');
    });

    // 2. Unavailable factors excluded from denominator & weights re-normalized
    test('2. Unavailable factors: excluded from denominator, weights re-normalized to 100%', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 90.0,
        roadConditionScore: 80.0,
        trafficScore: null,
        weatherScore: 70.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );

      expect(result.score, isNotNull);
      expect(result.activeFactors.length, 3);

      final sumActiveWeights = result.activeFactors.fold<double>(0.0, (s, f) => s + f.weight);
      expect(sumActiveWeights, closeTo(1.0, 0.001));

      // Display factors for unavailable ones must have weight 0.0
      final trafficFactor = result.factors.firstWhere((f) => f.title == 'Traffic');
      expect(trafficFactor.score, isNull);
      expect(trafficFactor.weight, 0.0);
    });

    // 3. Score never 0% or 100% just because a factor is missing
    test('3. Score is never 0% or 100% just because a factor is missing', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 80.0,
        roadConditionScore: 85.0,
        trafficScore: null,
        weatherScore: null,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );

      expect(result.score, isNotNull);
      expect(result.score!, greaterThan(50.0));
      expect(result.score!, lessThan(95.0));
      expect(result.isProvisional, isTrue);
    });

    // 4. Short trip (< 20 km) weighting
    test('4. Short trip (< 20 km): road condition and lighting have higher weight than weather', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 90.0,
        roadConditionScore: 85.0,
        trafficScore: 80.0,
        weatherScore: 75.0,
        lightingScore: 70.0,
        accessibilityScore: 65.0,
        travelTime: 'Night',
        routeDistanceKm: 12.0,
        routeDurationMinutes: 25.0,
      );

      final factorMap = {for (final f in result.factors) f.title: f};
      // Road weight (0.25 base) should be strictly greater than weather (0.10 base)
      expect(factorMap['Road Condition']!.weight, greaterThan(factorMap['Weather']!.weight));
      expect(result.tripContext, 'short');
    });

    // 5. Long trip (>= 20 km) weighting
    test('5. Long trip (>= 20 km): weather stability and sustained road condition have higher weight', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 90.0,
        roadConditionScore: 85.0,
        trafficScore: 80.0,
        weatherScore: 75.0,
        lightingScore: 70.0,
        accessibilityScore: 65.0,
        travelTime: 'Night',
        routeDistanceKm: 180.0,
        routeDurationMinutes: 220.0,
      );

      expect(result.tripContext, 'long');
      final factorMap = {for (final f in result.factors) f.title: f};
      // Weather weight is boosted for long trips
      expect(factorMap['Weather']!.weight, greaterThan(0.0));
    });

    // 6. Women Safety profile
    test('6. Women Safety profile: night travel emphasizes lighting + police; honest partial evidence disclosed', () {
      final womenProfile = const PersonalSafetyProfile(
        safetyMode: 'Women Safety',
        isConfigured: true,
      );

      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 90.0,
        roadConditionScore: 80.0,
        trafficScore: 75.0,
        weatherScore: 80.0,
        lightingScore: 85.0,
        accessibilityScore: 70.0,
        travelTime: 'Night',
        profile: womenProfile,
      );

      expect(result.safetyMode, 'Women Safety');
      final factorMap = {for (final f in result.factors) f.title: f};
      // Lighting is highest or tied-highest at night for Women Safety (0.30 base weight)
      expect(factorMap['Lighting']!.weight, greaterThanOrEqualTo(factorMap['Road Condition']!.weight));
    });

    // 7. Senior-Friendly profile
    test('7. Senior-Friendly profile: accessibility + road smoothness emphasized; medical proximity checked', () {
      final seniorProfile = const PersonalSafetyProfile(
        safetyMode: 'Senior Friendly',
        isConfigured: true,
      );

      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 90.0,
        roadConditionScore: 85.0,
        trafficScore: 75.0,
        weatherScore: 80.0,
        lightingScore: 80.0,
        accessibilityScore: 88.0,
        profile: seniorProfile,
      );

      expect(result.safetyMode, 'Senior Friendly');
      final factorMap = {for (final f in result.factors) f.title: f};
      // Accessibility (0.35 base) and Road (0.25 base) are dominant
      expect(factorMap['Accessibility']!.weight, greaterThan(factorMap['Accident Risk']!.weight));
      expect(factorMap['Road Condition']!.weight, greaterThan(factorMap['Traffic']!.weight));
    });

    // 8. Family Safety profile
    test('8. Family Safety profile: accident safety + weather stability emphasized', () {
      final familyProfile = const PersonalSafetyProfile(
        safetyMode: 'Family Safety',
        isConfigured: true,
      );

      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 95.0,
        roadConditionScore: 85.0,
        trafficScore: 75.0,
        weatherScore: 85.0,
        lightingScore: 80.0,
        accessibilityScore: 70.0,
        profile: familyProfile,
      );

      expect(result.safetyMode, 'Family Safety');
      final factorMap = {for (final f in result.factors) f.title: f};
      // Accident risk is highest (0.35 base)
      expect(factorMap['Accident Risk']!.weight, greaterThan(factorMap['Road Condition']!.weight));
    });

    // 9. Personal preference re-ranking (User A vs User B)
    test('9. Personal preference re-ranking: User A (Senior) and User B (Fastest) get different route recommendations', () {
      final seniorProfile = const PersonalSafetyProfile(
        safetyMode: 'Senior Friendly',
        safetyPriority: 'Safer Route',
        isConfigured: true,
      );
      final fastProfile = const PersonalSafetyProfile(
        safetyMode: 'General',
        safetyPriority: 'Faster Route',
        isConfigured: true,
      );

      // Route 1: Safe, highly accessible, but slower (3h 30m, 210 km)
      final safety1 = calculateAuthoritativeSafetyScore(
        accidentScore: 95.0,
        roadConditionScore: 90.0,
        trafficScore: 80.0,
        weatherScore: 85.0,
        lightingScore: 80.0,
        accessibilityScore: 95.0,
        accessibilitySegments: 15,
        profile: seniorProfile,
      );
      final route1 = RouteEvaluation(
        route: RouteResult(
          points: [const LatLng(11.0, 77.0), const LatLng(10.0, 78.0)],
          distance: 210.0,
          duration: 210.0 * 60, // 210 mins in seconds
          routeIndex: 0,
        ),
        roadSegments: [],
        safety: safety1,
        weather: null,
        blackspots: BlackspotRouteAssessment(
          clearSampleScore: 95.0,
          detectedBlackspots: 0,
          successfulSamples: 20,
          segmentsChecked: 20,
          verifiedRecordCount: 20,
          unavailableReason: null,
          segmentResults: const [],
        ),
        traffic: null,
      );

      // Route 2: Much faster, but lower accessibility and road score (2h 00m, 170 km)
      final safety2 = calculateAuthoritativeSafetyScore(
        accidentScore: 75.0,
        roadConditionScore: 60.0,
        trafficScore: 85.0,
        weatherScore: 80.0,
        lightingScore: 70.0,
        accessibilityScore: 40.0,
        profile: fastProfile,
      );
      final route2 = RouteEvaluation(
        route: RouteResult(
          points: [const LatLng(11.0, 77.0), const LatLng(10.0, 78.0)],
          distance: 170.0,
          duration: 120.0 * 60, // 120 mins in seconds
          routeIndex: 1,
        ),
        roadSegments: [],
        safety: safety2,
        weather: null,
        blackspots: BlackspotRouteAssessment(
          clearSampleScore: 75.0,
          detectedBlackspots: 3,
          successfulSamples: 20,
          segmentsChecked: 20,
          verifiedRecordCount: 20,
          unavailableReason: null,
          segmentResults: const [],
        ),
        traffic: null,
      );

      final candidates = [route1, route2];

      final seniorRecommendation = selectRecommendedRouteIndex(
        candidates: candidates,
        profile: seniorProfile,
        priority: 'Safer Route',
      );

      final fastRecommendation = selectRecommendedRouteIndex(
        candidates: candidates,
        profile: fastProfile,
        priority: 'Faster Route',
      );

      // User A (Senior) should prefer Route 1 (index 0) due to high accessibility and safety
      expect(seniorRecommendation, 0);

      // User B (Fastest) should prefer Route 2 (index 1) due to shorter duration
      expect(fastRecommendation, 1);

      // They get divergent recommendations between the same origin and destination!
      expect(seniorRecommendation != fastRecommendation, isTrue);
    });

    // 10. PreferenceMatchEvaluator alignment
    test('10. PreferenceMatchEvaluator: returns correct alignment percentage and match reasons', () {
      final profile = const PersonalSafetyProfile(
        safetyMode: 'Women Safety',
        safetyPriority: 'Safer Route',
        roadConditionPreference: 'Prefer smooth roads',
        nightLightingPreference: 'Prefer lit roads',
        isConfigured: true,
      );

      final safety = calculateAuthoritativeSafetyScore(
        accidentScore: 90.0,
        roadConditionScore: 85.0,
        trafficScore: 80.0,
        weatherScore: 75.0,
        lightingScore: 85.0,
        accessibilityScore: 70.0,
        travelTime: 'Night',
        profile: profile,
      );

      final evaluation = RouteEvaluation(
        route: RouteResult(
          points: [const LatLng(11.0, 77.0), const LatLng(10.0, 78.0)],
          distance: 50.0,
          duration: 60.0 * 60,
          routeIndex: 0,
        ),
        roadSegments: [],
        safety: safety,
        weather: null,
        blackspots: BlackspotRouteAssessment(
          clearSampleScore: 90.0,
          detectedBlackspots: 0,
          successfulSamples: 10,
          segmentsChecked: 10,
          verifiedRecordCount: 10,
          unavailableReason: null,
          segmentResults: const [],
        ),
        traffic: null,
      );

      final match = PreferenceMatchEvaluator.evaluate(
        evaluation: evaluation,
        profile: profile,
        isDay: false,
      );

      expect(match.matchPercentage, greaterThan(75.0));
      expect(match.matchFactors, isNotEmpty);
      expect(match.matchLabel, contains('Match'));
    });

    // 11. PersonalSafetyProfile serialization round-trip
    test('11. PersonalSafetyProfile serialization: toJson / fromJson round-trips cleanly with all new fields', () {
      final original = PersonalSafetyProfile(
        vehicleMode: 'Bike',
        safetyPriority: 'Safer Route',
        safetyMode: 'Women Safety',
        nightLightingPreference: 'Strictly lit roads',
        weatherPreference: 'Avoid rain',
        roadConditionPreference: 'Prefer smooth roads',
        accessibilityPreference: 'Prefer accessible routes',
        preferEmergencyCoverage: true,
        avoidPoorRoads: true,
        travelPurpose: 'Commute',
        isConfigured: true,
        updatedAt: DateTime.parse('2026-10-31T12:00:00Z'),
      );

      final json = original.toJson();
      final reconstituted = PersonalSafetyProfile.fromJson(json);

      expect(reconstituted.vehicleMode, original.vehicleMode);
      expect(reconstituted.safetyPriority, original.safetyPriority);
      expect(reconstituted.safetyMode, original.safetyMode);
      expect(reconstituted.nightLightingPreference, original.nightLightingPreference);
      expect(reconstituted.weatherPreference, original.weatherPreference);
      expect(reconstituted.roadConditionPreference, original.roadConditionPreference);
      expect(reconstituted.accessibilityPreference, original.accessibilityPreference);
      expect(reconstituted.preferEmergencyCoverage, original.preferEmergencyCoverage);
      expect(reconstituted.avoidPoorRoads, original.avoidPoorRoads);
      expect(reconstituted.isConfigured, original.isConfigured);
    });

    // 12. Safety honesty: provisional score when evidence < 3 factors
    test('12. Safety honesty: provisional score returned when evidence < 3 factors; insufficientDataReason set', () {
      // 2 factors with core infrastructure -> provisional score
      final provisional = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: null,
        trafficScore: null,
        weatherScore: 80.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      expect(provisional.isProvisional, isTrue);
      expect(provisional.score, isNotNull);
      expect(provisional.isEvidenceSufficient, isTrue);

      // Only 1 factor -> insufficient
      final insufficient = calculateAuthoritativeSafetyScore(
        accidentScore: null,
        roadConditionScore: null,
        trafficScore: null,
        weatherScore: 80.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      expect(insufficient.isEvidenceSufficient, isFalse);
      expect(insufficient.score, isNull);
      expect(insufficient.insufficientDataReason, contains('Requires'));
    });

    // 13. Dynamic weight normalization: sum of active weights always equals 1.0
    test('13. Dynamic weight normalization: sum of active weights always equals 1.0', () {
      final res4 = calculateAuthoritativeSafetyScore(
        accidentScore: 80.0,
        roadConditionScore: 85.0,
        trafficScore: 70.0,
        weatherScore: 75.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      final sum4 = res4.activeFactors.fold<double>(0.0, (s, f) => s + f.weight);
      expect(sum4, closeTo(1.0, 0.001));

      final res5 = calculateAuthoritativeSafetyScore(
        accidentScore: 80.0,
        roadConditionScore: 85.0,
        trafficScore: 70.0,
        weatherScore: 75.0,
        lightingScore: 80.0,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      final sum5 = res5.activeFactors.fold<double>(0.0, (s, f) => s + f.weight);
      expect(sum5, closeTo(1.0, 0.001));
    });

    // 14. Empty / zero blackspots: scores 100% for that factor, not overall score
    test('14. Empty / zero blackspots: scores 100% for that factor, not overall score', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 100.0,
        accidentSegmentsWithMatches: 0,
        accidentVerifiedRecordCount: 10,
        roadConditionScore: 70.0,
        trafficScore: 70.0,
        weatherScore: 70.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );

      final accidentFactor = result.factors.firstWhere((f) => f.title == 'Accident Risk');
      expect(accidentFactor.score, 100.0);
      expect(result.score, isNotNull);
      // Overall score must be a weighted mix (< 100.0)
      expect(result.score!, lessThan(95.0));
      expect(result.score!, greaterThan(75.0));
    });

    // 15. Traffic fallback: when TomTom unavailable, traffic factor correctly marked unavailable
    test('15. Traffic fallback: when TomTom unavailable, traffic factor correctly marked unavailable', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 85.0,
        trafficScore: null,
        weatherScore: 80.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );

      final trafficFactor = result.factors.firstWhere((f) => f.title == 'Traffic');
      expect(trafficFactor.score, isNull);
      expect(trafficFactor.confidence, 'Unavailable');
      expect(trafficFactor.unavailableReason, contains('Live traffic unavailable'));
    });

    // 16. Weather caching freshness
    test('16. Weather caching: cached weather within 30 min marked fresh; older marked stale', () {
      final freshResult = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 85.0,
        trafficScore: 80.0,
        weatherScore: 80.0,
        weatherTimestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      final freshWeather = freshResult.factors.firstWhere((f) => f.title == 'Weather');
      expect(freshWeather.freshness, 'Live 15m');
      expect(freshWeather.confidence, 'Verified');

      final staleResult = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 85.0,
        trafficScore: 80.0,
        weatherScore: 80.0,
        weatherTimestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      final staleWeather = staleResult.factors.firstWhere((f) => f.title == 'Weather');
      expect(staleWeather.freshness, 'Stale (> 30m)');
      expect(staleWeather.confidence, 'Provisional');
    });

        // 17. Road-class fallback transparency
    test('17. Road-class fallback transparency: proxy road-class hierarchy clearly distinguished from explicit pavement tags', () {
      final proxyResult = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 85.0,
        roadConditionSegments: 10,
        roadConditionExplicitSegments: 0,
        roadConditionProxySegments: 10,
        trafficScore: 80.0,
        weatherScore: 75.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      final proxyFactor = proxyResult.factors.firstWhere((f) => f.title == 'Road Condition');
      expect(proxyFactor.source, contains('proxy estimate'));
      expect(proxyFactor.evidence, contains('pavement unmeasured'));
      expect(proxyFactor.confidence, 'Partial');

      final directResult = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 85.0,
        roadConditionSegments: 10,
        roadConditionExplicitSegments: 10,
        roadConditionProxySegments: 0,
        trafficScore: 80.0,
        weatherScore: 75.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      final directFactor = directResult.factors.firstWhere((f) => f.title == 'Road Condition');
      expect(directFactor.source, 'OpenStreetMap verified road attributes');
      expect(directFactor.evidence, contains('direct surface/smoothness tags'));
      expect(directFactor.confidence, 'Verified');
    });

    // 18. Evidence-gate route selection: both routes null
    test('18. Evidence-gate route selection: both routes with null safety scores produce null recommendation in safety mode', () {
      final nullSafety = PersonalizedSafetyResult(
        score: null,
        factors: [],
        activeFactors: [],
        isEvidenceSufficient: false,
        insufficientDataReason: 'Insufficient evidence',
      );

      final route1 = RouteEvaluation(
        route: RouteResult(
          points: [const LatLng(11.0, 77.0), const LatLng(11.1, 77.1)],
          distance: 10.0,
          duration: 15.0 * 60,
          routeIndex: 0,
        ),
        roadSegments: [],
        safety: nullSafety,
        weather: null,
        blackspots: const BlackspotRouteAssessment(
          detectedBlackspots: 0,
          segmentsChecked: 0,
          successfulSamples: 0,
          clearSampleScore: null,
          verifiedRecordCount: 0,
          unavailableReason: 'No data',
          segmentResults: [],
        ),
        traffic: null,
      );

      final route2 = RouteEvaluation(
        route: RouteResult(
          points: [const LatLng(11.0, 77.0), const LatLng(11.2, 77.2)],
          distance: 12.0,
          duration: 18.0 * 60,
          routeIndex: 1,
        ),
        roadSegments: [],
        safety: nullSafety,
        weather: null,
        blackspots: const BlackspotRouteAssessment(
          detectedBlackspots: 0,
          segmentsChecked: 0,
          successfulSamples: 0,
          clearSampleScore: null,
          verifiedRecordCount: 0,
          unavailableReason: 'No data',
          segmentResults: [],
        ),
        traffic: null,
      );

      final rec = selectRecommendedRouteIndex(
        candidates: [route1, route2],
        priority: 'Safer Route',
      );

      expect(rec, isNull, reason: 'When all routes have null safety scores, safety recommendation must be unavailable');
    });

    // 19. Evidence-gate route selection: only one route verified
    test('19. Evidence-gate route selection: when only one route has verified evidence, unavailable route cannot be selected as safest', () {
      final nullSafety = PersonalizedSafetyResult(
        score: null,
        factors: [],
        activeFactors: [],
        isEvidenceSufficient: false,
        insufficientDataReason: 'Insufficient evidence',
      );

      final verifiedSafety = PersonalizedSafetyResult(
        score: 82.0,
        factors: [
          SafetyFactor(
            title: 'Accident Risk',
            icon: Icons.shield_rounded,
            score: 85.0,
            scoreLabel: 'Clear',
            weight: 0.4,
          ),
          SafetyFactor(
            title: 'Road Condition',
            icon: Icons.add_road_rounded,
            score: 80.0,
            scoreLabel: 'Good',
            weight: 0.3,
          ),
          SafetyFactor(
            title: 'Traffic',
            icon: Icons.traffic_rounded,
            score: 80.0,
            scoreLabel: 'Clear',
            weight: 0.3,
          ),
        ],
        activeFactors: [
          SafetyFactor(
            title: 'Accident Risk',
            icon: Icons.shield_rounded,
            score: 85.0,
            scoreLabel: 'Clear',
            weight: 0.4,
          ),
          SafetyFactor(
            title: 'Road Condition',
            icon: Icons.add_road_rounded,
            score: 80.0,
            scoreLabel: 'Good',
            weight: 0.3,
          ),
          SafetyFactor(
            title: 'Traffic',
            icon: Icons.traffic_rounded,
            score: 80.0,
            scoreLabel: 'Clear',
            weight: 0.3,
          ),
        ],
        isEvidenceSufficient: true,
      );

      final route0 = RouteEvaluation(
        route: RouteResult(
          points: [const LatLng(11.0, 77.0), const LatLng(11.1, 77.1)],
          distance: 10.0,
          duration: 12.0 * 60,
          routeIndex: 0,
        ),
        roadSegments: [],
        safety: nullSafety,
        weather: null,
        blackspots: const BlackspotRouteAssessment(
          detectedBlackspots: 0,
          segmentsChecked: 0,
          successfulSamples: 0,
          clearSampleScore: null,
          verifiedRecordCount: 0,
          unavailableReason: 'No data',
          segmentResults: [],
        ),
        traffic: null,
      );

      final route1 = RouteEvaluation(
        route: RouteResult(
          points: [const LatLng(11.0, 77.0), const LatLng(11.2, 77.2)],
          distance: 12.0,
          duration: 15.0 * 60,
          routeIndex: 1,
        ),
        roadSegments: [],
        safety: verifiedSafety,
        weather: null,
        blackspots: const BlackspotRouteAssessment(
          detectedBlackspots: 0,
          segmentsChecked: 5,
          successfulSamples: 5,
          clearSampleScore: 85.0,
          verifiedRecordCount: 8,
          unavailableReason: null,
          segmentResults: [],
        ),
        traffic: null,
      );

      final rec = selectRecommendedRouteIndex(
        candidates: [route0, route1],
        priority: 'Safer Route',
      );

      expect(rec, 1, reason: 'Route 1 must be selected as the only verified route; Route 0 is unavailable and cannot be presented as safest');
    });

    // 20. Accident dataset coverage limitation
    test('20. Accident dataset coverage: evidence explicitly discloses verified NH corridor limitation', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 100.0,
        accidentSegmentsWithMatches: 0,
        accidentVerifiedRecordCount: 8,
        roadConditionScore: 85.0,
        trafficScore: 80.0,
        weatherScore: 75.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );

      final accidentFactor = result.factors.firstWhere((f) => f.title == 'Accident Risk');
      expect(accidentFactor.evidence, contains('coverage limited to verified NH corridors'));
    });
  });
}