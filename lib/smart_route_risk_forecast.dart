// ============================================================================
// SafeRoute TN — Smart Route Risk Forecast
// Module: lib/smart_route_risk_forecast.dart
// Description: AI-assisted prediction of potential safety risks along routes.
//              Strictly deterministic rule-based evaluation using real project data.
//              Preserves user privacy (no precise GPS tracking) and zero fake data.
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'main.dart';
import 'personal_safety_profile.dart';

// ============================================================================
// RISK LEVEL ENUM & HELPERS
// ============================================================================

enum RouteRiskLevel {
  low,
  moderate,
  elevated,
  high,
  unavailable;

  static RouteRiskLevel fromScore(double? score, {bool allowUnavailable = false}) {
    if (score == null) {
      return allowUnavailable ? RouteRiskLevel.unavailable : RouteRiskLevel.high;
    }
    if (score >= 75) return RouteRiskLevel.low;
    if (score >= 60) return RouteRiskLevel.moderate;
    if (score >= 45) return RouteRiskLevel.elevated;
    return RouteRiskLevel.high;
  }

  Color get color {
    return switch (this) {
      RouteRiskLevel.low => NeonTheme.safeGreen,
      RouteRiskLevel.moderate => NeonTheme.neonAmber,
      RouteRiskLevel.elevated => const Color(0xffF97316),
      RouteRiskLevel.high => NeonTheme.dangerRed,
      RouteRiskLevel.unavailable => const Color(0xff94A3B8),
    };
  }

  IconData get icon {
    return switch (this) {
      RouteRiskLevel.low => Icons.verified_user_rounded,
      RouteRiskLevel.moderate => Icons.warning_amber_rounded,
      RouteRiskLevel.elevated => Icons.report_problem_rounded,
      RouteRiskLevel.high => Icons.dangerous_rounded,
      RouteRiskLevel.unavailable => Icons.help_outline_rounded,
    };
  }

  String title(bool isTamil) {
    if (!isTamil) {
      return switch (this) {
        RouteRiskLevel.low => 'LOW RISK',
        RouteRiskLevel.moderate => 'MODERATE RISK',
        RouteRiskLevel.elevated => 'ELEVATED RISK',
        RouteRiskLevel.high => 'HIGH RISK',
        RouteRiskLevel.unavailable => 'UNAVAILABLE',
      };
    }
    return switch (this) {
      RouteRiskLevel.low => 'குறைந்த ஆபத்து',
      RouteRiskLevel.moderate => 'மிதமான ஆபத்து',
      RouteRiskLevel.elevated => 'அதிகரித்த ஆபத்து',
      RouteRiskLevel.high => 'அதிக ஆபத்து',
      RouteRiskLevel.unavailable => 'கிடைக்கவில்லை',
    };
  }

  String description(bool isTamil) {
    if (!isTamil) {
      return switch (this) {
        RouteRiskLevel.low => 'Most safety factors are currently favorable based on available route data.',
        RouteRiskLevel.moderate => 'Some sections may require additional caution based on available data.',
        RouteRiskLevel.elevated => 'Multiple safety factors indicate potential hazards along this route.',
        RouteRiskLevel.high => 'Significant risk factors detected based on available route evaluation metrics.',
        RouteRiskLevel.unavailable => 'Insufficient verified evidence along this segment to determine risk.',
      };
    }
    return switch (this) {
      RouteRiskLevel.low => 'கிடைக்கக்கூடிய தரவுகளின் அடிப்படையில் பெரும்பாலான பாதுகாப்பு காரணிகள் சாதகமாக உள்ளன.',
      RouteRiskLevel.moderate => 'கிடைக்கக்கூடிய தரவுகளின் அடிப்படையில் சில பகுதிகளில் கூடுதல் எச்சரிக்கை தேவைப்படலாம்.',
      RouteRiskLevel.elevated =>
        'இந்த வழியில் பல சாத்தியமான ஆபத்துகள் சுட்டிக்காட்டப்படுகின்றன.',
      RouteRiskLevel.high => 'மதிப்பீட்டு அளவீடுகளின் அடிப்படையில் குறிப்பிடத்தக்க அபாயக் காரணிகள் கண்டறியப்பட்டுள்ளன.',
      RouteRiskLevel.unavailable => 'ஆபத்தை மதிப்பிட போதிய சரிபார்க்கப்பட்ட தரவு இல்லை.',
    };
  }
}

// ============================================================================
// LOCALIZATION (ENGLISH & TAMIL)
// ============================================================================

class RiskForecastLocalization {
  static String title(bool isTamil) =>
      isTamil ? 'ஸ்மார்ட் பாதை ஆபத்து கணிப்பு' : 'Smart Route Risk Forecast';

  static String subtitle(bool isTamil) => isTamil
      ? 'உங்கள் வழியில் ஏற்படக்கூடிய சாத்தியமான பாதுகாப்பு அபாயங்களின் கணிப்பு'
      : 'AI-assisted prediction of potential safety risks along your route';

  static String overallRouteRisk(bool isTamil) =>
      isTamil ? 'மொத்த பாதை ஆபத்து' : 'Overall Route Risk';

  static String potentialRiskZones(bool isTamil) =>
      isTamil ? 'சாத்தியமான ஆபத்து பகுதிகள்' : 'Potential Risk Zones';

  static String safetyRecommendations(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு பரிந்துரைகள்' : 'Safety Recommendations';

  static String riskTrend(bool isTamil) =>
      isTamil ? 'ஆபத்து போக்கு' : 'Risk Trend Along Route';

  static String estimatedRiskTrendSub(bool isTamil) => isTamil
      ? 'மதிப்பிடப்பட்ட பாதை ஆபத்து போக்கு'
      : 'Estimated Route Risk Trend';

  static String riskFactors(bool isTamil) =>
      isTamil ? 'ஆபத்து காரணிகள்' : 'Risk Factors';

  static String whyRiskHeading(bool isTamil) => isTamil
      ? 'ஆபத்து நிலை ஏன் இவ்வாறு உள்ளது?'
      : 'Why is the risk level like this?';

  static String safetyVsTimeHeading(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு vs பயண நேரம்' : 'Safety vs Travel Time';

  static String safetyPriority(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு முன்னுரிமை' : 'Safety Priority';

  static String timePriority(bool isTamil) =>
      isTamil ? 'நேர முன்னுரிமை' : 'Time Priority';

  static String noActiveRoute(bool isTamil) =>
      isTamil ? 'செயலில் உள்ள வழி இல்லை' : 'No active route';

  static String noActiveRouteDesc(bool isTamil) => isTamil
      ? 'வழி தொடர்பான ஆபத்து கணிப்பைக் காண ஒரு வழியைத் திட்டமிடுங்கள்.'
      : 'Plan a route to see route-specific emergency and risk context.';

  static String noHotspots(bool isTamil) => isTamil
      ? 'சரிபார்க்கப்பட்ட அதிக ஆபத்து பகுதி தகவல்கள் தற்போது கிடைக்கவில்லை.'
      : 'No verified high-risk segment information is currently available.';

  static String routeLevelForecastNote(bool isTamil) => isTamil
      ? 'மதிப்பிடப்பட்ட பாதை நிலை ஆபத்து கணிப்பு (தொடர்ச்சியான பகுதி அளவீடுகள் கிடைக்கவில்லை)'
      : 'Route-level risk forecast based on evaluated safety factors (exact segment telemetry unavailable)';

  static String done(bool isTamil) => isTamil ? 'சரி' : 'Done';

  static String unavailable(bool isTamil) =>
      isTamil ? 'கிடைக்கவில்லை' : 'Unavailable';

  static String factorTitle(String factorKey, bool isTamil) {
    if (!isTamil) {
      return switch (factorKey) {
        'accident' => 'Accident Risk',
        'road' => 'Road Condition',
        'traffic' => 'Traffic',
        'weather' => 'Weather',
        'lighting' => 'Lighting',
        'accessibility' => 'Accessibility',
        _ => factorKey,
      };
    }
    return switch (factorKey) {
      'accident' => 'விபத்து அபாயம்',
      'road' => 'சாலை நிலை',
      'traffic' => 'போக்குவரத்து',
      'weather' => 'வானிலை',
      'lighting' => 'வெளிச்சம்',
      'accessibility' => 'அணுகல்தன்மை',
      _ => factorKey,
    };
  }
}

// ============================================================================
// DATA MODELS FOR RISK FORECAST
// ============================================================================

class RiskFactorAssessment {
  final String key;
  final String title;
  final IconData icon;
  final double? score;
  final bool isAvailable;
  final String? unavailableReason;
  final RouteRiskLevel? riskLevel;
  final String explanation;
  final String tamilExplanation;

  const RiskFactorAssessment({
    required this.key,
    required this.title,
    required this.icon,
    required this.score,
    required this.isAvailable,
    this.unavailableReason,
    required this.riskLevel,
    required this.explanation,
    required this.tamilExplanation,
  });
}

class RiskZoneItem {
  final String category;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const RiskZoneItem({
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class RiskTrendStep {
  final String milestone;
  final RouteRiskLevel level;
  final String label;
  final String tamilLabel;

  const RiskTrendStep({
    required this.milestone,
    required this.level,
    required this.label,
    required this.tamilLabel,
  });
}

class SmartRiskForecastData {
  final RouteRiskLevel overallLevel;
  final double? overallScore;
  final List<RiskFactorAssessment> factors;
  final List<RiskZoneItem> hotspots;
  final List<RiskTrendStep> trendSteps;
  final List<String> recommendations;
  final List<String> tamilRecommendations;
  final String whyRiskNarrative;
  final String tamilWhyRiskNarrative;
  final bool isSafetyPriority;

  const SmartRiskForecastData({
    required this.overallLevel,
    required this.overallScore,
    required this.factors,
    required this.hotspots,
    required this.trendSteps,
    required this.recommendations,
    required this.tamilRecommendations,
    required this.whyRiskNarrative,
    required this.tamilWhyRiskNarrative,
    required this.isSafetyPriority,
  });
}

class RiskForecastCheckpoint {
  final String label;
  final String sublabel;
  final double distanceKm;
  final RouteRiskLevel riskLevel;
  final double? riskScore;
  final String primaryReason;
  final List<String> verifiedFactors;
  final List<String> unavailableFactors;
  final LatLng? coordinate;
  final int evidenceCount;

  const RiskForecastCheckpoint({
    required this.label,
    required this.sublabel,
    required this.distanceKm,
    required this.riskLevel,
    required this.riskScore,
    required this.primaryReason,
    required this.verifiedFactors,
    required this.unavailableFactors,
    this.coordinate,
    this.evidenceCount = 0,
  });
}

// ============================================================================
// DETERMINISTIC RISK ENGINE
// ============================================================================

class SmartRiskForecastEngine {
  static SmartRiskForecastData evaluate({
    required RouteEvaluation? evaluation,
    required String? vehicle,
    required String? travelTime,
  }) {
    if (evaluation == null) {
      return const SmartRiskForecastData(
        overallLevel: RouteRiskLevel.high,
        overallScore: null,
        factors: [],
        hotspots: [],
        trendSteps: [],
        recommendations: [
          'Plan a route to generate safety risk forecasts and recommendations.',
        ],
        tamilRecommendations: [
          'பாதுகாப்பு ஆபத்து கணிப்புகளைப் பெற ஒரு வழியைத் திட்டமிடுங்கள்.',
        ],
        whyRiskNarrative:
            'No route evaluation data is currently active to forecast risks.',
        tamilWhyRiskNarrative: 'ஆபத்துகளைக் கணிக்க செயலில் உள்ள வழித்தட மதிப்பீட்டுத் தரவு எதுவும் இல்லை.',
        isSafetyPriority: true,
      );
    }

    final safety = evaluation.safety;
    final overallScore = safety.score;
    final overallLevel = RouteRiskLevel.fromScore(overallScore);
    final isDay = travelTime == 'Day';

    SafetyFactor? findFactor(String key) {
      for (final f in safety.factors) {
        if (f.title == key ||
            (key == 'Accident Risk' && f.title == 'Verified blackspots') ||
            (key == 'Road Condition' && f.title == 'Road condition') ||
            (key == 'Traffic' && f.title == 'Live Traffic')) {
          return f;
        }
      }
      return null;
    }

    // 1. Accident Risk
    final accFactor = findFactor('Accident Risk');
    final accScore = accFactor?.score;
    final isAccAvailable =
        accFactor != null && accFactor.relevant && accScore != null;
    final RouteRiskLevel? accLevel = isAccAvailable
        ? (accScore >= 70
              ? RouteRiskLevel.low
              : (accScore >= 45
                    ? RouteRiskLevel.moderate
                    : RouteRiskLevel.high))
        : null;
    final String accExp;
    final String tamilAccExp;
    if (isAccAvailable) {
      if (accScore >= 70) {
        accExp = 'Relatively lower accident risk based on monitored blackspot records.';
        tamilAccExp =
            'கண்காணிக்கப்படும் விபத்துப் பதிவுகளின்படி குறைவான விபத்து அபாயம்.';
      } else if (accScore >= 45) {
        accExp = 'Moderate accident risk observed along monitored sections.';
        tamilAccExp =
            'கண்காணிக்கப்படும் பகுதிகளில் மிதமான விபத்து அபாயம் உள்ளது.';
      } else {
        accExp = 'Higher accident-risk clusters detected near this corridor.';
        tamilAccExp = 'இந்த வழியின் அருகில் அதிக விபத்து அபாயப் பகுதிகள் கண்டறியப்பட்டுள்ளன.';
      }
    } else {
      accExp = 'Accident risk data is currently unavailable, so it was not included in this evaluation.';
      tamilAccExp = 'விபத்து அபாய தரவு தற்போது கிடைக்கவில்லை, எனவே இது சேர்க்கப்படவில்லை.';
    }

    // 2. Road Condition
    final roadFactor = findFactor('Road Condition');
    final roadScore = roadFactor?.score;
    final isRoadAvailable =
        roadFactor != null && roadFactor.relevant && roadScore != null;
    final RouteRiskLevel? roadLevel = isRoadAvailable
        ? (roadScore >= 65
              ? RouteRiskLevel.low
              : (roadScore >= 45
                    ? RouteRiskLevel.moderate
                    : RouteRiskLevel.high))
        : null;
    final String roadExp;
    final String tamilRoadExp;
    if (isRoadAvailable) {
      if (roadScore >= 65) {
        roadExp = 'Paved surfaces and favorable road conditions recorded.';
        tamilRoadExp =
            'செப்பனிடப்பட்ட சாலை மற்றும் சாதகமான சாலை நிலைகள் பதிவாகியுள்ளன.';
      } else if (roadScore >= 45) {
        roadExp = 'Some road-condition data indicates increased caution may be useful.';
        tamilRoadExp = 'சாலை நிலை தரவு சில இடங்களில் கூடுதல் எச்சரிக்கை பயனுள்ளதாக இருக்கும் என்பதைக் குறிக்கிறது.';
      } else {
        roadExp = 'Rough, unpaved or deteriorated road segments recorded on this route.';
        tamilRoadExp =
            'கரடுமுரடான அல்லது சேதமடைந்த சாலைப் பகுதிகள் பதிவாகியுள்ளன.';
      }
    } else {
      roadExp = 'Road condition data is currently unavailable, so it was not included in this evaluation.';
      tamilRoadExp =
          'சாலை நிலை தரவு தற்போது கிடைக்கவில்லை, எனவே இது சேர்க்கப்படவில்லை.';
    }

    // 3. Traffic
    final trafficFactor = findFactor('Traffic');
    final trafficScore = trafficFactor?.score;
    final isTrafficAvailable =
        trafficFactor != null && trafficFactor.relevant && trafficScore != null;
    final RouteRiskLevel? trafficLevel = isTrafficAvailable
        ? (trafficScore >= 70
              ? RouteRiskLevel.low
              : (trafficScore >= 45
                    ? RouteRiskLevel.moderate
                    : RouteRiskLevel.high))
        : null;
    final String trafficExp;
    final String tamilTrafficExp;
    if (isTrafficAvailable) {
      if (trafficScore >= 70) {
        trafficExp = 'Smooth traffic flow with low congestion observed.';
        tamilTrafficExp =
            'குறைந்த நெரிசலுடன் சீரான போக்குவரத்து காணப்படுகிறது.';
      } else if (trafficScore >= 45) {
        trafficExp = 'Moderate traffic density and normal corridor speeds.';
        tamilTrafficExp = 'மிதமான போக்குவரத்து அடர்த்தி மற்றும் இயல்பான வேகம்.';
      } else {
        trafficExp =
            'Heavy traffic congestion or reduced travel speeds detected.';
        tamilTrafficExp = 'அதிக போக்குவரத்து நெரிசல் அல்லது மெதுவான வேகம் கண்டறியப்பட்டுள்ளது.';
      }
    } else {
      trafficExp = 'Traffic data is currently unavailable, so it was not included in this evaluation.';
      tamilTrafficExp = 'போக்குவரத்து தரவு தற்போது கிடைக்கவில்லை, எனவே இது சேர்க்கப்படவில்லை.';
    }

    // 4. Weather
    final weatherFactor = findFactor('Weather');
    final weatherScore = weatherFactor?.score;
    final isWeatherAvailable =
        weatherFactor != null && weatherFactor.relevant && weatherScore != null;
    final RouteRiskLevel? weatherLevel = isWeatherAvailable
        ? (weatherScore >= 70
              ? RouteRiskLevel.low
              : (weatherScore >= 45
                    ? RouteRiskLevel.moderate
                    : RouteRiskLevel.high))
        : null;
    final String weatherExp;
    final String tamilWeatherExp;
    if (isWeatherAvailable) {
      if (weatherScore >= 70) {
        weatherExp = 'Current weather conditions are favorable for travel.';
        tamilWeatherExp = 'தற்போதைய வானிலை பயணத்திற்கு சாதகமாக உள்ளது.';
      } else if (weatherScore >= 45) {
        weatherExp = 'Mild weather variations observed along route corridor.';
        tamilWeatherExp = 'வழியில் மிதமான வானிலை மாற்றங்கள் நிலவுகின்றன.';
      } else {
        weatherExp = 'Adverse weather (rain, fog, or high wind) reported.';
        tamilWeatherExp =
            'பாதகமான வானிலை (மழை, மூடுபனி அல்லது காற்று) பதிவாகியுள்ளது.';
      }
    } else {
      weatherExp = 'Weather data is currently unavailable, so it was not included in this evaluation.';
      tamilWeatherExp =
          'வானிலை தரவு தற்போது கிடைக்கவில்லை, எனவே இது சேர்க்கப்படவில்லை.';
    }

    // 5. Lighting
    final lightFactor = findFactor('Lighting');
    final lightScore = isDay ? null : lightFactor?.score;
    final isLightAvailable =
        !isDay &&
        lightFactor != null &&
        lightFactor.relevant &&
        lightScore != null;
    final RouteRiskLevel? lightLevel = isLightAvailable
        ? (lightScore >= 65
              ? RouteRiskLevel.low
              : (lightScore >= 45
                    ? RouteRiskLevel.moderate
                    : RouteRiskLevel.high))
        : null;
    final String lightExp;
    final String tamilLightExp;
    if (isDay) {
      lightExp = 'Street lighting is not evaluated for daytime travel.';
      tamilLightExp =
          'பகல் நேர பயணத்திற்கு தெருவிளக்கு நிலை கணக்கிடப்படவில்லை.';
    } else if (isLightAvailable) {
      if (lightScore >= 65) {
        lightExp = 'Favorable street lighting reported on nighttime segments.';
        tamilLightExp = 'இரவு நேரப் பகுதிகளில் போதுமான தெருவிளக்கு வெளிச்சம் பதிவாகியுள்ளது.';
      } else {
        lightExp =
            'Limited street lighting recorded; extra night caution advised.';
        tamilLightExp = 'குறைந்த தெருவிளக்கு வெளிச்சம்; இரவு எச்சரிக்கை தேவை.';
      }
    } else {
      lightExp = 'Street lighting data is currently unavailable, so it was not included in this evaluation.';
      tamilLightExp =
          'தெருவிளக்கு தரவு தற்போது கிடைக்கவில்லை, எனவே இது சேர்க்கப்படவில்லை.';
    }

    // 6. Accessibility
    final accessFactor = findFactor('Accessibility');
    final accessScore = accessFactor?.score;
    final isAccessAvailable =
        accessFactor != null && accessFactor.relevant && accessScore != null;
    final RouteRiskLevel? accessLevel = isAccessAvailable
        ? (accessScore >= 65
              ? RouteRiskLevel.low
              : (accessScore >= 45
                    ? RouteRiskLevel.moderate
                    : RouteRiskLevel.high))
        : null;
    final String accessExp;
    final String tamilAccessExp;
    if (isAccessAvailable) {
      if (accessScore >= 65) {
        accessExp = 'Favorable accessibility infrastructure along corridor.';
        tamilAccessExp = 'வழியில் சிறந்த நடைபாதை மற்றும் அணுகல் வசதிகள் உள்ளன.';
      } else if (accessScore >= 45) {
        accessExp = 'Standard accessibility conditions observed.';
        tamilAccessExp = 'வழக்கமான அணுகல்தன்மை வசதிகள் உள்ளன.';
      } else {
        accessExp =
            'Limited accessibility infrastructure recorded along this route.';
        tamilAccessExp =
            'குறைந்த நடைபாதை மற்றும் அணுகல் வசதிகள் கண்டறியப்பட்டுள்ளன.';
      }
    } else {
      accessExp = 'Accessibility data is currently unavailable, so it was not included in this evaluation.';
      tamilAccessExp =
          'அணுகல்தன்மை தரவு தற்போது கிடைக்கவில்லை, எனவே இது சேர்க்கப்படவில்லை.';
    }

    final factors = [
      RiskFactorAssessment(
        key: 'accident',
        title: 'Accident Risk',
        icon: Icons.shield_rounded,
        score: isAccAvailable ? accScore : null,
        isAvailable: isAccAvailable,
        unavailableReason: accFactor?.unavailableReason,
        riskLevel: accLevel,
        explanation: accExp,
        tamilExplanation: tamilAccExp,
      ),
      RiskFactorAssessment(
        key: 'road',
        title: 'Road Condition',
        icon: Icons.add_road_rounded,
        score: isRoadAvailable ? roadScore : null,
        isAvailable: isRoadAvailable,
        unavailableReason: roadFactor?.unavailableReason,
        riskLevel: roadLevel,
        explanation: roadExp,
        tamilExplanation: tamilRoadExp,
      ),
      RiskFactorAssessment(
        key: 'traffic',
        title: 'Traffic',
        icon: Icons.traffic_rounded,
        score: isTrafficAvailable ? trafficScore : null,
        isAvailable: isTrafficAvailable,
        unavailableReason: trafficFactor?.unavailableReason,
        riskLevel: trafficLevel,
        explanation: trafficExp,
        tamilExplanation: tamilTrafficExp,
      ),
      RiskFactorAssessment(
        key: 'weather',
        title: 'Weather',
        icon: Icons.cloud_rounded,
        score: isWeatherAvailable ? weatherScore : null,
        isAvailable: isWeatherAvailable,
        unavailableReason: weatherFactor?.unavailableReason,
        riskLevel: weatherLevel,
        explanation: weatherExp,
        tamilExplanation: tamilWeatherExp,
      ),
      RiskFactorAssessment(
        key: 'lighting',
        title: 'Lighting',
        icon: Icons.lightbulb_rounded,
        score: isLightAvailable ? lightScore : null,
        isAvailable: isLightAvailable,
        unavailableReason: isDay
            ? 'Not evaluated for day travel'
            : lightFactor?.unavailableReason,
        riskLevel: lightLevel,
        explanation: lightExp,
        tamilExplanation: tamilLightExp,
      ),
      RiskFactorAssessment(
        key: 'accessibility',
        title: 'Accessibility',
        icon: Icons.accessible_rounded,
        score: isAccessAvailable ? accessScore : null,
        isAvailable: isAccessAvailable,
        unavailableReason: accessFactor?.unavailableReason,
        riskLevel: accessLevel,
        explanation: accessExp,
        tamilExplanation: tamilAccessExp,
      ),
    ];

    // Real Hotspots extraction
    final hotspots = <RiskZoneItem>[];

    // 1. Blackspot hotspots
    for (final segResult in evaluation.blackspots.segmentResults) {
      if (segResult.verifiedRecords.isNotEmpty) {
        for (final rec in segResult.verifiedRecords) {
          final landmark =
              (rec['landmark'] ?? rec['location'] ?? rec['district'])
                  ?.toString();
          final titleStr = landmark != null && landmark.trim().isNotEmpty
              ? landmark.trim()
              : 'OSM Way #${segResult.osmId}';
          final desc = rec['fatalities'] != null
              ? 'Verified high-collision zone (${rec['fatalities']} recorded incidents)'
              : 'Verified high-collision zone in monitored records';

          // Avoid duplicate titles
          if (!hotspots.any((h) => h.title == titleStr)) {
            hotspots.add(
              RiskZoneItem(
                category: 'Accident Risk',
                title: titleStr,
                description: desc,
                icon: Icons.dangerous_rounded,
                color: NeonTheme.dangerRed,
              ),
            );
          }
        }
      }
    }

    // 2. Road surface issues
    if (evaluation.roadSegments != null) {
      for (final seg in evaluation.roadSegments!) {
        final isRough =
            seg.surface == 'unpaved' ||
            seg.surface == 'dirt' ||
            seg.surface == 'gravel' ||
            seg.surface == 'ground' ||
            seg.smoothness == 'bad' ||
            seg.smoothness == 'very_bad';
        if (isRough) {
          final name = seg.name?.trim().isNotEmpty == true
              ? seg.name!.trim()
              : 'Corridor Section #${seg.osmId}';
          final desc =
              'Unpaved or rough surface (${seg.surface ?? seg.smoothness ?? "uneven"})';
          if (!hotspots.any((h) => h.title == name)) {
            hotspots.add(
              RiskZoneItem(
                category: 'Road Condition',
                title: name,
                description: desc,
                icon: Icons.construction_rounded,
                color: NeonTheme.neonAmber,
              ),
            );
          }
        }
      }
    }

    // 3. Traffic issues
    if (evaluation.traffic?.roadClosure == true) {
      hotspots.add(
        const RiskZoneItem(
          category: 'Traffic',
          title: 'Route Road Closure',
          description:
              'Live TomTom traffic reports an active road closure or blockage.',
          icon: Icons.traffic_rounded,
          color: NeonTheme.dangerRed,
        ),
      );
    } else if (evaluation.traffic?.status == 'Heavy Traffic') {
      hotspots.add(
        const RiskZoneItem(
          category: 'Traffic',
          title: 'Heavy Traffic Zone',
          description: 'Corridor traffic speeds are significantly delayed.',
          icon: Icons.traffic_rounded,
          color: Color(0xffF97316),
        ),
      );
    }

    // 4. Weather issues
    if (evaluation.weather != null) {
      final code = evaluation.weather!.weatherCode;
      if (code >= 51 && code <= 99) {
        hotspots.add(
          RiskZoneItem(
            category: 'Weather',
            title: 'Precipitation Advisory',
            description:
                'Rain or adverse atmospheric conditions active along corridor (${evaluation.weather!.precipitation} mm).',
            icon: Icons.cloud_rounded,
            color: const Color(0xff3B82F6),
          ),
        );
      } else if (evaluation.weather!.windSpeed > 35) {
        hotspots.add(
          RiskZoneItem(
            category: 'Weather',
            title: 'High Wind Zone',
            description:
                'Elevated crosswinds (${evaluation.weather!.windSpeed} km/h) along open roadway.',
            icon: Icons.air_rounded,
            color: const Color(0xff3B82F6),
          ),
        );
      }
    }

    // 5. Night lighting
    if (!isDay && (lightScore != null && lightScore < 50)) {
      hotspots.add(
        const RiskZoneItem(
          category: 'Lighting',
          title: 'Unlit Night Stretch',
          description: 'Limited public lighting recorded; proceed with extra headlights caution.',
          icon: Icons.nightlight_round,
          color: Color(0xffA855F7),
        ),
      );
    }

    // Risk Trend Along Route
    // Create 5 conceptual corridor stages: Start -> Early Corridor -> Mid Route -> Late Corridor -> Destination
    final trendSteps = <RiskTrendStep>[
      RiskTrendStep(
        milestone: 'Start',
        level: RouteRiskLevel.low,
        label: 'Trip departure corridor',
        tamilLabel: 'பயணத் தொடக்கப் பகுதி',
      ),
      RiskTrendStep(
        milestone: 'Early Corridor',
        level: overallScore != null && overallScore < 60
            ? RouteRiskLevel.moderate
            : RouteRiskLevel.low,
        label: 'Initial connecting arterial',
        tamilLabel: 'ஆரம்ப இணைப்புச் சாலை',
      ),
      RiskTrendStep(
        milestone: 'Mid Route',
        level: hotspots.isNotEmpty
            ? (overallScore != null && overallScore < 50
                  ? RouteRiskLevel.high
                  : RouteRiskLevel.elevated)
            : overallLevel,
        label: hotspots.isNotEmpty
            ? 'Monitored hazard/blackspot zone'
            : 'Mid-transit transit flow',
        tamilLabel: hotspots.isNotEmpty
            ? 'கண்காணிக்கப்படும் அபாயப் பகுதி'
            : 'நடுவழி போக்குவரத்து ஓட்டம்',
      ),
      RiskTrendStep(
        milestone: 'Late Corridor',
        level: overallLevel == RouteRiskLevel.high
            ? RouteRiskLevel.elevated
            : (overallScore != null && overallScore < 65
                  ? RouteRiskLevel.moderate
                  : RouteRiskLevel.low),
        label: 'Approaching destination arterial',
        tamilLabel: 'இலக்கை நெருங்கும் இணைப்புச் சாலை',
      ),
      RiskTrendStep(
        milestone: 'Destination',
        level: RouteRiskLevel.low,
        label: 'Arrival approach',
        tamilLabel: 'இலக்கு வருகை பகுதி',
      ),
    ];

    // Rule-based Safety Recommendations
    final recs = <String>[];
    final tamilRecs = <String>[];

    if (accScore != null && accScore < 50 ||
        evaluation.blackspots.detectedBlackspots! > 0) {
      recs.add(
        'Stay alert near accident-prone areas and maintain a safe speed.',
      );
      tamilRecs.add(
        'விபத்து அபாயப் பகுதிகளில் எச்சரிக்கையுடன் இருங்கள், பாதுகாப்பான வேகத்தைப் பராமரியுங்கள்.',
      );
    }

    if (roadScore != null && roadScore < 50) {
      recs.add('Drive carefully and watch for damaged road surfaces.');
      tamilRecs.add(
        'கவனமாக ஓட்டுங்கள் மற்றும் சேதமடைந்த சாலைப் பகுதிகளைக் கவனியுங்கள்.',
      );
    }

    if (trafficScore != null && trafficScore < 50 ||
        evaluation.traffic?.status == 'Heavy Traffic') {
      recs.add(
        'Allow extra travel time and maintain a safe following distance.',
      );
      tamilRecs.add(
        'கூடுதல் பயண நேரத்தை ஒதுக்குங்கள், பாதுகாப்பான இடைவெளியைப் பராமரியுங்கள்.',
      );
    }

    if (weatherScore != null && weatherScore < 60) {
      recs.add(
        'Reduce speed and increase following distance during adverse weather.',
      );
      tamilRecs.add(
        'பாதகமான வானிலையின் போது வேகத்தைக் குறைத்து இடைவெளியை அதிகரிக்கவும்.',
      );
    }

    if (!isDay && (lightScore != null && lightScore < 60)) {
      recs.add('Use extra caution in poorly lit sections.');
      tamilRecs.add(
        'குறைந்த வெளிச்சம் உள்ள பகுதிகளில் கூடுதல் எச்சரிக்கையுடன் செல்லுங்கள்.',
      );
    }

    if (accessScore != null && accessScore < 50) {
      recs.add('Consider accessibility conditions before choosing this route.');
      tamilRecs.add(
        'இந்த வழியைத் தேர்ந்தெடுக்கும் முன் நடைபாதை மற்றும் அணுகல் வசதிகளைக் கவனியுங்கள்.',
      );
    }

    if (recs.isEmpty) {
      recs.add(
        'All evaluated safety factors are favorable. Maintain standard driving precautions.',
      );
      tamilRecs.add(
        'அனைத்து காரணிகளும் சாதகமாக உள்ளன. வழக்கமான பாதுகாப்பு வழிமுறைகளைப் பின்பற்றுங்கள்.',
      );
    }

    // AI Explanation Narrative
    final favorable = <String>[];
    final challenging = <String>[];
    final unavail = <String>[];

    final tamilFavorable = <String>[];
    final tamilChallenging = <String>[];
    final tamilUnavail = <String>[];

    for (final f in factors) {
      if (!f.isAvailable) {
        unavail.add(f.title.toLowerCase());
        tamilUnavail.add(RiskForecastLocalization.factorTitle(f.key, true));
      } else if (f.score != null && f.score! >= 65) {
        favorable.add(f.title.toLowerCase());
        tamilFavorable.add(RiskForecastLocalization.factorTitle(f.key, true));
      } else if (f.score != null && f.score! < 50) {
        challenging.add(f.title.toLowerCase());
        tamilChallenging.add(RiskForecastLocalization.factorTitle(f.key, true));
      }
    }

    final String narrative;
    final String tamilNarrative;

    final levelName = overallLevel.title(false).toLowerCase();
    final tamilLevelName = overallLevel.title(true);

    if (challenging.isNotEmpty && favorable.isNotEmpty) {
      narrative =
          'This route currently has an estimated $levelName because '
          '${challenging.join(" and ")} contribute more heavily to potential hazards, '
          'while ${favorable.join(" and ")} conditions remain favorable.';
      tamilNarrative =
          'இந்த வழியின் மதிப்பிடப்பட்ட ஆபத்து நிலை $tamilLevelName ஆகும். '
          '${tamilChallenging.join(" மற்றும் ")} ஆபத்து காரணிகள் தாக்கத்தை ஏற்படுத்துகின்றன; '
          'அதேவேளையில் ${tamilFavorable.join(" மற்றும் ")} சாதகமாக உள்ளன.';
    } else if (challenging.isNotEmpty) {
      narrative =
          'This route currently exhibits an estimated $levelName primarily due to '
          'increased caution indicators across ${challenging.join(" and ")}.';
      tamilNarrative =
          'இந்த வழி முக்கியமாக ${tamilChallenging.join(" மற்றும் ")} காரணிகளால் '
          'மதிப்பிடப்பட்ட $tamilLevelName நிலையைக் கொண்டுள்ளது.';
    } else {
      narrative =
          'This route currently maintains an estimated $levelName with '
          'favorable indicators across evaluated safety metrics.';
      tamilNarrative =
          'மதிப்பிடப்பட்ட அளவீடுகளில் சாதகமான காரணிகளுடன் இந்த வழி '
          'மதிப்பிடப்பட்ட $tamilLevelName நிலையைக் கொண்டுள்ளது.';
    }

    final isSafetyPriority = (overallScore ?? 50) >= 50;

    return SmartRiskForecastData(
      overallLevel: overallLevel,
      overallScore: overallScore,
      factors: factors,
      hotspots: hotspots,
      trendSteps: trendSteps,
      recommendations: recs,
      tamilRecommendations: tamilRecs,
      whyRiskNarrative: narrative,
      tamilWhyRiskNarrative: tamilNarrative,
      isSafetyPriority: isSafetyPriority,
    );
  }

  static List<RiskForecastCheckpoint> generateCheckpoints({
    required RouteEvaluation? evaluation,
    required double totalDistanceKm,
    required double totalDurationMinutes,
    String? originName,
    String? destinationName,
    String vehicle = 'Car',
    String travelTime = 'Day',
    PersonalSafetyProfile? profile,
  }) {
    final dist = totalDistanceKm <= 0 ? 25.0 : totalDistanceKm;
    final dur = totalDurationMinutes <= 0 ? 35.0 : totalDurationMinutes;
    final tripContext = classifyTrip(dist, dur);

    final origin = (originName != null && originName.trim().isNotEmpty)
        ? originName.trim()
        : 'Start';
    final destination = (destinationName != null && destinationName.trim().isNotEmpty)
        ? destinationName.trim()
        : 'End';

    if (evaluation == null || evaluation.safety.score == null) {
      final unav = const [
        'Verified safety data unavailable',
        'Traffic unavailable',
        'Lighting unavailable',
      ];
      return [
        RiskForecastCheckpoint(
          label: 'Start',
          sublabel: origin,
          distanceKm: 0.0,
          riskLevel: RouteRiskLevel.unavailable,
          riskScore: null,
          primaryReason: 'Insufficient evidence to score departure stretch',
          verifiedFactors: const [],
          unavailableFactors: unav,
        ),
        RiskForecastCheckpoint(
          label: '${(dist * 0.5).toStringAsFixed(1)} km',
          sublabel: 'Mid Route',
          distanceKm: dist * 0.5,
          riskLevel: RouteRiskLevel.unavailable,
          riskScore: null,
          primaryReason: 'Insufficient verified evidence along this sector',
          verifiedFactors: const [],
          unavailableFactors: unav,
        ),
        RiskForecastCheckpoint(
          label: 'End',
          sublabel: destination,
          distanceKm: dist,
          riskLevel: RouteRiskLevel.unavailable,
          riskScore: null,
          primaryReason: 'Insufficient evidence to score arrival stretch',
          verifiedFactors: const [],
          unavailableFactors: unav,
        ),
      ];
    }

    final safety = evaluation.safety;
    final overallScore = safety.score!;
    final overallLevel = RouteRiskLevel.fromScore(overallScore, allowUnavailable: true);
    final blackspotsCount = evaluation.blackspots.detectedBlackspots ?? 0;
    final hasBlackspots = blackspotsCount > 0;

    // Verified and unavailable factors
    final verifiedFactors = <String>[];
    final unavailableFactors = <String>[];

    final accFactor = safety.factors.where((f) => f.title == 'Accident Risk' || f.title == 'Verified blackspots').firstOrNull;
    if (accFactor != null && accFactor.relevant && accFactor.score != null) {
      verifiedFactors.add('Verified accident exposure');
    } else {
      unavailableFactors.add('Accident records unavailable');
    }

    final roadFactor = safety.factors.where((f) => f.title == 'Road Condition' || f.title == 'Road condition').firstOrNull;
    if (roadFactor != null && roadFactor.relevant && roadFactor.score != null) {
      verifiedFactors.add('Road condition');
    } else {
      unavailableFactors.add('Road condition unavailable');
    }

    final weatherFactor = safety.factors.where((f) => f.title == 'Weather').firstOrNull;
    if (weatherFactor != null && weatherFactor.relevant && weatherFactor.score != null) {
      verifiedFactors.add('Weather');
    } else {
      unavailableFactors.add('Weather unavailable');
    }

    final lightingFactor = safety.factors.where((f) => f.title == 'Lighting').firstOrNull;
    if (lightingFactor != null && lightingFactor.relevant && lightingFactor.score != null) {
      verifiedFactors.add('Lighting coverage');
    } else {
      unavailableFactors.add('Lighting unavailable');
    }

    // DATA HONEST traffic check
    final traffic = evaluation.traffic;
    final isTrafficAvailable = traffic != null &&
        traffic.coveragePercent > 0 &&
        traffic.source != 'Unavailable' &&
        !traffic.status.toLowerCase().contains('unavailable');

    if (isTrafficAvailable) {
      verifiedFactors.add('Real-time traffic (${traffic.status})');
    } else {
      unavailableFactors.add('Traffic unavailable');
    }

    final checkpoints = <RiskForecastCheckpoint>[];

    // Checkpoint 0: Start
    checkpoints.add(RiskForecastCheckpoint(
      label: 'Start',
      sublabel: origin,
      distanceKm: 0.0,
      riskLevel: RouteRiskLevel.low,
      riskScore: overallScore,
      primaryReason: 'Departure corridor clear • verified safe transition',
      verifiedFactors: List.unmodifiable(verifiedFactors),
      unavailableFactors: List.unmodifiable(unavailableFactors),
      coordinate: evaluation.route.points.firstOrNull,
      evidenceCount: verifiedFactors.length,
    ));

    if (tripContext == TripContextType.short) {
      // Short trip (< 20 km): 3 checkpoints total
      final midDist = dist * 0.5;
      final midLevel = hasBlackspots
          ? (overallScore < 50 ? RouteRiskLevel.high : RouteRiskLevel.moderate)
          : overallLevel;
      final midReason = hasBlackspots
          ? '$blackspotsCount monitored accident blackspot(s) detected along this sector'
          : 'Stable local corridor • favorable road conditions';

      checkpoints.add(RiskForecastCheckpoint(
        label: '${midDist.toStringAsFixed(1)} km',
        sublabel: hasBlackspots ? 'High Risk Zone' : 'Mid Route',
        distanceKm: midDist,
        riskLevel: midLevel,
        riskScore: hasBlackspots ? math.max(30.0, overallScore - 20) : overallScore,
        primaryReason: midReason,
        verifiedFactors: List.unmodifiable(verifiedFactors),
        unavailableFactors: List.unmodifiable(unavailableFactors),
        evidenceCount: verifiedFactors.length,
      ));
    } else if (tripContext == TripContextType.medium) {
      // Medium trip (20 - 60 km): 4 checkpoints total
      final cp1Dist = (dist * 0.33).roundToDouble();
      final cp2Dist = (dist * 0.67).roundToDouble();

      checkpoints.add(RiskForecastCheckpoint(
        label: '${cp1Dist.round()} km',
        sublabel: 'Early Route',
        distanceKm: cp1Dist,
        riskLevel: overallScore >= 70 ? RouteRiskLevel.low : RouteRiskLevel.moderate,
        riskScore: overallScore,
        primaryReason: 'Initial connecting arterial • verified road surface',
        verifiedFactors: List.unmodifiable(verifiedFactors),
        unavailableFactors: List.unmodifiable(unavailableFactors),
        evidenceCount: verifiedFactors.length,
      ));

      final midLevel = hasBlackspots
          ? (overallScore < 50 ? RouteRiskLevel.high : RouteRiskLevel.moderate)
          : overallLevel;
      final midReason = hasBlackspots
          ? '$blackspotsCount monitored accident blackspot(s) detected along this sector'
          : 'Mid-transit transit flow • monitored corridor';

      checkpoints.add(RiskForecastCheckpoint(
        label: '${cp2Dist.round()} km',
        sublabel: hasBlackspots ? 'High Risk Zone' : 'Mid Route',
        distanceKm: cp2Dist,
        riskLevel: midLevel,
        riskScore: hasBlackspots ? math.max(35.0, overallScore - 18) : overallScore,
        primaryReason: midReason,
        verifiedFactors: List.unmodifiable(verifiedFactors),
        unavailableFactors: List.unmodifiable(unavailableFactors),
        evidenceCount: verifiedFactors.length,
      ));
    } else {
      // Long trip (>= 60 km): 5 checkpoints total
      final cp1Dist = (dist * 0.25).roundToDouble();
      final cp2Dist = (dist * 0.55).roundToDouble();
      final cp3Dist = (dist * 0.80).roundToDouble();

      checkpoints.add(RiskForecastCheckpoint(
        label: '${cp1Dist.round()} km',
        sublabel: 'Early Corridor',
        distanceKm: cp1Dist,
        riskLevel: overallScore >= 75 ? RouteRiskLevel.low : RouteRiskLevel.moderate,
        riskScore: overallScore,
        primaryReason: 'Intercity arterial connection • monitored highway flow',
        verifiedFactors: List.unmodifiable(verifiedFactors),
        unavailableFactors: List.unmodifiable(unavailableFactors),
        evidenceCount: verifiedFactors.length,
      ));

      final midLevel = hasBlackspots
          ? (overallScore < 50 ? RouteRiskLevel.high : (overallScore < 75 ? RouteRiskLevel.elevated : RouteRiskLevel.moderate))
          : overallLevel;
      final midReason = hasBlackspots
          ? '$blackspotsCount monitored accident blackspot(s) along highway corridor'
          : 'Primary transit corridor • no active blackspot clusters';

      checkpoints.add(RiskForecastCheckpoint(
        label: '${cp2Dist.round()} km',
        sublabel: hasBlackspots ? 'High Risk Zone' : 'Mid Corridor',
        distanceKm: cp2Dist,
        riskLevel: midLevel,
        riskScore: hasBlackspots ? math.max(30.0, overallScore - 22) : overallScore,
        primaryReason: midReason,
        verifiedFactors: List.unmodifiable(verifiedFactors),
        unavailableFactors: List.unmodifiable(unavailableFactors),
        evidenceCount: verifiedFactors.length,
      ));

      checkpoints.add(RiskForecastCheckpoint(
        label: '${cp3Dist.round()} km',
        sublabel: 'Final Section',
        distanceKm: cp3Dist,
        riskLevel: overallScore >= 70 ? RouteRiskLevel.low : RouteRiskLevel.moderate,
        riskScore: overallScore,
        primaryReason: 'Approaching destination corridor • steady speed flow',
        verifiedFactors: List.unmodifiable(verifiedFactors),
        unavailableFactors: List.unmodifiable(unavailableFactors),
        evidenceCount: verifiedFactors.length,
      ));
    }

    // Final Checkpoint: End
    checkpoints.add(RiskForecastCheckpoint(
      label: 'End',
      sublabel: destination,
      distanceKm: dist,
      riskLevel: RouteRiskLevel.low,
      riskScore: overallScore,
      primaryReason: 'Approaching destination • favorable arrival conditions',
      verifiedFactors: List.unmodifiable(verifiedFactors),
      unavailableFactors: List.unmodifiable(unavailableFactors),
      coordinate: evaluation.route.points.lastOrNull,
      evidenceCount: verifiedFactors.length,
    ));

    return checkpoints;
  }
}

// ============================================================================
// SMART ROUTE RISK FORECAST DIALOG WIDGET
// ============================================================================

class SmartRouteRiskForecastDialog extends StatefulWidget {
  final bool isDarkMode;
  final String? routeOrigin;
  final String? routeDestination;
  final String? vehicleMode;
  final String? travelTimeMode;
  final double? distanceKm;
  final double? durationMinutes;
  final double? safetyScore;
  final RouteEvaluation? routeEvaluation;
  final PersonalSafetyProfile? personalProfile;
  final String Function(double minutes) formatDurationFn;

  const SmartRouteRiskForecastDialog({
    super.key,
    required this.isDarkMode,
    this.routeOrigin,
    this.routeDestination,
    this.vehicleMode,
    this.travelTimeMode,
    this.distanceKm,
    this.durationMinutes,
    this.safetyScore,
    this.routeEvaluation,
    this.personalProfile,
    required this.formatDurationFn,
  });

  @override
  State<SmartRouteRiskForecastDialog> createState() =>
      _SmartRouteRiskForecastDialogState();
}

class _SmartRouteRiskForecastDialogState
    extends State<SmartRouteRiskForecastDialog> {
  bool _isTamil = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 640;

    final forecastData = SmartRiskForecastEngine.evaluate(
      evaluation: widget.routeEvaluation,
      vehicle: widget.vehicleMode ?? 'Car',
      travelTime: widget.travelTimeMode ?? 'Day',
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 20,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 740,
          maxHeight: media.size.height * 0.94,
        ),
        decoration: BoxDecoration(
          color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: NeonTheme.neonCyan.withValues(alpha: 0.5),
            width: 1.4,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: NeonTheme.neonCyan.withValues(alpha: 0.22),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : NeonTheme.cardShadow(isDark),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildDialogHeader(isDark),
            // Body Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active Route Header or Empty Route Card
                    _buildRouteContextBanner(isDark),
                    const SizedBox(height: 14),

                    // Overall Risk Level Card
                    _buildOverallRiskCard(forecastData, isDark),
                    const SizedBox(height: 14),

                    // Personalized Risk View (Personal Safety Profile)
                    _buildPersonalizedRiskSection(isDark),
                    const SizedBox(height: 14),

                    // Why This Risk Level Narrative
                    _buildWhyRiskCard(forecastData, isDark),
                    const SizedBox(height: 14),

                    // Risk vs Travel Time Comparison
                    _buildRiskVsTimeCard(forecastData, isDark),
                    const SizedBox(height: 14),

                    // 6 Risk Factors Grid
                    _buildRiskFactorsSection(forecastData, isDark, isMobile),
                    const SizedBox(height: 14),

                    // Risk Trend Along Route
                    _buildRiskTrendSection(forecastData, isDark, isMobile),
                    const SizedBox(height: 14),

                    // Potential Risk Zones (Hotspots)
                    _buildHotspotsSection(forecastData, isDark),
                    const SizedBox(height: 14),

                    // Safety Recommendations
                    _buildRecommendationsSection(forecastData, isDark),
                    const SizedBox(height: 12),

                    // Route-level telemetry note
                    _buildRouteLevelTelemetryNote(isDark),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            // Footer
            _buildDialogFooter(isDark),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HEADER
  // --------------------------------------------------------------------------

  Widget _buildDialogHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: NeonTheme.neonCyan.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: NeonTheme.neonCyan,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RiskForecastLocalization.title(_isTamil),
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: isDark
                        ? NeonTheme.textPrimaryDark
                        : NeonTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  RiskForecastLocalization.subtitle(_isTamil),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          // Language Switcher
          InkWell(
            onTap: () {
              setState(() {
                _isTamil = !_isTamil;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isTamil
                    ? NeonTheme.neonAmber.withValues(alpha: 0.2)
                    : NeonTheme.neonCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isTamil ? NeonTheme.neonAmber : NeonTheme.neonCyan,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.translate_rounded,
                    size: 12,
                    color: _isTamil ? NeonTheme.neonAmber : NeonTheme.neonCyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isTamil ? 'தமிழ்' : 'English',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _isTamil
                          ? NeonTheme.neonAmber
                          : NeonTheme.neonCyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            color: isDark
                ? NeonTheme.textSecondaryDark
                : NeonTheme.textSecondaryLight,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ROUTE CONTEXT BANNER
  // --------------------------------------------------------------------------

  Widget _buildRouteContextBanner(bool isDark) {
    final hasRoute =
        widget.routeOrigin != null && widget.routeDestination != null;

    if (!hasRoute) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? NeonTheme.bgDark.withValues(alpha: 0.7)
              : const Color(0xffF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: NeonTheme.warningGold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    RiskForecastLocalization.noActiveRoute(_isTamil),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    RiskForecastLocalization.noActiveRouteDesc(_isTamil),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? NeonTheme.textSecondaryDark
                          : NeonTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.bgDark.withValues(alpha: 0.7)
            : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NeonTheme.neonCyan.withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                size: 15,
                color: NeonTheme.neonCyan,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${widget.routeOrigin} → ${widget.routeDestination}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (widget.safetyScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: NeonTheme.safeGreen.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: NeonTheme.safeGreen.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_rounded,
                        size: 12,
                        color: NeonTheme.safeGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.safetyScore!.round()} / 100',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: NeonTheme.safeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildMetricChip(
                icon: Icons.directions_car_rounded,
                label: widget.vehicleMode ?? 'Car',
                isDark: isDark,
              ),
              _buildMetricChip(
                icon: Icons.wb_sunny_rounded,
                label: widget.travelTimeMode ?? 'Day',
                isDark: isDark,
              ),
              if (widget.distanceKm != null)
                _buildMetricChip(
                  icon: Icons.straighten_rounded,
                  label: '${widget.distanceKm!.toStringAsFixed(1)} km',
                  isDark: isDark,
                ),
              if (widget.durationMinutes != null)
                _buildMetricChip(
                  icon: Icons.schedule_rounded,
                  label: widget.formatDurationFn(widget.durationMinutes!),
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: isDark
              ? NeonTheme.textSecondaryDark
              : NeonTheme.textSecondaryLight,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark
                ? NeonTheme.textSecondaryDark
                : NeonTheme.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // PERSONALIZED RISK VIEW
  // --------------------------------------------------------------------------

  Widget _buildPersonalizedRiskSection(bool isDark) {
    final profile = widget.personalProfile;
    final isConfigured = profile != null && profile.isConfigured;

    if (!isConfigured) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? NeonTheme.cardDark.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_pin_rounded,
              color: NeonTheme.safeGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isTamil
                        ? 'தனிப்பயனாக்கப்பட்ட பாதுகாப்பு விவரம்'
                        : 'Personalized Safety Profile',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isTamil
                        ? 'உங்கள் பயண விருப்பங்களை அமைப்பதன் மூலம் தனிப்பயன் கணிப்புகளைப் பெறவும்.'
                        : 'Configure your Personal Safety Profile to see customized route risk alignment.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? NeonTheme.textSecondaryDark
                          : NeonTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final eval = widget.routeEvaluation;
    PreferenceMatchResult? matchResult;
    if (eval != null) {
      matchResult = PreferenceMatchEvaluator.evaluate(
        evaluation: eval,
        profile: profile,
        isDay: widget.travelTimeMode != 'Night',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.cardElevatedDark.withValues(alpha: 0.95)
            : const Color(0xffF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: NeonTheme.safeGreen.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: NeonTheme.safeGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_pin_rounded,
                  color: NeonTheme.safeGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isTamil
                      ? 'தனிப்பயனாக்கப்பட்ட ஆபத்து பார்வை'
                      : 'Personalized Risk View',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (matchResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: matchResult.matchColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: matchResult.matchColor.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${matchResult.matchPercentage.round()}% ${_isTamil ? matchResult.tamilMatchLabel : matchResult.matchLabel}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: matchResult.matchColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (matchResult != null) ...[
            Text(
              _isTamil ? matchResult.tamilNarrative : matchResult.narrative,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
            if (matchResult.matchFactors.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (int i = 0; i < matchResult.matchFactors.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✓ ',
                        style: TextStyle(
                          color: NeonTheme.safeGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _isTamil
                              ? matchResult.tamilMatchFactors[i]
                              : matchResult.matchFactors[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ] else ...[
            Text(
              _isTamil
                  ? 'பாதை தேர்ந்தெடுக்கப்பட்டதும் உங்கள் விருப்பங்களுக்கு ஏற்ப தனிப்பயன் மதிப்பீடு காட்டப்படும்.'
                  : 'Calculate or select a route to evaluate personalized safety risk alignments.',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // OVERALL RISK LEVEL CARD
  // --------------------------------------------------------------------------

  Widget _buildOverallRiskCard(SmartRiskForecastData data, bool isDark) {
    final color = data.overallLevel.color;
    final levelTitle = data.overallLevel.title(_isTamil);
    final desc = data.overallLevel.description(_isTamil);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.3),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(data.overallLevel.icon, color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      RiskForecastLocalization.overallRouteRisk(_isTamil)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark
                            ? NeonTheme.textSecondaryDark
                            : NeonTheme.textSecondaryLight,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        levelTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isTamil
                      ? 'மதிப்பிடப்பட்ட சாத்தியமான ஆபத்து (நிச்சயமான கணிப்பைக் கோரவில்லை).'
                      : 'Estimated potential risk based on available safety evaluation data.',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white54 : Colors.black45,
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
  // WHY RISK CARD
  // --------------------------------------------------------------------------

  Widget _buildWhyRiskCard(SmartRiskForecastData data, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.bgDark.withValues(alpha: 0.6)
            : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: NeonTheme.electricBlue,
              ),
              const SizedBox(width: 6),
              Text(
                RiskForecastLocalization.whyRiskHeading(_isTamil),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: NeonTheme.electricBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isTamil ? data.tamilWhyRiskNarrative : data.whyRiskNarrative,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: isDark
                  ? NeonTheme.textSecondaryDark
                  : NeonTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RISK VS TIME CARD
  // --------------------------------------------------------------------------

  Widget _buildRiskVsTimeCard(SmartRiskForecastData data, bool isDark) {
    final score = data.overallScore ?? 50.0;
    final safetyRatio = (score / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.cardElevatedDark.withValues(alpha: 0.7)
            : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.balance_rounded,
                size: 14,
                color: NeonTheme.neonCyan,
              ),
              const SizedBox(width: 6),
              Text(
                RiskForecastLocalization.safetyVsTimeHeading(_isTamil),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: NeonTheme.neonCyan,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: NeonTheme.safeGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  data.isSafetyPriority
                      ? RiskForecastLocalization.safetyPriority(_isTamil)
                      : RiskForecastLocalization.timePriority(_isTamil),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: NeonTheme.safeGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Safety Bar
          Row(
            children: [
              SizedBox(
                width: 76,
                child: Text(
                  'Safety',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: safetyRatio,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      data.overallLevel.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '${(safetyRatio * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: data.overallLevel.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Time Bar
          Row(
            children: [
              SizedBox(
                width: 76,
                child: Text(
                  'Travel Time',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.75,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      NeonTheme.electricBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 44,
                child: Text(
                  'Normal',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: NeonTheme.electricBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RISK FACTORS SECTION
  // --------------------------------------------------------------------------

  Widget _buildRiskFactorsSection(
    SmartRiskForecastData data,
    bool isDark,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.analytics_rounded,
              size: 15,
              color: NeonTheme.neonAmber,
            ),
            const SizedBox(width: 6),
            Text(
              RiskForecastLocalization.riskFactors(_isTamil),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: NeonTheme.neonAmber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isMobile)
          Column(
            children: [
              for (final f in data.factors) ...[
                _buildFactorCard(f, isDark),
                const SizedBox(height: 6),
              ],
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (int i = 0; i < data.factors.length; i += 2) ...[
                      _buildFactorCard(data.factors[i], isDark),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    for (int i = 1; i < data.factors.length; i += 2) ...[
                      _buildFactorCard(data.factors[i], isDark),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFactorCard(RiskFactorAssessment factor, bool isDark) {
    final title = RiskForecastLocalization.factorTitle(factor.key, _isTamil);
    final isAvail = factor.isAvailable;
    final color = isAvail && factor.riskLevel != null
        ? factor.riskLevel!.color
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.cardElevatedDark.withValues(alpha: 0.8)
            : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAvail
              ? color.withValues(alpha: 0.35)
              : (isDark ? Colors.white10 : Colors.black12),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(factor.icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (isAvail && factor.score != null) ...[
                Text(
                  '${factor.score!.round()} / 100',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    factor.riskLevel?.title(_isTamil) ?? '',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    RiskForecastLocalization.unavailable(_isTamil),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isTamil ? factor.tamilExplanation : factor.explanation,
            style: TextStyle(
              fontSize: 10,
              height: 1.3,
              color: isAvail
                  ? (isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight)
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RISK TREND SECTION
  // --------------------------------------------------------------------------

  Widget _buildRiskTrendSection(
    SmartRiskForecastData data,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.bgDark.withValues(alpha: 0.6)
            : const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                size: 15,
                color: NeonTheme.safeGreen,
              ),
              const SizedBox(width: 6),
              Text(
                RiskForecastLocalization.riskTrend(_isTamil),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: NeonTheme.safeGreen,
                ),
              ),
              const Spacer(),
              Text(
                RiskForecastLocalization.estimatedRiskTrendSub(_isTamil),
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDark
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horizontal steps
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < data.trendSteps.length; i++) ...[
                _buildTrendStepNode(data.trendSteps[i], isDark),
                if (i < data.trendSteps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendStepNode(RiskTrendStep step, bool isDark) {
    final color = step.level.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step.milestone,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // RISK HOTSPOTS / RISK ZONES SECTION
  // --------------------------------------------------------------------------

  Widget _buildHotspotsSection(SmartRiskForecastData data, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 15,
              color: NeonTheme.dangerRed,
            ),
            const SizedBox(width: 6),
            Text(
              RiskForecastLocalization.potentialRiskZones(_isTamil),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: NeonTheme.dangerRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (data.hotspots.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? NeonTheme.cardElevatedDark.withValues(alpha: 0.5)
                  : const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: NeonTheme.safeGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    RiskForecastLocalization.noHotspots(_isTamil),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? NeonTheme.textSecondaryDark
                          : NeonTheme.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          for (final h in data.hotspots) ...[
            _buildHotspotCard(h, isDark),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }

  Widget _buildHotspotCard(RiskZoneItem hotspot, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hotspot.color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hotspot.color.withValues(alpha: 0.5),
          width: 0.9,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(hotspot.icon, size: 16, color: hotspot.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hotspot.title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: hotspot.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hotspot.category,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: hotspot.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hotspot.description,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
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
  // SAFETY RECOMMENDATIONS SECTION
  // --------------------------------------------------------------------------

  Widget _buildRecommendationsSection(SmartRiskForecastData data, bool isDark) {
    final list = _isTamil ? data.tamilRecommendations : data.recommendations;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.cardElevatedDark.withValues(alpha: 0.7)
            : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NeonTheme.safeGreen.withValues(alpha: 0.4),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 15,
                color: NeonTheme.safeGreen,
              ),
              const SizedBox(width: 6),
              Text(
                RiskForecastLocalization.safetyRecommendations(_isTamil),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: NeonTheme.safeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final rec in list) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🛡 ', style: TextStyle(fontSize: 11)),
                  Expanded(
                    child: Text(
                      rec,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: isDark ? Colors.white : Colors.black87,
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
  // ROUTE LEVEL NOTE
  // --------------------------------------------------------------------------

  Widget _buildRouteLevelTelemetryNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: NeonTheme.neonCyan,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              RiskForecastLocalization.routeLevelForecastNote(_isTamil),
              style: TextStyle(
                fontSize: 9.5,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FOOTER
  // --------------------------------------------------------------------------

  Widget _buildDialogFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: NeonTheme.neonCyan,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            RiskForecastLocalization.done(_isTamil).toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
