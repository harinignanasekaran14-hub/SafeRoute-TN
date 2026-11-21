// ============================================================================
// SafeRoute TN — Smart Route Comparison Center
// Module: lib/smart_route_comparison.dart
// Description: Deterministic, privacy-preserving route comparison dashboard
//              helping users choose between available routes using safety,
//              travel time, distance, risk and real-world evidence.
//              Strictly client-side evaluation using verified project data.
//              Zero fake traffic, weather, or safety values.
//              Zero continuous background GPS tracking.
// ============================================================================

import 'package:flutter/material.dart';

import 'main.dart';
import 'personal_safety_profile.dart';
import 'smart_route_risk_forecast.dart';

// ============================================================================
// 1. DATA MODEL
// ============================================================================

/// Represents the comparative metrics and evidence for a single evaluated route.
class SmartRouteComparison {
  final int routeIndex;
  final String routeLabel;
  final double distanceKm;
  final double durationMinutes;
  final double? safetyScore;
  final RouteRiskLevel? riskLevel;
  final double? accidentRisk;
  final double? roadCondition;
  final double? traffic;
  final double? weather;
  final double? lighting;
  final double? accessibility;
  final Map<String, bool> evidenceAvailability;
  final double? preferenceMatch;
  final bool isRecommended;
  final List<String> pros;
  final List<String> cons;
  final List<String> tamilPros;
  final List<String> tamilCons;
  final String? recommendationReason;
  final String? tamilRecommendationReason;

  const SmartRouteComparison({
    required this.routeIndex,
    required this.routeLabel,
    required this.distanceKm,
    required this.durationMinutes,
    this.safetyScore,
    this.riskLevel,
    this.accidentRisk,
    this.roadCondition,
    this.traffic,
    this.weather,
    this.lighting,
    this.accessibility,
    required this.evidenceAvailability,
    this.preferenceMatch,
    this.isRecommended = false,
    this.pros = const [],
    this.cons = const [],
    this.tamilPros = const [],
    this.tamilCons = const [],
    this.recommendationReason,
    this.tamilRecommendationReason,
  });

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  String formattedDistanceTamil() => '${distanceKm.toStringAsFixed(1)} கி.மீ';

  String get formattedEta {
    final totalMinutes = durationMinutes.round();
    if (totalMinutes < 60) {
      return '$totalMinutes m';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  String formattedEtaTamil() {
    final totalMinutes = durationMinutes.round();
    if (totalMinutes < 60) {
      return '$totalMinutes நிமி';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins > 0 ? '$hours மணி $mins நிமி' : '$hours மணி';
  }

  bool get hasSafetyScore => safetyScore != null;

  String get safetyScoreDisplay =>
      safetyScore != null ? '${safetyScore!.round()}%' : 'Unavailable';

  String safetyScoreDisplayTamil(bool isTamil) {
    if (safetyScore != null) return '${safetyScore!.round()}%';
    return isTamil ? 'கிடைக்கவில்லை' : 'Unavailable';
  }

  String factorDisplay(
    double? score, {
    bool isTraffic = false,
    bool isTamil = false,
  }) {
    if (score != null) return '${score.round()}%';
    if (isTraffic) {
      return isTamil ? 'போக்குவரத்து கிடைக்கவில்லை' : 'Traffic unavailable';
    }
    return isTamil ? 'கிடைக்கவில்லை' : 'Unavailable';
  }
}

// ============================================================================
// 2. COMPARISON ENGINE
// ============================================================================

/// Deterministic comparison engine reusing existing evaluated route data.
class SmartRouteComparisonEngine {
  /// Safely extracts a named factor score from [PersonalizedSafetyResult].
  static double? extractFactorScore(
    PersonalizedSafetyResult? safety,
    String title,
  ) {
    if (safety == null || safety.factors.isEmpty) return null;
    for (final factor in safety.factors) {
      if (factor.title == title ||
          (title == 'Accident Risk' && factor.title == 'Verified blackspots') ||
          (title == 'Verified blackspots' && factor.title == 'Accident Risk') ||
          (title == 'Road Condition' && factor.title == 'Road condition') ||
          (title == 'Road condition' && factor.title == 'Road Condition') ||
          (title == 'Traffic' && factor.title == 'Live Traffic') ||
          (title == 'Live Traffic' && factor.title == 'Traffic')) {
        return factor.score;
      }
    }
    return null;
  }

  /// Determines evidence availability map from the existing evaluation.
  static Map<String, bool> checkEvidenceAvailability(
    RouteEvaluation? evaluation,
  ) {
    final hasOsm =
        evaluation?.roadSegments != null &&
        evaluation!.roadSegments!.isNotEmpty;

    final trafficStatus = evaluation?.traffic?.status.toLowerCase() ?? '';
    final hasTraffic =
        evaluation?.traffic != null &&
        trafficStatus != 'unavailable' &&
        trafficStatus != 'traffic unavailable' &&
        trafficStatus != 'error' &&
        trafficStatus.isNotEmpty;

    final hasWeather = evaluation?.weather != null;

    final hasBlackspots =
        evaluation != null && evaluation.blackspots.unavailableReason == null;

    return {
      'osm': hasOsm,
      'traffic': hasTraffic,
      'weather': hasWeather,
      'blackspots': hasBlackspots,
    };
  }

  /// Compares evaluated routes deterministically respecting user profile.
  static List<SmartRouteComparison> compareRoutes({
    required List<RouteResult> routes,
    required Map<int, RouteEvaluation> evaluations,
    required PersonalSafetyProfile profile,
    bool isDay = true,
    int? recommendedRouteIndex,
  }) {
    if (routes.isEmpty) return const [];

    // Step 1: Build preliminary comparisons without relative trade-offs
    final preliminary = <_PreliminaryComparison>[];

    for (var i = 0; i < routes.length; i++) {
      final route = routes[i];
      final eval = evaluations[route.routeIndex];

      final distanceKm = route.distance;
      final durationMinutes = route.duration;
      final safetyScore = eval?.safety.score;

      RouteRiskLevel? riskLevel;
      if (eval != null) {
        riskLevel = SmartRiskForecastEngine.evaluate(
          evaluation: eval,
          vehicle: profile.vehicleMode,
          travelTime: null,
        ).overallLevel;
      }

      final accidentRisk = extractFactorScore(eval?.safety, 'Accident Risk');
      final roadCondition = extractFactorScore(eval?.safety, 'Road Condition');
      final traffic = extractFactorScore(eval?.safety, 'Traffic');
      final weather = extractFactorScore(eval?.safety, 'Weather');
      final lighting = extractFactorScore(eval?.safety, 'Lighting');
      final accessibility = extractFactorScore(eval?.safety, 'Accessibility');

      final evidence = checkEvidenceAvailability(eval);

      double? preferenceMatch;
      if (eval != null) {
        final matchRes = PreferenceMatchEvaluator.evaluate(
          evaluation: eval,
          profile: profile,
          isDay: isDay,
        );
        preferenceMatch = matchRes.matchPercentage;
      }

      preliminary.add(
        _PreliminaryComparison(
          routeIndex: route.routeIndex,
          routeLabel: 'Route ${i + 1}',
          distanceKm: distanceKm,
          durationMinutes: durationMinutes,
          safetyScore: safetyScore,
          riskLevel: riskLevel,
          accidentRisk: accidentRisk,
          roadCondition: roadCondition,
          traffic: traffic,
          weather: weather,
          lighting: lighting,
          accessibility: accessibility,
          evidenceAvailability: evidence,
          preferenceMatch: preferenceMatch,
        ),
      );
    }

    // Step 2: Determine recommended route based on profile priority
    final resolvedRecommendedIndex = _determineRecommendedRouteIndex(
      preliminary,
      profile,
      explicitRecommendedIndex: recommendedRouteIndex,
    );

    // Step 3: Compute data-driven Pros & Cons and AI recommendation narrative
    final results = <SmartRouteComparison>[];

    for (final p in preliminary) {
      final isRec = p.routeIndex == resolvedRecommendedIndex;
      final tradeOff = _buildTradeOffs(p, preliminary, profile);

      String? recReason;
      String? tamilRecReason;

      if (isRec) {
        recReason = _generateRecommendationNarrative(
          p,
          profile,
          isTamil: false,
        );
        tamilRecReason = _generateRecommendationNarrative(
          p,
          profile,
          isTamil: true,
        );
      }

      results.add(
        SmartRouteComparison(
          routeIndex: p.routeIndex,
          routeLabel: p.routeLabel,
          distanceKm: p.distanceKm,
          durationMinutes: p.durationMinutes,
          safetyScore: p.safetyScore,
          riskLevel: p.riskLevel,
          accidentRisk: p.accidentRisk,
          roadCondition: p.roadCondition,
          traffic: p.traffic,
          weather: p.weather,
          lighting: p.lighting,
          accessibility: p.accessibility,
          evidenceAvailability: p.evidenceAvailability,
          preferenceMatch: p.preferenceMatch,
          isRecommended: isRec,
          pros: tradeOff.pros,
          cons: tradeOff.cons,
          tamilPros: tradeOff.tamilPros,
          tamilCons: tradeOff.tamilCons,
          recommendationReason: recReason,
          tamilRecommendationReason: tamilRecReason,
        ),
      );
    }

    return results;
  }

  /// Determines the winning route index respecting the user's priority.
  static int _determineRecommendedRouteIndex(
    List<_PreliminaryComparison> items,
    PersonalSafetyProfile profile, {
    int? explicitRecommendedIndex,
  }) {
    if (items.isEmpty) return 0;

    if (explicitRecommendedIndex != null &&
        items.any((item) => item.routeIndex == explicitRecommendedIndex)) {
      return explicitRecommendedIndex;
    }

    final priority = profile.safetyPriority;

    if (priority == 'Faster Route') {
      // Primary: lowest duration; Secondary: highest safety/preference
      var best = items.first;
      for (final item in items.skip(1)) {
        if (item.durationMinutes < best.durationMinutes - 0.5) {
          best = item;
        } else if ((item.durationMinutes - best.durationMinutes).abs() <= 0.5) {
          final itemScore = item.safetyScore ?? item.preferenceMatch ?? 0;
          final bestScore = best.safetyScore ?? best.preferenceMatch ?? 0;
          if (itemScore > bestScore) {
            best = item;
          }
        }
      }
      return best.routeIndex;
    }

    if (priority == 'Safer Route') {
      // Primary: highest safety score; Secondary: preference match, then duration
      var best = items.first;
      for (final item in items.skip(1)) {
        final itemSafety = item.safetyScore;
        final bestSafety = best.safetyScore;

        if (itemSafety != null && bestSafety != null) {
          if (itemSafety > bestSafety + 1.0) {
            best = item;
          } else if ((itemSafety - bestSafety).abs() <= 1.0) {
            if (item.durationMinutes < best.durationMinutes) {
              best = item;
            }
          }
        } else if (itemSafety != null && bestSafety == null) {
          best = item;
        } else if (itemSafety == null && bestSafety == null) {
          final itemPref = item.preferenceMatch ?? 0;
          final bestPref = best.preferenceMatch ?? 0;
          if (itemPref > bestPref) {
            best = item;
          } else if (itemPref == bestPref &&
              item.durationMinutes < best.durationMinutes) {
            best = item;
          }
        }
      }
      return best.routeIndex;
    }

    // Default: 'Balanced'
    // Score based on 60% safety/preference + 40% duration score
    double minDuration = items.first.durationMinutes;
    double maxDuration = items.first.durationMinutes;
    for (final item in items) {
      if (item.durationMinutes < minDuration) {
        minDuration = item.durationMinutes;
      }
      if (item.durationMinutes > maxDuration) {
        maxDuration = item.durationMinutes;
      }
    }

    var best = items.first;
    double bestComposite = -1.0;

    for (final item in items) {
      final safeComponent = item.safetyScore ?? item.preferenceMatch ?? 50.0;

      double timeComponent = 80.0;
      if (maxDuration > minDuration) {
        final ratio =
            (item.durationMinutes - minDuration) / (maxDuration - minDuration);
        timeComponent = 100.0 - (ratio * 40.0);
      }

      final composite = (safeComponent * 0.6) + (timeComponent * 0.4);
      if (composite > bestComposite) {
        bestComposite = composite;
        best = item;
      }
    }

    return best.routeIndex;
  }

  /// Builds data-supported pros and cons by comparing against other routes.
  static _TradeOffResult _buildTradeOffs(
    _PreliminaryComparison current,
    List<_PreliminaryComparison> all,
    PersonalSafetyProfile profile,
  ) {
    final pros = <String>[];
    final cons = <String>[];
    final tamilPros = <String>[];
    final tamilCons = <String>[];

    if (all.length > 1) {
      // Find min & max durations
      final durations = all.map((e) => e.durationMinutes).toList()..sort();
      final minDuration = durations.first;
      final durationDiff = current.durationMinutes - minDuration;

      if (durationDiff <= 0.5) {
        pros.add('Fastest travel time (${current.formattedEta})');
        tamilPros.add('குறைந்த பயண நேரம் (${current.formattedEtaTamil()})');
      } else if (durationDiff >= 3.0) {
        cons.add('+${durationDiff.round()} min longer travel time');
        tamilCons.add('+${durationDiff.round()} நிமி கூடுதல் பயண நேரம்');
      }

      // Find safety comparison
      final validSafeties =
          all.map((e) => e.safetyScore).whereType<double>().toList()..sort();
      if (current.safetyScore != null && validSafeties.isNotEmpty) {
        final maxSafety = validSafeties.last;
        if (current.safetyScore! >= maxSafety - 0.5) {
          pros.add('Highest safety score (${current.safetyScore!.round()}%)');
          tamilPros.add(
            'மிக உயர்ந்த பாதுகாப்பு மதிப்பீடு (${current.safetyScore!.round()}%)',
          );
        } else if (maxSafety - current.safetyScore! >= 4.0) {
          cons.add('Lower safety score (${current.safetyScore!.round()}%)');
          tamilCons.add(
            'குறைவான பாதுகாப்பு மதிப்பீடு (${current.safetyScore!.round()}%)',
          );
        }
      }

      // Find distance comparison
      final distances = all.map((e) => e.distanceKm).toList()..sort();
      final minDistance = distances.first;
      final distDiff = current.distanceKm - minDistance;

      if (distDiff <= 0.3) {
        pros.add('Shortest distance (${current.formattedDistance})');
        tamilPros.add('குறைந்த தூரம் (${current.formattedDistanceTamil()})');
      } else if (distDiff >= 3.0) {
        cons.add('+${distDiff.toStringAsFixed(1)} km longer distance');
        tamilCons.add('+${distDiff.toStringAsFixed(1)} கி.மீ கூடுதல் தூரம்');
      }
    } else {
      // Single route
      pros.add('Primary route calculated (${current.formattedDistance})');
      tamilPros.add(
        'கணக்கிடப்பட்ட முதன்மை பாதை (${current.formattedDistanceTamil()})',
      );
    }

    // Evidence-based factors
    if (current.safetyScore == null) {
      cons.add('Safety score unavailable');
      tamilCons.add('பாதுகாப்பு மதிப்பீடு கிடைக்கவில்லை');
    }

    if (current.preferenceMatch != null && current.preferenceMatch! >= 75) {
      pros.add(
        'Matches your ${profile.vehicleMode} & ${profile.safetyPriority} preference (${current.preferenceMatch!.round()}%)',
      );
      tamilPros.add(
        'உங்கள் ${profile.vehicleMode} மற்றும் ${profile.safetyPriority} விருப்பங்களுடன் பொருந்துகிறது (${current.preferenceMatch!.round()}%)',
      );
    }

    if (current.evidenceAvailability['blackspots'] == true) {
      pros.add('Verified TN blackspot data evaluated');
      tamilPros.add(
        'சரிபார்க்கப்பட்ட விபத்துப் பகுதி தரவு மதிப்பீடு செய்யப்பட்டது',
      );
    } else {
      cons.add('Blackspot data unavailable');
      tamilCons.add('விபத்துப் பகுதி தரவு கிடைக்கவில்லை');
    }

    if (current.evidenceAvailability['traffic'] == true) {
      pros.add('Live traffic data active');
      tamilPros.add('நேரலை போக்குவரத்து தரவு இணைக்கப்பட்டுள்ளது');
    } else {
      cons.add('Live traffic unavailable');
      tamilCons.add('நேரலை போக்குவரத்து கிடைக்கவில்லை');
    }

    return _TradeOffResult(
      pros: pros,
      cons: cons,
      tamilPros: tamilPros,
      tamilCons: tamilCons,
    );
  }

  /// Generates cautious, data-grounded AI recommendation narrative.
  static String _generateRecommendationNarrative(
    _PreliminaryComparison rec,
    PersonalSafetyProfile profile, {
    required bool isTamil,
  }) {
    if (!isTamil) {
      final buffer = StringBuffer('Based on available data, ');
      buffer.write('${rec.routeLabel} is recommended ');

      if (profile.safetyPriority == 'Faster Route') {
        buffer.write(
          'because it provides the lowest travel time (${rec.formattedEta}) among available routes',
        );
        if (rec.safetyScore != null) {
          buffer.write(
            ' while maintaining a safety score of ${rec.safetyScore!.round()}%.',
          );
        } else {
          buffer.write('.');
        }
      } else if (profile.safetyPriority == 'Safer Route') {
        if (rec.safetyScore != null) {
          buffer.write(
            'because it provides the strongest available safety score (${rec.safetyScore!.round()}%) while keeping travel time reasonable (${rec.formattedEta}).',
          );
        } else {
          buffer.write(
            'because it aligns best with your safety preferences based on available road attributes.',
          );
        }
      } else {
        // Balanced
        if (rec.safetyScore != null) {
          buffer.write(
            'because it balances verified route safety (${rec.safetyScore!.round()}%) with an estimated duration of ${rec.formattedEta}.',
          );
        } else {
          buffer.write(
            'because it offers a balanced alternative for travel time (${rec.formattedEta}) based on available evidence.',
          );
        }
      }
      return buffer.toString();
    } else {
      final buffer = StringBuffer('கிடைக்கக்கூடிய தரவுகளின் அடிப்படையில், ');
      buffer.write('${rec.routeLabel} பரிந்துரைக்கப்படுகிறது. ');

      if (profile.safetyPriority == 'Faster Route') {
        buffer.write(
          'இது கிடைக்கக்கூடிய வழிகளில் குறைந்த பயண நேரத்தை (${rec.formattedEtaTamil()}) வழங்குகிறது.',
        );
      } else if (profile.safetyPriority == 'Safer Route') {
        if (rec.safetyScore != null) {
          buffer.write(
            'இது பயண நேரத்தை (${rec.formattedEtaTamil()}) மிதமாக வைத்துக்கொண்டு சிறந்த பாதுகாப்பு மதிப்பீட்டை (${rec.safetyScore!.round()}%) வழங்குகிறது.',
          );
        } else {
          buffer.write(
            'இது கிடைக்கக்கூடிய சாலை பண்புகளின் அடிப்படையில் உங்கள் பாதுகாப்பு விருப்பங்களுடன் ஒத்துப்போகிறது.',
          );
        }
      } else {
        if (rec.safetyScore != null) {
          buffer.write(
            'இது சரிபார்க்கப்பட்ட பாதுகாப்பு (${rec.safetyScore!.round()}%) மற்றும் பயண நேரம் (${rec.formattedEtaTamil()}) இரண்டையும் சமநிலைப்படுத்துகிறது.',
          );
        } else {
          buffer.write(
            'இது கிடைக்கக்கூடிய சான்றுகளின் அடிப்படையில் சமநிலையான பயண நேரத்தை (${rec.formattedEtaTamil()}) வழங்குகிறது.',
          );
        }
      }
      return buffer.toString();
    }
  }
}

class _PreliminaryComparison {
  final int routeIndex;
  final String routeLabel;
  final double distanceKm;
  final double durationMinutes;
  final double? safetyScore;
  final RouteRiskLevel? riskLevel;
  final double? accidentRisk;
  final double? roadCondition;
  final double? traffic;
  final double? weather;
  final double? lighting;
  final double? accessibility;
  final Map<String, bool> evidenceAvailability;
  final double? preferenceMatch;

  const _PreliminaryComparison({
    required this.routeIndex,
    required this.routeLabel,
    required this.distanceKm,
    required this.durationMinutes,
    this.safetyScore,
    this.riskLevel,
    this.accidentRisk,
    this.roadCondition,
    this.traffic,
    this.weather,
    this.lighting,
    this.accessibility,
    required this.evidenceAvailability,
    this.preferenceMatch,
  });

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';
  String formattedDistanceTamil() => '${distanceKm.toStringAsFixed(1)} கி.மீ';

  String get formattedEta {
    final totalMinutes = durationMinutes.round();
    if (totalMinutes < 60) return '$totalMinutes m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  String formattedEtaTamil() {
    final totalMinutes = durationMinutes.round();
    if (totalMinutes < 60) return '$totalMinutes நிமி';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins > 0 ? '$hours மணி $mins நிமி' : '$hours மணி';
  }
}

class _TradeOffResult {
  final List<String> pros;
  final List<String> cons;
  final List<String> tamilPros;
  final List<String> tamilCons;

  const _TradeOffResult({
    required this.pros,
    required this.cons,
    required this.tamilPros,
    required this.tamilCons,
  });
}

// ============================================================================
// 3. LOCALIZATION STRINGS
// ============================================================================

class SmartRouteComparisonLocalization {
  static String title(bool isTamil) =>
      isTamil ? 'ஸ்மார்ட் பாதை ஒப்பீடு' : 'Smart Route Comparison';

  static String subtitle(bool isTamil) => isTamil
      ? 'பாதுகாப்பு, நேரம் மற்றும் உண்மையான தரவுகளின் அடிப்படையில் வழிகளை ஒப்பிடுங்கள்.'
      : 'Compare routes using safety, time and real-world evidence.';

  static String aiRecommendation(bool isTamil) =>
      isTamil ? 'AI பாதை பரிந்துரை' : 'AI Route Recommendation';

  static String safetyVsTime(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு ↔ நேரம்' : 'SAFETY ↔ TIME';

  static String dataEvidence(bool isTamil) =>
      isTamil ? 'தரவு சான்றுகள்' : 'Data Evidence';

  static String recommendedBadge(bool isTamil) =>
      isTamil ? 'பரிந்துரைக்கப்பட்டது' : 'RECOMMENDED';

  static String activeRouteBadge(bool isTamil) =>
      isTamil ? 'செயலில் உள்ள பாதை' : 'ACTIVE ROUTE';

  static String bestMatch(bool isTamil) =>
      isTamil ? 'சிறந்த பொருத்தம்' : 'BEST MATCH';

  static String chooseRoute(bool isTamil) =>
      isTamil ? 'இந்த வழியைத் தேர்ந்தெடு' : 'Choose Route';

  static String selectedRoute(bool isTamil) =>
      isTamil ? 'தேர்ந்தெடுக்கப்பட்டது' : 'Selected Route';

  static String whyThisRoute(bool isTamil) =>
      isTamil ? 'இந்த வழி ஏன்?' : 'Why this route?';

  static String whyMatchesYou(bool isTamil) => isTamil
      ? 'இது ஏன் உங்களுக்கு பொருந்துகிறது?'
      : 'Why this route matches you';

  static String preferenceMatch(bool isTamil) =>
      isTamil ? 'உங்கள் விருப்ப பொருத்தம்' : 'Your Preference Match';

  static String distance(bool isTamil) => isTamil ? 'தூரம்' : 'Distance';

  static String eta(bool isTamil) => isTamil ? 'பயண நேரம்' : 'ETA';

  static String safetyScore(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு' : 'Safety Score';

  static String riskLevel(bool isTamil) =>
      isTamil ? 'ஆபத்து நிலை' : 'Risk Level';

  static String accidentRisk(bool isTamil) =>
      isTamil ? 'விபத்து ஆபத்து' : 'Accident Risk';

  static String roadCondition(bool isTamil) =>
      isTamil ? 'சாலை நிலை' : 'Road Condition';

  static String traffic(bool isTamil) => isTamil ? 'போக்குவரத்து' : 'Traffic';

  static String weather(bool isTamil) => isTamil ? 'வானிலை' : 'Weather';

  static String lighting(bool isTamil) => isTamil ? 'வெளிச்சம்' : 'Lighting';

  static String accessibility(bool isTamil) =>
      isTamil ? 'அணுகல்தன்மை' : 'Accessibility';

  static String unavailable(bool isTamil) =>
      isTamil ? 'கிடைக்கவில்லை' : 'Unavailable';

  static String trafficUnavailable(bool isTamil) =>
      isTamil ? 'போக்குவரத்து கிடைக்கவில்லை' : 'Traffic unavailable';

  static String faster(bool isTamil) => isTamil ? 'விரைவானது' : 'Faster';

  static String safer(bool isTamil) => isTamil ? 'பாதுகாப்பானது' : 'Safer';

  static String noRoutesTitle(bool isTamil) => isTamil
      ? 'ஒப்பிடுவதற்கு பாதைகள் இல்லை'
      : 'No Routes Available to Compare';

  static String noRoutesDesc(bool isTamil) => isTamil
      ? 'பாதைகளை ஒப்பிடுவதற்கு தயவுசெய்து தொடக்க மற்றும் சேருமிடத்தை உள்ளிட்டு பாதையை கணக்கிடுங்கள்.'
      : 'Please enter starting point and destination in Route Planner to calculate and compare alternative routes.';

  static String planRouteBtn(bool isTamil) =>
      isTamil ? 'பாதை திட்டமிடு' : 'Plan a Route';

  static String singleRouteNotice(bool isTamil) => isTamil
      ? 'ஒரே ஒரு பாதை மட்டுமே உள்ளது. OSRM மாற்று பாதைகளை வழங்கும் போது ஒப்பிட்டுப் பார்க்கலாம்.'
      : 'Only 1 route available. Compare alternative routes when OSRM provides alternative paths.';

  static String privacyNotice(bool isTamil) => isTamil
      ? '🔒 தனியுரிமை உத்தரவாதம்: நேரலை GPS கண்காணிப்பு இல்லை • இருப்பிட வரலாறு சேமிக்கப்படவில்லை • அமர்வு தரவு மட்டுமே பயன்படுத்தப்படுகிறது.'
      : '🔒 Privacy Notice: No continuous GPS tracking • Zero location history • Strictly uses current session route evidence.';
}

// ============================================================================
// 4. MAIN COMPARISON VIEW WIDGET
// ============================================================================

/// Responsive and bilingual Smart Route Comparison Center View.
class SmartRouteComparisonView extends StatelessWidget {
  final bool isDarkMode;
  final bool isTamil;
  final List<RouteResult> routes;
  final Map<int, RouteEvaluation> evaluations;
  final PersonalSafetyProfile profile;
  final int selectedRouteIndex;
  final int? recommendedRouteIndex;
  final bool isDay;
  final ValueChanged<int>? onSelectRoute;
  final ValueChanged<int>? onWhyThisRoute;
  final ValueChanged<int>? onWhyThisRouteMatches;
  final VoidCallback? onPlanRoute;

  const SmartRouteComparisonView({
    super.key,
    required this.isDarkMode,
    this.isTamil = false,
    required this.routes,
    required this.evaluations,
    required this.profile,
    this.selectedRouteIndex = 0,
    this.recommendedRouteIndex,
    this.isDay = true,
    this.onSelectRoute,
    this.onWhyThisRoute,
    this.onWhyThisRouteMatches,
    this.onPlanRoute,
  });

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return _buildNoRoutesPlaceholder(context);
    }

    final comparisons = SmartRouteComparisonEngine.compareRoutes(
      routes: routes,
      evaluations: evaluations,
      profile: profile,
      isDay: isDay,
      recommendedRouteIndex: recommendedRouteIndex,
    );

    return Container(
      color: isDarkMode ? NeonTheme.bgDark : NeonTheme.bgLight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildAiRecommendationBanner(context, comparisons),
                const SizedBox(height: 16),
                _buildSafetyVsTimeTradeOffSection(context, comparisons),
                const SizedBox(height: 20),
                if (routes.length == 1) ...[
                  _buildSingleRouteNotice(context),
                  const SizedBox(height: 16),
                ],
                _buildResponsiveComparisonSection(context, comparisons),
                const SizedBox(height: 24),
                _buildDataEvidenceSection(context, comparisons),
                const SizedBox(height: 20),
                _buildPrivacyNotice(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HEADER
  // --------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode ? NeonTheme.cyanBorder : const Color(0x330284C7),
          width: 1.2,
        ),
        boxShadow: NeonTheme.cardShadow(isDarkMode),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NeonTheme.neonCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: NeonTheme.neonCyan.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: const Icon(
              Icons.compare_arrows_rounded,
              color: NeonTheme.neonCyan,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SmartRouteComparisonLocalization.title(isTamil),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: isDarkMode
                        ? NeonTheme.textPrimaryDark
                        : NeonTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SmartRouteComparisonLocalization.subtitle(isTamil),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (routes.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: NeonTheme.electricBlue.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: NeonTheme.electricBlue.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Text(
                isTamil ? '${routes.length} வழிகள்' : '${routes.length} Routes',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: NeonTheme.neonCyan,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // AI ROUTE RECOMMENDATION BANNER
  // --------------------------------------------------------------------------

  Widget _buildAiRecommendationBanner(
    BuildContext context,
    List<SmartRouteComparison> comparisons,
  ) {
    final rec = comparisons.firstWhere(
      (c) => c.isRecommended,
      orElse: () => comparisons.first,
    );

    final narrative = isTamil
        ? (rec.tamilRecommendationReason ??
              SmartRouteComparisonEngine._generateRecommendationNarrative(
                _PreliminaryComparison(
                  routeIndex: rec.routeIndex,
                  routeLabel: rec.routeLabel,
                  distanceKm: rec.distanceKm,
                  durationMinutes: rec.durationMinutes,
                  safetyScore: rec.safetyScore,
                  riskLevel: rec.riskLevel,
                  evidenceAvailability: rec.evidenceAvailability,
                  preferenceMatch: rec.preferenceMatch,
                ),
                profile,
                isTamil: true,
              ))
        : (rec.recommendationReason ??
              SmartRouteComparisonEngine._generateRecommendationNarrative(
                _PreliminaryComparison(
                  routeIndex: rec.routeIndex,
                  routeLabel: rec.routeLabel,
                  distanceKm: rec.distanceKm,
                  durationMinutes: rec.durationMinutes,
                  safetyScore: rec.safetyScore,
                  riskLevel: rec.riskLevel,
                  evidenceAvailability: rec.evidenceAvailability,
                  preferenceMatch: rec.preferenceMatch,
                ),
                profile,
                isTamil: false,
              ));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NeonTheme.safeGreen.withValues(alpha: isDarkMode ? 0.14 : 0.08),
            NeonTheme.neonCyan.withValues(alpha: isDarkMode ? 0.08 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NeonTheme.safeGreen.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: NeonTheme.safeGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  SmartRouteComparisonLocalization.aiRecommendation(isTamil),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: NeonTheme.safeGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: NeonTheme.safeGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rec.routeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: NeonTheme.safeGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            narrative,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? NeonTheme.textPrimaryDark
                  : NeonTheme.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SAFETY VS TIME TRADE-OFF SECTION
  // --------------------------------------------------------------------------

  Widget _buildSafetyVsTimeTradeOffSection(
    BuildContext context,
    List<SmartRouteComparison> comparisons,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? NeonTheme.cyanBorder : const Color(0x330284C7),
          width: 1.0,
        ),
        boxShadow: NeonTheme.cardShadow(isDarkMode),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: NeonTheme.neonAmber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                SmartRouteComparisonLocalization.safetyVsTime(isTamil),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: NeonTheme.neonAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 720 && comparisons.length > 1) {
                // Multi-column trade-off row
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < comparisons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _buildTradeOffCard(context, comparisons[i]),
                      ),
                    ],
                  ],
                );
              }
              // Stacked trade-off list
              return Column(
                children: [
                  for (final item in comparisons) ...[
                    _buildTradeOffCard(context, item),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTradeOffCard(BuildContext context, SmartRouteComparison comp) {
    final pros = isTamil ? comp.tamilPros : comp.pros;
    final cons = isTamil ? comp.tamilCons : comp.cons;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode
            ? NeonTheme.cardElevatedDark
            : NeonTheme.cardElevatedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: comp.isRecommended
              ? NeonTheme.safeGreen.withValues(alpha: 0.45)
              : (isDarkMode
                    ? const Color(0x2238BDF8)
                    : const Color(0x220284C7)),
          width: comp.isRecommended ? 1.4 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                comp.routeLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: comp.isRecommended
                      ? NeonTheme.safeGreen
                      : (isDarkMode
                            ? NeonTheme.textPrimaryDark
                            : NeonTheme.textPrimaryLight),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '${comp.formattedEta} • ${comp.formattedDistance}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final pro in pros)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '+ ',
                    style: TextStyle(
                      color: NeonTheme.safeGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      pro,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: isDarkMode
                            ? NeonTheme.textPrimaryDark
                            : NeonTheme.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final con in cons)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '- ',
                    style: TextStyle(
                      color: NeonTheme.neonAmber,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      con,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: isDarkMode
                            ? NeonTheme.textSecondaryDark
                            : NeonTheme.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RESPONSIVE COMPARISON SECTION (DESKTOP / TABLET / MOBILE)
  // --------------------------------------------------------------------------

  Widget _buildResponsiveComparisonSection(
    BuildContext context,
    List<SmartRouteComparison> comparisons,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900 && comparisons.length > 1) {
          // Desktop side-by-side comparison table
          return _buildDesktopSideBySideComparison(context, comparisons);
        }
        if (constraints.maxWidth >= 600 && comparisons.length > 1) {
          // Tablet 2-column or horizontal scroll layout
          return _buildTabletComparison(context, comparisons);
        }
        // Mobile layout: vertically stacked cards
        return _buildMobileComparison(context, comparisons);
      },
    );
  }

  // --------------------------------------------------------------------------
  // DESKTOP SIDE-BY-SIDE COMPARISON
  // --------------------------------------------------------------------------

  Widget _buildDesktopSideBySideComparison(
    BuildContext context,
    List<SmartRouteComparison> comparisons,
  ) {
    // Determine winning metric values for highlighting
    final minDistance = comparisons
        .map((c) => c.distanceKm)
        .reduce((a, b) => a < b ? a : b);
    final minDuration = comparisons
        .map((c) => c.durationMinutes)
        .reduce((a, b) => a < b ? a : b);

    final validSafeties = comparisons
        .map((c) => c.safetyScore)
        .whereType<double>()
        .toList();
    final maxSafety = validSafeties.isNotEmpty
        ? validSafeties.reduce((a, b) => a > b ? a : b)
        : null;

    final validPrefs = comparisons
        .map((c) => c.preferenceMatch)
        .whereType<double>()
        .toList();
    final maxPref = validPrefs.isNotEmpty
        ? validPrefs.reduce((a, b) => a > b ? a : b)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode ? NeonTheme.cyanBorder : const Color(0x330284C7),
          width: 1.2,
        ),
        boxShadow: NeonTheme.cardShadow(isDarkMode),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Header Row: Route Labels, Recommended Badges, Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: isDarkMode
                  ? NeonTheme.cardElevatedDark
                  : NeonTheme.cardElevatedLight,
              child: Row(
                children: [
                  const SizedBox(
                    width: 180,
                    child: Text(
                      'METRICS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: NeonTheme.neonCyan,
                      ),
                    ),
                  ),
                  for (final comp in comparisons)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildRouteHeaderCell(context, comp),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0x2238BDF8)),
            // Metric Rows
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.distance(isTamil),
              icon: Icons.straighten_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) {
                final isWinner =
                    comparisons.length > 1 &&
                    comp.distanceKm <= minDistance + 0.05;
                return _buildValueCell(
                  value: comp.formattedDistance,
                  isWinner: isWinner,
                  winnerLabel: isWinner
                      ? (isTamil ? 'குறைந்தது' : 'Shortest')
                      : null,
                );
              },
            ),
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.eta(isTamil),
              icon: Icons.timer_outlined,
              comparisons: comparisons,
              cellBuilder: (comp) {
                final isWinner =
                    comparisons.length > 1 &&
                    comp.durationMinutes <= minDuration + 0.5;
                return _buildValueCell(
                  value: comp.formattedEta,
                  isWinner: isWinner,
                  winnerLabel: isWinner
                      ? SmartRouteComparisonLocalization.faster(isTamil)
                      : null,
                );
              },
            ),
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.safetyScore(isTamil),
              icon: Icons.shield_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) {
                final isWinner =
                    comp.safetyScore != null &&
                    maxSafety != null &&
                    comp.safetyScore! >= maxSafety - 0.5 &&
                    comparisons.length > 1;
                return _buildValueCell(
                  value: comp.safetyScoreDisplayTamil(isTamil),
                  isWinner: isWinner,
                  winnerLabel: isWinner
                      ? SmartRouteComparisonLocalization.safer(isTamil)
                      : null,
                  isAvailable: comp.safetyScore != null,
                );
              },
            ),
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.riskLevel(isTamil),
              icon: Icons.warning_amber_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) {
                if (comp.riskLevel == null) {
                  return _buildValueCell(
                    value: SmartRouteComparisonLocalization.unavailable(
                      isTamil,
                    ),
                    isAvailable: false,
                  );
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: comp.riskLevel!.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: comp.riskLevel!.color.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      comp.riskLevel!.title(isTamil),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: comp.riskLevel!.color,
                      ),
                    ),
                  ),
                );
              },
            ),
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.preferenceMatch(isTamil),
              icon: Icons.tune_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) {
                final isWinner =
                    comp.preferenceMatch != null &&
                    maxPref != null &&
                    comp.preferenceMatch! >= maxPref - 0.5 &&
                    comparisons.length > 1;
                return _buildValueCell(
                  value: comp.preferenceMatch != null
                      ? '${comp.preferenceMatch!.round()}%'
                      : SmartRouteComparisonLocalization.unavailable(isTamil),
                  isWinner: isWinner,
                  winnerLabel: isWinner
                      ? SmartRouteComparisonLocalization.bestMatch(isTamil)
                      : null,
                  isAvailable: comp.preferenceMatch != null,
                );
              },
            ),
            // Factors
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.accidentRisk(isTamil),
              icon: Icons.gavel_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) => _buildValueCell(
                value: comp.factorDisplay(comp.accidentRisk, isTamil: isTamil),
                isAvailable: comp.accidentRisk != null,
              ),
            ),
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.roadCondition(isTamil),
              icon: Icons.add_road_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) => _buildValueCell(
                value: comp.factorDisplay(comp.roadCondition, isTamil: isTamil),
                isAvailable: comp.roadCondition != null,
              ),
            ),
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.traffic(isTamil),
              icon: Icons.traffic_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) => _buildValueCell(
                value: comp.factorDisplay(
                  comp.traffic,
                  isTraffic: true,
                  isTamil: isTamil,
                ),
                isAvailable: comp.traffic != null,
              ),
            ),
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.weather(isTamil),
              icon: Icons.cloud_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) => _buildValueCell(
                value: comp.factorDisplay(comp.weather, isTamil: isTamil),
                isAvailable: comp.weather != null,
              ),
            ),
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.lighting(isTamil),
              icon: Icons.lightbulb_outline_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) => _buildValueCell(
                value: comp.factorDisplay(comp.lighting, isTamil: isTamil),
                isAvailable: comp.lighting != null,
              ),
            ),
            _buildComparisonRow(
              title: SmartRouteComparisonLocalization.accessibility(isTamil),
              icon: Icons.accessible_rounded,
              comparisons: comparisons,
              cellBuilder: (comp) => _buildValueCell(
                value: comp.factorDisplay(comp.accessibility, isTamil: isTamil),
                isAvailable: comp.accessibility != null,
              ),
            ),
            // Action Buttons Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: isDarkMode
                  ? NeonTheme.cardElevatedDark
                  : NeonTheme.cardElevatedLight,
              child: Row(
                children: [
                  const SizedBox(width: 180),
                  for (final comp in comparisons)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildRouteActionButtons(context, comp),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteHeaderCell(
    BuildContext context,
    SmartRouteComparison comp,
  ) {
    final isSelected = comp.routeIndex == selectedRouteIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              comp.routeLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDarkMode
                    ? NeonTheme.textPrimaryDark
                    : NeonTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(width: 6),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: NeonTheme.neonCyan.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  SmartRouteComparisonLocalization.activeRouteBadge(isTamil),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: NeonTheme.neonCyan,
                  ),
                ),
              ),
          ],
        ),
        if (comp.isRecommended) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: NeonTheme.safeGreen.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: NeonTheme.safeGreen.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Text(
              SmartRouteComparisonLocalization.recommendedBadge(isTamil),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: NeonTheme.safeGreen,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildComparisonRow({
    required String title,
    required IconData icon,
    required List<SmartRouteComparison> comparisons,
    required Widget Function(SmartRouteComparison comp) cellBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1538BDF8))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isDarkMode
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? NeonTheme.textSecondaryDark
                          : NeonTheme.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final comp in comparisons)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cellBuilder(comp),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildValueCell({
    required String value,
    bool isWinner = false,
    String? winnerLabel,
    bool isAvailable = true,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isWinner ? FontWeight.w900 : FontWeight.w600,
            color: isAvailable
                ? (isWinner
                      ? NeonTheme.safeGreen
                      : (isDarkMode
                            ? NeonTheme.textPrimaryDark
                            : NeonTheme.textPrimaryLight))
                : (isDarkMode
                      ? NeonTheme.textSecondaryDark.withValues(alpha: 0.7)
                      : NeonTheme.textSecondaryLight.withValues(alpha: 0.7)),
          ),
        ),
        if (isWinner && winnerLabel != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: NeonTheme.safeGreen.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              winnerLabel,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: NeonTheme.safeGreen,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRouteActionButtons(
    BuildContext context,
    SmartRouteComparison comp,
  ) {
    final isSelected = comp.routeIndex == selectedRouteIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? NeonTheme.neonCyan.withValues(alpha: 0.25)
                : NeonTheme.neonCyan,
            foregroundColor: isSelected ? NeonTheme.neonCyan : Colors.black,
            elevation: isSelected ? 0 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: isSelected
                  ? const BorderSide(color: NeonTheme.neonCyan, width: 1.2)
                  : BorderSide.none,
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: () => onSelectRoute?.call(comp.routeIndex),
          child: Text(
            isSelected
                ? SmartRouteComparisonLocalization.selectedRoute(isTamil)
                : SmartRouteComparisonLocalization.chooseRoute(isTamil),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: NeonTheme.neonCyan,
                  side: const BorderSide(color: Color(0x4038BDF8), width: 0.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                onPressed: () => onWhyThisRoute?.call(comp.routeIndex),
                child: Text(
                  SmartRouteComparisonLocalization.whyThisRoute(isTamil),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => onWhyThisRouteMatches?.call(comp.routeIndex),
          child: Text(
            SmartRouteComparisonLocalization.whyMatchesYou(isTamil),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode
                  ? NeonTheme.textSecondaryDark
                  : NeonTheme.textSecondaryLight,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // TABLET COMPARISON
  // --------------------------------------------------------------------------

  Widget _buildTabletComparison(
    BuildContext context,
    List<SmartRouteComparison> comparisons,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < comparisons.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: _buildRouteCard(context, comparisons[i])),
        ],
      ],
    );
  }

  // --------------------------------------------------------------------------
  // MOBILE COMPARISON
  // --------------------------------------------------------------------------

  Widget _buildMobileComparison(
    BuildContext context,
    List<SmartRouteComparison> comparisons,
  ) {
    return Column(
      children: [
        for (final comp in comparisons) ...[
          _buildRouteCard(context, comp),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // --------------------------------------------------------------------------
  // INDIVIDUAL ROUTE CARD (Used in Tablet & Mobile, or as Standalone Card)
  // --------------------------------------------------------------------------

  Widget _buildRouteCard(BuildContext context, SmartRouteComparison comp) {
    final isSelected = comp.routeIndex == selectedRouteIndex;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? NeonTheme.neonCyan
              : (comp.isRecommended
                    ? NeonTheme.safeGreen.withValues(alpha: 0.5)
                    : (isDarkMode
                          ? NeonTheme.cyanBorder
                          : const Color(0x330284C7))),
          width: isSelected ? 1.8 : (comp.isRecommended ? 1.4 : 1.0),
        ),
        boxShadow: isSelected
            ? NeonTheme.cyanGlow(12)
            : NeonTheme.cardShadow(isDarkMode),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Route name, badges
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    comp.routeLabel,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isDarkMode
                          ? NeonTheme.textPrimaryDark
                          : NeonTheme.textPrimaryLight,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: NeonTheme.neonCyan.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        SmartRouteComparisonLocalization.activeRouteBadge(
                          isTamil,
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: NeonTheme.neonCyan,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (comp.isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: NeonTheme.safeGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: NeonTheme.safeGreen.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    SmartRouteComparisonLocalization.recommendedBadge(isTamil),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: NeonTheme.safeGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Key Summary Metrics in 4-box grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: SmartRouteComparisonLocalization.distance(isTamil),
                  value: comp.formattedDistance,
                  icon: Icons.straighten_rounded,
                  color: NeonTheme.neonCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: SmartRouteComparisonLocalization.eta(isTamil),
                  value: comp.formattedEta,
                  icon: Icons.timer_outlined,
                  color: NeonTheme.electricBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: SmartRouteComparisonLocalization.safetyScore(isTamil),
                  value: comp.safetyScoreDisplayTamil(isTamil),
                  icon: Icons.shield_rounded,
                  color: NeonTheme.safeGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: SmartRouteComparisonLocalization.riskLevel(isTamil),
                  value:
                      comp.riskLevel?.title(isTamil) ??
                      SmartRouteComparisonLocalization.unavailable(isTamil),
                  icon: Icons.warning_amber_rounded,
                  color:
                      comp.riskLevel?.color ??
                      (isDarkMode
                          ? NeonTheme.textSecondaryDark
                          : NeonTheme.textSecondaryLight),
                ),
              ),
            ],
          ),
          if (comp.preferenceMatch != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NeonTheme.neonViolet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: NeonTheme.neonViolet.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: NeonTheme.neonViolet,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text:
                            '${SmartRouteComparisonLocalization.preferenceMatch(isTamil)}: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? NeonTheme.textSecondaryDark
                              : NeonTheme.textSecondaryLight,
                        ),
                        children: [
                          TextSpan(
                            text: '${comp.preferenceMatch!.round()}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: NeonTheme.neonViolet,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Compact Factor Rows
          _buildCompactFactorRow(
            SmartRouteComparisonLocalization.accidentRisk(isTamil),
            comp.factorDisplay(comp.accidentRisk, isTamil: isTamil),
            comp.accidentRisk != null,
          ),
          _buildCompactFactorRow(
            SmartRouteComparisonLocalization.roadCondition(isTamil),
            comp.factorDisplay(comp.roadCondition, isTamil: isTamil),
            comp.roadCondition != null,
          ),
          _buildCompactFactorRow(
            SmartRouteComparisonLocalization.traffic(isTamil),
            comp.factorDisplay(comp.traffic, isTraffic: true, isTamil: isTamil),
            comp.traffic != null,
          ),
          _buildCompactFactorRow(
            SmartRouteComparisonLocalization.weather(isTamil),
            comp.factorDisplay(comp.weather, isTamil: isTamil),
            comp.weather != null,
          ),
          _buildCompactFactorRow(
            SmartRouteComparisonLocalization.lighting(isTamil),
            comp.factorDisplay(comp.lighting, isTamil: isTamil),
            comp.lighting != null,
          ),
          _buildCompactFactorRow(
            SmartRouteComparisonLocalization.accessibility(isTamil),
            comp.factorDisplay(comp.accessibility, isTamil: isTamil),
            comp.accessibility != null,
          ),
          const SizedBox(height: 16),
          // Actions
          _buildRouteActionButtons(context, comp),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? NeonTheme.cardElevatedDark
            : NeonTheme.cardElevatedLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDarkMode
                  ? NeonTheme.textPrimaryDark
                  : NeonTheme.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFactorRow(String label, String value, bool isAvailable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isAvailable
                  ? (isDarkMode
                        ? NeonTheme.textPrimaryDark
                        : NeonTheme.textPrimaryLight)
                  : (isDarkMode
                        ? NeonTheme.textSecondaryDark.withValues(alpha: 0.6)
                        : NeonTheme.textSecondaryLight.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EVIDENCE TRANSPARENCY SECTION
  // --------------------------------------------------------------------------

  Widget _buildDataEvidenceSection(
    BuildContext context,
    List<SmartRouteComparison> comparisons,
  ) {
    // Check aggregated evidence across evaluated routes
    final hasOsm = comparisons.any(
      (c) => c.evidenceAvailability['osm'] == true,
    );
    final hasTraffic = comparisons.any(
      (c) => c.evidenceAvailability['traffic'] == true,
    );
    final hasWeather = comparisons.any(
      (c) => c.evidenceAvailability['weather'] == true,
    );
    final hasBlackspots = comparisons.any(
      (c) => c.evidenceAvailability['blackspots'] == true,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? NeonTheme.cyanBorder : const Color(0x330284C7),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_rounded,
                color: NeonTheme.neonCyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                SmartRouteComparisonLocalization.dataEvidence(isTamil),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: NeonTheme.neonCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildEvidenceSourcePill(
                source: 'OSM road data',
                tamilSource: 'OSM சாலை தரவு',
                available: hasOsm,
              ),
              _buildEvidenceSourcePill(
                source: 'TomTom traffic',
                tamilSource: 'TomTom போக்குவரத்து',
                available: hasTraffic,
                unavailableOverride:
                    SmartRouteComparisonLocalization.trafficUnavailable(
                      isTamil,
                    ),
              ),
              _buildEvidenceSourcePill(
                source: 'Open-Meteo weather',
                tamilSource: 'Open-Meteo வானிலை',
                available: hasWeather,
              ),
              _buildEvidenceSourcePill(
                source: 'Verified Tamil Nadu blackspots',
                tamilSource: 'தமிழ்நாடு விபத்துப் பகுதிகள்',
                available: hasBlackspots,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSourcePill({
    required String source,
    required String tamilSource,
    required bool available,
    String? unavailableOverride,
  }) {
    final displayName = isTamil ? tamilSource : source;
    final statusText = available
        ? (isTamil ? 'கிடைக்கிறது' : 'Available')
        : (unavailableOverride ??
              (isTamil ? 'தரவு கிடைக்கவில்லை' : 'Data unavailable'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: available
            ? NeonTheme.safeGreen.withValues(alpha: 0.12)
            : (isDarkMode ? const Color(0x18F43F5E) : const Color(0x10F43F5E)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: available
              ? NeonTheme.safeGreen.withValues(alpha: 0.4)
              : const Color(0x33F43F5E),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 14,
            color: available ? NeonTheme.safeGreen : NeonTheme.dangerRed,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: '$displayName: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? NeonTheme.textPrimaryDark
                      : NeonTheme.textPrimaryLight,
                ),
                children: [
                  TextSpan(
                    text: statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: available
                          ? NeonTheme.safeGreen
                          : NeonTheme.dangerRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SINGLE ROUTE & PRIVACY NOTICES
  // --------------------------------------------------------------------------

  Widget _buildSingleRouteNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NeonTheme.neonAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: NeonTheme.neonAmber.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: NeonTheme.neonAmber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              SmartRouteComparisonLocalization.singleRouteNotice(isTamil),
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode
                    ? NeonTheme.textPrimaryDark
                    : NeonTheme.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice(BuildContext context) {
    return Text(
      SmartRouteComparisonLocalization.privacyNotice(isTamil),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        color: isDarkMode
            ? NeonTheme.textSecondaryDark.withValues(alpha: 0.8)
            : NeonTheme.textSecondaryLight.withValues(alpha: 0.8),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EMPTY STATE
  // --------------------------------------------------------------------------

  Widget _buildNoRoutesPlaceholder(BuildContext context) {
    return Container(
      color: isDarkMode ? NeonTheme.bgDark : NeonTheme.bgLight,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDarkMode ? NeonTheme.cardDark : NeonTheme.cardLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkMode ? NeonTheme.cyanBorder : const Color(0x330284C7),
            width: 1.2,
          ),
          boxShadow: NeonTheme.cardShadow(isDarkMode),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NeonTheme.neonCyan.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                size: 40,
                color: NeonTheme.neonCyan,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              SmartRouteComparisonLocalization.noRoutesTitle(isTamil),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDarkMode
                    ? NeonTheme.textPrimaryDark
                    : NeonTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              SmartRouteComparisonLocalization.noRoutesDesc(isTamil),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDarkMode
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: NeonTheme.neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onPlanRoute,
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: Text(
                SmartRouteComparisonLocalization.planRouteBtn(isTamil),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
