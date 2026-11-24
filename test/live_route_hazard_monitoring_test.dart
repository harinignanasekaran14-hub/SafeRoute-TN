import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// Standalone unit tests for Phase 2A: Live Route Hazard Monitoring & Ahead-of-User Detection
// Covers:
// 1. Ahead vs Behind route progress projection
// 2. Clearing hazards once user passes them
// 3. Polyline slicing for remaining route ahead of GPS position
// 4. Duplicate alert suppression and alerted IDs set tracking
// 5. Cooldown logic for voice/audio guidance
// 6. Distinction between verified, pending, and meteorological alerts
// 7. Rejection of low-accuracy GPS fixes (> 50m) to guard against jitter

double _distanceBetweenMeters(LatLng p1, LatLng p2) {
  const earthRadius = 6371000.0;
  final dLat = (p2.latitude - p1.latitude) * math.pi / 180.0;
  final dLon = (p2.longitude - p1.longitude) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(p1.latitude * math.pi / 180.0) *
          math.cos(p2.latitude * math.pi / 180.0) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double? _calculateRouteProgressMeters(LatLng location, List<LatLng> points) {
  if (points.isEmpty) return null;
  if (points.length == 1) return 0;
  final longitudeScale =
      111320.0 * math.cos(location.latitude * math.pi / 180);
  const latitudeScale = 110540.0;
  double toX(LatLng point) =>
      (point.longitude - location.longitude) * longitudeScale;
  double toY(LatLng point) =>
      (point.latitude - location.latitude) * latitudeScale;

  var progressMeters = 0.0;
  var nearestSquared = double.infinity;
  var nearestProgress = 0.0;
  for (var index = 0; index < points.length - 1; index++) {
    final first = points[index];
    final second = points[index + 1];
    final firstX = toX(first);
    final firstY = toY(first);
    final segmentX = toX(second) - firstX;
    final segmentY = toY(second) - firstY;
    final squaredLength = segmentX * segmentX + segmentY * segmentY;
    final fraction = squaredLength == 0
        ? 0.0
        : (-(firstX * segmentX + firstY * segmentY) / squaredLength)
            .clamp(0.0, 1.0)
            .toDouble();
    final dx = firstX + segmentX * fraction;
    final dy = firstY + segmentY * fraction;
    final distanceSquared = dx * dx + dy * dy;
    if (distanceSquared < nearestSquared) {
      nearestSquared = distanceSquared;
      nearestProgress = progressMeters +
          _distanceBetweenMeters(first, second) * fraction;
    }
    progressMeters += _distanceBetweenMeters(first, second);
  }
  return nearestProgress;
}

double? _checkHazardRemaining(
  LatLng userPosition,
  LatLng hazardPosition,
  List<LatLng> routePoints,
) {
  final userProgress = _calculateRouteProgressMeters(userPosition, routePoints);
  final hazardProgress =
      _calculateRouteProgressMeters(hazardPosition, routePoints);
  if (userProgress == null || hazardProgress == null) return null;
  // If hazard is more than 35m behind the user, consider it passed
  if (hazardProgress < userProgress - 35.0) return null;
  return math.max(0.0, hazardProgress - userProgress);
}

List<LatLng> _sliceRemainingRoute(LatLng userLoc, List<LatLng> routePoints) {
  if (routePoints.isEmpty) return const [];
  if (routePoints.length <= 2) return [userLoc, routePoints.last];

  final currentProgress =
      _calculateRouteProgressMeters(userLoc, routePoints) ?? 0.0;
  int sliceIndex = 0;
  double accumulated = 0.0;
  for (int i = 0; i < routePoints.length - 1; i++) {
    final segDist = _distanceBetweenMeters(routePoints[i], routePoints[i + 1]);
    if (accumulated + segDist >= currentProgress) {
      sliceIndex = i;
      break;
    }
    accumulated += segDist;
  }

  final remaining = <LatLng>[userLoc];
  for (int i = sliceIndex + 1; i < routePoints.length; i++) {
    remaining.add(routePoints[i]);
  }
  return remaining.length >= 2 ? remaining : [userLoc, routePoints.last];
}

void main() {
  group('Phase 2A: Live Route Hazard Monitoring & Ahead Detection Tests', () {
    // 3-point straight route: Chennai Central -> Guindy -> Tambaram
    // Total approx 25 km
    final routePoints = [
      const LatLng(13.0827, 80.2707), // Chennai Central (0 km)
      const LatLng(13.0067, 80.2026), // Guindy (~12 km)
      const LatLng(12.9249, 80.1000), // Tambaram (~25 km)
    ];

    test('1. Hazard ahead is detected with accurate positive remaining distance', () {
      final userAtCentral = const LatLng(13.0827, 80.2707);
      final hazardAtGuindy = const LatLng(13.0067, 80.2026);

      final remaining = _checkHazardRemaining(
        userAtCentral,
        hazardAtGuindy,
        routePoints,
      );

      expect(remaining, isNotNull);
      expect(remaining!, greaterThan(10000.0)); // > 10 km
      expect(remaining, lessThan(15000.0)); // < 15 km
    });

    test('2. Hazard behind user is identified as passed and returns null', () {
      // User is now at Tambaram (end of route)
      final userAtTambaram = const LatLng(12.9249, 80.1000);
      // Hazard was at Guindy (behind user)
      final hazardAtGuindy = const LatLng(13.0067, 80.2026);

      final remaining = _checkHazardRemaining(
        userAtTambaram,
        hazardAtGuindy,
        routePoints,
      );

      // Must be null because hazard has been passed
      expect(remaining, isNull);
    });

    test('3. Small 35-meter trailing buffer prevents premature alert dismissal right at the hazard', () {
      final hazardAtGuindy = const LatLng(13.0067, 80.2026);
      // User is 10 meters past the hazard (within 35m tolerance buffer)
      final userJustPast = const LatLng(13.0066, 80.2025);

      final remaining = _checkHazardRemaining(
        userJustPast,
        hazardAtGuindy,
        routePoints,
      );

      // Still considered active/at the hazard (clamp to 0.0) rather than immediately null
      expect(remaining, isNotNull);
      expect(remaining!, equals(0.0));
    });

    test('4. Route slicing produces remaining points starting from current GPS fix to destination', () {
      final userMidway = const LatLng(13.0067, 80.2026); // At Guindy
      final remainingRoute = _sliceRemainingRoute(userMidway, routePoints);

      expect(remainingRoute.length, greaterThanOrEqualTo(2));
      expect(remainingRoute.first.latitude, equals(userMidway.latitude));
      expect(remainingRoute.first.longitude, equals(userMidway.longitude));
      expect(remainingRoute.last.latitude, equals(routePoints.last.latitude));
      expect(remainingRoute.last.longitude, equals(routePoints.last.longitude));
    });

    test('5. Duplicate alert suppression prevents re-speaking the same incident ID', () {
      final alertedIds = <int>{};
      const hazardId = 42;

      // First detection: triggers alert
      bool shouldAlertFirstTime = !alertedIds.contains(hazardId);
      expect(shouldAlertFirstTime, isTrue);
      alertedIds.add(hazardId);

      // Subsequent checks: suppressed
      bool shouldAlertSecondTime = !alertedIds.contains(hazardId);
      expect(shouldAlertSecondTime, isFalse);
    });

    test('6. User-dismissed hazards are excluded from triggering new cockpit banners', () {
      final dismissedIds = <int>{};
      const hazardId = 101;

      // User taps "Dismiss" in cockpit
      dismissedIds.add(hazardId);

      // Hazard evaluation loop filters it out
      final candidateIds = [101, 102, 103];
      final activeCandidates = candidateIds.where((id) => !dismissedIds.contains(id)).toList();

      expect(activeCandidates, equals([102, 103]));
      expect(activeCandidates.contains(hazardId), isFalse);
    });

    test('7. Global voice cooldown suppresses rapid voice alerts within 60 seconds', () {
      DateTime? lastSpokenTime;
      final now = DateTime(2026, 11, 23, 23, 0, 0);

      // First alert speaks
      lastSpokenTime = now;

      // Second alert arrives 25 seconds later (within 60s cooldown)
      final tooSoon = now.add(const Duration(seconds: 25));
      final canSpeakSoon =
          tooSoon.difference(lastSpokenTime).inSeconds >= 60;
      expect(canSpeakSoon, isFalse);

      // Third alert arrives 65 seconds later (cooldown elapsed)
      final cooldownElapsed = now.add(const Duration(seconds: 65));
      final canSpeakLater =
          cooldownElapsed.difference(lastSpokenTime).inSeconds >= 60;
      expect(canSpeakLater, isTrue);
    });

    test('8. Low accuracy GPS fixes (> 50m) are safely rejected to guard against jitter', () {
      const accurateGps = 12.5; // meters
      const inaccurateJitter = 75.0; // meters

      bool shouldProcess(double accuracy) => accuracy.isFinite && accuracy <= 50.0;

      expect(shouldProcess(accurateGps), isTrue);
      expect(shouldProcess(inaccurateJitter), isFalse);
    });

    test('9. Verification status clearly distinguishes verified vs unverified reports', () {
      final confirmedReport = {'status': 'Confirmed', 'problem_type': 'Flooding / waterlogging'};
      final pendingReport = {'status': 'Pending', 'problem_type': 'Road blocked'};
      final weatherAlert = {'type': 'severe_weather', 'condition': 'Heavy Rain', 'status': 'Weather Alert'};

      String getBadgeLabel(Map<String, dynamic> item) {
        if (item['type'] == 'severe_weather') return 'METEOROLOGICAL';
        if (item['status'] == 'Confirmed') return 'VERIFIED';
        return 'COMMUNITY NOTICE';
      }

      expect(getBadgeLabel(confirmedReport), equals('VERIFIED'));
      expect(getBadgeLabel(pendingReport), equals('COMMUNITY NOTICE'));
      expect(getBadgeLabel(weatherAlert), equals('METEOROLOGICAL'));
    });
  });
}
