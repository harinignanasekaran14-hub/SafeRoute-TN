// ============================================================================
// SafeRoute TN — Personal Safety Profile + Smart Preferences
// Module: lib/personal_safety_profile.dart
// Description: Allows users to configure local travel & safety preferences.
//              Strictly client-side persistence in SharedPreferences.
//              No precise GPS tracking. Zero external API calls.
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

// ============================================================================
// PROFILE MODEL
// ============================================================================

class PersonalSafetyProfile {
  final String vehicleMode;
  final String safetyPriority;
  final String safetyMode; // 'General', 'Women Safety', 'Senior Friendly', 'Family Safety'
  final String nightLightingPreference;
  final String weatherPreference;
  final String roadConditionPreference;
  final String accessibilityPreference;
  final bool preferEmergencyCoverage;
  final bool avoidPoorRoads;
  final String travelPurpose;
  final bool isConfigured;
  final DateTime? updatedAt;

  String get travelMode => vehicleMode;

  const PersonalSafetyProfile({
    this.vehicleMode = 'Car',
    this.safetyPriority = 'Safer Route',
    this.safetyMode = 'General',
    this.nightLightingPreference = 'Prefer well-lit roads',
    this.weatherPreference = 'Prefer safer weather conditions',
    this.roadConditionPreference = 'Prefer better road surfaces',
    this.accessibilityPreference = 'Standard',
    this.preferEmergencyCoverage = false,
    this.avoidPoorRoads = false,
    this.travelPurpose = 'Daily commute',
    this.isConfigured = true,
    this.updatedAt,
  });

  static const defaultVehicle = 'Car';
  static const defaultPriority = 'Safer Route';
  static const defaultSafetyMode = 'General';
  static const defaultLighting = 'Prefer well-lit roads';
  static const defaultWeather = 'Prefer safer weather conditions';
  static const defaultRoad = 'Prefer better road surfaces';
  static const defaultAccessibility = 'Standard';
  static const defaultPurpose = 'Daily commute';

  static const List<String> travelModes = ['Car', 'Bike', 'Bus', 'Walk'];
  static const List<String> safetyPriorities = [
    'Safer Route',
    'Faster Route',
    'Balanced',
  ];
  static const List<String> safetyModes = [
    'General',
    'Women Safety',
    'Senior Friendly',
    'Family Safety',
  ];
  static const List<String> nightLightingOptions = [
    'Prefer well-lit roads',
    'No special preference',
    'Avoid poorly lit roads',
    'Avoid poorly lit roads when possible',
  ];
  static const List<String> weatherOptions = [
    'Prefer safer weather',
    'Prefer safer weather conditions',
    'No special preference',
    'Avoid higher risk weather',
    'Avoid routes with higher weather-related risk when alternatives exist',
  ];
  static const List<String> roadConditionOptions = [
    'Prefer better road surfaces',
    'No special preference',
    'Avoid poor road conditions',
    'Strongly avoid poor road conditions',
  ];
  static const List<String> accessibilityOptions = [
    'Standard',
    'Prefer accessible routes',
  ];
  static const List<String> travelPurposes = [
    'Daily commute',
    'College',
    'College / Education',
    'Work',
    'Family travel',
    'Long-distance',
    'Long-distance travel',
    'Other',
  ];

  static PersonalSafetyProfile defaultProfile() =>
      const PersonalSafetyProfile(isConfigured: true);

  static PersonalSafetyProfile unconfiguredProfile() =>
      const PersonalSafetyProfile(isConfigured: false);

  PersonalSafetyProfile copyWith({
    String? vehicleMode,
    String? travelMode,
    String? safetyPriority,
    String? safetyMode,
    String? nightLightingPreference,
    String? weatherPreference,
    String? roadConditionPreference,
    String? accessibilityPreference,
    bool? preferEmergencyCoverage,
    bool? avoidPoorRoads,
    String? travelPurpose,
    bool? isConfigured,
    DateTime? updatedAt,
  }) {
    return PersonalSafetyProfile(
      vehicleMode: travelMode ?? vehicleMode ?? this.vehicleMode,
      safetyPriority: safetyPriority ?? this.safetyPriority,
      safetyMode: safetyMode ?? this.safetyMode,
      nightLightingPreference:
          nightLightingPreference ?? this.nightLightingPreference,
      weatherPreference: weatherPreference ?? this.weatherPreference,
      roadConditionPreference:
          roadConditionPreference ?? this.roadConditionPreference,
      accessibilityPreference:
          accessibilityPreference ?? this.accessibilityPreference,
      preferEmergencyCoverage:
          preferEmergencyCoverage ?? this.preferEmergencyCoverage,
      avoidPoorRoads: avoidPoorRoads ?? this.avoidPoorRoads,
      travelPurpose: travelPurpose ?? this.travelPurpose,
      isConfigured: isConfigured ?? this.isConfigured,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicle_mode': vehicleMode,
    'travel_mode': vehicleMode,
    'safety_priority': safetyPriority,
    'safety_mode': safetyMode,
    'night_lighting_preference': nightLightingPreference,
    'weather_preference': weatherPreference,
    'road_condition_preference': roadConditionPreference,
    'accessibility_preference': accessibilityPreference,
    'prefer_emergency_coverage': preferEmergencyCoverage,
    'avoid_poor_roads': avoidPoorRoads,
    'travel_purpose': travelPurpose,
    'is_configured': isConfigured,
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  factory PersonalSafetyProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['updated_at'] != null) {
      try {
        parsedDate = DateTime.parse(json['updated_at'] as String);
      } catch (_) {}
    }

    return PersonalSafetyProfile(
      vehicleMode:
          (json['vehicle_mode'] ?? json['travel_mode']) as String? ??
          defaultVehicle,
      safetyPriority: json['safety_priority'] as String? ?? defaultPriority,
      safetyMode: json['safety_mode'] as String? ?? defaultSafetyMode,
      nightLightingPreference:
          (json['night_lighting_preference'] ?? json['night_lighting'])
              as String? ??
          defaultLighting,
      weatherPreference:
          (json['weather_preference'] ?? json['weather_safety']) as String? ??
          defaultWeather,
      roadConditionPreference:
          (json['road_condition_preference'] ?? json['road_condition'])
              as String? ??
          defaultRoad,
      accessibilityPreference:
          (json['accessibility_preference'] ?? json['accessibility'])
              as String? ??
          defaultAccessibility,
      preferEmergencyCoverage:
          json['prefer_emergency_coverage'] as bool? ?? false,
      avoidPoorRoads: json['avoid_poor_roads'] as bool? ?? false,
      travelPurpose: json['travel_purpose'] as String? ?? defaultPurpose,
      isConfigured: json['is_configured'] as bool? ?? true,
      updatedAt: parsedDate,
    );
  }
}

// ============================================================================
// STORAGE HELPERS (SHARED PREFERENCES)
// ============================================================================

class PersonalSafetyProfileStorage {
  static const String storageKey = 'saferoute_personal_safety_profile';

  static Future<PersonalSafetyProfile> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return PersonalSafetyProfile.unconfiguredProfile();
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return PersonalSafetyProfile.fromJson(decoded);
    } catch (_) {
      return PersonalSafetyProfile.unconfiguredProfile();
    }
  }

  static Future<bool> saveProfile(PersonalSafetyProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(profile.toJson());
      return await prefs.setString(storageKey, encoded);
    } catch (_) {
      return false;
    }
  }

  static Future<PersonalSafetyProfile> resetProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
    return PersonalSafetyProfile.unconfiguredProfile();
  }
}

// ============================================================================
// LOCALIZATION (ENGLISH & TAMIL)
// ============================================================================

class SafetyProfileLocalization {
  static String title(bool isTamil) => isTamil
      ? 'தனிப்பட்ட பாதுகாப்பு விவரக்குறிப்பு'
      : 'Personal Safety Profile';

  static String subtitle(bool isTamil) => isTamil
      ? 'நீங்கள் எவ்வாறு பயணிக்க விரும்புகிறீர்கள் என்பதை SafeRoute TN-க்கு தெரிவிக்கவும்.'
      : 'Tell SafeRoute TN how you prefer to travel.';

  static String cardTitle(bool isTamil) => isTamil
      ? 'தனிப்பட்ட பாதுகாப்பு விவரக்குறிப்பு'
      : 'Personal Safety Profile';

  static String cardSubtitle(bool isTamil) => isTamil
      ? 'உங்கள் பயண விருப்பங்களுக்கு SafeRoute TN-ஐ தனிப்பயனாக்குங்கள்'
      : 'Customize SafeRoute TN for your travel preferences';

  static String managePreferences(bool isTamil) =>
      isTamil ? 'விருப்பங்களை நிர்வகி' : 'Manage Preferences';

  static String editPreferences(bool isTamil) =>
      isTamil ? 'விருப்பங்களைத் திருத்து' : 'Edit Preferences';

  static String noPreferencesConfigured(bool isTamil) => isTamil
      ? 'இன்னும் விருப்பங்கள் கட்டமைக்கப்படவில்லை.'
      : 'No preferences configured yet.';

  static String travelModeHeading(bool isTamil) =>
      isTamil ? 'பயண முறை (Travel Mode)' : 'Travel Mode';

  static String safetyPriorityHeading(bool isTamil) => isTamil
      ? 'உங்களுக்கு மிகவும் முக்கியமானது எது?'
      : 'What matters most to you?';

  static String saferRoute(bool isTamil) =>
      isTamil ? 'அதிக பாதுகாப்பு வழி' : 'Safer Route';

  static String saferRouteDesc(bool isTamil) => isTamil
      ? 'பயணம் அதிக நேரம் எடுத்தாலும் பாதுகாப்பிற்கு முன்னுரிமை அளியுங்கள்.'
      : 'Prefer safety even if the journey takes longer.';

  static String fasterRoute(bool isTamil) =>
      isTamil ? 'வேகமான வழி' : 'Faster Route';

  static String fasterRouteDesc(bool isTamil) => isTamil
      ? 'ஏற்றுக்கொள்ளக்கூடிய பாதுகாப்பை பராமரிக்கும் போது குறைவான பயண நேரத்தை விரும்புங்கள்.'
      : 'Prefer shorter travel time while maintaining acceptable safety.';

  static String balanced(bool isTamil) =>
      isTamil ? 'சமநிலையான வழி' : 'Balanced';

  static String balancedDesc(bool isTamil) => isTamil
      ? 'பாதுகாப்பு மற்றும் பயண நேரத்தை சமநிலைப்படுத்துங்கள்.'
      : 'Balance safety and travel time.';

  static String nightTravelHeading(bool isTamil) =>
      isTamil ? 'இரவு நேரப் பயணம்' : 'Night Travel';

  static String preferWellLit(bool isTamil) =>
      isTamil ? 'நன்றாக வெளிச்சம் உள்ள சாலைகள்' : 'Prefer well-lit roads';

  static String noSpecialPref(bool isTamil) =>
      isTamil ? 'சிறப்பு விருப்பம் இல்லை' : 'No special preference';

  static String avoidPoorlyLit(bool isTamil) => isTamil
      ? 'குறைந்த வெளிச்சம் உள்ள சாலைகளைத் தவிர்க்கவும்'
      : 'Avoid poorly lit roads when possible';

  static String weatherHeading(bool isTamil) =>
      isTamil ? 'வானிலை பாதுகாப்பு' : 'Weather Safety';

  static String preferSaferWeather(bool isTamil) => isTamil
      ? 'பாதுகாப்பான வானிலை நிலைகளுக்கு முன்னுரிமை'
      : 'Prefer safer weather conditions';

  static String avoidRiskWeather(bool isTamil) => isTamil
      ? 'வானிலை அபாயம் உள்ள வழிகளைத் தவிர்க்கவும்'
      : 'Avoid routes with higher weather-related risk when alternatives exist';

  static String roadConditionHeading(bool isTamil) =>
      isTamil ? 'சாலை நிலை' : 'Road Condition';

  static String preferBetterRoads(bool isTamil) => isTamil
      ? 'சிறந்த சாலை மேற்பரப்புகளுக்கு முன்னுரிமை'
      : 'Prefer better road surfaces';

  static String avoidPoorRoads(bool isTamil) => isTamil
      ? 'மோசமான சாலை நிலைகளைத் தவிர்க்கவும்'
      : 'Strongly avoid poor road conditions';

  static String accessibilityHeading(bool isTamil) =>
      isTamil ? 'அணுகல்தன்மை' : 'Accessibility';

  static String standardAccess(bool isTamil) =>
      isTamil ? 'வழக்கமான முறை' : 'Standard';

  static String preferAccessible(bool isTamil) => isTamil
      ? 'அணுகக்கூடிய வழிகளுக்கு முன்னுரிமை'
      : 'Prefer accessible routes';

  static String travelContextHeading(bool isTamil) =>
      isTamil ? 'பயண சூழல் / நோக்கம்' : 'Travel Purpose / Context';

  static String dailyCommute(bool isTamil) =>
      isTamil ? 'தினசரி பயணம்' : 'Daily commute';

  static String collegeEducation(bool isTamil) =>
      isTamil ? 'கல்லூரி / கல்வி' : 'College / Education';

  static String work(bool isTamil) => isTamil ? 'பணி / வேலை' : 'Work';

  static String familyTravel(bool isTamil) =>
      isTamil ? 'குடும்பப் பயணம்' : 'Family travel';

  static String longDistance(bool isTamil) =>
      isTamil ? 'நீண்ட தூரப் பயணம்' : 'Long-distance travel';

  static String other(bool isTamil) => isTamil ? 'மற்றவை' : 'Other';

  static String privacyNote(bool isTamil) => isTamil
      ? 'தனியுரிமை: உங்கள் விருப்பங்கள் இந்த சாதனத்தில் மட்டுமே சேமிக்கப்படும். அவை SafeRoute TN backend-க்கு அனுப்பப்படாது.'
      : 'Your preferences are stored locally on this device and are not sent to the SafeRoute TN backend.';

  static String resetPreferences(bool isTamil) =>
      isTamil ? 'விருப்பங்களை மீட்டமை' : 'Reset Preferences';

  static String resetConfirmTitle(bool isTamil) => isTamil
      ? 'பாதுகாப்பு சுயவிவரத்தை மீட்டமைக்கவா?'
      : 'Reset Safety Profile?';

  static String resetConfirmDesc(bool isTamil) => isTamil
      ? 'சேமிக்கப்பட்ட உங்கள் வழி விருப்பங்கள் அழிக்கப்படும்.'
      : 'Your saved route preferences will be cleared.';

  static String save(bool isTamil) => isTamil ? 'சேமி' : 'Save Preferences';

  static String cancel(bool isTamil) => isTamil ? 'ரத்து' : 'Cancel';

  static String applyToRoute(bool isTamil) =>
      isTamil ? 'என் விருப்பங்களைப் பயன்படுத்து' : 'Apply My Preferences';

  static String preferenceMatch(bool isTamil) =>
      isTamil ? 'விருப்பப் பொருத்தம்' : 'Preference Match';

  static String bestMatchForYou(bool isTamil) =>
      isTamil ? 'உங்களுக்கான சிறந்த பொருத்தம்' : 'Best Match for You';

  static String personalizedRiskView(bool isTamil) =>
      isTamil ? 'தனிப்பயனாக்கப்பட்ட ஆபத்து பார்வை' : 'Personalized Risk View';

  static String saveButton(bool isTamil) => applyToRoute(isTamil);

  static String resetButton(bool isTamil) => resetPreferences(isTamil);
}

// ============================================================================
// PREFERENCE MATCH RESULT & DETERMINISTIC EVALUATOR
// ============================================================================

class PreferenceMatchResult {
  final double matchPercentage;
  final String matchLabel;
  final String tamilMatchLabel;
  final Color matchColor;
  final List<String> matchFactors;
  final List<String> tamilMatchFactors;
  final String narrative;
  final String tamilNarrative;

  const PreferenceMatchResult({
    required this.matchPercentage,
    required this.matchLabel,
    required this.tamilMatchLabel,
    required this.matchColor,
    required this.matchFactors,
    required this.tamilMatchFactors,
    required this.narrative,
    required this.tamilNarrative,
  });
}

class PreferenceMatchEvaluator {
  static PreferenceMatchResult evaluate({
    required RouteEvaluation evaluation,
    required PersonalSafetyProfile profile,
    required bool isDay,
  }) {
    double totalWeight = 0.0;
    double accumulatedScore = 0.0;
    final matchFactors = <String>[];
    final tamilMatchFactors = <String>[];

    SafetyFactor? findFactor(String key) {
      for (final f in evaluation.safety.factors) {
        if (f.title == key ||
            (key == 'Accident Risk' && f.title == 'Verified blackspots') ||
            (key == 'Road Condition' && f.title == 'Road condition') ||
            (key == 'Traffic' && f.title == 'Live Traffic')) {
          return f;
        }
      }
      return null;
    }

    // 1. Safety Priority vs Travel Time
    final routeSafetyScore = evaluation.safety.score;
    if (routeSafetyScore != null) {
      if (profile.safetyPriority == 'Safer Route') {
        const weight = 35.0;
        totalWeight += weight;
        accumulatedScore += (routeSafetyScore / 100.0) * weight;
        if (routeSafetyScore >= 70) {
          matchFactors.add(
            'High safety score aligned with safer route preference',
          );
          tamilMatchFactors.add(
            'பாதுகாப்பான வழி விருப்பத்துடன் ஒத்துப்போகும் அதிக பாதுகாப்பு',
          );
        }
      } else if (profile.safetyPriority == 'Faster Route') {
        const weight = 35.0;
        totalWeight += weight;
        final speedBonus = evaluation.traffic?.meanSpeedRatio != null
            ? (evaluation.traffic!.meanSpeedRatio.clamp(0.4, 1.2) / 1.2) * 100
            : (routeSafetyScore);
        accumulatedScore += (speedBonus / 100.0) * weight;
        if (speedBonus >= 70) {
          matchFactors.add(
            'Optimal travel speeds aligned with faster route preference',
          );
          tamilMatchFactors.add(
            'வேகமான வழி விருப்பத்துடன் ஒத்துப்போகும் உகந்த வேகம்',
          );
        }
      } else {
        // Balanced
        const weight = 35.0;
        totalWeight += weight;
        final balancedScore = (routeSafetyScore * 0.7) + 30.0;
        accumulatedScore += (balancedScore / 100.0) * weight;
        matchFactors.add('Balanced safety and transit ratio');
        tamilMatchFactors.add('சமநிலையான பாதுகாப்பு மற்றும் பயண விகிதம்');
      }
    }

    // 2. Road Condition Preference
    final roadFactor = findFactor('Road Condition');
    if (roadFactor != null && roadFactor.relevant && roadFactor.score != null) {
      if (profile.roadConditionPreference != 'No special preference') {
        const weight = 25.0;
        totalWeight += weight;
        accumulatedScore += (roadFactor.score! / 100.0) * weight;
        if (roadFactor.score! >= 65) {
          matchFactors.add(
            'Smooth, paved surfaces matching road condition preference',
          );
          tamilMatchFactors.add(
            'சாலை நிலை விருப்பத்திற்கு ஏற்ற செப்பனிடப்பட்ட சாலை',
          );
        }
      }
    }

    // 3. Night Lighting Preference (only relevant if not daytime)
    final lightFactor = findFactor('Lighting');
    if (!isDay &&
        lightFactor != null &&
        lightFactor.relevant &&
        lightFactor.score != null) {
      if (profile.nightLightingPreference != 'No special preference') {
        const weight = 15.0;
        totalWeight += weight;
        accumulatedScore += (lightFactor.score! / 100.0) * weight;
        if (lightFactor.score! >= 65) {
          matchFactors.add(
            'Well-illuminated night segments matching lighting preference',
          );
          tamilMatchFactors.add(
            'வெளிச்ச விருப்பத்திற்கு ஏற்ற இரவு நேர தெருவிளக்குகள்',
          );
        }
      }
    }

    // 4. Weather Preference
    final weatherFactor = findFactor('Weather');
    if (weatherFactor != null &&
        weatherFactor.relevant &&
        weatherFactor.score != null) {
      if (profile.weatherPreference != 'No special preference') {
        const weight = 15.0;
        totalWeight += weight;
        accumulatedScore += (weatherFactor.score! / 100.0) * weight;
        if (weatherFactor.score! >= 70) {
          matchFactors.add(
            'Clear weather conditions matching weather safety preference',
          );
          tamilMatchFactors.add(
            'வானிலை பாதுகாப்பு விருப்பத்திற்கு ஏற்ற சாதகமான சூழல்',
          );
        }
      }
    }

    // 5. Accessibility Preference
    final accessFactor = findFactor('Accessibility');
    if (accessFactor != null &&
        accessFactor.relevant &&
        accessFactor.score != null) {
      if (profile.accessibilityPreference == 'Prefer accessible routes') {
        const weight = 10.0;
        totalWeight += weight;
        accumulatedScore += (accessFactor.score! / 100.0) * weight;
        if (accessFactor.score! >= 60) {
          matchFactors.add(
            'Accessible sidewalk and infrastructure tags verified',
          );
          tamilMatchFactors.add(
            'சரிபார்க்கப்பட்ட நடைபாதை மற்றும் அணுகல் வசதிகள்',
          );
        }
      }
    }

    // Compute percentage strictly from available factors
    final double matchPercent = totalWeight > 0
        ? ((accumulatedScore / totalWeight) * 100).clamp(10.0, 99.0)
        : (routeSafetyScore ?? 75.0);

    final String label;
    final String tamilLabel;
    final Color color;

    if (matchPercent >= 80) {
      label = 'High Preference Match';
      tamilLabel = 'அதிக விருப்பப் பொருத்தம்';
      color = NeonTheme.safeGreen;
    } else if (matchPercent >= 60) {
      label = 'Moderate Preference Match';
      tamilLabel = 'மிதமான விருப்பப் பொருத்தம்';
      color = NeonTheme.neonAmber;
    } else {
      label = 'Lower Preference Match';
      tamilLabel = 'குறைந்த விருப்பப் பொருத்தம்';
      color = const Color(0xffF97316);
    }

    final narrative =
        'This route achieves a ${matchPercent.round()}% match with your personal safety profile${matchFactors.isNotEmpty ? ' based on ${matchFactors.join(", ")}.' : '.'}';

    final tamilNarrative =
        'இந்த வழி உங்கள் தனிப்பட்ட பாதுகாப்பு விவரக்குறிப்புடன் ${matchPercent.round()}% பொருந்துகின்றது${tamilMatchFactors.isNotEmpty ? ' (${tamilMatchFactors.join(", ")} அடிப்படையில்).' : '.'}';

    return PreferenceMatchResult(
      matchPercentage: matchPercent,
      matchLabel: label,
      tamilMatchLabel: tamilLabel,
      matchColor: color,
      matchFactors: matchFactors,
      tamilMatchFactors: tamilMatchFactors,
      narrative: narrative,
      tamilNarrative: tamilNarrative,
    );
  }
}

// ============================================================================
// PERSONAL SAFETY PROFILE DIALOG WIDGET
// ============================================================================

class PersonalSafetyProfileDialog extends StatefulWidget {
  final bool isDarkMode;
  final RouteEvaluation? activeRouteEvaluation;
  final bool isDay;
  final VoidCallback? onProfileSaved;
  final ValueChanged<String>? onApplyVehicleMode;

  const PersonalSafetyProfileDialog({
    super.key,
    required this.isDarkMode,
    this.activeRouteEvaluation,
    this.isDay = true,
    this.onProfileSaved,
    this.onApplyVehicleMode,
  });

  @override
  State<PersonalSafetyProfileDialog> createState() =>
      _PersonalSafetyProfileDialogState();
}

class _PersonalSafetyProfileDialogState
    extends State<PersonalSafetyProfileDialog> {
  bool _isTamil = false;
  bool _isLoading = true;
  PersonalSafetyProfile _profile = PersonalSafetyProfile.defaultProfile();

  @override
  void initState() {
    super.initState();
    _loadStoredProfile();
  }

  Future<void> _loadStoredProfile() async {
    final loaded = await PersonalSafetyProfileStorage.loadProfile();
    if (mounted) {
      setState(() {
        _profile = loaded.isConfigured
            ? loaded
            : PersonalSafetyProfile.defaultProfile();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAndClose() async {
    await PersonalSafetyProfileStorage.saveProfile(_profile);
    if (mounted) {
      widget.onProfileSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTamil
                ? '✓ விருப்பங்கள் வெற்றிகரமாக சேமிக்கப்பட்டன'
                : '✓ Safety preferences saved successfully',
          ),
          backgroundColor: NeonTheme.safeGreen,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dlgContext) {
        final isDark = widget.isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: NeonTheme.dangerRed.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          title: Text(
            SafetyProfileLocalization.resetConfirmTitle(_isTamil),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? NeonTheme.textPrimaryDark
                  : NeonTheme.textPrimaryLight,
            ),
          ),
          content: Text(
            SafetyProfileLocalization.resetConfirmDesc(_isTamil),
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? NeonTheme.textSecondaryDark
                  : NeonTheme.textSecondaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgContext).pop(false),
              child: Text(
                SafetyProfileLocalization.cancel(_isTamil),
                style: TextStyle(
                  color: isDark
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dlgContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: NeonTheme.dangerRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isTamil ? 'மீட்டமை' : 'Reset',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await PersonalSafetyProfileStorage.resetProfile();
      setState(() {
        _profile = PersonalSafetyProfile.unconfiguredProfile();
      });
      widget.onProfileSaved?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isTamil
                  ? 'சுயவிவரம் மீட்டமைக்கப்பட்டது'
                  : 'Safety profile preferences reset',
            ),
            backgroundColor: NeonTheme.electricBlue,
          ),
        );
      }
    }
  }

  void _applyToActiveRoute() {
    widget.onApplyVehicleMode?.call(_profile.vehicleMode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isTamil
              ? '✓ விருப்பங்கள் செயலில் உள்ள வழிக்கு பொருத்தப்பட்டன'
              : '✓ Preferences applied to route planner',
        ),
        backgroundColor: NeonTheme.safeGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 640;

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
            color: NeonTheme.safeGreen.withValues(alpha: 0.5),
            width: 1.4,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: NeonTheme.safeGreen.withValues(alpha: 0.22),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : NeonTheme.cardShadow(isDark),
        ),
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: NeonTheme.safeGreen),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildDialogHeader(isDark),
                  // Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Privacy Note
                          _buildPrivacyBanner(isDark),
                          const SizedBox(height: 12),

                          // Active Route Match Indicator (if route evaluation present)
                          if (widget.activeRouteEvaluation != null) ...[
                            _buildActiveRouteMatchCard(isDark),
                            const SizedBox(height: 14),
                          ] else ...[
                            _buildNoActiveRouteCard(isDark),
                            const SizedBox(height: 14),
                          ],

                          // 1. Travel Mode
                          _buildTravelModeSection(isDark),
                          const SizedBox(height: 14),

                          // 1.5. Safety Mode
                          _buildSafetyModeSection(isDark),
                          const SizedBox(height: 14),

                          // 2. Safety Priority
                          _buildSafetyPrioritySection(isDark),
                          const SizedBox(height: 14),

                          // 3. Night Lighting & Weather
                          _buildDualSection(
                            left: _buildNightLightingSection(isDark),
                            right: _buildWeatherSection(isDark),
                            isMobile: isMobile,
                          ),
                          const SizedBox(height: 14),

                          // 4. Road Condition & Accessibility
                          _buildDualSection(
                            left: _buildRoadConditionSection(isDark),
                            right: _buildAccessibilitySection(isDark),
                            isMobile: isMobile,
                          ),
                          const SizedBox(height: 14),

                          // 5. Travel Context / Purpose
                          _buildTravelPurposeSection(isDark),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  // Footer Actions
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
              color: NeonTheme.safeGreen.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_pin_rounded,
              color: NeonTheme.safeGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SafetyProfileLocalization.title(_isTamil),
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
                  SafetyProfileLocalization.subtitle(_isTamil),
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
          // English / தமிழ் Segmented Toggle
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _isTamil = false),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: !_isTamil
                          ? NeonTheme.neonCyan.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'English',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: !_isTamil
                            ? NeonTheme.neonCyan
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isTamil = true),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isTamil
                          ? NeonTheme.neonAmber.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'தமிழ்',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _isTamil
                            ? NeonTheme.neonAmber
                            : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ),
                ),
              ],
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
  // PRIVACY BANNER
  // --------------------------------------------------------------------------

  Widget _buildPrivacyBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NeonTheme.neonCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: NeonTheme.neonCyan.withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: NeonTheme.neonCyan,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              SafetyProfileLocalization.privacyNote(_isTamil),
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
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
  // ACTIVE ROUTE MATCH CARD
  // --------------------------------------------------------------------------

  Widget _buildActiveRouteMatchCard(bool isDark) {
    final eval = widget.activeRouteEvaluation!;
    final match = PreferenceMatchEvaluator.evaluate(
      evaluation: eval,
      profile: _profile,
      isDay: widget.isDay,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: match.matchColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: match.matchColor.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.thumb_up_rounded, size: 16, color: match.matchColor),
              const SizedBox(width: 8),
              Text(
                SafetyProfileLocalization.preferenceMatch(_isTamil),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: match.matchColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: match.matchColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${match.matchPercentage.round()}% MATCH',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: match.matchColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isTamil ? match.tamilNarrative : match.narrative,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _applyToActiveRoute,
              icon: const Icon(Icons.check_circle_outline, size: 13),
              label: Text(
                SafetyProfileLocalization.applyToRoute(_isTamil),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: match.matchColor,
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveRouteCard(bool isDark) {
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
          Icon(
            Icons.route_rounded,
            color: isDark
                ? NeonTheme.textSecondaryDark
                : NeonTheme.textSecondaryLight,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTamil
                      ? 'செயலில் உள்ள பாதை இல்லை'
                      : 'No active route loaded',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isTamil
                      ? 'நிகழ்நேர விருப்பப் பொருத்தத்தைக் காண ஒரு வழியைத் திட்டமிடுங்கள்.'
                      : 'Plan a route to see real-time preference alignment.',
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

  // --------------------------------------------------------------------------
  // 1. TRAVEL MODE
  // --------------------------------------------------------------------------

  Widget _buildTravelModeSection(bool isDark) {
    const modes = [
      ('Car', '🚗', 'Car'),
      ('Bike', '🏍', 'Bike'),
      ('Bus', '🚌', 'Bus'),
      ('Walk', '🚶', 'Walk'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SafetyProfileLocalization.travelModeHeading(_isTamil),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final m in modes) ...[
              Expanded(
                child: _buildSelectableChip(
                  label: '${m.$2} ${m.$3}',
                  isSelected:
                      _profile.vehicleMode.toLowerCase() == m.$1.toLowerCase(),
                  onTap: () {
                    setState(() {
                      _profile = _profile.copyWith(
                        vehicleMode: m.$1,
                        isConfigured: true,
                      );
                    });
                  },
                  isDark: isDark,
                  activeColor: NeonTheme.safeGreen,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 1.5. SAFETY MODE (Women Safety, Senior Friendly, Family Safety, General)
  // --------------------------------------------------------------------------

  Widget _buildSafetyModeSection(bool isDark) {
    final modes = [
      (
        'General',
        'General Safety',
        'Standard balanced safety intelligence across all verified route factors.',
        Icons.explore_rounded,
        NeonTheme.neonCyan,
      ),
      (
        'Women Safety',
        'Women Safety',
        'Prioritizes verified lighting, emergency coverage & low-risk night corridors.',
        Icons.security_rounded,
        const Color(0xffE879F9),
      ),
      (
        'Senior Friendly',
        'Senior Friendly',
        'Prioritizes accessibility, smooth road surfaces & medical services along route.',
        Icons.elderly_rounded,
        const Color(0xff38BDF8),
      ),
      (
        'Family Safety',
        'Family Safety',
        'Prioritizes accident-free corridors, favorable weather & emergency support.',
        Icons.family_restroom_rounded,
        NeonTheme.safeGreen,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isTamil ? 'பயண பாதுகாப்பு வகை' : 'Travel Safety Profile',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isTamil
              ? 'உங்கள் குறிப்பிட்ட பயணத் தேவைகளுக்கு ஏற்ப நுண்ணறிவைத் தேர்ந்தெடுக்கவும்'
              : 'Tailor route intelligence to your specific travel needs',
          style: TextStyle(
            fontSize: 10,
            color: isDark ? NeonTheme.textSecondaryDark : NeonTheme.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 8),
        for (final m in modes) ...[
          _buildPriorityCard(
            keyName: m.$1,
            title: m.$2,
            desc: m.$3,
            icon: m.$4,
            accentColor: m.$5,
            isSelected: _profile.safetyMode == m.$1,
            isDark: isDark,
            onTap: () {
              setState(() {
                _profile = _profile.copyWith(
                  safetyMode: m.$1,
                );
              });
            },
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

    // --------------------------------------------------------------------------
  // 2. SAFETY PRIORITY
  // --------------------------------------------------------------------------

  Widget _buildSafetyPrioritySection(bool isDark) {
    final priorities = [
      (
        'Safer Route',
        SafetyProfileLocalization.saferRoute(_isTamil),
        SafetyProfileLocalization.saferRouteDesc(_isTamil),
        Icons.shield_rounded,
        NeonTheme.safeGreen,
      ),
      (
        'Faster Route',
        SafetyProfileLocalization.fasterRoute(_isTamil),
        SafetyProfileLocalization.fasterRouteDesc(_isTamil),
        Icons.bolt_rounded,
        NeonTheme.electricBlue,
      ),
      (
        'Balanced',
        SafetyProfileLocalization.balanced(_isTamil),
        SafetyProfileLocalization.balancedDesc(_isTamil),
        Icons.balance_rounded,
        NeonTheme.neonCyan,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SafetyProfileLocalization.safetyPriorityHeading(_isTamil),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        for (final p in priorities) ...[
          _buildPriorityCard(
            keyName: p.$1,
            title: p.$2,
            desc: p.$3,
            icon: p.$4,
            accentColor: p.$5,
            isSelected: _profile.safetyPriority == p.$1,
            isDark: isDark,
            onTap: () {
              setState(() {
                _profile = _profile.copyWith(
                  safetyPriority: p.$1,
                  isConfigured: true,
                );
              });
            },
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildPriorityCard({
    required String keyName,
    required String title,
    required String desc,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: isDark ? 0.16 : 0.1)
              : (isDark
                    ? NeonTheme.cardElevatedDark.withValues(alpha: 0.5)
                    : const Color(0xffF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? accentColor : Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? accentColor
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isDark
                          ? NeonTheme.textSecondaryDark
                          : NeonTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 16, color: accentColor),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // DUAL COLUMN HELPER
  // --------------------------------------------------------------------------

  Widget _buildDualSection({
    required Widget left,
    required Widget right,
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 3. NIGHT LIGHTING & WEATHER SECTIONS
  // --------------------------------------------------------------------------

  Widget _buildNightLightingSection(bool isDark) {
    return _buildRadioGroupCard(
      title: '🌙 ${SafetyProfileLocalization.nightTravelHeading(_isTamil)}',
      subtitle: widget.isDay
          ? (_isTamil
                ? '(பகல் நேரப் பயணத்திற்கு குறைந்த பொருத்தப்பாடு)'
                : '(Limited relevance for daytime routes)')
          : null,
      options: [
        (
          'Prefer well-lit roads',
          SafetyProfileLocalization.preferWellLit(_isTamil),
        ),
        (
          'No special preference',
          SafetyProfileLocalization.noSpecialPref(_isTamil),
        ),
        (
          'Avoid poorly lit roads',
          SafetyProfileLocalization.avoidPoorlyLit(_isTamil),
        ),
      ],
      selectedValue: _profile.nightLightingPreference,
      onSelected: (val) {
        setState(() {
          _profile = _profile.copyWith(
            nightLightingPreference: val,
            isConfigured: true,
          );
        });
      },
      isDark: isDark,
    );
  }

  Widget _buildWeatherSection(bool isDark) {
    return _buildRadioGroupCard(
      title: '🌧 ${SafetyProfileLocalization.weatherHeading(_isTamil)}',
      options: [
        (
          'Prefer safer weather conditions',
          SafetyProfileLocalization.preferSaferWeather(_isTamil),
        ),
        (
          'No special preference',
          SafetyProfileLocalization.noSpecialPref(_isTamil),
        ),
        (
          'Avoid higher risk weather',
          SafetyProfileLocalization.avoidRiskWeather(_isTamil),
        ),
      ],
      selectedValue: _profile.weatherPreference,
      onSelected: (val) {
        setState(() {
          _profile = _profile.copyWith(
            weatherPreference: val,
            isConfigured: true,
          );
        });
      },
      isDark: isDark,
    );
  }

  // --------------------------------------------------------------------------
  // 4. ROAD CONDITION & ACCESSIBILITY SECTIONS
  // --------------------------------------------------------------------------

  Widget _buildRoadConditionSection(bool isDark) {
    return _buildRadioGroupCard(
      title: '🛣 ${SafetyProfileLocalization.roadConditionHeading(_isTamil)}',
      options: [
        (
          'Prefer better road surfaces',
          SafetyProfileLocalization.preferBetterRoads(_isTamil),
        ),
        (
          'No special preference',
          SafetyProfileLocalization.noSpecialPref(_isTamil),
        ),
        (
          'Avoid poor road conditions',
          SafetyProfileLocalization.avoidPoorRoads(_isTamil),
        ),
      ],
      selectedValue: _profile.roadConditionPreference,
      onSelected: (val) {
        setState(() {
          _profile = _profile.copyWith(
            roadConditionPreference: val,
            isConfigured: true,
          );
        });
      },
      isDark: isDark,
    );
  }

  Widget _buildAccessibilitySection(bool isDark) {
    return _buildRadioGroupCard(
      title: '♿ ${SafetyProfileLocalization.accessibilityHeading(_isTamil)}',
      options: [
        ('Standard', SafetyProfileLocalization.standardAccess(_isTamil)),
        (
          'Prefer accessible routes',
          SafetyProfileLocalization.preferAccessible(_isTamil),
        ),
      ],
      selectedValue: _profile.accessibilityPreference,
      onSelected: (val) {
        setState(() {
          _profile = _profile.copyWith(
            accessibilityPreference: val,
            isConfigured: true,
          );
        });
      },
      isDark: isDark,
    );
  }

  Widget _buildRadioGroupCard({
    required String title,
    String? subtitle,
    required List<(String, String)> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? NeonTheme.bgDark.withValues(alpha: 0.6)
            : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
          const SizedBox(height: 6),
          for (final opt in options) ...[
            InkWell(
              onTap: () => onSelected(opt.$1),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      selectedValue == opt.$1
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 14,
                      color: selectedValue == opt.$1
                          ? NeonTheme.safeGreen
                          : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: selectedValue == opt.$1
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selectedValue == opt.$1
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark
                                    ? NeonTheme.textSecondaryDark
                                    : NeonTheme.textSecondaryLight),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 5. TRAVEL CONTEXT / PURPOSE
  // --------------------------------------------------------------------------

  Widget _buildTravelPurposeSection(bool isDark) {
    final purposes = [
      ('Daily commute', SafetyProfileLocalization.dailyCommute(_isTamil)),
      (
        'College / Education',
        SafetyProfileLocalization.collegeEducation(_isTamil),
      ),
      ('Work', SafetyProfileLocalization.work(_isTamil)),
      ('Family travel', SafetyProfileLocalization.familyTravel(_isTamil)),
      (
        'Long-distance travel',
        SafetyProfileLocalization.longDistance(_isTamil),
      ),
      ('Other', SafetyProfileLocalization.other(_isTamil)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SafetyProfileLocalization.travelContextHeading(_isTamil),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in purposes) ...[
              _buildSelectableChip(
                label: p.$2,
                isSelected: _profile.travelPurpose == p.$1,
                onTap: () {
                  setState(() {
                    _profile = _profile.copyWith(
                      travelPurpose: p.$1,
                      isConfigured: true,
                    );
                  });
                },
                isDark: isDark,
                activeColor: NeonTheme.electricBlue,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.2 : 0.12)
              : (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected
                ? activeColor
                : (isDark
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FOOTER ACTIONS
  // --------------------------------------------------------------------------

  Widget _buildDialogFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _confirmReset,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: Text(
              SafetyProfileLocalization.resetPreferences(_isTamil),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(foregroundColor: NeonTheme.dangerRed),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _saveAndClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonTheme.safeGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              SafetyProfileLocalization.save(_isTamil).toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DASHBOARD SUMMARY CARD WIDGET
// ============================================================================

class PersonalSafetyProfileCard extends StatelessWidget {
  final bool isDarkMode;
  final PersonalSafetyProfile profile;
  final VoidCallback onManagePreferences;

  const PersonalSafetyProfileCard({
    super.key,
    required this.isDarkMode,
    required this.profile,
    required this.onManagePreferences,
  });

  @override
  Widget build(BuildContext context) {
    final isConfigured = profile.isConfigured;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode
            ? NeonTheme.cardDark.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: NeonTheme.safeGreen.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: NeonTheme.safeGreen.withValues(alpha: 0.25),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ]
            : null,
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
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Safety Profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Customize SafeRoute TN for your travel preferences',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode
                            ? NeonTheme.textSecondaryDark
                            : NeonTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onManagePreferences,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NeonTheme.safeGreen,
                  side: const BorderSide(color: NeonTheme.safeGreen, width: 1),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Manage Preferences',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!isConfigured) ...[
            Text(
              'No preferences configured yet.',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: isDarkMode ? Colors.white38 : Colors.black38,
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildSummaryBadge(
                  '${_modeEmoji(profile.vehicleMode)} ${profile.vehicleMode}',
                  NeonTheme.safeGreen,
                ),
                _buildSummaryBadge(
                  '🛡 ${profile.safetyPriority}',
                  NeonTheme.electricBlue,
                ),
                if (profile.nightLightingPreference != 'No special preference')
                  _buildSummaryBadge(
                    '🌙 ${profile.nightLightingPreference}',
                    const Color(0xffA855F7),
                  ),
                if (profile.roadConditionPreference != 'No special preference')
                  _buildSummaryBadge(
                    '🛣 ${profile.roadConditionPreference}',
                    NeonTheme.neonAmber,
                  ),
                if (profile.weatherPreference != 'No special preference')
                  _buildSummaryBadge(
                    '🌧 Weather Safety',
                    const Color(0xff3B82F6),
                  ),
                if (profile.accessibilityPreference ==
                    'Prefer accessible routes')
                  _buildSummaryBadge('♿ Accessible', NeonTheme.neonCyan),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _modeEmoji(String mode) => switch (mode) {
    'Bike' => '🏍',
    'Bus' => '🚌',
    'Walk' => '🚶',
    _ => '🚗',
  };
}
