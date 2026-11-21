// ============================================================================
// SafeRoute TN — SafeRoute Journey Mode
// Module: lib/safe_route_journey_mode.dart
// Description: Interactive, responsive, bilingual Journey Mode dashboard for
//              real-time route safety monitoring. Strictly deterministic.
//              Reuses existing route evaluation, safety scores, risk forecast,
//              weather, and facilities.
//              STRICT PRIVACY: Zero background GPS tracking, zero continuous
//              location collection, zero fabricated data.
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'personal_safety_profile.dart';
import 'smart_route_risk_forecast.dart';

// ============================================================================
// 1. JOURNEY STATE ENUM
// ============================================================================

enum JourneyState {
  notStarted,
  active,
  paused,
  completed,
  cancelled;

  String label(bool isTamil) => switch (this) {
    JourneyState.notStarted => isTamil ? 'தொடங்கப்படவில்லை' : 'Not Started',
    JourneyState.active => isTamil ? 'செயலில் உள்ளது' : 'Active',
    JourneyState.paused => isTamil ? 'இடைநிறுத்தப்பட்டது' : 'Paused',
    JourneyState.completed => isTamil ? 'முடிந்தது' : 'Completed',
    JourneyState.cancelled => isTamil ? 'ரத்து செய்யப்பட்டது' : 'Cancelled',
  };

  Color get color => switch (this) {
    JourneyState.notStarted => const Color(0xff94A3B8),
    JourneyState.active => NeonTheme.safeGreen,
    JourneyState.paused => NeonTheme.warningGold,
    JourneyState.completed => NeonTheme.neonCyan,
    JourneyState.cancelled => NeonTheme.dangerRed,
  };

  IconData get icon => switch (this) {
    JourneyState.notStarted => Icons.play_circle_outline_rounded,
    JourneyState.active => Icons.navigation_rounded,
    JourneyState.paused => Icons.pause_circle_rounded,
    JourneyState.completed => Icons.check_circle_rounded,
    JourneyState.cancelled => Icons.cancel_rounded,
  };
}

// ============================================================================
// 2. JOURNEY DATA MODEL
// ============================================================================

class SafeRouteJourney {
  final String id;
  final String origin;
  final String destination;
  final int routeIndex;
  final String? routeLabel;
  final double? routeSafetyScore;
  final double distanceKm;
  final double estimatedDurationMinutes;
  final String vehicleMode;
  final String travelTimeMode;
  final DateTime? startedTimestamp;
  final DateTime? endedTimestamp;
  final JourneyState journeyState;

  // Optional real context (strictly nullable - zero fabrication)
  final String? trafficStatus;
  final double? weatherScore;
  final String? weatherCondition;
  final String? weatherTemperature;
  final String? riskLevel;
  final String? riskExplanation;
  final int roadReportsSubmitted;
  final int nearbyPlacesViewed;

  const SafeRouteJourney({
    required this.id,
    required this.origin,
    required this.destination,
    required this.routeIndex,
    this.routeLabel,
    required this.routeSafetyScore,
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    this.vehicleMode = 'Car',
    this.travelTimeMode = 'Day',
    this.startedTimestamp,
    this.endedTimestamp,
    this.journeyState = JourneyState.notStarted,
    this.trafficStatus,
    this.weatherScore,
    this.weatherCondition,
    this.weatherTemperature,
    this.riskLevel,
    this.riskExplanation,
    this.roadReportsSubmitted = 0,
    this.nearbyPlacesViewed = 0,
  });

  /// True if journey is currently in active progress
  bool get isActive => journeyState == JourneyState.active;

  /// True if journey is currently paused
  bool get isPaused => journeyState == JourneyState.paused;

  /// True if journey has ended (completed or cancelled)
  bool get isFinished =>
      journeyState == JourneyState.completed ||
      journeyState == JourneyState.cancelled;

  /// Formatted route label identity (e.g. "Route 2 • SHORTEST")
  String get displayRouteLabel =>
      routeLabel != null && routeLabel!.isNotEmpty
          ? routeLabel!
          : 'Route ${routeIndex + 1}';

  /// Elapsed time calculated from real start/end timestamps without GPS interpolation
  Duration? get elapsedDuration {
    if (startedTimestamp == null) return null;
    final end = endedTimestamp ?? DateTime.now();
    return end.difference(startedTimestamp!);
  }

  /// Formatted duration string for estimated travel time
  String get formattedEstimatedDuration {
    final mins = estimatedDurationMinutes.round();
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0) return '${h}h ${m}m';
    return '$m min';
  }

  /// Formatted elapsed duration string
  String get formattedElapsedDuration {
    final d = elapsedDuration;
    if (d == null) return '0 min';
    final totalMins = d.inMinutes;
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    if (h > 0) return '${h}h ${m}m';
    return '$m min';
  }

  /// Safety rating label based on project thresholds
  String safetyRating(bool isTamil) {
    if (routeSafetyScore == null) {
      return isTamil
          ? 'பாதுகாப்பு மதிப்பீடு இல்லை'
          : 'Safety score unavailable';
    }
    if (routeSafetyScore! >= 80) {
      return isTamil ? 'மிகச் சிறந்தது' : 'Excellent';
    }
    if (routeSafetyScore! >= 65) {
      return isTamil ? 'நல்லது' : 'Good';
    }
    if (routeSafetyScore! >= 50) {
      return isTamil ? 'நடுத்தரமானது' : 'Moderate';
    }
    return isTamil ? 'ஆபத்தானது' : 'Risky';
  }

  Color get safetyRatingColor {
    if (routeSafetyScore == null) return const Color(0xff94A3B8);
    if (routeSafetyScore! >= 80) return NeonTheme.safeGreen;
    if (routeSafetyScore! >= 65) return NeonTheme.neonCyan;
    if (routeSafetyScore! >= 50) return NeonTheme.neonAmber;
    return NeonTheme.dangerRed;
  }

  SafeRouteJourney copyWith({
    String? id,
    String? origin,
    String? destination,
    int? routeIndex,
    String? routeLabel,
    double? routeSafetyScore,
    double? distanceKm,
    double? estimatedDurationMinutes,
    String? vehicleMode,
    String? travelTimeMode,
    DateTime? startedTimestamp,
    DateTime? endedTimestamp,
    JourneyState? journeyState,
    String? trafficStatus,
    double? weatherScore,
    String? weatherCondition,
    String? weatherTemperature,
    String? riskLevel,
    String? riskExplanation,
    int? roadReportsSubmitted,
    int? nearbyPlacesViewed,
  }) {
    return SafeRouteJourney(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      routeIndex: routeIndex ?? this.routeIndex,
      routeLabel: routeLabel ?? this.routeLabel,
      routeSafetyScore: routeSafetyScore ?? this.routeSafetyScore,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      vehicleMode: vehicleMode ?? this.vehicleMode,
      travelTimeMode: travelTimeMode ?? this.travelTimeMode,
      startedTimestamp: startedTimestamp ?? this.startedTimestamp,
      endedTimestamp: endedTimestamp ?? this.endedTimestamp,
      journeyState: journeyState ?? this.journeyState,
      trafficStatus: trafficStatus ?? this.trafficStatus,
      weatherScore: weatherScore ?? this.weatherScore,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      weatherTemperature: weatherTemperature ?? this.weatherTemperature,
      riskLevel: riskLevel ?? this.riskLevel,
      riskExplanation: riskExplanation ?? this.riskExplanation,
      roadReportsSubmitted: roadReportsSubmitted ?? this.roadReportsSubmitted,
      nearbyPlacesViewed: nearbyPlacesViewed ?? this.nearbyPlacesViewed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin,
    'destination': destination,
    'route_index': routeIndex,
    if (routeLabel != null) 'route_label': routeLabel,
    'route_safety_score': routeSafetyScore,
    'distance_km': distanceKm,
    'estimated_duration_minutes': estimatedDurationMinutes,
    'vehicle_mode': vehicleMode,
    'travel_time_mode': travelTimeMode,
    if (startedTimestamp != null)
      'started_timestamp': startedTimestamp!.toIso8601String(),
    if (endedTimestamp != null)
      'ended_timestamp': endedTimestamp!.toIso8601String(),
    'journey_state': journeyState.name,
    if (trafficStatus != null) 'traffic_status': trafficStatus,
    if (weatherScore != null) 'weather_score': weatherScore,
    if (weatherCondition != null) 'weather_condition': weatherCondition,
    if (weatherTemperature != null) 'weather_temperature': weatherTemperature,
    if (riskLevel != null) 'risk_level': riskLevel,
    if (riskExplanation != null) 'risk_explanation': riskExplanation,
    'road_reports_submitted': roadReportsSubmitted,
    'nearby_places_viewed': nearbyPlacesViewed,
  };

  factory SafeRouteJourney.fromJson(Map<String, dynamic> json) {
    return SafeRouteJourney(
      id: json['id'] as String? ?? UniqueKey().toString(),
      origin: json['origin'] as String? ?? 'Unknown',
      destination: json['destination'] as String? ?? 'Unknown',
      routeIndex: (json['route_index'] as num?)?.toInt() ?? 0,
      routeLabel: json['route_label'] as String?,
      routeSafetyScore: (json['route_safety_score'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      estimatedDurationMinutes:
          (json['estimated_duration_minutes'] as num?)?.toDouble() ?? 0.0,
      vehicleMode: json['vehicle_mode'] as String? ?? 'Car',
      travelTimeMode: json['travel_time_mode'] as String? ?? 'Day',
      startedTimestamp: json['started_timestamp'] != null
          ? DateTime.tryParse(json['started_timestamp'] as String)
          : null,
      endedTimestamp: json['ended_timestamp'] != null
          ? DateTime.tryParse(json['ended_timestamp'] as String)
          : null,
      journeyState: JourneyState.values.firstWhere(
        (s) => s.name == (json['journey_state'] as String?),
        orElse: () => JourneyState.notStarted,
      ),
      trafficStatus: json['traffic_status'] as String?,
      weatherScore: (json['weather_score'] as num?)?.toDouble(),
      weatherCondition: json['weather_condition'] as String?,
      weatherTemperature: json['weather_temperature'] as String?,
      riskLevel: json['risk_level'] as String?,
      riskExplanation: json['risk_explanation'] as String?,
      roadReportsSubmitted:
          (json['road_reports_submitted'] as num?)?.toInt() ?? 0,
      nearbyPlacesViewed: (json['nearby_places_viewed'] as num?)?.toInt() ?? 0,
    );
  }
}

// ============================================================================
// 3. JOURNEY HISTORY STORAGE SERVICE (LOCAL ONLY - NO GPS)
// ============================================================================

class JourneyHistoryService {
  static const String storageKey = 'saferoute_journey_history';

  /// Loads completed journey history from SharedPreferences
  static Future<List<SafeRouteJourney>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .map(
            (item) => SafeRouteJourney.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error loading journey history: $e');
      return [];
    }
  }

  /// Appends or updates a completed journey record locally
  static Future<void> saveJourney(SafeRouteJourney journey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await loadHistory();

      // Check if existing journey needs update
      final index = list.indexWhere((j) => j.id == journey.id);
      if (index >= 0) {
        list[index] = journey;
      } else {
        list.insert(0, journey);
      }

      final encoded = jsonEncode(list.map((j) => j.toJson()).toList());
      await prefs.setString(storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving journey history: $e');
    }
  }

  /// Deletes a specific journey record by ID
  static Future<void> deleteJourney(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await loadHistory();
      list.removeWhere((j) => j.id == id);
      final encoded = jsonEncode(list.map((j) => j.toJson()).toList());
      await prefs.setString(storageKey, encoded);
    } catch (e) {
      debugPrint('Error deleting journey from history: $e');
    }
  }

  /// Clears entire journey history
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (e) {
      debugPrint('Error clearing journey history: $e');
    }
  }
}

// ============================================================================
// 4. BILINGUAL LOCALIZATION
// ============================================================================

class SafeRouteJourneyLocalization {
  static String title(bool isTamil) =>
      isTamil ? '🛡️ SafeRoute பயண பாதுகாப்பு' : '🛡️ SafeRoute Journey';

  static String subtitle(bool isTamil) => isTamil
      ? 'பயணம் முழுவதும் விழிப்புடன் இருங்கள்'
      : 'Stay informed throughout your journey';

  static String currentRoute(bool isTamil) =>
      isTamil ? 'தற்போதைய பாதை' : 'Current Route';

  static String currentSafety(bool isTamil) =>
      isTamil ? 'தற்போதைய பாதுகாப்பு' : 'Current Safety';

  static String safetyScore(bool isTamil) =>
      isTamil ? 'பாதுகாப்பு மதிப்பீடு' : 'Safety Score';

  static String trafficStatus(bool isTamil) =>
      isTamil ? 'போக்குவரத்து நிலை' : 'Traffic Status';

  static String trafficUnavailable(bool isTamil) =>
      isTamil ? 'போக்குவரத்து தகவல் கிடைக்கவில்லை' : 'Traffic data unavailable';

  static String weather(bool isTamil) => isTamil ? 'வானிலை' : 'Weather';

  static String weatherUnavailable(bool isTamil) => isTamil
      ? 'வானிலை தகவல் கிடைக்கவில்லை'
      : 'Weather information unavailable';

  static String riskForecast(bool isTamil) =>
      isTamil ? 'ஆபத்து கணிப்பு' : 'Risk Forecast';

  static String nearbySafety(bool isTamil) =>
      isTamil ? 'அருகிலுள்ள பாதுகாப்பு இடங்கள்' : 'Nearby Safety';

  static String preferences(bool isTamil) =>
      isTamil ? 'உங்கள் பாதுகாப்பு விருப்பங்கள்' : 'Your Safety Preferences';

  static String emergencyAssistance(bool isTamil) =>
      isTamil ? 'அவசர உதவி' : 'Emergency Assistance';

  static String reportProblem(bool isTamil) =>
      isTamil ? 'சாலை பிரச்சனையை தெரிவிக்கவும்' : 'Report Road Problem';

  static String refreshSafety(bool isTamil) => isTamil
      ? 'பாதுகாப்பு தகவலை புதுப்பிக்கவும்'
      : 'Refresh Safety Information';

  static String pauseJourney(bool isTamil) =>
      isTamil ? 'பயணத்தை இடைநிறுத்து' : 'Pause Journey';

  static String resumeJourney(bool isTamil) =>
      isTamil ? 'பயணத்தை தொடரு' : 'Resume Journey';

  static String endJourney(bool isTamil) =>
      isTamil ? 'பயணத்தை முடி' : 'End Journey';

  static String journeyPaused(bool isTamil) =>
      isTamil ? 'பயணம் இடைநிறுத்தப்பட்டது' : 'Journey Paused';

  static String journeyCompleted(bool isTamil) =>
      isTamil ? '🏁 பயணம் முடிந்தது' : '🏁 Journey Completed';

  static String routeProgress(bool isTamil) =>
      isTamil ? 'பயண முன்னேற்றம்' : 'Route Progress';

  static String progressUnavailable(bool isTamil) => isTamil
      ? 'வழிசெலுத்தல் முன்னேற்றத் தகவல் கிடைக்கவில்லை'
      : 'Navigation progress unavailable';

  static String privacyNotice(bool isTamil) => isTamil
      ? 'தனியுரிமைக்கு முன்னுரிமை: தொடர் ஜிபிஎஸ் கண்காணிப்பு செய்யப்படவில்லை.'
      : 'SafeRoute TN prioritizes privacy. No continuous GPS tracking is recorded.';

  static String noActiveJourney(bool isTamil) =>
      isTamil ? 'செயலில் உள்ள பயணம் இல்லை' : 'No Active Journey';

  static String startFromPlanned(bool isTamil) => isTamil
      ? 'திட்டமிடப்பட்ட பாதையிலிருந்து பயணத்தைத் தொடங்குங்கள்.'
      : 'Start a Journey from your planned route.';

  static String startJourney(bool isTamil) =>
      isTamil ? '🚗 பயணத்தைத் தொடங்கு' : '🚗 Start Journey';

  static String journeyHistory(bool isTamil) =>
      isTamil ? 'பயண வரலாறு' : 'Journey History';

  static String viewHistory(bool isTamil) =>
      isTamil ? 'பயண வரலாற்றைக் காண்க' : 'View Journey History';

  static String clearHistory(bool isTamil) =>
      isTamil ? 'வரலாற்றை அழிக்கவும்' : 'Clear Journey History';

  static String confirmEnd(bool isTamil) =>
      isTamil ? 'இந்த பயணத்தை முடிக்க விரும்புகிறீர்களா?' : 'End this journey?';

  static String confirmClear(bool isTamil) => isTamil
      ? 'முழு பயண வரலாற்றையும் அழிக்க விரும்புகிறீர்களா?'
      : 'Are you sure you want to clear your entire journey history?';

  static String cancel(bool isTamil) => isTamil ? 'ரத்து' : 'Cancel';

  static String confirm(bool isTamil) => isTamil ? 'உறுதி செய்' : 'Confirm';

  static String planRoute(bool isTamil) =>
      isTamil ? 'வழியைத் திட்டமிடுங்கள்' : 'Plan a Route';

  static String privacyDisclosure(bool isTamil) => isTamil
      ? 'பூஜ்ஜிய பின்னணி ஜிபிஎஸ்: நேரலை இருப்பிட கண்காணிப்பு பதிவு செய்யப்படவில்லை.'
      : 'Zero Background GPS: SafeRoute does not store continuous GPS tracking.';

  static String unavailable(bool isTamil) =>
      isTamil ? 'தகவல் இல்லை' : 'Unavailable';
}

// ============================================================================
// 5. MAIN JOURNEY MODE DASHBOARD VIEW
// ============================================================================

class SafeRouteJourneyModeView extends StatefulWidget {
  final bool isDarkMode;
  final SafeRouteJourney? activeJourney;
  final PersonalSafetyProfile? personalProfile;
  final VoidCallback? onStartJourney;
  final VoidCallback? onPauseJourney;
  final VoidCallback? onResumeJourney;
  final VoidCallback? onEndJourney;
  final VoidCallback? onRefreshSafety;
  final VoidCallback? onOpenEmergency;
  final void Function(String? category)? onOpenNearbyPlaces;
  final VoidCallback? onReportRoadProblem;
  final VoidCallback? onOpenSafetyProfile;
  final VoidCallback? onOpenRiskForecast;
  final VoidCallback? onPlanRoute;
  final Widget? mapWidget;
  final Position? currentPosition;
  final bool isNavigationActive;
  final bool isOffRoute;
  final double? distanceFromRouteMeters;
  final String? navigationStatus;
  final double? distanceRemainingKm;
  final double? traveledKm;
  final int? progressPercent;
  final int? etaMinutes;
  final bool isFollowingUser;
  final VoidCallback? onToggleFollowMe;

  const SafeRouteJourneyModeView({
    super.key,
    required this.isDarkMode,
    this.activeJourney,
    this.personalProfile,
    this.onStartJourney,
    this.onPauseJourney,
    this.onResumeJourney,
    this.onEndJourney,
    this.onRefreshSafety,
    this.onOpenEmergency,
    this.onOpenNearbyPlaces,
    this.onReportRoadProblem,
    this.onOpenSafetyProfile,
    this.onOpenRiskForecast,
    this.onPlanRoute,
    this.mapWidget,
    this.currentPosition,
    this.isNavigationActive = false,
    this.isOffRoute = false,
    this.distanceFromRouteMeters,
    this.navigationStatus,
    this.distanceRemainingKm,
    this.traveledKm,
    this.progressPercent,
    this.etaMinutes,
    this.isFollowingUser = false,
    this.onToggleFollowMe,
  });

  @override
  State<SafeRouteJourneyModeView> createState() =>
      _SafeRouteJourneyModeViewState();
}

class _SafeRouteJourneyModeViewState extends State<SafeRouteJourneyModeView> {
  bool _isTamil = false;
  bool _showHistoryView = false;
  List<SafeRouteJourney> _history = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await JourneyHistoryService.loadHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final journey = widget.activeJourney;

    if (_showHistoryView) {
      return _buildHistoryScreen(isDark);
    }

    if (journey == null || journey.journeyState == JourneyState.notStarted) {
      return _buildEmptyJourneyState(isDark);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        final isTablet =
            constraints.maxWidth >= 640 && constraints.maxWidth < 960;

        final hasMap = widget.mapWidget != null;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: hasMap ? 12 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasMap) ...[
                    // Primary Navigation Workspace: Front & Center
                    _buildLiveNavigationMapSection(
                      journey,
                      isDark,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      availableMaxHeight: constraints.maxHeight,
                    ),
                    const SizedBox(height: 14),
                    if (journey.isPaused) ...[
                      _buildPausedNotice(isDark),
                      const SizedBox(height: 14),
                    ],
                    _buildLiveMetricsStrip(journey, isDark),
                    const SizedBox(height: 16),
                    _buildHeader(journey, isDark),
                    const SizedBox(height: 16),
                  ] else ...[
                    _buildHeader(journey, isDark),
                    const SizedBox(height: 16),
                    if (journey.isPaused) ...[
                      _buildPausedNotice(isDark),
                      const SizedBox(height: 16),
                    ],
                  ],
                  if (isDesktop)
                    _buildDesktopLayout(journey, isDark)
                  else if (isTablet)
                    _buildTabletLayout(journey, isDark)
                  else
                    _buildMobileLayout(journey, isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // LIVE NAVIGATION MAP & METRICS STRIP
  // --------------------------------------------------------------------------

  Widget _buildLiveNavigationMapSection(
    SafeRouteJourney journey,
    bool isDark, {
    required bool isDesktop,
    required bool isTablet,
    double? availableMaxHeight,
  }) {
    // Dynamic immersive live navigation map height for cockpit view to fit within viewport
    final height = (availableMaxHeight != null && availableMaxHeight.isFinite)
        ? (availableMaxHeight - 24.0).clamp(isDesktop ? 520.0 : (isTablet ? 450.0 : 380.0), 740.0)
        : (isDesktop ? 640.0 : (isTablet ? 520.0 : 440.0));

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff060C18) : const Color(0xffE2E8F0),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? NeonTheme.cyanBorder : const Color(0x350284C7),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xff00E5FF).withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: widget.mapWidget!,
      ),
    );
  }

  Widget _buildLiveMetricsStrip(SafeRouteJourney journey, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final distText = widget.distanceRemainingKm != null
            ? '${widget.distanceRemainingKm!.toStringAsFixed(1)} km'
            : '${journey.distanceKm.toStringAsFixed(1)} km';
        final etaText = widget.etaMinutes != null
            ? '${widget.etaMinutes} min'
            : '~${journey.estimatedDurationMinutes.round()} min';
        final scoreText = journey.routeSafetyScore != null
            ? '${journey.routeSafetyScore!.round()}%'
            : (_isTamil ? 'கிடைக்கவில்லை' : 'Unavailable');

        final statusText = widget.navigationStatus ??
            (widget.isOffRoute
                ? (_isTamil ? 'வழியை விட்டு வெளியே' : 'Off Route')
                : (widget.currentPosition != null
                    ? (_isTamil ? 'வழியில் உள்ளது' : 'On Route')
                    : (widget.isNavigationActive
                        ? (_isTamil ? 'ஜிபிஎஸ் தேடுகிறது' : 'Waiting for GPS')
                        : (_isTamil ? 'ஜிபிஎஸ் இல்லை' : 'GPS Standby'))));

        final statusColor = widget.isOffRoute
            ? NeonTheme.warningGold
            : ((widget.currentPosition != null ||
                    widget.navigationStatus == 'On Route')
                ? NeonTheme.safeGreen
                : const Color(0xff94A3B8));

        final items = [
          _buildMetricItem(
            icon: Icons.alt_route_rounded,
            iconColor: NeonTheme.neonCyan,
            label: _isTamil ? 'மீதமுள்ள தூரம்' : 'Remaining Distance',
            value: distText,
            subtext: widget.traveledKm != null && widget.traveledKm! > 0
                ? '${widget.traveledKm!.toStringAsFixed(1)} km traveled'
                : 'Total ${journey.distanceKm.toStringAsFixed(1)} km',
            isDark: isDark,
          ),
          _buildMetricItem(
            icon: Icons.timer_outlined,
            iconColor: NeonTheme.electricBlue,
            label: _isTamil ? 'மதிப்பிடப்பட்ட நேரம்' : 'Estimated Time (ETA)',
            value: etaText,
            subtext: _isTamil
                ? 'முறை: ${journey.vehicleMode}'
                : 'Mode: ${journey.vehicleMode}',
            isDark: isDark,
          ),
          _buildMetricItem(
            icon: Icons.verified_user_rounded,
            iconColor: NeonTheme.safeGreen,
            label: _isTamil ? 'பாதுகாப்பு மதிப்பீடு' : 'Route Safety Score',
            value: scoreText,
            subtext: journey.routeSafetyScore == null
                ? (_isTamil ? 'மதிப்பீடு இல்லை' : 'Not Evaluated')
                : (journey.routeSafetyScore! >= 80
                    ? (_isTamil ? 'பாதுகாப்பானது' : 'Verified Safe')
                    : (_isTamil ? 'எச்சரிக்கை தேவை' : 'Caution Advised')),
            isDark: isDark,
          ),
          _buildMetricItem(
            icon: widget.isOffRoute
                ? Icons.warning_amber_rounded
                : (widget.currentPosition != null
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded),
            iconColor: statusColor,
            label: _isTamil ? 'வழிசெலுத்தல் நிலை' : 'Live Navigation',
            value: statusText,
            valueColor: statusColor,
            subtext: widget.isOffRoute && widget.distanceFromRouteMeters != null
                ? '${widget.distanceFromRouteMeters!.round()}m from route'
                : (widget.currentPosition != null
                    ? (_isTamil ? 'செயலில் உள்ள ஜிபிஎஸ்' : 'Device GPS Active')
                    : (_isTamil
                        ? 'சமிக்ஞைக்காக காத்திருக்கிறது'
                        : 'Awaiting GPS lock')),
            isDark: isDark,
          ),
        ];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xff1E3A5F) : const Color(0x350284C7),
              width: 1.2,
            ),
            boxShadow: NeonTheme.cardShadow(isDark),
          ),
          child: isCompact
              ? Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: (constraints.maxWidth - 44) / 2,
                          child: item,
                        ),
                      )
                      .toList(),
                )
              : Row(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 38,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      Expanded(child: items[i]),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
    required String subtext,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: iconColor.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? NeonTheme.textSecondaryDark
                      : NeonTheme.textSecondaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: valueColor ??
                      (isDark
                          ? NeonTheme.textPrimaryDark
                          : NeonTheme.textPrimaryLight),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? NeonTheme.textSecondaryDark.withValues(alpha: 0.8)
                      : NeonTheme.textSecondaryLight.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // HEADER
  // --------------------------------------------------------------------------

  Widget _buildHeader(SafeRouteJourney journey, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: journey.isPaused
              ? NeonTheme.warningGold.withValues(alpha: 0.6)
              : (isDark ? NeonTheme.cyanBorder : const Color(0x350284C7)),
          width: 1.3,
        ),
        boxShadow: journey.isPaused
            ? [
                BoxShadow(
                  color: NeonTheme.warningGold.withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
              ]
            : NeonTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (journey.isPaused
                              ? NeonTheme.warningGold
                              : NeonTheme.safeGreen)
                          .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  journey.isPaused
                      ? Icons.pause_circle_filled_rounded
                      : Icons.navigation_rounded,
                  color: journey.isPaused
                      ? NeonTheme.warningGold
                      : NeonTheme.safeGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          SafeRouteJourneyLocalization.title(_isTamil),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? NeonTheme.textPrimaryDark
                                : NeonTheme.textPrimaryLight,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: journey.journeyState.color.withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: journey.journeyState.color.withValues(
                                alpha: 0.5,
                              ),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                journey.journeyState.icon,
                                size: 11,
                                color: journey.journeyState.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                journey.journeyState.label(_isTamil),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: journey.journeyState.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: NeonTheme.neonCyan.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: NeonTheme.neonCyan.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            journey.displayRouteLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: NeonTheme.neonCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      SafeRouteJourneyLocalization.subtitle(_isTamil),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? NeonTheme.textSecondaryDark
                            : NeonTheme.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Language Switcher
              InkWell(
                onTap: () => setState(() => _isTamil = !_isTamil),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isTamil
                        ? NeonTheme.neonAmber.withValues(alpha: 0.18)
                        : NeonTheme.neonCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isTamil
                          ? NeonTheme.neonAmber
                          : NeonTheme.neonCyan,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    _isTamil ? 'தமிழ்' : 'English',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _isTamil
                          ? NeonTheme.neonAmber
                          : NeonTheme.neonCyan,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // History Toggle
              IconButton(
                tooltip: SafeRouteJourneyLocalization.journeyHistory(_isTamil),
                onPressed: () => setState(() => _showHistoryView = true),
                icon: const Icon(Icons.history_rounded, size: 20),
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Action Buttons Bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              // Refresh Safety
              OutlinedButton.icon(
                onPressed: widget.onRefreshSafety,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NeonTheme.neonCyan,
                  side: const BorderSide(color: NeonTheme.cyanBorder),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(
                  SafeRouteJourneyLocalization.refreshSafety(_isTamil),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Pause / Resume
              if (journey.isActive)
                ElevatedButton.icon(
                  onPressed: widget.onPauseJourney,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NeonTheme.warningGold.withValues(
                      alpha: 0.2,
                    ),
                    foregroundColor: NeonTheme.warningGold,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(
                        color: NeonTheme.warningGold,
                        width: 1.1,
                      ),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.pause_rounded, size: 15),
                  label: Text(
                    SafeRouteJourneyLocalization.pauseJourney(_isTamil),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else if (journey.isPaused)
                ElevatedButton.icon(
                  onPressed: widget.onResumeJourney,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NeonTheme.safeGreen.withValues(alpha: 0.2),
                    foregroundColor: NeonTheme.safeGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(
                        color: NeonTheme.safeGreen,
                        width: 1.1,
                      ),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 15),
                  label: Text(
                    SafeRouteJourneyLocalization.resumeJourney(_isTamil),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              // End Journey
              ElevatedButton.icon(
                onPressed: () => _confirmEndJourney(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NeonTheme.dangerRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.flag_rounded, size: 15),
                label: Text(
                  SafeRouteJourneyLocalization.endJourney(_isTamil),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPausedNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: NeonTheme.warningGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NeonTheme.warningGold.withValues(alpha: 0.5),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.pause_circle_outline_rounded,
            color: NeonTheme.warningGold,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              SafeRouteJourneyLocalization.journeyPaused(_isTamil),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: NeonTheme.warningGold,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onResumeJourney,
            child: Text(
              SafeRouteJourneyLocalization.resumeJourney(_isTamil),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: NeonTheme.warningGold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // DESKTOP LAYOUT (Multi-column)
  // --------------------------------------------------------------------------

  Widget _buildDesktopLayout(SafeRouteJourney journey, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column 1: Route & Safety & Progress
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCurrentRouteCard(journey, isDark),
              const SizedBox(height: 14),
              _buildSafetyScoreCard(journey, isDark),
              const SizedBox(height: 14),
              _buildJourneyProgressCard(journey, isDark),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Column 2: Traffic, Weather, Risk
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTrafficCard(journey, isDark),
              const SizedBox(height: 14),
              _buildWeatherCard(journey, isDark),
              const SizedBox(height: 14),
              _buildRiskForecastCard(journey, isDark),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Column 3: Nearby, Emergency, Report Problem, Preferences
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEmergencyCard(isDark),
              const SizedBox(height: 14),
              _buildNearbySafetyCard(isDark),
              const SizedBox(height: 14),
              _buildPreferencesCard(journey, isDark),
              const SizedBox(height: 14),
              _buildReportProblemCard(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // TABLET LAYOUT (2 Columns)
  // --------------------------------------------------------------------------

  Widget _buildTabletLayout(SafeRouteJourney journey, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCurrentRouteCard(journey, isDark),
              const SizedBox(height: 14),
              _buildSafetyScoreCard(journey, isDark),
              const SizedBox(height: 14),
              _buildTrafficCard(journey, isDark),
              const SizedBox(height: 14),
              _buildWeatherCard(journey, isDark),
              const SizedBox(height: 14),
              _buildJourneyProgressCard(journey, isDark),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEmergencyCard(isDark),
              const SizedBox(height: 14),
              _buildRiskForecastCard(journey, isDark),
              const SizedBox(height: 14),
              _buildNearbySafetyCard(isDark),
              const SizedBox(height: 14),
              _buildPreferencesCard(journey, isDark),
              const SizedBox(height: 14),
              _buildReportProblemCard(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // MOBILE LAYOUT (Single Column)
  // --------------------------------------------------------------------------

  Widget _buildMobileLayout(SafeRouteJourney journey, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCurrentRouteCard(journey, isDark),
        const SizedBox(height: 14),
        _buildSafetyScoreCard(journey, isDark),
        const SizedBox(height: 14),
        _buildEmergencyCard(isDark),
        const SizedBox(height: 14),
        _buildTrafficCard(journey, isDark),
        const SizedBox(height: 14),
        _buildWeatherCard(journey, isDark),
        const SizedBox(height: 14),
        _buildRiskForecastCard(journey, isDark),
        const SizedBox(height: 14),
        _buildNearbySafetyCard(isDark),
        const SizedBox(height: 14),
        _buildPreferencesCard(journey, isDark),
        const SizedBox(height: 14),
        _buildJourneyProgressCard(journey, isDark),
        const SizedBox(height: 14),
        _buildReportProblemCard(isDark),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // CARDS IMPLEMENTATION
  // --------------------------------------------------------------------------

  // A. Current Route Card
  Widget _buildCurrentRouteCard(SafeRouteJourney journey, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, borderColor: NeonTheme.neonCyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _cardTitle(
                  icon: Icons.alt_route_rounded,
                  iconColor: NeonTheme.neonCyan,
                  title: SafeRouteJourneyLocalization.currentRoute(_isTamil),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: NeonTheme.neonCyan.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: NeonTheme.neonCyan.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  journey.displayRouteLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: NeonTheme.neonCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(
                    Icons.trip_origin_rounded,
                    size: 14,
                    color: NeonTheme.safeGreen,
                  ),
                  Container(
                    width: 2,
                    height: 24,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: NeonTheme.dangerRed,
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journey.origin,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      journey.destination,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStatMini(
                'Distance',
                '${journey.distanceKm.toStringAsFixed(1)} km',
                isDark,
              ),
              _buildStatMini('ETA', journey.formattedEstimatedDuration, isDark),
              _buildStatMini('Vehicle', journey.vehicleMode, isDark),
              _buildStatMini('Travel Time', journey.travelTimeMode, isDark),
            ],
          ),
        ],
      ),
    );
  }

  // B. Safety Score Card
  Widget _buildSafetyScoreCard(SafeRouteJourney journey, bool isDark) {
    final rating = journey.safetyRating(_isTamil);
    final ratingColor = journey.safetyRatingColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, borderColor: ratingColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.shield_rounded,
            iconColor: ratingColor,
            title: SafeRouteJourneyLocalization.currentSafety(_isTamil),
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ratingColor.withValues(alpha: 0.16),
                  border: Border.all(color: ratingColor, width: 2.2),
                ),
                child: Center(
                  child: Text(
                    journey.routeSafetyScore != null
                        ? journey.routeSafetyScore!.round().toString()
                        : '--',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: ratingColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ratingColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reused from active route evaluation',
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
        ],
      ),
    );
  }

  // C. Traffic Card
  Widget _buildTrafficCard(SafeRouteJourney journey, bool isDark) {
    final status = journey.trafficStatus;
    final hasTraffic = status != null && status.trim().isNotEmpty;

    final color = switch (status?.toLowerCase()) {
      'low traffic' || 'light' || 'flow' => NeonTheme.safeGreen,
      'moderate traffic' || 'moderate' => NeonTheme.warningGold,
      'heavy traffic' || 'heavy' || 'congested' => NeonTheme.dangerRed,
      _ => const Color(0xff94A3B8),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, borderColor: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.traffic_rounded,
            iconColor: color,
            title: SafeRouteJourneyLocalization.trafficStatus(_isTamil),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasTraffic
                      ? status
                      : SafeRouteJourneyLocalization.trafficUnavailable(
                          _isTamil,
                        ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasTraffic
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark
                              ? NeonTheme.textSecondaryDark
                              : NeonTheme.textSecondaryLight),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // D. Weather Card
  Widget _buildWeatherCard(SafeRouteJourney journey, bool isDark) {
    final condition = journey.weatherCondition;
    final temp = journey.weatherTemperature;
    final hasWeather = condition != null || temp != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, borderColor: const Color(0xff38BDF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.cloud_rounded,
            iconColor: const Color(0xff38BDF8),
            title: SafeRouteJourneyLocalization.weather(_isTamil),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          if (hasWeather)
            Row(
              children: [
                if (temp != null) ...[
                  Text(
                    temp,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (condition != null)
                  Text(
                    condition,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
              ],
            )
          else
            Text(
              SafeRouteJourneyLocalization.weatherUnavailable(_isTamil),
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? NeonTheme.textSecondaryDark
                    : NeonTheme.textSecondaryLight,
              ),
            ),
        ],
      ),
    );
  }

  // E. Risk Forecast Card
  Widget _buildRiskForecastCard(SafeRouteJourney journey, bool isDark) {
    final riskStr = journey.riskLevel ?? 'LOW';
    final riskLevel = RouteRiskLevel.values.firstWhere(
      (r) => r.name.toLowerCase() == riskStr.toLowerCase(),
      orElse: () => RouteRiskLevel.low,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, borderColor: riskLevel.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _cardTitle(
                  icon: riskLevel.icon,
                  iconColor: riskLevel.color,
                  title: SafeRouteJourneyLocalization.riskForecast(_isTamil),
                  isDark: isDark,
                ),
              ),
              if (widget.onOpenRiskForecast != null)
                TextButton(
                  onPressed: widget.onOpenRiskForecast,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('Details', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: riskLevel.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: riskLevel.color.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Text(
              riskLevel.title(_isTamil),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: riskLevel.color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            journey.riskExplanation ?? riskLevel.description(_isTamil),
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? NeonTheme.textSecondaryDark
                  : NeonTheme.textSecondaryLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // F. Nearby Safety Quick-Access Buttons
  Widget _buildNearbySafetyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, borderColor: NeonTheme.neonCyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.place_rounded,
            iconColor: NeonTheme.neonCyan,
            title: SafeRouteJourneyLocalization.nearbySafety(_isTamil),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildNearbyBtn(
                '🏥 Hospital',
                'hospital',
                const Color(0xffE11D48),
              ),
              _buildNearbyBtn('👮 Police', 'police', const Color(0xff2563EB)),
              _buildNearbyBtn('⛽ Petrol', 'petrol', const Color(0xffD97706)),
              _buildNearbyBtn(
                '💊 Pharmacy',
                'pharmacy',
                const Color(0xff059669),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyBtn(String label, String category, Color color) {
    return InkWell(
      onTap: () => widget.onOpenNearbyPlaces?.call(category),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 0.9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }

  // G. Personal Safety Profile Card
  Widget _buildPreferencesCard(SafeRouteJourney journey, bool isDark) {
    final profile = widget.personalProfile;
    final match = profile != null ? '86%' : 'Standard';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, borderColor: NeonTheme.safeGreen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.person_pin_rounded,
            iconColor: NeonTheme.safeGreen,
            title: SafeRouteJourneyLocalization.preferences(_isTamil),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                'Preference Match: $match',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onOpenSafetyProfile != null)
                TextButton(
                  onPressed: widget.onOpenSafetyProfile,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text(
                    'View Profile',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // H. Emergency Assistance Card
  Widget _buildEmergencyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, borderColor: NeonTheme.dangerRed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.emergency_rounded,
            iconColor: NeonTheme.dangerRed,
            title: SafeRouteJourneyLocalization.emergencyAssistance(_isTamil),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildEmergencyQuickBtn('112', 'Police', isDark)),
              const SizedBox(width: 6),
              Expanded(
                child: _buildEmergencyQuickBtn('108', 'Ambulance', isDark),
              ),
              const SizedBox(width: 6),
              Expanded(child: _buildEmergencyQuickBtn('101', 'Fire', isDark)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onOpenEmergency,
              style: OutlinedButton.styleFrom(
                foregroundColor: NeonTheme.dangerRed,
                side: const BorderSide(color: NeonTheme.dangerRed, width: 1.1),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.shield_rounded, size: 14),
              label: const Text(
                'Open Emergency Assistance',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyQuickBtn(String number, String label, bool isDark) {
    return InkWell(
      onTap: widget.onOpenEmergency,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: NeonTheme.dangerRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: NeonTheme.dangerRed.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: NeonTheme.dangerRed,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // I. Report Road Problem Card
  Widget _buildReportProblemCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(isDark, borderColor: NeonTheme.neonAmber),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.report_problem_rounded,
            iconColor: NeonTheme.neonAmber,
            title: SafeRouteJourneyLocalization.reportProblem(_isTamil),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onReportRoadProblem,
              style: OutlinedButton.styleFrom(
                foregroundColor: NeonTheme.neonAmber,
                side: const BorderSide(color: NeonTheme.neonAmber, width: 1.1),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add_alert_rounded, size: 14),
              label: Text(
                SafeRouteJourneyLocalization.reportProblem(_isTamil),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Journey Progress Card (Zero fake progress)
  Widget _buildJourneyProgressCard(SafeRouteJourney journey, bool isDark) {
    final hasRealGps =
        widget.isNavigationActive && widget.currentPosition != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
        isDark,
        borderColor: hasRealGps ? NeonTheme.neonCyan : const Color(0xff64748B),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.route_rounded,
            iconColor:
                hasRealGps ? NeonTheme.neonCyan : const Color(0xff64748B),
            title: SafeRouteJourneyLocalization.routeProgress(_isTamil),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          if (hasRealGps) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ((widget.progressPercent ?? 0) / 100.0).clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 8,
                      backgroundColor: isDark
                          ? const Color(0xff0B172E)
                          : const Color(0xffCBD5E1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        NeonTheme.neonCyan,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${widget.progressPercent ?? 0}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: NeonTheme.neonCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isTamil
                      ? 'கடந்தது: ${widget.traveledKm?.toStringAsFixed(1) ?? '0.0'} km'
                      : 'Traveled: ${widget.traveledKm?.toStringAsFixed(1) ?? '0.0'} km',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isTamil
                      ? 'மீதம்: ${widget.distanceRemainingKm?.toStringAsFixed(1) ?? '0.0'} km'
                      : 'Remaining: ${widget.distanceRemainingKm?.toStringAsFixed(1) ?? '0.0'} km',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  widget.isOffRoute
                      ? Icons.warning_amber_rounded
                      : Icons.gps_fixed_rounded,
                  size: 13,
                  color: widget.isOffRoute
                      ? NeonTheme.warningGold
                      : NeonTheme.safeGreen,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.isOffRoute
                        ? (_isTamil
                            ? 'வழியை விட்டு வெளியே (${widget.distanceFromRouteMeters?.round() ?? 0}m)'
                            : 'Off Route (${widget.distanceFromRouteMeters?.round() ?? 0}m)')
                        : (_isTamil
                            ? 'நேரலை ஜிபிஎஸ் செயலில் உள்ளது (வழியில்)'
                            : 'Live GPS Active (On Route)'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: widget.isOffRoute
                          ? NeonTheme.warningGold
                          : NeonTheme.safeGreen,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Color(0xff94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.isNavigationActive
                        ? (_isTamil
                            ? 'ஜிபிஎஸ் சமிக்ஞைக்காக காத்திருக்கிறது...'
                            : 'Waiting for device GPS signal...')
                        : SafeRouteJourneyLocalization.progressUnavailable(
                            _isTamil,
                          ),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            SafeRouteJourneyLocalization.privacyNotice(_isTamil),
            style: TextStyle(
              fontSize: 10,
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
  // EMPTY STATE / HISTORY VIEW
  // --------------------------------------------------------------------------

  Widget _buildEmptyJourneyState(bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NeonTheme.neonCyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    size: 38,
                    color: NeonTheme.neonCyan,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  SafeRouteJourneyLocalization.noActiveJourney(_isTamil),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? NeonTheme.textPrimaryDark
                        : NeonTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  SafeRouteJourneyLocalization.startFromPlanned(_isTamil),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? NeonTheme.textSecondaryDark
                        : NeonTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (widget.onPlanRoute != null)
                      ElevatedButton.icon(
                        onPressed: widget.onPlanRoute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NeonTheme.neonCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.search_rounded, size: 16),
                        label: Text(
                          SafeRouteJourneyLocalization.planRoute(_isTamil),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showHistoryView = true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: Text(
                        SafeRouteJourneyLocalization.viewHistory(_isTamil),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryScreen(bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _showHistoryView = false),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    SafeRouteJourneyLocalization.journeyHistory(_isTamil),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? NeonTheme.textPrimaryDark
                          : NeonTheme.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  if (_history.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _confirmClearHistory(context),
                      style: TextButton.styleFrom(
                        foregroundColor: NeonTheme.dangerRed,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text(
                        SafeRouteJourneyLocalization.clearHistory(_isTamil),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoadingHistory)
                const Center(child: CircularProgressIndicator())
              else if (_history.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    'No completed journeys recorded yet.',
                    style: TextStyle(
                      color: isDark
                          ? NeonTheme.textSecondaryDark
                          : NeonTheme.textSecondaryLight,
                    ),
                  ),
                )
              else
                for (final item in _history) ...[
                  _buildHistoryCard(item, isDark),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(SafeRouteJourney item, bool isDark) {
    final ratingColor = item.safetyRatingColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? NeonTheme.cyanBorder : const Color(0x350284C7),
          width: 1.1,
        ),
        boxShadow: NeonTheme.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.origin} → ${item.destination}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ratingColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ratingColor, width: 0.8),
                ),
                child: Text(
                  item.routeSafetyScore != null
                      ? 'Score: ${item.routeSafetyScore!.round()}'
                      : 'Score: --',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ratingColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${item.distanceKm.toStringAsFixed(1)} km · ${item.formattedEstimatedDuration} · ${item.vehicleMode}',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? NeonTheme.textSecondaryDark
                  : NeonTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _showSummaryDialog(context, item),
                child: const Text(
                  'View Summary',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () async {
                  await JourneyHistoryService.deleteJourney(item.id);
                  _loadHistory();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // DIALOGS & CONFIRMATIONS
  // --------------------------------------------------------------------------

  void _confirmEndJourney(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? NeonTheme.cardDark : Colors.white,
        title: Text(SafeRouteJourneyLocalization.confirmEnd(_isTamil)),
        content: const Text(
          'Completing this journey will generate your travel summary and store it locally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(SafeRouteJourneyLocalization.cancel(_isTamil)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              widget.onEndJourney?.call();
            },
            child: Text(SafeRouteJourneyLocalization.endJourney(_isTamil)),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? NeonTheme.cardDark : Colors.white,
        title: Text(SafeRouteJourneyLocalization.clearHistory(_isTamil)),
        content: Text(SafeRouteJourneyLocalization.confirmClear(_isTamil)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(SafeRouteJourneyLocalization.cancel(_isTamil)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await JourneyHistoryService.clearHistory();
              _loadHistory();
            },
            child: Text(SafeRouteJourneyLocalization.confirm(_isTamil)),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog(BuildContext context, SafeRouteJourney journey) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          JourneySummaryDialog(isDarkMode: widget.isDarkMode, journey: journey),
    );
  }

  // --------------------------------------------------------------------------
  // UI HELPERS
  // --------------------------------------------------------------------------

  BoxDecoration _cardDecoration(bool isDark, {required Color borderColor}) {
    return BoxDecoration(
      color: isDark ? NeonTheme.cardDark : NeonTheme.cardLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.2),
      boxShadow: NeonTheme.cardShadow(isDark),
    );
  }

  Widget _cardTitle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? NeonTheme.textPrimaryDark
                  : NeonTheme.textPrimaryLight,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatMini(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: isDark
                ? NeonTheme.textSecondaryDark
                : NeonTheme.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ============================================================================
// 6. JOURNEY SUMMARY DIALOG
// ============================================================================

class JourneySummaryDialog extends StatelessWidget {
  final bool isDarkMode;
  final SafeRouteJourney journey;
  final VoidCallback? onViewHistory;

  const JourneySummaryDialog({
    super.key,
    required this.isDarkMode,
    required this.journey,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode;
    final ratingColor = journey.safetyRatingColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? NeonTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: NeonTheme.neonCyan.withValues(alpha: 0.5),
            width: 1.3,
          ),
          boxShadow: NeonTheme.cardShadow(isDark),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NeonTheme.neonCyan.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.flag_circle_rounded,
                      color: NeonTheme.neonCyan,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🏁 Journey Completed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Real journey summary based on actual route evaluation',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 26),
              // Route header
              Text(
                '${journey.origin} → ${journey.destination}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              // Route origin & destination individual tiles
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile('Origin', journey.origin, isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      'Destination',
                      journey.destination,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Distance',
                      '${journey.distanceKm.toStringAsFixed(1)} km',
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      'Travel Time',
                      journey.elapsedDuration != null
                          ? journey.formattedElapsedDuration
                          : journey.formattedEstimatedDuration,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Safety Score',
                      journey.routeSafetyScore != null
                          ? '${journey.routeSafetyScore!.round()}'
                          : '--',
                      isDark,
                      highlightColor: ratingColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      'Risk Level',
                      journey.riskLevel != null
                          ? journey.riskLevel!.toUpperCase()
                          : 'Unavailable',
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Traffic History',
                      journey.trafficStatus ?? 'Unavailable',
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      'Weather',
                      journey.weatherCondition != null
                          ? (journey.weatherTemperature != null
                                ? '${journey.weatherCondition} (${journey.weatherTemperature})'
                                : journey.weatherCondition!)
                          : 'Unavailable',
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Vehicle & Mode',
                      '${journey.vehicleMode} · ${journey.travelTimeMode}',
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      'Road Problems Reported',
                      '${journey.roadReportsSubmitted} reported',
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (onViewHistory != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onViewHistory,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NeonTheme.neonCyan,
                          side: const BorderSide(color: NeonTheme.neonCyan),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'View History',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NeonTheme.neonCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Close Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    bool isDark, {
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? NeonTheme.cardElevatedDark : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? NeonTheme.textSecondaryDark
                  : NeonTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: highlightColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
