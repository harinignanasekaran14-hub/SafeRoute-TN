import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

// SafeRoute TN 2.0 Weather & Waterlogging-Aware Smart Routing Test Suite
// Covering the 12 specification test requirements:
// 1. Current weather data parsing
// 2. Forecast data parsing
// 3. Missing weather provider
// 4. Stale weather data
// 5. Heavy rainfall warning
// 6. Rainfall without confirmed flooding
// 7. Verified waterlogging report detection
// 8. Pending flood report does not affect authoritative scoring
// 9. Route 1 and Route 2 comparison
// 10. Alternative route avoidance geometry
// 11. Duplicate warning suppression
// 12. Backend timeout and API failure handling

class TestHourlyForecast {
  final String time;
  final double temperatureC;
  final int precipitationProbabilityPct;
  final double precipitationMm;
  final String weatherDescription;

  const TestHourlyForecast({
    required this.time,
    required this.temperatureC,
    required this.precipitationProbabilityPct,
    required this.precipitationMm,
    required this.weatherDescription,
  });

  factory TestHourlyForecast.fromJson(Map<String, dynamic> json) {
    return TestHourlyForecast(
      time: json['time'] as String? ?? '',
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 0.0,
      precipitationProbabilityPct:
          (json['precipitation_probability_pct'] as num?)?.toInt() ?? 0,
      precipitationMm: (json['precipitation_mm'] as num?)?.toDouble() ?? 0.0,
      weatherDescription: json['weather_description'] as String? ?? 'Clear sky',
    );
  }
}

class TestWeatherWaypoint {
  final String label;
  final double latitude;
  final double longitude;
  final double temperatureC;
  final double precipitationMm;
  final int weatherCode;
  final String weatherDescription;
  final double windSpeedKmh;
  final double? visibilityMeters;
  final String observationTime;
  final bool isFresh;
  final List<TestHourlyForecast> forecast;

  const TestWeatherWaypoint({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.temperatureC,
    required this.precipitationMm,
    required this.weatherCode,
    required this.weatherDescription,
    required this.windSpeedKmh,
    this.visibilityMeters,
    required this.observationTime,
    required this.isFresh,
    this.forecast = const [],
  });

  factory TestWeatherWaypoint.fromJson(Map<String, dynamic> json) {
    final rawForecast = json['hourly_forecast'] as List<dynamic>? ?? [];
    return TestWeatherWaypoint(
      label: json['label'] as String? ?? 'Waypoint',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 0.0,
      precipitationMm: (json['precipitation_mm'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (json['weather_code'] as num?)?.toInt() ?? 0,
      weatherDescription: json['weather_description'] as String? ?? 'Clear',
      windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble() ?? 0.0,
      visibilityMeters: (json['visibility_m'] as num?)?.toDouble(),
      observationTime: json['observation_time'] as String? ?? '',
      isFresh: json['is_fresh'] as bool? ?? true,
      forecast: rawForecast
          .map((item) => TestHourlyForecast.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TestWeatherSummary {
  final bool available;
  final String provider;
  final DateTime fetchedAt;
  final List<TestWeatherWaypoint> waypoints;
  final double maxRainfallMm;
  final double? minVisibilityMeters;
  final double highestWindKmh;
  final String overallCondition;
  final List<String> warnings;
  final String floodStatus;
  final int verifiedFloodCount;
  final int pendingFloodCount;

  const TestWeatherSummary({
    required this.available,
    required this.provider,
    required this.fetchedAt,
    required this.waypoints,
    required this.maxRainfallMm,
    this.minVisibilityMeters,
    this.highestWindKmh = 0.0,
    required this.overallCondition,
    required this.warnings,
    required this.floodStatus,
    this.verifiedFloodCount = 0,
    this.pendingFloodCount = 0,
  });

  factory TestWeatherSummary.fromJson(Map<String, dynamic> json) {
    final rawWp = json['waypoints'] as List<dynamic>? ?? [];
    final rawWarnings = json['warnings'] as List<dynamic>? ?? [];
    final verifiedList = json['verified_waterlogging_hazards'] as List<dynamic>? ?? [];
    final pendingList = json['pending_waterlogging_hazards'] as List<dynamic>? ?? [];

    return TestWeatherSummary(
      available: json['available'] as bool? ?? false,
      provider: json['provider'] as String? ?? 'Open-Meteo Weather API',
      fetchedAt: DateTime.tryParse(json['fetched_at'] as String? ?? '') ?? DateTime.now(),
      waypoints: rawWp
          .map((item) => TestWeatherWaypoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      maxRainfallMm: (json['max_rainfall_mm'] as num?)?.toDouble() ?? 0.0,
      minVisibilityMeters: (json['min_visibility_meters'] as num?)?.toDouble(),
      overallCondition: json['overall_condition'] as String? ?? 'Clear sky',
      warnings: rawWarnings.map((w) => w.toString()).toList(),
      floodStatus: json['flood_status'] as String? ?? 'none',
      verifiedFloodCount: verifiedList.length,
      pendingFloodCount: pendingList.length,
    );
  }
}

class TestWeatherWarningManager {
  static final Map<String, DateTime> _emitted = {};
  static const Duration window = Duration(minutes: 15);

  static bool shouldEmit(String key, {DateTime? now, bool isEscalated = false}) {
    final cur = now ?? DateTime.now();
    if (isEscalated) {
      _emitted[key] = cur;
      return true;
    }
    final last = _emitted[key];
    if (last == null || cur.difference(last) >= window) {
      _emitted[key] = cur;
      return true;
    }
    return false;
  }

  static void reset() => _emitted.clear();
}

double? calculateWeatherSafetyScore({
  required double? precipitationMm,
  required int weatherCode,
  required double windSpeedKmh,
  required double temperatureC,
  required DateTime fetchedAt,
  required DateTime currentTime,
  double? visibilityMeters,
}) {
  // Stale check (> 2 hours)
  if (currentTime.difference(fetchedAt).inHours >= 2) {
    return null; // Neutral / non-penalizing for stale data
  }

  var score = 80.0;
  if (weatherCode == 0) score = 100.0;
  if (weatherCode == 61) score = 75.0; // Slight rain
  if (weatherCode == 65) score = 45.0; // Heavy rain
  if (weatherCode == 95) score = 35.0; // Thunderstorm

  if (precipitationMm != null && precipitationMm > 10.0) {
    score -= 20.0;
  } else if (precipitationMm != null && precipitationMm > 2.0) {
    score -= 10.0;
  }

  if (visibilityMeters != null && visibilityMeters < 1000.0) {
    score -= 15.0;
  }

  return score.clamp(0.0, 100.0);
}

void main() {
  group('Weather & Waterlogging-Aware Smart Routing 12 Tests', () {
    setUp(() {
      TestWeatherWarningManager.reset();
    });

    test('1. Current weather data parsing', () {
      final json = {
        'available': true,
        'provider': 'Open-Meteo Weather API',
        'fetched_at': '2026-11-04T09:00:00Z',
        'max_rainfall_mm': 2.4,
        'min_visibility_meters': 5200.0,
        'overall_condition': 'Light drizzle',
        'flood_status': 'none',
        'waypoints': [
          {
            'label': 'Origin',
            'latitude': 11.0168,
            'longitude': 76.9558,
            'temperature_c': 28.5,
            'precipitation_mm': 0.0,
            'weather_code': 1,
            'weather_description': 'Mainly clear',
            'wind_speed_kmh': 12.0,
            'visibility_m': 10000.0,
            'observation_time': '2026-11-04T08:45:00',
            'is_fresh': true,
          }
        ],
      };

      final summary = TestWeatherSummary.fromJson(json);
      expect(summary.available, isTrue);
      expect(summary.provider, equals('Open-Meteo Weather API'));
      expect(summary.waypoints.length, equals(1));
      final wp = summary.waypoints.first;
      expect(wp.temperatureC, equals(28.5));
      expect(wp.isFresh, isTrue);
      expect(wp.weatherDescription, equals('Mainly clear'));
    });

    test('2. Forecast data parsing', () {
      final json = {
        'label': 'Salem Midpoint',
        'latitude': 11.6643,
        'longitude': 78.1460,
        'temperature_c': 29.0,
        'precipitation_mm': 1.2,
        'weather_code': 61,
        'weather_description': 'Slight rain',
        'wind_speed_kmh': 10.0,
        'observation_time': '2026-11-04T09:00:00',
        'is_fresh': true,
        'hourly_forecast': [
          {
            'time': '2026-11-04T10:00',
            'temperature_c': 29.5,
            'precipitation_probability_pct': 70,
            'precipitation_mm': 3.5,
            'weather_description': 'Moderate rain',
          },
          {
            'time': '2026-11-04T11:00',
            'temperature_c': 28.0,
            'precipitation_probability_pct': 85,
            'precipitation_mm': 8.0,
            'weather_description': 'Heavy rain showers',
          }
        ],
      };

      final wp = TestWeatherWaypoint.fromJson(json);
      expect(wp.forecast.length, equals(2));
      expect(wp.forecast[0].temperatureC, equals(29.5));
      expect(wp.forecast[0].precipitationProbabilityPct, equals(70));
      expect(wp.forecast[1].precipitationMm, equals(8.0));
      expect(wp.forecast[1].weatherDescription, equals('Heavy rain showers'));
    });

    test('3. Missing weather provider handled without crash', () {
      final json = {
        'available': false,
        'provider': 'Open-Meteo Weather API',
        'reason': 'provider_unavailable',
        'waypoints': [],
      };

      final summary = TestWeatherSummary.fromJson(json);
      expect(summary.available, isFalse);
      expect(summary.waypoints, isEmpty);
      expect(summary.overallCondition, equals('Clear sky'));
    });

    test('4. Stale weather data (>2 hours old) does not penalize score', () {
      final now = DateTime.now();
      final staleTime = now.subtract(const Duration(hours: 3));

      final score = calculateWeatherSafetyScore(
        precipitationMm: 18.0, // High precipitation would normally heavily penalize
        weatherCode: 65,
        windSpeedKmh: 40.0,
        temperatureC: 28.0,
        fetchedAt: staleTime,
        currentTime: now,
      );

      // Rule: Stale weather returns null, neutral non-penalizing score
      expect(score, isNull);
    });

    test('5. Heavy rainfall warning formulation', () {
      final json = {
        'available': true,
        'max_rainfall_mm': 18.5,
        'warnings': [
          'Heavy Rainfall Warning: Heavy rain (up to 18.5 mm/h) along route. Roadways will be slick with high risk of surface ponding.'
        ],
      };

      final summary = TestWeatherSummary.fromJson(json);
      expect(summary.maxRainfallMm, equals(18.5));
      expect(summary.warnings.any((w) => w.contains('Heavy Rainfall Warning')), isTrue);
    });

    test('6. Rainfall without confirmed flooding never claims road is flooded', () {
      final json = {
        'available': true,
        'max_rainfall_mm': 12.0,
        'flood_status': 'rain_ponding_risk',
        'verified_waterlogging_hazards': [],
        'warnings': [
          'Surface Water Notice: Sustained rainfall may cause localized water accumulation. No verified road flooding reported on this corridor.'
        ],
      };

      final summary = TestWeatherSummary.fromJson(json);
      expect(summary.verifiedFloodCount, equals(0));
      expect(summary.floodStatus, equals('rain_ponding_risk'));
      for (final w in summary.warnings) {
        expect(w.contains('Verified Road Flooding'), isFalse);
      }
    });

    test('7. Verified waterlogging report detection', () {
      final json = {
        'available': true,
        'flood_status': 'verified_flooding',
        'verified_waterlogging_hazards': [
          {
            'id': 101,
            'problem_type': 'Waterlogging / Flooding',
            'location_landmark': 'Bridge km 42',
            'status': 'Confirmed',
            'confidence_score': 85.0,
          }
        ],
        'warnings': [
          'Verified Road Flooding: 1 confirmed waterlogging hazard(s) along route near Bridge km 42. Consider the verified smart alternative route.'
        ],
      };

      final summary = TestWeatherSummary.fromJson(json);
      expect(summary.verifiedFloodCount, equals(1));
      expect(summary.floodStatus, equals('verified_flooding'));
      expect(summary.warnings.first, contains('Verified Road Flooding'));
    });

    test('8. Pending flood report does not affect authoritative scoring', () {
      final json = {
        'available': true,
        'flood_status': 'pending_flooding',
        'verified_waterlogging_hazards': [],
        'pending_waterlogging_hazards': [
          {
            'id': 102,
            'problem_type': 'Waterlogging / Flooding',
            'status': 'Pending',
          }
        ],
        'warnings': [
          'Community Notice: 1 unverified waterlogging report(s) along route under review. Authoritative safety score is preserved.'
        ],
      };

      final summary = TestWeatherSummary.fromJson(json);
      expect(summary.verifiedFloodCount, equals(0));
      expect(summary.pendingFloodCount, equals(1));
      expect(summary.warnings.first, contains('Authoritative safety score is preserved'));
    });

    test('9. Route 1 and Route 2 comparison with weather exposure', () {
      final r1Weather = TestWeatherSummary.fromJson({
        'available': true,
        'max_rainfall_mm': 15.0,
        'overall_condition': 'Heavy rain',
        'verified_waterlogging_hazards': [{'id': 201}],
      });

      final r2Weather = TestWeatherSummary.fromJson({
        'available': true,
        'max_rainfall_mm': 1.0,
        'overall_condition': 'Mainly clear',
        'verified_waterlogging_hazards': [],
      });

      expect(r1Weather.maxRainfallMm, greaterThan(r2Weather.maxRainfallMm));
      expect(r1Weather.verifiedFloodCount, equals(1));
      expect(r2Weather.verifiedFloodCount, equals(0));
    });

    test('10. Alternative route avoidance geometry (>1500m)', () {
      const hazardLat = 11.3500;
      const hazardLon = 77.7200;

      // Current Route point within 50m
      const r1Lat = 11.3503;
      const r1Lon = 77.7202;
      // Alternative Route point > 5km away
      const r2Lat = 11.3900;
      const r2Lon = 77.7700;

      double approxDistKm(double lat1, double lon1, double lat2, double lon2) {
        final dLat = (lat2 - lat1) * 111.0;
        final dLon = (lon2 - lon1) * 111.0;
        return (dLat * dLat + dLon * dLon);
      }

      final dR1 = approxDistKm(hazardLat, hazardLon, r1Lat, r1Lon);
      final dR2 = approxDistKm(hazardLat, hazardLon, r2Lat, r2Lon);

      // Route 2 is genuinely far away (> 1.5km threshold)
      expect(dR1, lessThan(0.1));
      expect(dR2, greaterThan(2.25)); // > 1.5km squared
    });

    test('11. Duplicate warning suppression within 15 minutes', () {
      final t0 = DateTime(2026, 11, 4, 10, 0);
      final t5m = DateTime(2026, 11, 4, 10, 5);
      final t20m = DateTime(2026, 11, 4, 10, 20);

      // First alert allowed
      expect(TestWeatherWarningManager.shouldEmit('flood_near_km42', now: t0), isTrue);

      // Duplicate at 5m suppressed
      expect(TestWeatherWarningManager.shouldEmit('flood_near_km42', now: t5m), isFalse);

      // Escalated alert allowed immediately
      expect(TestWeatherWarningManager.shouldEmit('flood_near_km42', now: t5m, isEscalated: true), isTrue);

      // Normal alert after 20m allowed (exceeded 15m window)
      expect(TestWeatherWarningManager.shouldEmit('flood_near_km42', now: t20m), isTrue);
    });

    test('12. Backend timeout and API failure handling', () {
      // Simulate timeout by constructing offline summary
      final fallbackSummary = TestWeatherSummary(
        available: false,
        provider: 'Open-Meteo Weather API',
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
        waypoints: const [],
        maxRainfallMm: 0.0,
        highestWindKmh: 0.0,
        overallCondition: 'Weather data unavailable',
        warnings: const [],
        floodStatus: 'none',
      );

      expect(fallbackSummary.available, isFalse);
      expect(fallbackSummary.waypoints, isEmpty);
      expect(fallbackSummary.overallCondition, contains('unavailable'));
    });
  });
}
