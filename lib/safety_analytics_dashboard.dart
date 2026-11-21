// ============================================================================
// SafeRoute TN — Safety Analytics Dashboard
// Module: lib/safety_analytics_dashboard.dart
// Description: Responsive, bilingual safety analytics dashboard showcasing real
//              safety travel statistics from saved route records.
//              Strictly on-device local analytics in SharedPreferences.
//              No precise GPS tracking. Zero external tracking APIs.
//              Zero fabricated trips, factors, or scores.
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'personal_safety_profile.dart';
import 'smart_route_risk_forecast.dart';

// ============================================================================
// 1. ANALYTICS DATA MODEL
// ============================================================================

class SafetyAnalyticsRecord {
  final String id;
  final String origin;
  final String destination;
  final double distanceKm;
  final double durationMinutes;
  final double? safetyScore;
  final String vehicleMode;
  final String travelTimeMode;
  final String? routeLabel;
  final DateTime createdAt;
  final String? trafficStatus;
  final double? weatherScore;
  final double? accidentRiskScore;
  final double? roadConditionScore;
  final double? lightingScore;
  final double? accessibilityScore;

  const SafetyAnalyticsRecord({
    required this.id,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.durationMinutes,
    this.safetyScore,
    required this.vehicleMode,
    required this.travelTimeMode,
    this.routeLabel,
    required this.createdAt,
    this.trafficStatus,
    this.weatherScore,
    this.accidentRiskScore,
    this.roadConditionScore,
    this.lightingScore,
    this.accessibilityScore,
  });

  SafetyAnalyticsRecord copyWith({
    String? id,
    String? origin,
    String? destination,
    double? distanceKm,
    double? durationMinutes,
    double? safetyScore,
    String? vehicleMode,
    String? travelTimeMode,
    String? routeLabel,
    DateTime? createdAt,
    String? trafficStatus,
    double? weatherScore,
    double? accidentRiskScore,
    double? roadConditionScore,
    double? lightingScore,
    double? accessibilityScore,
  }) {
    return SafetyAnalyticsRecord(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      safetyScore: safetyScore ?? this.safetyScore,
      vehicleMode: vehicleMode ?? this.vehicleMode,
      travelTimeMode: travelTimeMode ?? this.travelTimeMode,
      routeLabel: routeLabel ?? this.routeLabel,
      createdAt: createdAt ?? this.createdAt,
      trafficStatus: trafficStatus ?? this.trafficStatus,
      weatherScore: weatherScore ?? this.weatherScore,
      accidentRiskScore: accidentRiskScore ?? this.accidentRiskScore,
      roadConditionScore: roadConditionScore ?? this.roadConditionScore,
      lightingScore: lightingScore ?? this.lightingScore,
      accessibilityScore: accessibilityScore ?? this.accessibilityScore,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin,
    'destination': destination,
    'distance_km': distanceKm,
    'duration_minutes': durationMinutes,
    if (safetyScore != null) 'safety_score': safetyScore,
    'vehicle_mode': vehicleMode,
    'travel_time_mode': travelTimeMode,
    if (routeLabel != null) 'route_label': routeLabel,
    'created_at': createdAt.toIso8601String(),
    if (trafficStatus != null) 'traffic_status': trafficStatus,
    if (weatherScore != null) 'weather_score': weatherScore,
    if (accidentRiskScore != null) 'accident_risk_score': accidentRiskScore,
    if (roadConditionScore != null) 'road_condition_score': roadConditionScore,
    if (lightingScore != null) 'lighting_score': lightingScore,
    if (accessibilityScore != null) 'accessibility_score': accessibilityScore,
  };

  factory SafetyAnalyticsRecord.fromJson(Map<String, dynamic> json) {
    return SafetyAnalyticsRecord(
      id: json['id'] as String? ?? UniqueKey().toString(),
      origin: json['origin'] as String? ?? 'Unknown',
      destination: json['destination'] as String? ?? 'Unknown',
      distanceKm:
          (json['distance_km'] ?? json['distanceKm'] as num?)?.toDouble() ??
          0.0,
      durationMinutes:
          (json['duration_minutes'] ?? json['durationMinutes'] as num?)
              ?.toDouble() ??
          0.0,
      safetyScore: (json['safety_score'] ?? json['safetyScore'] as num?)
          ?.toDouble(),
      vehicleMode:
          json['vehicle_mode'] ?? json['vehicleMode'] as String? ?? 'Car',
      travelTimeMode:
          json['travel_time_mode'] ??
          json['travelTimeMode'] as String? ??
          'Day',
      routeLabel: json['route_label'] ?? json['routeLabel'] as String?,
      createdAt: json['created_at'] != null || json['createdAt'] != null
          ? DateTime.tryParse(
                  (json['created_at'] ?? json['createdAt']) as String,
                ) ??
                DateTime.now()
          : DateTime.now(),
      trafficStatus: json['traffic_status'] ?? json['trafficStatus'] as String?,
      weatherScore: (json['weather_score'] ?? json['weatherScore'] as num?)
          ?.toDouble(),
      accidentRiskScore:
          (json['accident_risk_score'] ?? json['accidentRiskScore'] as num?)
              ?.toDouble(),
      roadConditionScore:
          (json['road_condition_score'] ?? json['roadConditionScore'] as num?)
              ?.toDouble(),
      lightingScore: (json['lighting_score'] ?? json['lightingScore'] as num?)
          ?.toDouble(),
      accessibilityScore:
          (json['accessibility_score'] ?? json['accessibilityScore'] as num?)
              ?.toDouble(),
    );
  }
}

// ============================================================================
// 2. ANALYTICS LOCAL STORAGE
// ============================================================================

class SafetyAnalyticsStorage {
  static const String storageKey = 'saferoute_safety_analytics';
  static const String savedTripsKey = 'saferoute_saved_trips';
  static const String reportsCountKey = 'saferoute_road_reports_count';

  /// Saves or updates a single analytics record locally
  static Future<bool> saveRecord(SafetyAnalyticsRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRecords = await loadRecords();

      final updated = List<SafetyAnalyticsRecord>.from(existingRecords);
      final index = updated.indexWhere((r) => r.id == record.id);
      if (index >= 0) {
        updated[index] = record;
      } else {
        updated.insert(0, record);
      }

      final jsonList = updated.map((r) => jsonEncode(r.toJson())).toList();
      return await prefs.setStringList(storageKey, jsonList);
    } catch (e) {
      debugPrint('Error saving analytics record: $e');
      return false;
    }
  }

  /// Bulk saves records
  static Future<bool> saveRecords(List<SafetyAnalyticsRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = records.map((r) => jsonEncode(r.toJson())).toList();
      return await prefs.setStringList(storageKey, jsonList);
    } catch (e) {
      debugPrint('Error saving analytics records: $e');
      return false;
    }
  }

  /// Loads all analytics records, seamlessly ingesting any existing saved trips
  /// from SharedPreferences so historical user data is preserved accurately.
  static Future<List<SafetyAnalyticsRecord>> loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsMap = <String, SafetyAnalyticsRecord>{};

      // 1. Load directly stored analytics records
      final rawList = prefs.getStringList(storageKey);
      if (rawList != null) {
        for (final item in rawList) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            final record = SafetyAnalyticsRecord.fromJson(map);
            recordsMap[record.id] = record;
          } catch (_) {}
        }
      }

      // 2. Ingest any saved trips from My Trips if not already present
      final savedTripsRaw = prefs.getStringList(savedTripsKey);
      if (savedTripsRaw != null) {
        for (final item in savedTripsRaw) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            final tripId = map['id']?.toString() ?? '';
            if (tripId.isNotEmpty && !recordsMap.containsKey(tripId)) {
              final tripRecord = SafetyAnalyticsRecord(
                id: tripId,
                origin: map['origin'] as String? ?? 'Unknown',
                destination: map['destination'] as String? ?? 'Unknown',
                distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0.0,
                durationMinutes:
                    (map['duration_minutes'] as num?)?.toDouble() ?? 0.0,
                safetyScore: (map['safety_score'] as num?)?.toDouble(),
                vehicleMode: map['vehicle_mode'] as String? ?? 'Car',
                travelTimeMode: map['travel_time_mode'] as String? ?? 'Day',
                routeLabel: map['route_label'] as String?,
                createdAt: map['created_at'] != null
                    ? DateTime.tryParse(map['created_at'] as String) ??
                          DateTime.now()
                    : DateTime.now(),
                trafficStatus: map['traffic_status'] as String?,
                weatherScore: (map['weather_score'] as num?)?.toDouble(),
              );
              recordsMap[tripId] = tripRecord;
            }
          } catch (_) {}
        }
      }

      final list = recordsMap.values.toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('Error loading analytics records: $e');
      return [];
    }
  }

  /// Clears stored analytics records
  static Future<bool> clearRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(storageKey);
    } catch (e) {
      return false;
    }
  }

  /// Gets the count of locally submitted road reports, if any
  static Future<int?> getLocalRoadReportsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(reportsCountKey);
      if (count != null && count > 0) return count;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Increments local road reports counter
  static Future<void> incrementRoadReportsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(reportsCountKey) ?? 0;
      await prefs.setInt(reportsCountKey, current + 1);
    } catch (_) {}
  }
}

// ============================================================================
// 3. ANALYTICS SUMMARY & DETERMINISTIC AGGREGATOR
// ============================================================================

class SafetyAnalyticsSummary {
  final List<SafetyAnalyticsRecord> allRecords;
  final List<SafetyAnalyticsRecord> filteredRecords;
  final String timeFilter; // 'All', 'Weekly', 'Monthly'
  final int totalSavedRoutes;
  final double? averageSafetyScore;
  final SafetyAnalyticsRecord? safestRoute;
  final double totalSavedDistanceKm;
  final double? averageDurationMinutes;
  final double? lowestSafetyScore;
  final double? highestSafetyScore;
  final double? latestSafetyScore;
  final List<double> recentSafetyScores;
  final List<SafetyAnalyticsRecord> scoreHistoryRecords;
  final String? dominantTrafficStatus;
  final double? averageWeatherScore;
  final Map<String, double?> factorAverages;
  final List<MapEntry<String, int>> frequentRoutes;
  final int? roadReportsCount;

  const SafetyAnalyticsSummary({
    required this.allRecords,
    required this.filteredRecords,
    required this.timeFilter,
    required this.totalSavedRoutes,
    required this.averageSafetyScore,
    required this.safestRoute,
    required this.totalSavedDistanceKm,
    required this.averageDurationMinutes,
    required this.lowestSafetyScore,
    required this.highestSafetyScore,
    required this.latestSafetyScore,
    required this.recentSafetyScores,
    required this.scoreHistoryRecords,
    required this.dominantTrafficStatus,
    required this.averageWeatherScore,
    required this.factorAverages,
    required this.frequentRoutes,
    this.roadReportsCount,
  });

  static SafetyAnalyticsSummary compute({
    required List<SafetyAnalyticsRecord> records,
    String timeFilter = 'All',
    int? roadReportsCount,
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();

    // 1. Time Filter
    final List<SafetyAnalyticsRecord> filtered;
    if (timeFilter == 'Weekly') {
      filtered = records
          .where((r) => now.difference(r.createdAt).inDays <= 7)
          .toList();
    } else if (timeFilter == 'Monthly') {
      filtered = records
          .where((r) => now.difference(r.createdAt).inDays <= 30)
          .toList();
    } else {
      filtered = List<SafetyAnalyticsRecord>.from(records);
    }

    // 2. Metric Calculations
    final totalSaved = filtered.length;

    // Safety Scores (only from records with real safety scores)
    final scoredRecords = filtered.where((r) => r.safetyScore != null).toList();
    double? avgScore;
    double? minScore;
    double? maxScore;
    double? latestScore;
    SafetyAnalyticsRecord? safest;

    if (scoredRecords.isNotEmpty) {
      double sum = 0;
      for (final r in scoredRecords) {
        final sc = r.safetyScore!;
        sum += sc;
        if (minScore == null || sc < minScore) minScore = sc;
        if (maxScore == null || sc > maxScore) {
          maxScore = sc;
          safest = r;
        }
      }
      avgScore = sum / scoredRecords.length;
      latestScore = scoredRecords.first.safetyScore;
    }

    // Recent Scores chronologically for the trend graph
    final chronoScores = List<SafetyAnalyticsRecord>.from(scoredRecords)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final recentScores = chronoScores.map((r) => r.safetyScore!).toList();

    // Total Distance
    double totalDist = 0.0;
    for (final r in filtered) {
      totalDist += r.distanceKm;
    }

    // Average Duration (only from valid durations > 0)
    final validDurations = filtered
        .where((r) => r.durationMinutes > 0)
        .toList();
    double? avgDuration;
    if (validDurations.isNotEmpty) {
      final sumDur = validDurations.fold<double>(
        0.0,
        (acc, r) => acc + r.durationMinutes,
      );
      avgDuration = sumDur / validDurations.length;
    }

    // Traffic Insights (only real traffic statuses)
    final trafficCounts = <String, int>{};
    for (final r in filtered) {
      if (r.trafficStatus != null && r.trafficStatus!.trim().isNotEmpty) {
        trafficCounts[r.trafficStatus!] =
            (trafficCounts[r.trafficStatus!] ?? 0) + 1;
      }
    }
    String? dominantTraffic;
    if (trafficCounts.isNotEmpty) {
      dominantTraffic = trafficCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    // Weather Impact
    final weatherScores = filtered
        .where((r) => r.weatherScore != null)
        .map((r) => r.weatherScore!)
        .toList();
    double? avgWeather;
    if (weatherScores.isNotEmpty) {
      avgWeather = weatherScores.reduce((a, b) => a + b) / weatherScores.length;
    }

    // Safety Factor Averages (Accident Risk, Road Condition, Traffic, Weather, Lighting, Accessibility)
    double? avgOf(Iterable<double?> values) {
      final valid = values.whereType<double>().toList();
      if (valid.isEmpty) return null;
      return valid.reduce((a, b) => a + b) / valid.length;
    }

    final factors = <String, double?>{
      'Accident Risk': avgOf(filtered.map((r) => r.accidentRiskScore)),
      'Road Condition': avgOf(filtered.map((r) => r.roadConditionScore)),
      'Traffic': avgOf(
        filtered.map(
          (r) => r.trafficStatus != null
              ? (r.trafficStatus == 'Low Traffic'
                    ? 88.0
                    : r.trafficStatus == 'Moderate Traffic'
                    ? 68.0
                    : 45.0)
              : null,
        ),
      ),
      'Weather': avgWeather,
      'Lighting': avgOf(filtered.map((r) => r.lightingScore)),
      'Accessibility': avgOf(filtered.map((r) => r.accessibilityScore)),
    };

    // Frequently Saved Routes (group by origin -> destination, only show duplicates with count >= 2)
    final routeCounts = <String, int>{};
    for (final r in records) {
      final key = '${r.origin.trim()} → ${r.destination.trim()}';
      routeCounts[key] = (routeCounts[key] ?? 0) + 1;
    }
    final frequent = routeCounts.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SafetyAnalyticsSummary(
      allRecords: records,
      filteredRecords: filtered,
      timeFilter: timeFilter,
      totalSavedRoutes: totalSaved,
      averageSafetyScore: avgScore,
      safestRoute: safest,
      totalSavedDistanceKm: totalDist,
      averageDurationMinutes: avgDuration,
      lowestSafetyScore: minScore,
      highestSafetyScore: maxScore,
      latestSafetyScore: latestScore,
      recentSafetyScores: recentScores,
      scoreHistoryRecords: chronoScores,
      dominantTrafficStatus: dominantTraffic,
      averageWeatherScore: avgWeather,
      factorAverages: factors,
      frequentRoutes: frequent,
      roadReportsCount: roadReportsCount,
    );
  }
}

// ============================================================================
// 4. BILINGUAL LOCALIZATION
// ============================================================================

class SafetyAnalyticsLocalization {
  static String title(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு பகுப்பாய்வு' : 'Safety Analytics';

  static String subtitle(bool isTamil) => isTamil
      ? 'உங்கள் சேமிக்கப்பட்ட வழிகளிலிருந்து பெறப்பட்ட உண்மையான பாதுகாப்பு புள்ளிவிவரங்கள்'
      : 'Real-world safety travel statistics from your saved route records';

  static String savedRoutes(bool isTamil) =>
      isTamil ? 'சேமிக்கப்பட்ட வழிகள்' : 'Saved Routes';

  static String averageSafetyScore(bool isTamil) =>
      isTamil ? 'சராசரி பாதுகாப்பு மதிப்பெண்' : 'Average Safety Score';

  static String safestRoute(bool isTamil) =>
      isTamil ? 'மிகவும் பாதுகாப்பான வழி' : 'Safest Saved Route';

  static String totalDistance(bool isTamil) =>
      isTamil ? 'மொத்த சேமிக்கப்பட்ட தூரம்' : 'Total Saved Distance';

  static String averageEta(bool isTamil) =>
      isTamil ? 'சராசரி பயண நேரம்' : 'Average ETA';

  static String trafficInsights(bool isTamil) =>
      isTamil ? 'போக்குவரத்து தகவல்கள்' : 'Traffic Insights';

  static String weatherImpact(bool isTamil) =>
      isTamil ? 'வானிலை தாக்கம்' : 'Weather Impact';

  static String roadReports(bool isTamil) =>
      isTamil ? 'சாலை புகார்கள்' : 'Road Reports';

  static String noLocalReports(bool isTamil) => isTamil
      ? 'உள்ளூர் அறிக்கை வரலாறு இல்லை'
      : 'No local report history available';

  static String safetyScoreTrend(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு மதிப்பெண் போக்கு' : 'Safety Score Trend';

  static String highestScore(bool isTamil) =>
      isTamil ? 'அதிகபட்சம்' : 'Highest';

  static String lowestScore(bool isTamil) =>
      isTamil ? 'குறைந்தபட்சம்' : 'Lowest';

  static String latestScore(bool isTamil) => isTamil ? 'சமீபத்திய' : 'Latest';

  static String averageScore(bool isTamil) => isTamil ? 'சராசரி' : 'Average';

  static String notEnoughHistory(bool isTamil) => isTamil
      ? 'இன்னும் போதுமான வழி வரலாறு இல்லை.'
      : 'No enough route history yet.';

  static String timeAll(bool isTamil) => isTamil ? 'அனைத்தும்' : 'All';

  static String timeWeekly(bool isTamil) => isTamil ? 'வாராந்திரம்' : 'Weekly';

  static String timeMonthly(bool isTamil) =>
      isTamil ? 'மாதாந்திரம்' : 'Monthly';

  static String noRecordsForPeriod(bool isTamil) => isTamil
      ? 'இந்த காலத்திற்கு பாதுகாப்பு பதிவுகள் இல்லை.'
      : 'No safety records for this period.';

  static String safetyFactors(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு காரணிகள்' : 'Safety Factors';

  static String unavailable(bool isTamil) =>
      isTamil ? 'தகவல் இல்லை' : 'Unavailable';

  static String noHistoricalData(bool isTamil) =>
      isTamil ? 'வரலாற்று தரவு கிடைக்கவில்லை' : 'No historical data available';

  static String yourSafestRoute(bool isTamil) => isTamil
      ? '🏆 உங்கள் மிகவும் பாதுகாப்பான வழி'
      : '🏆 Your Safest Saved Route';

  static String noSavedRouteYet(bool isTamil) =>
      isTamil ? 'இன்னும் சேமிக்கப்பட்ட வழி இல்லை.' : 'No saved route yet.';

  static String viewRoute(bool isTamil) =>
      isTamil ? 'வழியைக் காண்க' : 'View Route';

  static String planARoute(bool isTamil) =>
      isTamil ? 'வழியைத் திட்டமிடுங்கள்' : 'Plan a Route';

  static String frequentlySavedRoutes(bool isTamil) => isTamil
      ? '📍 அடிக்கடி சேமிக்கப்பட்ட வழிகள்'
      : '📍 Frequently Saved Routes';

  static String savedRecords(bool isTamil) =>
      isTamil ? 'சேமிக்கப்பட்ட பதிவுகள்' : 'saved records';

  static String personalizedSafetyInsight(bool isTamil) => isTamil
      ? '🧠 தனிப்பயனாக்கப்பட்ட பாதுகாப்பு தகவல்'
      : '🧠 Personalized Safety Insight';

  static String currentRouteRisk(bool isTamil) =>
      isTamil ? '🧠 தற்போதைய வழி ஆபத்து' : '🧠 Current Route Risk';

  static String viewRiskForecast(bool isTamil) =>
      isTamil ? 'ஆபத்து கணிப்பைக் காண்க' : 'View Risk Forecast';

  static String aiRouteInsight(bool isTamil) =>
      isTamil ? '🤖 AI வழி நுண்ணறிவு' : '🤖 AI Route Insight';

  static String whyThisRoute(bool isTamil) =>
      isTamil ? 'ஏன் இந்த வழி?' : 'Why This Route?';

  static String emptyStateTitle(bool isTamil) => isTamil
      ? 'உங்கள் பாதுகாப்பு பகுப்பாய்வு இங்கே தோன்றும்'
      : 'Your Safety Analytics will appear here';

  static String emptyStateSubtitle(bool isTamil) => isTamil
      ? 'உங்கள் தனிப்பட்ட பாதுகாப்பு வரலாற்றை உருவாக்க வழிகளை சேமிக்கவும்.'
      : 'Save routes to build your personal safety history.';

  static String factorGood(bool isTamil) => isTamil ? 'நன்று' : 'Good';

  static String factorModerate(bool isTamil) =>
      isTamil ? 'மிதமானது' : 'Moderate';

  static String factorCaution(bool isTamil) =>
      isTamil ? 'எச்சரிக்கை' : 'Caution';

  static String profileInsightText(
    PersonalSafetyProfile profile,
    bool isTamil,
  ) {
    if (profile.safetyPriority == 'Safer Route') {
      return isTamil
          ? 'உங்கள் விவரக்குறிப்பு அதிக பாதுகாப்பு கொண்ட வழிகளுக்கு முன்னுரிமை அளிக்கிறது.'
          : 'Your profile prioritizes safer routes even if travel time is longer.';
    } else if (profile.safetyPriority == 'Faster Route') {
      return isTamil
          ? 'உங்கள் விவரக்குறிப்பு குறைந்த பயண நேரத்திற்கு முன்னுரிமை அளிக்கிறது.'
          : 'Your profile prioritizes shorter travel times while maintaining safety.';
    } else {
      return isTamil
          ? 'உங்கள் விவரக்குறிப்பு பாதுகாப்பு மற்றும் பயண நேரத்தை சீராக சமநிலைப்படுத்துகிறது.'
          : 'Your profile currently balances safety and travel time.';
    }
  }
}

// ============================================================================
// 5. SAFETY SCORE TREND GRAPH WIDGET
// ============================================================================

class SafetyScoreTrendGraph extends StatelessWidget {
  final List<SafetyAnalyticsRecord> records;
  final bool isDark;
  final bool isTamil;

  const SafetyScoreTrendGraph({
    super.key,
    required this.records,
    required this.isDark,
    required this.isTamil,
  });

  @override
  Widget build(BuildContext context) {
    if (records.length < 2) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? NeonTheme.cardElevatedDark.withValues(alpha: 0.5)
              : const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline_rounded,
              color: isDark ? Colors.white38 : Colors.black38,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              SafetyAnalyticsLocalization.notEnoughHistory(isTamil),
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.cardElevatedDark.withValues(alpha: 0.7)
            : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? NeonTheme.cyanBorder : const Color(0x300284C7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _SafetyTrendPainter(records: records, isDark: isDark),
            ),
          ),
          const SizedBox(height: 12),
          // Legend / Axis bounds
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Oldest (${_formatDate(records.first.createdAt)})',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight,
                ),
              ),
              Text(
                'Latest (${_formatDate(records.last.createdAt)})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? NeonTheme.neonCyan : NeonTheme.electricBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}';
  }
}

class _SafetyTrendPainter extends CustomPainter {
  final List<SafetyAnalyticsRecord> records;
  final bool isDark;

  _SafetyTrendPainter({required this.records, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final width = size.width;
    final height = size.height;

    // Background horizontal grid lines (25%, 50%, 75%, 100%)
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      final y = height - (height * (i / 4.0));
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    final n = records.length;
    final points = <Offset>[];

    for (int i = 0; i < n; i++) {
      final score = records[i].safetyScore ?? 50.0;
      final x = n == 1 ? width / 2 : (i / (n - 1)) * (width - 24) + 12;
      final y = height - ((score / 100.0) * (height - 18)) - 9;
      points.add(Offset(x, y));
    }

    // Draw gradient area below curve
    final path = Path();
    path.moveTo(points.first.dx, height);
    for (int i = 0; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.lineTo(points.last.dx, height);
    path.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          NeonTheme.neonCyan.withValues(alpha: isDark ? 0.35 : 0.20),
          NeonTheme.neonCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(path, fillPaint);

    // Draw connecting line
    final linePaint = Paint()
      ..color = NeonTheme.neonCyan
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Draw glowing points with score labels
    for (int i = 0; i < points.length; i++) {
      final score = records[i].safetyScore?.round() ?? 0;
      final p = points[i];
      final color = score >= 75
          ? NeonTheme.safeGreen
          : (score >= 60 ? NeonTheme.neonAmber : NeonTheme.dangerRed);

      // Glow halo
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(p, 6.5, glowPaint);

      // Dot
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, 4.0, dotPaint);

      // White center
      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, 1.8, centerPaint);

      // Text score label on top of point
      final textSpan = TextSpan(
        text: '$score',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(p.dx - (tp.width / 2), p.dy - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _SafetyTrendPainter oldDelegate) {
    return oldDelegate.records != records || oldDelegate.isDark != isDark;
  }
}

// ============================================================================
// 6. MAIN SAFETY ANALYTICS DASHBOARD VIEW
// ============================================================================

class SafetyAnalyticsDashboardView extends StatefulWidget {
  final bool isDarkMode;
  final RouteEvaluation? activeRouteEvaluation;
  final PersonalSafetyProfile? personalProfile;
  final VoidCallback? onPlanRoute;
  final void Function(SafetyAnalyticsRecord record)? onViewSavedRoute;
  final VoidCallback? onOpenRiskForecast;
  final VoidCallback? onOpenWhyThisRoute;
  final VoidCallback? onOpenSafetyProfile;

  const SafetyAnalyticsDashboardView({
    super.key,
    required this.isDarkMode,
    this.activeRouteEvaluation,
    this.personalProfile,
    this.onPlanRoute,
    this.onViewSavedRoute,
    this.onOpenRiskForecast,
    this.onOpenWhyThisRoute,
    this.onOpenSafetyProfile,
  });

  @override
  State<SafetyAnalyticsDashboardView> createState() =>
      _SafetyAnalyticsDashboardViewState();
}

class _SafetyAnalyticsDashboardViewState
    extends State<SafetyAnalyticsDashboardView> {
  bool _isLoading = true;
  bool _isTamil = false;
  String _timeFilter = 'All'; // 'All', 'Weekly', 'Monthly'
  List<SafetyAnalyticsRecord> _allRecords = [];
  int? _roadReportsCount;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    final records = await SafetyAnalyticsStorage.loadRecords();
    final reportsCount =
        await SafetyAnalyticsStorage.getLocalRoadReportsCount();
    if (mounted) {
      setState(() {
        _allRecords = records;
        _roadReportsCount = reportsCount;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: NeonTheme.neonCyan),
        ),
      );
    }

    final summary = SafetyAnalyticsSummary.compute(
      records: _allRecords,
      timeFilter: _timeFilter,
      roadReportsCount: _roadReportsCount,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Language Toggle & Time Filter
              _buildHeader(isDark),
              const SizedBox(height: 20),

              // 2. Empty State if zero records exist
              if (_allRecords.isEmpty)
                _buildZeroDataEmptyState(isDark)
              else ...[
                // Filter bar: All / Weekly / Monthly
                _buildTimeFilterBar(isDark),
                const SizedBox(height: 18),

                // If filtered records is empty for selected period
                if (summary.filteredRecords.isEmpty)
                  _buildPeriodEmptyState(isDark)
                else ...[
                  // 3. Metrics Summary Grid (Responsive 4/2/1 cols)
                  _buildMetricsGrid(summary, isDark),
                  const SizedBox(height: 24),

                  // 4. Safety Score Trend Section
                  _buildTrendSection(summary, isDark),
                  const SizedBox(height: 24),

                  // 5. Safest Route Highlight
                  _buildSafestRouteSection(summary, isDark),
                  const SizedBox(height: 24),

                  // 6. Safety Factor Analysis
                  _buildSafetyFactorsSection(summary, isDark),
                  const SizedBox(height: 24),

                  // 7. Traffic & Weather Insights
                  _buildTrafficWeatherInsights(summary, isDark),
                  const SizedBox(height: 24),

                  // 8. Frequently Saved Routes (Duplicate routes only)
                  if (summary.frequentRoutes.isNotEmpty) ...[
                    _buildFrequentRoutesSection(summary, isDark),
                    const SizedBox(height: 24),
                  ],

                  // 9. Personalized Safety Insight (Profile integration)
                  if (widget.personalProfile != null) ...[
                    _buildPersonalizedInsightSection(
                      widget.personalProfile!,
                      isDark,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 10. Active Route Context (Risk Forecast + Why This Route)
                  if (widget.activeRouteEvaluation != null) ...[
                    _buildActiveRouteContextSection(
                      widget.activeRouteEvaluation!,
                      isDark,
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HEADER
  // --------------------------------------------------------------------------

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NeonTheme.cyanBorder : const Color(0x350284C7),
          width: 1.2,
        ),
        boxShadow: NeonTheme.cardShadow(isDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NeonTheme.neonCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NeonTheme.neonCyan.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: NeonTheme.neonCyan,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SafetyAnalyticsLocalization.title(_isTamil),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? NeonTheme.textPrimaryDark
                        : NeonTheme.textPrimaryLight,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  SafetyAnalyticsLocalization.subtitle(_isTamil),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Bilingual Toggle
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? NeonTheme.cardElevatedDark
                  : const Color(0xffF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLangButton('EN', !_isTamil, isDark),
                _buildLangButton('தமிழ்', _isTamil, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangButton(String text, bool isSelected, bool isDark) {
    return InkWell(
      onTap: () => setState(() => _isTamil = text == 'தமிழ்'),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? NeonTheme.neonCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TIME FILTER BAR
  // --------------------------------------------------------------------------

  Widget _buildTimeFilterBar(bool isDark) {
    return Row(
      children: [
        Text(
          'FILTER: ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: isDark ? NeonTheme.neonCyan : NeonTheme.electricBlue,
          ),
        ),
        const SizedBox(width: 8),
        _buildFilterChip(
          'All',
          SafetyAnalyticsLocalization.timeAll(_isTamil),
          isDark,
        ),
        const SizedBox(width: 6),
        _buildFilterChip(
          'Weekly',
          SafetyAnalyticsLocalization.timeWeekly(_isTamil),
          isDark,
        ),
        const SizedBox(width: 6),
        _buildFilterChip(
          'Monthly',
          SafetyAnalyticsLocalization.timeMonthly(_isTamil),
          isDark,
        ),
        const Spacer(),
        Text(
          '${_allRecords.length} ${SafetyAnalyticsLocalization.savedRecords(_isTamil)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark
                ? NeonTheme.textSecondaryDark
                : NeonTheme.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _timeFilter == key;
    return InkWell(
      onTap: () => setState(() => _timeFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? NeonTheme.neonCyan.withValues(alpha: 0.18)
              : (isDark ? NeonTheme.cardDark : NeonTheme.cardLight),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? NeonTheme.neonCyan
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? NeonTheme.neonCyan
                : (isDark
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // METRICS SUMMARY GRID
  // --------------------------------------------------------------------------

  Widget _buildMetricsGrid(SafetyAnalyticsSummary summary, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int crossAxisCount = w >= 900 ? 4 : (w >= 540 ? 2 : 1);

        final avgScoreText = summary.averageSafetyScore != null
            ? '${summary.averageSafetyScore!.round()}%'
            : SafetyAnalyticsLocalization.unavailable(_isTamil);

        final safestText = summary.safestRoute?.safetyScore != null
            ? '${summary.safestRoute!.safetyScore!.round()}%'
            : SafetyAnalyticsLocalization.unavailable(_isTamil);

        final distText =
            '${summary.totalSavedDistanceKm.toStringAsFixed(1)} km';

        final etaText = summary.averageDurationMinutes != null
            ? '${summary.averageDurationMinutes!.round()} min'
            : SafetyAnalyticsLocalization.unavailable(_isTamil);

        final trafficText =
            summary.dominantTrafficStatus ??
            SafetyAnalyticsLocalization.noHistoricalData(_isTamil);

        final weatherText = summary.averageWeatherScore != null
            ? '${summary.averageWeatherScore!.round()}%'
            : SafetyAnalyticsLocalization.noHistoricalData(_isTamil);

        final reportsText = summary.roadReportsCount != null
            ? '${summary.roadReportsCount}'
            : SafetyAnalyticsLocalization.noLocalReports(_isTamil);

        final cards = [
          _buildMetricCard(
            title: SafetyAnalyticsLocalization.savedRoutes(_isTamil),
            value: '${summary.totalSavedRoutes}',
            icon: Icons.alt_route_rounded,
            color: NeonTheme.neonCyan,
            isDark: isDark,
          ),
          _buildMetricCard(
            title: SafetyAnalyticsLocalization.averageSafetyScore(_isTamil),
            value: avgScoreText,
            icon: Icons.shield_rounded,
            color: NeonTheme.safeGreen,
            isDark: isDark,
          ),
          _buildMetricCard(
            title: SafetyAnalyticsLocalization.safestRoute(_isTamil),
            value: safestText,
            icon: Icons.star_rounded,
            color: NeonTheme.neonAmber,
            isDark: isDark,
          ),
          _buildMetricCard(
            title: SafetyAnalyticsLocalization.totalDistance(_isTamil),
            value: distText,
            icon: Icons.straighten_rounded,
            color: const Color(0xffA855F7),
            isDark: isDark,
          ),
          _buildMetricCard(
            title: SafetyAnalyticsLocalization.averageEta(_isTamil),
            value: etaText,
            icon: Icons.schedule_rounded,
            color: const Color(0xff3B82F6),
            isDark: isDark,
          ),
          _buildMetricCard(
            title: SafetyAnalyticsLocalization.trafficInsights(_isTamil),
            value: trafficText,
            icon: Icons.traffic_rounded,
            color: NeonTheme.safeGreen,
            isDark: isDark,
          ),
          _buildMetricCard(
            title: SafetyAnalyticsLocalization.weatherImpact(_isTamil),
            value: weatherText,
            icon: Icons.cloud_rounded,
            color: const Color(0xff06B6D4),
            isDark: isDark,
          ),
          _buildMetricCard(
            title: SafetyAnalyticsLocalization.roadReports(_isTamil),
            value: reportsText,
            icon: Icons.report_problem_outlined,
            color: NeonTheme.warningGold,
            isDark: isDark,
          ),
        ];

        if (crossAxisCount == 1) {
          return Column(
            children: [
              for (final c in cards) ...[c, const SizedBox(height: 10)],
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 110,
          ),
          itemCount: cards.length,
          itemBuilder: (ctx, i) => cards[i],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.1,
        ),
        boxShadow: NeonTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: value.length > 15 ? 12.5 : 18,
              fontWeight: FontWeight.w900,
              color: isDark
                  ? NeonTheme.textPrimaryDark
                  : NeonTheme.textPrimaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TREND SECTION
  // --------------------------------------------------------------------------

  Widget _buildTrendSection(SafetyAnalyticsSummary summary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NeonTheme.cyanBorder : const Color(0x350284C7),
          width: 1.2,
        ),
        boxShadow: NeonTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                color: NeonTheme.neonCyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                SafetyAnalyticsLocalization.safetyScoreTrend(_isTamil),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              if (summary.averageSafetyScore != null)
                _buildStatPill(
                  SafetyAnalyticsLocalization.averageScore(_isTamil),
                  '${summary.averageSafetyScore!.round()}%',
                  NeonTheme.neonCyan,
                  isDark,
                ),
              if (summary.highestSafetyScore != null) ...[
                const SizedBox(width: 6),
                _buildStatPill(
                  SafetyAnalyticsLocalization.highestScore(_isTamil),
                  '${summary.highestSafetyScore!.round()}%',
                  NeonTheme.safeGreen,
                  isDark,
                ),
              ],
              if (summary.lowestSafetyScore != null) ...[
                const SizedBox(width: 6),
                _buildStatPill(
                  SafetyAnalyticsLocalization.lowestScore(_isTamil),
                  '${summary.lowestSafetyScore!.round()}%',
                  NeonTheme.dangerRed,
                  isDark,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SafetyScoreTrendGraph(
            records: summary.scoreHistoryRecords,
            isDark: isDark,
            isTamil: _isTamil,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SAFEST ROUTE HIGHLIGHT
  // --------------------------------------------------------------------------

  Widget _buildSafestRouteSection(SafetyAnalyticsSummary summary, bool isDark) {
    final safest = summary.safestRoute;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NeonTheme.safeGreen.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: NeonTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                SafetyAnalyticsLocalization.yourSafestRoute(_isTamil),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              if (safest?.safetyScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: NeonTheme.safeGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NeonTheme.safeGreen, width: 1.2),
                  ),
                  child: Text(
                    '${safest!.safetyScore!.round()}% Safety',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: NeonTheme.safeGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (safest == null) ...[
            Text(
              SafetyAnalyticsLocalization.noSavedRouteYet(_isTamil),
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: widget.onPlanRoute,
                icon: const Icon(Icons.explore_rounded, size: 14),
                label: Text(SafetyAnalyticsLocalization.planARoute(_isTamil)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NeonTheme.neonCyan,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${safest.origin} → ${safest.destination}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${safest.distanceKm.toStringAsFixed(1)} km · ${safest.durationMinutes.round()} min · ${safest.vehicleMode} · ${safest.travelTimeMode}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? NeonTheme.textSecondaryDark
                              : NeonTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    if (widget.onViewSavedRoute != null) {
                      widget.onViewSavedRoute!(safest);
                    }
                  },
                  icon: const Icon(Icons.map_rounded, size: 14),
                  label: Text(SafetyAnalyticsLocalization.viewRoute(_isTamil)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NeonTheme.safeGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SAFETY FACTORS SECTION
  // --------------------------------------------------------------------------

  Widget _buildSafetyFactorsSection(
    SafetyAnalyticsSummary summary,
    bool isDark,
  ) {
    final factors = summary.factorAverages;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NeonTheme.cyanBorder : const Color(0x350284C7),
          width: 1.2,
        ),
        boxShadow: NeonTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.security_rounded,
                color: NeonTheme.electricBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                SafetyAnalyticsLocalization.safetyFactors(_isTamil),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFactorBar(
            'Accident Risk',
            factors['Accident Risk'],
            NeonTheme.dangerRed,
            isDark,
          ),
          const SizedBox(height: 10),
          _buildFactorBar(
            'Road Condition',
            factors['Road Condition'],
            NeonTheme.neonAmber,
            isDark,
          ),
          const SizedBox(height: 10),
          _buildFactorBar(
            'Traffic',
            factors['Traffic'],
            NeonTheme.safeGreen,
            isDark,
          ),
          const SizedBox(height: 10),
          _buildFactorBar(
            'Weather',
            factors['Weather'],
            const Color(0xff06B6D4),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildFactorBar(
            'Lighting',
            factors['Lighting'],
            const Color(0xffA855F7),
            isDark,
          ),
          const SizedBox(height: 10),
          _buildFactorBar(
            'Accessibility',
            factors['Accessibility'],
            NeonTheme.neonCyan,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFactorBar(
    String title,
    double? score,
    Color color,
    bool isDark,
  ) {
    final isUnavailable = score == null;
    final rating = isUnavailable
        ? SafetyAnalyticsLocalization.unavailable(_isTamil)
        : (score >= 75
              ? SafetyAnalyticsLocalization.factorGood(_isTamil)
              : (score >= 60
                    ? SafetyAnalyticsLocalization.factorModerate(_isTamil)
                    : SafetyAnalyticsLocalization.factorCaution(_isTamil)));

    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.08),
              child: isUnavailable
                  ? null
                  : FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (score / 100.0).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.7), color],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 85,
          child: Text(
            isUnavailable
                ? SafetyAnalyticsLocalization.unavailable(_isTamil)
                : '${score.round()} ($rating)',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isUnavailable
                  ? (isDark ? Colors.white38 : Colors.black38)
                  : (isDark ? Colors.white : Colors.black87),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // TRAFFIC & WEATHER INSIGHTS
  // --------------------------------------------------------------------------

  Widget _buildTrafficWeatherInsights(
    SafetyAnalyticsSummary summary,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.traffic_rounded,
                      color: NeonTheme.safeGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      SafetyAnalyticsLocalization.trafficInsights(_isTamil),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  summary.dominantTrafficStatus != null
                      ? 'Observed conditions: ${summary.dominantTrafficStatus}'
                      : SafetyAnalyticsLocalization.noHistoricalData(_isTamil),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_rounded,
                      color: Color(0xff06B6D4),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      SafetyAnalyticsLocalization.weatherImpact(_isTamil),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  summary.averageWeatherScore != null
                      ? 'Average weather score: ${summary.averageWeatherScore!.round()}%'
                      : SafetyAnalyticsLocalization.noHistoricalData(_isTamil),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // FREQUENTLY SAVED ROUTES (Duplicates only)
  // --------------------------------------------------------------------------

  Widget _buildFrequentRoutesSection(
    SafetyAnalyticsSummary summary,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NeonTheme.cyanBorder : const Color(0x350284C7),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                SafetyAnalyticsLocalization.frequentlySavedRoutes(_isTamil),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final entry in summary.frequentRoutes) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? NeonTheme.cardElevatedDark
                    : const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    color: NeonTheme.neonCyan,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: NeonTheme.neonCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${entry.value} ${SafetyAnalyticsLocalization.savedRecords(_isTamil)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: NeonTheme.neonCyan,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PERSONALIZED SAFETY INSIGHT
  // --------------------------------------------------------------------------

  Widget _buildPersonalizedInsightSection(
    PersonalSafetyProfile profile,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NeonTheme.electricBlue.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NeonTheme.electricBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: NeonTheme.electricBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SafetyAnalyticsLocalization.personalizedSafetyInsight(
                    _isTamil,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  SafetyAnalyticsLocalization.profileInsightText(
                    profile,
                    _isTamil,
                  ),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onOpenSafetyProfile != null) ...[
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: widget.onOpenSafetyProfile,
              style: OutlinedButton.styleFrom(
                foregroundColor: NeonTheme.electricBlue,
                side: const BorderSide(color: NeonTheme.electricBlue),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
              child: const Text('Manage', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ACTIVE ROUTE CONTEXT
  // --------------------------------------------------------------------------

  Widget _buildActiveRouteContextSection(RouteEvaluation eval, bool isDark) {
    final score = eval.safety.score?.round() ?? 0;
    final riskLevel = RouteRiskLevel.fromScore(eval.safety.score);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: riskLevel.color.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: riskLevel.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.route_rounded, color: riskLevel.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SafetyAnalyticsLocalization.currentRouteRisk(_isTamil),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Active route score: $score/100 · Potential risk level: ${riskLevel.name.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (widget.onOpenRiskForecast != null)
            ElevatedButton(
              onPressed: widget.onOpenRiskForecast,
              style: ElevatedButton.styleFrom(
                backgroundColor: riskLevel.color,
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                SafetyAnalyticsLocalization.viewRiskForecast(_isTamil),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (widget.onOpenWhyThisRoute != null) ...[
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: widget.onOpenWhyThisRoute,
              style: OutlinedButton.styleFrom(
                foregroundColor: NeonTheme.neonCyan,
                side: const BorderSide(color: NeonTheme.neonCyan),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                SafetyAnalyticsLocalization.whyThisRoute(_isTamil),
                style: const TextStyle(fontSize: 10.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EMPTY STATES
  // --------------------------------------------------------------------------

  Widget _buildZeroDataEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? NeonTheme.cyanBorder : const Color(0x350284C7),
          width: 1.2,
        ),
        boxShadow: NeonTheme.cardShadow(isDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: NeonTheme.neonCyan.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: NeonTheme.neonCyan.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.analytics_rounded,
                size: 42,
                color: NeonTheme.neonCyan,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            SafetyAnalyticsLocalization.emptyStateTitle(_isTamil),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: isDark
                  ? NeonTheme.textPrimaryDark
                  : NeonTheme.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            SafetyAnalyticsLocalization.emptyStateSubtitle(_isTamil),
            style: TextStyle(
              fontSize: 12.5,
              color: isDark
                  ? NeonTheme.textSecondaryDark
                  : NeonTheme.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onPlanRoute,
            icon: const Icon(Icons.explore_rounded, size: 16),
            label: Text(
              SafetyAnalyticsLocalization.planARoute(_isTamil),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonTheme.neonCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 36,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 10),
            Text(
              SafetyAnalyticsLocalization.noRecordsForPeriod(_isTamil),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? NeonTheme.textPrimaryDark
                    : NeonTheme.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
