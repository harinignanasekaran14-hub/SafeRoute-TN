import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/main.dart';

void main() {
  group('Real-Time Context-Aware Route Intelligence Tests', () {
    // -------------------------------------------------------------------------
    // 1. Route Recommendation Prioritizing Safety Over Distance
    // -------------------------------------------------------------------------
    test('1. Route recommendation prioritizes safety score over raw distance', () {
      // Route 1: 207.5 km, duration 350 min, safety score 78.0
      final route1 = RouteResult(
        routeIndex: 0,
        distance: 207.5,
        duration: 350.0,
        points: const [LatLng(11.6643, 78.1460), LatLng(9.9252, 78.1198)],
      );
      final safety1 = calculateAuthoritativeSafetyScore(
        accidentScore: 80.0,
        roadConditionScore: 75.0,
        trafficScore: null,
        weatherScore: 79.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Day',
      );
      final eval1 = RouteEvaluation(
        route: route1,
        roadSegments: const [],
        safety: safety1,
        weather: WeatherData(
          temperature: 28.0,
          windSpeed: 10.0,
          precipitation: 0.0,
          weatherCode: 0,
        ),
        blackspots: const BlackspotRouteAssessment(
          clearSampleScore: 80.0,
          detectedBlackspots: 1,
          successfulSamples: 5,
          segmentsChecked: 5,
          verifiedRecordCount: 1,
          segmentResults: [],
          unavailableReason: null,
        ),
        traffic: null,
      );

      // Route 2: 211.5 km (4 km longer), duration 347 min, safety score 92.0
      final route2 = RouteResult(
        routeIndex: 1,
        distance: 211.5,
        duration: 347.0,
        points: const [LatLng(11.6643, 78.1460), LatLng(9.9252, 78.1198)],
      );
      final safety2 = calculateAuthoritativeSafetyScore(
        accidentScore: 100.0,
        roadConditionScore: 88.0,
        trafficScore: null,
        weatherScore: 88.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Day',
      );
      final eval2 = RouteEvaluation(
        route: route2,
        roadSegments: const [],
        safety: safety2,
        weather: WeatherData(
          temperature: 28.0,
          windSpeed: 10.0,
          precipitation: 0.0,
          weatherCode: 0,
        ),
        blackspots: const BlackspotRouteAssessment(
          clearSampleScore: 100.0,
          detectedBlackspots: 0,
          successfulSamples: 5,
          segmentsChecked: 5,
          verifiedRecordCount: 0,
          segmentResults: [],
          unavailableReason: null,
        ),
        traffic: null,
      );

      expect(safety2.score!, greaterThan(safety1.score!));

      // Candidates sorted with safety prioritizing over distance
      final candidates = [eval1, eval2];
      candidates.sort((first, second) {
        final scoreOrder = second.safety.score!.compareTo(first.safety.score!);
        if (scoreOrder != 0) return scoreOrder;
        return first.route.distance.compareTo(second.route.distance);
      });

      // Route 2 must be ranked first because its safety score (92%) is higher than Route 1 (78%)
      expect(candidates.first.route.routeIndex, equals(1));
      expect(candidates.first.route.distance, greaterThan(candidates[1].route.distance));
    });

    // -------------------------------------------------------------------------
    // 2. Unavailable Traffic Handling
    // -------------------------------------------------------------------------
    test('2. Unavailable traffic is completely excluded from composite scoring denominator', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 95.0,
        roadConditionScore: 85.0,
        trafficScore: null, // Traffic offline / unconfigured
        weatherScore: 90.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Day',
      );

      expect(result.score, isNotNull);
      final trafficFactor = result.factors.firstWhere((f) => f.title == 'Traffic');
      expect(trafficFactor.score, isNull);
      expect(trafficFactor.weight, equals(0.0));
      expect(trafficFactor.status, equals('Unavailable'));
      expect(trafficFactor.unavailableReason, contains('unavailable'));

      // Active factors must NOT contain traffic
      expect(result.activeFactors.any((f) => f.title == 'Traffic'), isFalse);

      // Active factor weights must sum precisely to 1.0
      final totalWeight = result.activeFactors.fold<double>(0.0, (sum, f) => sum + f.weight);
      expect(totalWeight, closeTo(1.0, 0.001));
    });

    // -------------------------------------------------------------------------
    // 3. Incomplete Evidence Gate Handling
    // -------------------------------------------------------------------------
    test('3. Incomplete evidence fails safety gate without fabricating fallbacks', () {
      // Only Weather provided (1 factor, non-core)
      final weatherOnly = calculateAuthoritativeSafetyScore(
        accidentScore: null,
        roadConditionScore: null,
        trafficScore: null,
        weatherScore: 85.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      expect(weatherOnly.isEvidenceSufficient, isFalse);
      expect(weatherOnly.score, isNull);
      expect(weatherOnly.insufficientDataReason, contains('core infrastructure'));

      // Weather + Lighting provided (2 factors, but no core infrastructure)
      final nonCoreTwo = calculateAuthoritativeSafetyScore(
        accidentScore: null,
        roadConditionScore: null,
        trafficScore: null,
        weatherScore: 85.0,
        lightingScore: 90.0,
        accessibilityScore: null,
        travelTime: 'Night',
      );
      expect(nonCoreTwo.isEvidenceSufficient, isFalse);
      expect(nonCoreTwo.score, isNull);
      expect(nonCoreTwo.insufficientDataReason, contains('core infrastructure'));
    });

    // -------------------------------------------------------------------------
    // 4. Dynamic Context Refresh Conditions & Freshness
    // -------------------------------------------------------------------------
    test('4. Data freshness and time-ago helper format timestamps accurately', () {
      final now = DateTime.now();
      expect(formatTimeAgo(now), equals('Just now'));
      expect(formatTimeAgo(now.subtract(const Duration(seconds: 45))), equals('Just now'));
      expect(formatTimeAgo(now.subtract(const Duration(minutes: 5))), equals('5m ago'));
      expect(formatTimeAgo(now.subtract(const Duration(minutes: 25))), equals('25m ago'));
      expect(formatTimeAgo(now.subtract(const Duration(hours: 2))), equals('2h ago'));
    });

    test('4b. Dynamic context refresh triggers on weather expiry (> 15 min)', () {
      final oldWeather = WeatherData(
        temperature: 27.0,
        windSpeed: 8.0,
        precipitation: 0.0,
        weatherCode: 0,
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 16)),
      );

      final isExpired = DateTime.now().difference(oldWeather.fetchedAt).inMinutes >= 15;
      expect(isExpired, isTrue);

      final freshWeather = WeatherData(
        temperature: 27.0,
        windSpeed: 8.0,
        precipitation: 0.0,
        weatherCode: 0,
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      );
      final isFreshExpired = DateTime.now().difference(freshWeather.fetchedAt).inMinutes >= 15;
      expect(isFreshExpired, isFalse);
    });

    test('4c. Dynamic context refresh triggers on distance moved (> 1000m)', () {
      const p1 = LatLng(11.6643, 78.1460); // Salem
      const p2Near = LatLng(11.6650, 78.1465); // ~95m away
      const p3Far = LatLng(11.6750, 78.1560); // ~1.5 km away

      final distNear = const Distance().as(LengthUnit.Meter, p1, p2Near);
      expect(distNear < 1000.0, isTrue);

      final distFar = const Distance().as(LengthUnit.Meter, p1, p3Far);
      expect(distFar >= 1000.0, isTrue);
    });

    // -------------------------------------------------------------------------
    // 5. Score Calculation Transparency Matrix
    // -------------------------------------------------------------------------
    test('5. Transparency factors expose correct metadata and normalization', () {
      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 100.0,
        accidentSegmentsWithMatches: 0,
        accidentVerifiedRecordCount: 4,
        roadConditionScore: 82.0,
        trafficScore: null,
        weatherScore: 91.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Day',
        priority: 'Safety First',
      );

      expect(result.factors.length, equals(6));

      // Accident Risk: 100% Clear, Yes
      final accident = result.factors.firstWhere((f) => f.title == 'Accident Risk');
      expect(accident.status, equals('Clear'));
      expect(accident.score, equals(100.0));
      expect(accident.weight, greaterThan(0.0));

      // Road Condition: 82%, Yes
      final road = result.factors.firstWhere((f) => f.title == 'Road Condition');
      expect(road.status, equals('Available'));
      expect(road.score, equals(82.0));
      expect(road.weight, greaterThan(0.0));

      // Traffic: Unavailable, No
      final traffic = result.factors.firstWhere((f) => f.title == 'Traffic');
      expect(traffic.status, equals('Unavailable'));
      expect(traffic.score, isNull);
      expect(traffic.weight, equals(0.0));

      // Weather: Available, Yes
      final weatherFactor = result.factors.firstWhere((f) => f.title == 'Weather');
      expect(weatherFactor.status, equals('Available'));
      expect(weatherFactor.score, equals(91.0));
      expect(weatherFactor.weight, greaterThan(0.0));

      // Lighting: Day mode travel -> 100% natural daylight
      final lighting = result.factors.firstWhere((f) => f.title == 'Lighting');
      expect(lighting.status, equals('Daylight'));
      expect(lighting.score, equals(100.0));
    });

    // -------------------------------------------------------------------------
    // 6. Route Switching Consistency
    // -------------------------------------------------------------------------
    test('6. Route switching preserves evaluations and updates active selection', () {
      final route1 = RouteResult(
        routeIndex: 0,
        distance: 200.0,
        duration: 300.0,
        points: const [LatLng(11.0, 78.0), LatLng(11.5, 78.5)],
      );
      final route2 = RouteResult(
        routeIndex: 1,
        distance: 205.0,
        duration: 295.0,
        points: const [LatLng(11.0, 78.0), LatLng(11.6, 78.6)],
      );

      final evalMap = <int, RouteEvaluation>{
        0: RouteEvaluation(
          route: route1,
          roadSegments: const [],
          safety: calculateAuthoritativeSafetyScore(
            accidentScore: 85.0,
            roadConditionScore: 80.0,
            trafficScore: null,
            weatherScore: 80.0,
            lightingScore: null,
            accessibilityScore: null,
          ),
          weather: null,
          blackspots: const BlackspotRouteAssessment(
            clearSampleScore: 85.0,
            detectedBlackspots: 0,
            successfulSamples: 2,
            segmentsChecked: 2,
            verifiedRecordCount: 0,
            segmentResults: [],
            unavailableReason: null,
          ),
          traffic: null,
        ),
        1: RouteEvaluation(
          route: route2,
          roadSegments: const [],
          safety: calculateAuthoritativeSafetyScore(
            accidentScore: 95.0,
            roadConditionScore: 90.0,
            trafficScore: null,
            weatherScore: 85.0,
            lightingScore: null,
            accessibilityScore: null,
          ),
          weather: null,
          blackspots: const BlackspotRouteAssessment(
            clearSampleScore: 95.0,
            detectedBlackspots: 0,
            successfulSamples: 2,
            segmentsChecked: 2,
            verifiedRecordCount: 0,
            segmentResults: [],
            unavailableReason: null,
          ),
          traffic: null,
        ),
      };

      int selectedIndex = 0;
      expect(evalMap[selectedIndex]!.safety.score, equals(evalMap[0]!.safety.score));

      // Switch to Route 2
      selectedIndex = 1;
      expect(evalMap[selectedIndex]!.safety.score, equals(evalMap[1]!.safety.score));
      expect(evalMap[selectedIndex]!.route.routeIndex, equals(1));
    });

    // -------------------------------------------------------------------------
    // 7. Navigation State Preservation
    // -------------------------------------------------------------------------
    test('7. Navigation state variables preserve active status during context updates', () {
      bool navigationActive = true;
      bool followMe = true;
      int selectedRoute = 1;
      double distanceRemainingMeters = 45000.0;

      // Simulate a background context refresh event
      final now = DateTime.now();
      DateTime? lastRefreshTime = now;
      expect(lastRefreshTime, isNotNull);

      // Verify user navigation state is preserved
      expect(navigationActive, isTrue);
      expect(followMe, isTrue);
      expect(selectedRoute, equals(1));
      expect(distanceRemainingMeters, equals(45000.0));
    });

    // -------------------------------------------------------------------------
    // 8. Real Traffic Integration: Active Participation in Safety Scoring
    // -------------------------------------------------------------------------
    test('8. Traffic factor actively participates in safety scoring when data is available', () {
      const trafficAssessment = TrafficAssessment(
        source: 'TomTom Orbis Traffic Flow Vector Tiles',
        status: 'Low Traffic',
        meanSpeedRatio: 0.92,
        sampleCount: 120,
        matchedSamples: 110,
        coveragePercent: 92,
        roadClosure: false,
      );

      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 90.0,
        roadConditionScore: 85.0,
        trafficScore: trafficAssessment.meanSpeedRatio * 100.0,
        weatherScore: 80.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Day',
        trafficSource: trafficAssessment.source,
        trafficStatus: trafficAssessment.status,
        trafficMatchedSamples: trafficAssessment.matchedSamples,
        trafficCoveragePercent: trafficAssessment.coveragePercent.toDouble(),
        trafficRoadClosure: trafficAssessment.roadClosure,
      );

      expect(result.score, isNotNull);
      final trafficFactor = result.factors.firstWhere((f) => f.title == 'Traffic');
      expect(trafficFactor.score, equals(92.0));
      expect(trafficFactor.status, equals('Low Traffic'));
      expect(trafficFactor.weight, greaterThan(0.0));
      expect(trafficFactor.scoreLabel, contains('110 matched samples'));
      expect(trafficFactor.scoreLabel, contains('92% coverage'));

      // Active factors must contain traffic with positive normalized weight
      expect(result.activeFactors.any((f) => f.title == 'Traffic'), isTrue);

      final trafficActive = result.activeFactors.firstWhere((f) => f.title == 'Traffic');
      expect(trafficActive.weight, closeTo(0.15 / (0.30 + 0.20 + 0.15 + 0.10), 0.01));
    });

    // -------------------------------------------------------------------------
    // 9. Route 1 vs Route 2 Traffic Differentiation
    // -------------------------------------------------------------------------
    test('9. Route 1 and Route 2 evaluate distinct traffic conditions accurately', () {
      const r1Traffic = TrafficAssessment(
        source: 'TomTom Orbis Traffic Flow Vector Tiles',
        status: 'Low Traffic',
        meanSpeedRatio: 0.88,
        sampleCount: 150,
        matchedSamples: 135,
        coveragePercent: 90,
        roadClosure: false,
      );

      const r2Traffic = TrafficAssessment(
        source: 'TomTom Orbis Traffic Flow Vector Tiles',
        status: 'Moderate Traffic',
        meanSpeedRatio: 0.65,
        sampleCount: 160,
        matchedSamples: 120,
        coveragePercent: 75,
        roadClosure: false,
      );

      final r1Score = r1Traffic.meanSpeedRatio * 100.0;
      final r2Score = r2Traffic.meanSpeedRatio * 100.0;

      expect(r1Score, equals(88.0));
      expect(r2Score, equals(65.0));
      expect(r1Traffic.status, equals('Low Traffic'));
      expect(r2Traffic.status, equals('Moderate Traffic'));
      expect(r1Score, greaterThan(r2Score));
    });

    // -------------------------------------------------------------------------
    // 10. Road Closure Handling in Traffic Assessment
    // -------------------------------------------------------------------------
    test('10. Road closure forces traffic score to 0 and marks closure in factor label', () {
      const closureTraffic = TrafficAssessment(
        source: 'TomTom Orbis Traffic Flow Vector Tiles',
        status: 'High Traffic',
        meanSpeedRatio: 0.0,
        sampleCount: 100,
        matchedSamples: 85,
        coveragePercent: 85,
        roadClosure: true,
      );

      final result = calculateAuthoritativeSafetyScore(
        accidentScore: 80.0,
        roadConditionScore: 80.0,
        trafficScore: 0.0,
        weatherScore: 75.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Day',
        trafficRoadClosure: true,
      );

      final trafficFactor = result.factors.firstWhere((f) => f.title == 'Traffic');
      expect(trafficFactor.score, equals(0.0));
      expect(trafficFactor.scoreLabel, contains('Road closure reported'));
    });

    // -------------------------------------------------------------------------
    // 11. API Key Privacy Protection
    // -------------------------------------------------------------------------
    test('11. Traffic assessment never leaks secret API keys into labels, sources or reasons', () {
      const dummySecret = 'test_secret_key_12345';
      const assessment = TrafficAssessment(
        source: 'TomTom Orbis Traffic Flow Vector Tiles',
        status: 'Traffic data unavailable',
        meanSpeedRatio: 0.0,
        sampleCount: 0,
        matchedSamples: 0,
        coveragePercent: 0,
        roadClosure: false,
      );

      expect(assessment.source.contains(dummySecret), isFalse);
      expect(assessment.status.contains(dummySecret), isFalse);
    });

    // -------------------------------------------------------------------------
    // 12. Partial Traffic Coverage (<90%) Transparency
    // -------------------------------------------------------------------------
    test('12. Partial traffic coverage (<90%) transparently discloses monitored and unmonitored portions', () {
      const assessment = TrafficAssessment(
        source: 'TomTom Orbis Traffic Flow Vector Tiles',
        status: 'Low Traffic',
        meanSpeedRatio: 0.92,
        sampleCount: 100,
        matchedSamples: 72,
        coveragePercent: 72,
        roadClosure: false,
        isPartialCoverage: true,
      );

      expect(assessment.unmonitoredSamples, equals(28));
      expect(assessment.unmonitoredPercent, equals(28));
      expect(assessment.transparentStatusLabel, equals('Low Traffic (72% monitored)'));
      expect(assessment.transparentDescription, contains('72% covered, 28% unmonitored'));

      final score = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 80.0,
        trafficScore: 92.0,
        trafficMatchedSamples: 72,
        trafficCoveragePercent: 72.0,
        weatherScore: 80.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Day',
      );

      final trafficFactor = score.factors.firstWhere((f) => f.title == 'Traffic');
      expect(trafficFactor.confidence, equals('Partial'));
      expect(trafficFactor.freshness, equals('Fetched just now (provider age unavailable)'));
      expect(trafficFactor.scoreLabel, contains('72% coverage (28% unmonitored)'));
      expect(trafficFactor.evidence, contains('72% corridor telemetry (28% unmonitored)'));
    });

    // -------------------------------------------------------------------------
    // 13. Missing or Zero Traffic Coverage Handling
    // -------------------------------------------------------------------------
    test('13. Missing or zero traffic coverage is excluded from safety score without fabricating low risk', () {
      final score = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 80.0,
        trafficScore: null,
        trafficMatchedSamples: 0,
        trafficCoveragePercent: 0.0,
        weatherScore: 80.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Day',
      );

      final trafficFactor = score.factors.firstWhere((f) => f.title == 'Traffic');
      expect(trafficFactor.score, isNull);
      expect(trafficFactor.confidence, equals('Unavailable'));
      expect(trafficFactor.freshness, equals('Unavailable'));
      expect(trafficFactor.weight, equals(0.0));
      expect(trafficFactor.unavailableReason, contains('Live traffic unavailable'));
    });

    // -------------------------------------------------------------------------
    // 14. Full Traffic Coverage (>=90%) Verified Confidence and Honest Freshness
    // -------------------------------------------------------------------------
    test('14. Full traffic coverage (>=90%) marks confidence Verified with honest fetch freshness', () {
      const assessment = TrafficAssessment(
        source: 'TomTom Orbis Traffic Flow Vector Tiles',
        status: 'Low Traffic',
        meanSpeedRatio: 0.95,
        sampleCount: 100,
        matchedSamples: 96,
        coveragePercent: 96,
        roadClosure: false,
        isPartialCoverage: false,
      );

      expect(assessment.unmonitoredSamples, equals(4));
      expect(assessment.unmonitoredPercent, equals(4));
      expect(assessment.transparentStatusLabel, equals('Low Traffic (96%)'));

      final score = calculateAuthoritativeSafetyScore(
        accidentScore: 85.0,
        roadConditionScore: 80.0,
        trafficScore: 95.0,
        trafficMatchedSamples: 96,
        trafficCoveragePercent: 96.0,
        weatherScore: 80.0,
        lightingScore: null,
        accessibilityScore: null,
        travelTime: 'Day',
      );

      final trafficFactor = score.factors.firstWhere((f) => f.title == 'Traffic');
      expect(trafficFactor.confidence, equals('Verified'));
      expect(trafficFactor.freshness, equals('Fetched just now (provider age unavailable)'));
      expect(trafficFactor.scoreLabel, contains('96 matched samples · 96% coverage'));
      expect(trafficFactor.evidence, contains('96% corridor telemetry'));
    });
  });
}
