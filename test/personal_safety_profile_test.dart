import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saferoute_tn/main.dart';
import 'package:saferoute_tn/personal_safety_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to create mock RouteEvaluation for preference matching
  RouteEvaluation createMockEvaluation({
    required double? score,
    double accidentScore = 85,
    double roadScore = 75,
    double trafficScore = 80,
    double weatherScore = 85,
    double? lightingScore,
    double accessibilityScore = 70,
  }) {
    final factors = [
      SafetyFactor(
        title: 'Accident Risk',
        icon: Icons.shield_rounded,
        score: accidentScore,
        weight: 0.35,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Road Condition',
        icon: Icons.add_road_rounded,
        score: roadScore,
        weight: 0.25,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Traffic',
        icon: Icons.traffic_rounded,
        score: trafficScore,
        weight: 0.15,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Weather',
        icon: Icons.cloud_rounded,
        score: weatherScore,
        weight: 0.10,
        relevant: true,
      ),
      SafetyFactor(
        title: 'Lighting',
        icon: Icons.lightbulb_rounded,
        score: lightingScore,
        weight: 0.08,
        relevant: lightingScore != null,
        unavailableReason: lightingScore == null
            ? 'Not evaluated for day travel'
            : null,
      ),
      SafetyFactor(
        title: 'Accessibility',
        icon: Icons.accessible_rounded,
        score: accessibilityScore,
        weight: 0.07,
        relevant: true,
      ),
    ];

    return RouteEvaluation(
      route: RouteResult(
        points: const [LatLng(13.0827, 80.2707), LatLng(12.9249, 80.1000)],
        distance: 28.5,
        duration: 2100,
        routeIndex: 0,
      ),
      roadSegments: const [],
      safety: PersonalizedSafetyResult(
        score: score,
        factors: factors,
        activeFactors: factors.where((f) => f.relevant).toList(),
      ),
      weather: WeatherData(
        temperature: 29.5,
        windSpeed: 12.0,
        precipitation: 0.0,
        weatherCode: 0,
      ),
      traffic: const TrafficAssessment(
        source: 'TomTom',
        status: 'Flowing smoothly',
        meanSpeedRatio: 0.95,
        sampleCount: 18,
        matchedSamples: 18,
        coveragePercent: 100,
        roadClosure: false,
      ),
      blackspots: BlackspotRouteAssessment(
        clearSampleScore: 90,
        detectedBlackspots: 0,
        successfulSamples: 15,
        segmentsChecked: 15,
        verifiedRecordCount: 0,
        segmentResults: const [],
        unavailableReason: null,
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Category 1: Default Profile State', () {
    test('Default profile has standard initial values', () {
      final profile = PersonalSafetyProfile.defaultProfile();
      expect(profile.travelMode, 'Car');
      expect(profile.vehicleMode, 'Car');
      expect(profile.safetyPriority, 'Safer Route');
      expect(profile.nightLightingPreference, 'Prefer well-lit roads');
      expect(profile.weatherPreference, 'Prefer safer weather conditions');
      expect(profile.roadConditionPreference, 'Prefer better road surfaces');
      expect(profile.accessibilityPreference, 'Standard');
      expect(profile.travelPurpose, 'Daily commute');
      expect(profile.isConfigured, isTrue);
    });

    test('Unconfigured profile starts with isConfigured false', () {
      final unconfigured = PersonalSafetyProfile.unconfiguredProfile();
      expect(unconfigured.isConfigured, isFalse);
      expect(unconfigured.travelMode, 'Car');
      expect(unconfigured.vehicleMode, 'Car');
      expect(unconfigured.safetyPriority, 'Safer Route');
    });
  });

  group('Category 2: Save Profile to SharedPreferences', () {
    test(
      'Saves custom profile to saferoute_personal_safety_profile key',
      () async {
        SharedPreferences.setMockInitialValues({});
        final custom = PersonalSafetyProfile(
          vehicleMode: 'Bike',
          safetyPriority: 'Safer Route',
          nightLightingPreference: 'Prefer well-lit roads',
          weatherPreference: 'Avoid higher risk weather',
          roadConditionPreference: 'Prefer better road surfaces',
          accessibilityPreference: 'Prefer accessible routes',
          travelPurpose: 'College',
          isConfigured: true,
        );

        final success = await PersonalSafetyProfileStorage.saveProfile(custom);
        expect(success, isTrue);

        final prefs = await SharedPreferences.getInstance();
        final storedString = prefs.getString(
          PersonalSafetyProfileStorage.storageKey,
        );
        expect(storedString, isNotNull);

        final decoded = jsonDecode(storedString!) as Map<String, dynamic>;
        expect(decoded['vehicle_mode'], 'Bike');
        expect(decoded['safety_priority'], 'Safer Route');
        expect(decoded['travel_purpose'], 'College');
        expect(decoded['is_configured'], isTrue);
      },
    );
  });

  group('Category 3: Load Profile from SharedPreferences', () {
    test('Loads saved profile accurately', () async {
      final prefsData = {
        'vehicle_mode': 'Bus',
        'safety_priority': 'Faster Route',
        'night_lighting_preference': 'Avoid poorly lit roads',
        'weather_preference': 'Prefer safer weather conditions',
        'road_condition_preference': 'Prefer better road surfaces',
        'accessibility_preference': 'Standard',
        'travel_purpose': 'Work',
        'is_configured': true,
      };

      SharedPreferences.setMockInitialValues({
        PersonalSafetyProfileStorage.storageKey: jsonEncode(prefsData),
      });

      final loaded = await PersonalSafetyProfileStorage.loadProfile();
      expect(loaded.travelMode, 'Bus');
      expect(loaded.safetyPriority, 'Faster Route');
      expect(loaded.nightLightingPreference, 'Avoid poorly lit roads');
      expect(loaded.weatherPreference, 'Prefer safer weather conditions');
      expect(loaded.travelPurpose, 'Work');
      expect(loaded.isConfigured, isTrue);
    });

    test('Returns unconfiguredProfile when no data stored', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await PersonalSafetyProfileStorage.loadProfile();
      expect(loaded.isConfigured, isFalse);
      expect(loaded.travelMode, 'Car');
    });
  });

  group('Category 4: Persistence Across Sessions & JSON Round-Trip', () {
    test('toJson and fromJson preserve all fields', () {
      final now = DateTime(2026, 10, 11, 14, 30);
      final original = PersonalSafetyProfile(
        vehicleMode: 'Walk',
        safetyPriority: 'Safer Route',
        nightLightingPreference: 'Prefer well-lit roads',
        weatherPreference: 'Avoid higher risk weather',
        roadConditionPreference: 'Avoid poor road conditions',
        accessibilityPreference: 'Prefer accessible routes',
        travelPurpose: 'Family travel',
        isConfigured: true,
        updatedAt: now,
      );

      final json = original.toJson();
      final restored = PersonalSafetyProfile.fromJson(json);

      expect(restored.travelMode, original.travelMode);
      expect(restored.safetyPriority, original.safetyPriority);
      expect(
        restored.nightLightingPreference,
        original.nightLightingPreference,
      );
      expect(restored.weatherPreference, original.weatherPreference);
      expect(
        restored.roadConditionPreference,
        original.roadConditionPreference,
      );
      expect(
        restored.accessibilityPreference,
        original.accessibilityPreference,
      );
      expect(restored.travelPurpose, original.travelPurpose);
      expect(restored.isConfigured, original.isConfigured);
      expect(restored.updatedAt?.year, original.updatedAt?.year);
    });

    test('copyWith properly overrides specified fields', () {
      final initial = PersonalSafetyProfile.defaultProfile();
      final updated = initial.copyWith(
        vehicleMode: 'Bike',
        safetyPriority: 'Safer Route',
      );

      expect(updated.travelMode, 'Bike');
      expect(updated.safetyPriority, 'Safer Route');
      expect(updated.nightLightingPreference, initial.nightLightingPreference);
      expect(updated.travelPurpose, initial.travelPurpose);
    });
  });

  group('Category 5: Reset Preferences', () {
    test('resetProfile restores defaults in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        PersonalSafetyProfileStorage.storageKey: jsonEncode({
          'vehicle_mode': 'Bus',
          'safety_priority': 'Faster Route',
          'is_configured': true,
        }),
      });

      final resetProfile = await PersonalSafetyProfileStorage.resetProfile();
      expect(resetProfile.travelMode, 'Car');
      expect(resetProfile.safetyPriority, 'Safer Route');
      expect(resetProfile.isConfigured, isFalse);

      final loaded = await PersonalSafetyProfileStorage.loadProfile();
      expect(loaded.isConfigured, isFalse);
    });
  });

  group('Category 6: Vehicle Mode Selection', () {
    test('Validates available vehicle modes', () {
      expect(
        PersonalSafetyProfile.travelModes,
        containsAll(['Car', 'Bike', 'Bus', 'Walk']),
      );
      for (final mode in PersonalSafetyProfile.travelModes) {
        final profile = PersonalSafetyProfile.defaultProfile().copyWith(
          vehicleMode: mode,
        );
        expect(profile.travelMode, mode);
      }
    });
  });

  group('Category 7: Safety Priority Selection', () {
    test('Validates available safety priority options', () {
      expect(
        PersonalSafetyProfile.safetyPriorities,
        containsAll(['Safer Route', 'Faster Route', 'Balanced']),
      );
      for (final p in PersonalSafetyProfile.safetyPriorities) {
        final profile = PersonalSafetyProfile.defaultProfile().copyWith(
          safetyPriority: p,
        );
        expect(profile.safetyPriority, p);
      }
    });
  });

  group('Category 8: Night Travel Lighting Preference', () {
    test('Validates night lighting preference options', () {
      expect(
        PersonalSafetyProfile.nightLightingOptions,
        containsAll([
          'Prefer well-lit roads',
          'No special preference',
          'Avoid poorly lit roads',
        ]),
      );
    });
  });

  group('Category 9: Weather Safety Preference', () {
    test('Validates weather safety preference options', () {
      expect(
        PersonalSafetyProfile.weatherOptions,
        containsAll([
          'Prefer safer weather',
          'No special preference',
          'Avoid higher risk weather',
        ]),
      );
    });
  });

  group('Category 10: Road Condition Preference', () {
    test('Validates road condition preference options', () {
      expect(
        PersonalSafetyProfile.roadConditionOptions,
        containsAll([
          'Prefer better road surfaces',
          'No special preference',
          'Avoid poor road conditions',
        ]),
      );
    });
  });

  group('Category 11: Accessibility Preference', () {
    test('Validates accessibility preference options', () {
      expect(
        PersonalSafetyProfile.accessibilityOptions,
        containsAll(['Standard', 'Prefer accessible routes']),
      );
    });
  });

  group('Category 12: Travel Purpose Selection', () {
    test('Validates travel purpose options', () {
      expect(
        PersonalSafetyProfile.travelPurposes,
        containsAll([
          'Daily commute',
          'College',
          'Work',
          'Family travel',
          'Long-distance',
          'Other',
        ]),
      );
    });
  });

  group('Category 13: English Localization Strings', () {
    test('Verifies English translations exist for key UI elements', () {
      expect(SafetyProfileLocalization.title(false), 'Personal Safety Profile');
      expect(
        SafetyProfileLocalization.subtitle(false),
        'Tell SafeRoute TN how you prefer to travel.',
      );
      expect(
        SafetyProfileLocalization.saveButton(false),
        'Apply My Preferences',
      );
      expect(SafetyProfileLocalization.resetButton(false), 'Reset Preferences');
      expect(
        SafetyProfileLocalization.resetConfirmTitle(false),
        'Reset Safety Profile?',
      );
      expect(
        SafetyProfileLocalization.privacyNote(false),
        contains('stored locally on this device'),
      );
    });
  });

  group('Category 14: Tamil Localization Strings & Toggle', () {
    test('Verifies Tamil translations exist for key UI elements', () {
      expect(
        SafetyProfileLocalization.title(true),
        'தனிப்பட்ட பாதுகாப்பு விவரக்குறிப்பு',
      );
      expect(
        SafetyProfileLocalization.subtitle(true),
        'நீங்கள் எவ்வாறு பயணிக்க விரும்புகிறீர்கள் என்பதை SafeRoute TN-க்கு தெரிவிக்கவும்.',
      );
      expect(
        SafetyProfileLocalization.saveButton(true),
        'என் விருப்பங்களைப் பயன்படுத்து',
      );
      expect(
        SafetyProfileLocalization.resetButton(true),
        'விருப்பங்களை மீட்டமை',
      );
      expect(
        SafetyProfileLocalization.resetConfirmTitle(true),
        'பாதுகாப்பு சுயவிவரத்தை மீட்டமைக்கவா?',
      );
      expect(
        SafetyProfileLocalization.privacyNote(true),
        contains('உங்கள் விருப்பங்கள் இந்த சாதனத்தில் மட்டுமே'),
      );
    });
  });

  group('Category 15: Preference Match Calculation', () {
    test('Calculates High Preference Match when route aligns well', () {
      final eval = createMockEvaluation(
        score: 88,
        accidentScore: 88,
        roadScore: 82,
        lightingScore: 85,
        weatherScore: 90,
      );

      final profile = PersonalSafetyProfile(
        vehicleMode: 'Car',
        safetyPriority: 'Safer Route',
        roadConditionPreference: 'Prefer better road surfaces',
        weatherPreference: 'Prefer safer weather conditions',
        nightLightingPreference: 'Prefer well-lit roads',
        accessibilityPreference: 'Standard',
        travelPurpose: 'Daily commute',
        isConfigured: true,
      );

      final result = PreferenceMatchEvaluator.evaluate(
        evaluation: eval,
        profile: profile,
        isDay: false,
      );

      expect(result.matchPercentage, greaterThanOrEqualTo(80.0));
      expect(result.matchLabel, 'High Preference Match');
      expect(result.matchColor, NeonTheme.safeGreen);
      expect(result.matchFactors.isNotEmpty, isTrue);
      expect(result.narrative, contains('% match'));
    });

    test('Calculates Moderate / Lower Match for lower scoring route', () {
      final eval = createMockEvaluation(
        score: 42,
        accidentScore: 40,
        roadScore: 35,
        lightingScore: 40,
        weatherScore: 45,
      );

      final profile = PersonalSafetyProfile(
        vehicleMode: 'Car',
        safetyPriority: 'Safer Route',
        roadConditionPreference: 'Prefer better road surfaces',
        weatherPreference: 'Prefer safer weather conditions',
        nightLightingPreference: 'Prefer well-lit roads',
        accessibilityPreference: 'Standard',
        travelPurpose: 'Daily commute',
        isConfigured: true,
      );

      final result = PreferenceMatchEvaluator.evaluate(
        evaluation: eval,
        profile: profile,
        isDay: false,
      );

      expect(result.matchPercentage, lessThan(60.0));
      expect(result.matchLabel, 'Lower Preference Match');
      expect(result.matchColor, const Color(0xffF97316));
    });
  });

  group('Category 16: Handling Unavailable Safety Factors', () {
    test('Does not penalize or fabricate fake score when lighting is unavailable in daytime', () {
      final eval = createMockEvaluation(
        score: 85,
        accidentScore: 85,
        roadScore: 80,
        lightingScore: null, // Day travel: lighting unavailable
      );

      final profile = PersonalSafetyProfile(
        vehicleMode: 'Car',
        safetyPriority: 'Safer Route',
        roadConditionPreference: 'Prefer better road surfaces',
        nightLightingPreference: 'Prefer well-lit roads',
        accessibilityPreference: 'Standard',
        travelPurpose: 'Daily commute',
        isConfigured: true,
      );

      final result = PreferenceMatchEvaluator.evaluate(
        evaluation: eval,
        profile: profile,
        isDay: true, // isDay = true excludes lighting weight cleanly
      );

      expect(result.matchPercentage, greaterThanOrEqualTo(75.0));
      // No lighting factor claimed when lighting was unavailable in daytime
      expect(result.matchFactors.any((f) => f.contains('night')), isFalse);
    });
  });

  group('Category 17: Active Route Integration & Widgets', () {
    testWidgets('PersonalSafetyProfileCard renders summary properly', (
      tester,
    ) async {
      final profile = PersonalSafetyProfile(
        vehicleMode: 'Bike',
        safetyPriority: 'Safer Route',
        travelPurpose: 'College',
        isConfigured: true,
      );

      bool clicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonalSafetyProfileCard(
              isDarkMode: true,
              profile: profile,
              onManagePreferences: () {
                clicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Personal Safety Profile'), findsOneWidget);
      expect(
        find.text('Customize SafeRoute TN for your travel preferences'),
        findsOneWidget,
      );
      expect(find.text('Manage Preferences'), findsOneWidget);
      expect(find.textContaining('Bike'), findsOneWidget);
      expect(find.textContaining('Safer Route'), findsOneWidget);

      await tester.tap(find.text('Manage Preferences'));
      await tester.pump();
      expect(clicked, isTrue);
    });

    testWidgets(
      'PersonalSafetyProfileDialog renders with active route context',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final eval = createMockEvaluation(score: 82);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PersonalSafetyProfileDialog(
                isDarkMode: true,
                activeRouteEvaluation: eval,
                isDay: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Personal Safety Profile'), findsOneWidget);
        expect(find.text('Apply My Preferences'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('தமிழ்'), findsOneWidget);
      },
    );

    testWidgets(
      'PersonalSafetyProfileDialog renders without route (empty state)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PersonalSafetyProfileDialog(
                isDarkMode: true,
                activeRouteEvaluation: null,
                isDay: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Personal Safety Profile'), findsOneWidget);
        expect(find.text('No active route loaded'), findsOneWidget);
      },
    );

    testWidgets('Toggling language changes strings in dialog', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PersonalSafetyProfileDialog(
              isDarkMode: true,
              activeRouteEvaluation: null,
              isDay: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Tamil
      await tester.tap(find.text('தமிழ்'));
      await tester.pumpAndSettle();

      expect(find.text('தனிப்பட்ட பாதுகாப்பு விவரக்குறிப்பு'), findsOneWidget);
      expect(find.text('செயலில் உள்ள பாதை இல்லை'), findsOneWidget);
    });
  });
}
