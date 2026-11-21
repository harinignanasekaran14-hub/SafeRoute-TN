import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:saferoute_tn/turn_by_turn_navigation.dart';
import 'package:saferoute_tn/web_speech.dart';

void main() {
  group('SafeRoute TN 2.0 – Turn-by-Turn Navigation Tests', () {
    // 1. OSRM manoeuvre parsing
    test('1. OSRM manoeuvre parsing parses diverse maneuver types, modifiers, roads, and exits', () {
      final rawSteps = [
        {
          'distance': 150.0,
          'duration': 20.0,
          'name': 'Anna Salai',
          'maneuver': {
            'type': 'depart',
            'modifier': null,
            'location': [80.2707, 13.0827],
          },
        },
        {
          'distance': 650.0,
          'duration': 55.0,
          'name': 'Mount Road',
          'maneuver': {
            'type': 'turn',
            'modifier': 'right',
            'location': [80.2600, 13.0700],
          },
        },
        {
          'distance': 400.0,
          'duration': 35.0,
          'name': 'Poonamallee High Road',
          'maneuver': {
            'type': 'turn',
            'modifier': 'slight left',
            'location': [80.2500, 13.0600],
          },
        },
        {
          'distance': 300.0,
          'duration': 25.0,
          'name': 'GST Road',
          'maneuver': {
            'type': 'roundabout',
            'modifier': null,
            'exit': 2,
            'location': [80.2300, 13.0400],
          },
        },
        {
          'distance': 200.0,
          'duration': 18.0,
          'name': 'Kamarajar Salai',
          'maneuver': {
            'type': 'continue',
            'modifier': 'uturn',
            'location': [80.2200, 13.0300],
          },
        },
        {
          'distance': 100.0,
          'duration': 10.0,
          'name': 'Airport Road',
          'maneuver': {
            'type': 'arrive',
            'modifier': null,
            'location': [80.2100, 13.0200],
          },
        },
      ];

      final steps = rawSteps.map(RouteStep.fromOsrm).toList();

      expect(steps.length, equals(6));

      // Step 0: Depart
      expect(steps[0].maneuverType, equals('depart'));
      expect(steps[0].instruction, contains('Anna Salai'));
      expect(steps[0].icon, equals(Icons.navigation_rounded));

      // Step 1: Turn right
      expect(steps[1].maneuverType, equals('turn'));
      expect(steps[1].maneuverModifier, equals('right'));
      expect(steps[1].instruction, equals('Turn right onto Mount Road'));
      expect(steps[1].shortInstruction, equals('Turn right'));
      expect(steps[1].icon, equals(Icons.turn_right_rounded));

      // Step 2: Slight left
      expect(steps[2].instruction, equals('Slight left onto Poonamallee High Road'));
      expect(steps[2].shortInstruction, equals('Slight left'));
      expect(steps[2].icon, equals(Icons.turn_slight_left_rounded));

      // Step 3: Roundabout with exit 2
      expect(steps[3].exitNumber, equals(2));
      expect(steps[3].instruction, equals('At the roundabout, take exit 2 onto GST Road'));
      expect(steps[3].shortInstruction, equals('Take exit 2'));
      expect(steps[3].icon, equals(Icons.roundabout_right_rounded));

      // Step 4: U-turn
      expect(steps[4].instruction, equals('Make a U-turn on Kamarajar Salai'));
      expect(steps[4].icon, equals(Icons.u_turn_left_rounded));

      // Step 5: Arrive
      expect(steps[5].maneuverType, equals('arrive'));
      expect(steps[5].instruction, equals('Arrive at destination on Airport Road'));
      expect(steps[5].icon, equals(Icons.place_rounded));
    });

    // 2. Turn instruction text generation without road names
    test('2. Turn instruction text generation handles missing road names gracefully', () {
      final step = RouteStep.fromOsrm({
        'distance': 250.0,
        'duration': 20.0,
        'name': '',
        'maneuver': {
          'type': 'turn',
          'modifier': 'left',
          'location': [80.20, 13.00],
        },
      });

      expect(step.instruction, equals('Turn left'));
      expect(step.shortInstruction, equals('Turn left'));
      expect(step.icon, equals(Icons.turn_left_rounded));
    });

    // 3. Distance-to-manoeuvre calculation
    test('3. Distance-to-manoeuvre calculation decreases accurately along route progress', () {
      final engine = NavigationInstructionEngine();
      final steps = [
        RouteStep(
          instruction: 'Start route on Main St',
          shortInstruction: 'Start',
          maneuverType: 'depart',
          location: const LatLng(13.08, 80.27),
          roadName: 'Main St',
          distanceMeters: 500.0,
          durationSeconds: 40.0,
          icon: Icons.navigation_rounded,
        ),
        RouteStep(
          instruction: 'Turn right onto Cross Rd',
          shortInstruction: 'Turn right',
          maneuverType: 'turn',
          maneuverModifier: 'right',
          location: const LatLng(13.07, 80.26),
          roadName: 'Cross Rd',
          distanceMeters: 600.0,
          durationSeconds: 50.0,
          icon: Icons.turn_right_rounded,
        ),
        RouteStep(
          instruction: 'Arrive at destination',
          shortInstruction: 'Arrive',
          maneuverType: 'arrive',
          location: const LatLng(13.06, 80.25),
          roadName: '',
          distanceMeters: 0.0,
          durationSeconds: 0.0,
          icon: Icons.place_rounded,
        ),
      ];

      engine.initializeRoute(steps, 1100.0);

      // User at 100m progress: distance to Step 1 (at 500m) should be 400m
      final state1 = engine.updateGpsPosition(
        userPosition: const LatLng(13.079, 80.269),
        userProgressMeters: 100.0,
      );
      expect(state1.distanceToStepMeters, closeTo(400.0, 1.0));
      expect(state1.currentStep?.shortInstruction, equals('Turn right'));

      // User at 450m progress: distance to Step 1 should be 50m
      final state2 = engine.updateGpsPosition(
        userPosition: const LatLng(13.071, 80.261),
        userProgressMeters: 450.0,
      );
      expect(state2.distanceToStepMeters, closeTo(50.0, 1.0));

      // User passes Step 1 at 540m (> 500 + 25m): advances to Step 2 (destination at 1100m)
      final state3 = engine.updateGpsPosition(
        userPosition: const LatLng(13.069, 80.259),
        userProgressMeters: 540.0,
      );
      expect(state3.currentStep?.maneuverType, equals('arrive'));
      expect(state3.distanceToStepMeters, closeTo(560.0, 1.0));
    });

    // 4. Announcement threshold triggering
    test('4. Announcement threshold triggering emits 500m, 150m, and now at appropriate distances', () {
      final engine = NavigationInstructionEngine();
      final steps = [
        RouteStep(
          instruction: 'Start on Highway 45',
          shortInstruction: 'Start',
          maneuverType: 'depart',
          location: const LatLng(13.08, 80.27),
          roadName: 'Highway 45',
          distanceMeters: 1000.0,
          durationSeconds: 80.0,
          icon: Icons.navigation_rounded,
        ),
        RouteStep(
          instruction: 'Turn left onto OMR',
          shortInstruction: 'Turn left',
          maneuverType: 'turn',
          maneuverModifier: 'left',
          location: const LatLng(13.07, 80.26),
          roadName: 'OMR',
          distanceMeters: 800.0,
          durationSeconds: 60.0,
          icon: Icons.turn_left_rounded,
        ),
      ];

      engine.initializeRoute(steps, 1800.0);

      // At 510m distance (user at 490m): triggers 500m stage
      final state500 = engine.updateGpsPosition(
        userPosition: const LatLng(13.075, 80.265),
        userProgressMeters: 490.0,
      );
      expect(state500.voiceToSpeak, isNotNull);
      expect(state500.voiceToSpeak, contains('In 500 metres, turn left onto OMR'));

      // At 140m distance (user at 860m): triggers 150m stage
      final state150 = engine.updateGpsPosition(
        userPosition: const LatLng(13.071, 80.261),
        userProgressMeters: 860.0,
      );
      expect(state150.voiceToSpeak, isNotNull);
      expect(state150.voiceToSpeak, contains('Turn left ahead onto OMR'));

      // At 20m distance (user at 980m): triggers now stage
      final stateNow = engine.updateGpsPosition(
        userPosition: const LatLng(13.0702, 80.2602),
        userProgressMeters: 980.0,
      );
      expect(stateNow.voiceToSpeak, isNotNull);
      expect(stateNow.voiceToSpeak, contains('Turn left now onto OMR'));
    });

    // 5. Preventing duplicate speech
    test('5. Preventing duplicate speech never repeats the same announcement within the same stage', () {
      final engine = NavigationInstructionEngine();
      final steps = [
        RouteStep(
          instruction: 'Start on Highway',
          shortInstruction: 'Start',
          maneuverType: 'depart',
          location: const LatLng(13.08, 80.27),
          roadName: 'Highway',
          distanceMeters: 1000.0,
          durationSeconds: 80.0,
          icon: Icons.navigation_rounded,
        ),
        RouteStep(
          instruction: 'Turn right onto Ring Road',
          shortInstruction: 'Turn right',
          maneuverType: 'turn',
          maneuverModifier: 'right',
          location: const LatLng(13.07, 80.26),
          roadName: 'Ring Road',
          distanceMeters: 500.0,
          durationSeconds: 40.0,
          icon: Icons.turn_right_rounded,
        ),
      ];

      engine.initializeRoute(steps, 1500.0);

      // Fix 1 at 490m distance: triggers 500m announcement
      final fix1 = engine.updateGpsPosition(
        userPosition: const LatLng(13.075, 80.265),
        userProgressMeters: 510.0,
      );
      expect(fix1.voiceToSpeak, isNotNull);

      // Fix 2 at 480m distance (still in 500m window): must be NULL (no duplicate)
      final fix2 = engine.updateGpsPosition(
        userPosition: const LatLng(13.074, 80.264),
        userProgressMeters: 520.0,
      );
      expect(fix2.voiceToSpeak, isNull);

      // Fix 3 at 470m distance: must be NULL
      final fix3 = engine.updateGpsPosition(
        userPosition: const LatLng(13.073, 80.263),
        userProgressMeters: 530.0,
      );
      expect(fix3.voiceToSpeak, isNull);
    });

    // 6. Voice OFF suppressing speech while preserving visual instructions
    test('6. Voice OFF suppresses speech output while visual fields update faithfully', () {
      final engine = NavigationInstructionEngine();
      final steps = [
        RouteStep(
          instruction: 'Start on Ave',
          shortInstruction: 'Start',
          maneuverType: 'depart',
          location: const LatLng(13.08, 80.27),
          roadName: 'Ave',
          distanceMeters: 1000.0,
          durationSeconds: 80.0,
          icon: Icons.navigation_rounded,
        ),
        RouteStep(
          instruction: 'Turn left onto Boulevard',
          shortInstruction: 'Turn left',
          maneuverType: 'turn',
          maneuverModifier: 'left',
          location: const LatLng(13.07, 80.26),
          roadName: 'Boulevard',
          distanceMeters: 500.0,
          durationSeconds: 40.0,
          icon: Icons.turn_left_rounded,
        ),
      ];

      engine.initializeRoute(steps, 1500.0);
      engine.setVoiceEnabled(false);
      expect(engine.voiceEnabled, isFalse);

      final state = engine.updateGpsPosition(
        userPosition: const LatLng(13.075, 80.265),
        userProgressMeters: 510.0, // within 500m window
      );

      // Speech suppressed
      expect(state.voiceToSpeak, isNull);

      // Visual fields remain accurate
      expect(state.currentStep?.shortInstruction, equals('Turn left'));
      expect(state.distanceToStepMeters, closeTo(490.0, 1.0));
      expect(state.isOffRoute, isFalse);
    });

    // 7. Route change resetting instruction progress
    test('7. Route change resetting instruction progress clears announced stages for new route', () {
      final engine = NavigationInstructionEngine();
      final routeA = [
        RouteStep(
          instruction: 'Start on A',
          shortInstruction: 'Start',
          maneuverType: 'depart',
          location: const LatLng(13.08, 80.27),
          roadName: 'A',
          distanceMeters: 1000.0,
          durationSeconds: 80.0,
          icon: Icons.navigation_rounded,
        ),
        RouteStep(
          instruction: 'Turn left on B',
          shortInstruction: 'Turn left',
          maneuverType: 'turn',
          location: const LatLng(13.07, 80.26),
          roadName: 'B',
          distanceMeters: 400.0,
          durationSeconds: 30.0,
          icon: Icons.turn_left_rounded,
        ),
      ];

      engine.initializeRoute(routeA, 1400.0);
      // Trigger 500m on Route A
      engine.updateGpsPosition(
        userPosition: const LatLng(13.075, 80.265),
        userProgressMeters: 520.0,
      );

      // Now switch to Route B
      final routeB = [
        RouteStep(
          instruction: 'Start on New Road',
          shortInstruction: 'Start',
          maneuverType: 'depart',
          location: const LatLng(13.08, 80.27),
          roadName: 'New Road',
          distanceMeters: 800.0,
          durationSeconds: 60.0,
          icon: Icons.navigation_rounded,
        ),
        RouteStep(
          instruction: 'Turn right on Expressway',
          shortInstruction: 'Turn right',
          maneuverType: 'turn',
          location: const LatLng(13.06, 80.24),
          roadName: 'Expressway',
          distanceMeters: 600.0,
          durationSeconds: 40.0,
          icon: Icons.turn_right_rounded,
        ),
      ];

      engine.initializeRoute(routeB, 1400.0);
      expect(engine.currentStepIndex, equals(0));

      // At 300m on Route B (distance to step 1 is 500m): triggers fresh 500m announcement for Route B
      final stateB = engine.updateGpsPosition(
        userPosition: const LatLng(13.077, 80.267),
        userProgressMeters: 300.0,
      );
      expect(stateB.voiceToSpeak, isNotNull);
      expect(stateB.voiceToSpeak?.toLowerCase(), contains('turn right'));
      expect(stateB.currentStep?.roadName, equals('Expressway'));
    });

    // 8. Stale GPS handling
    test('8. Stale GPS or poor accuracy suppresses turn voice announcements', () {
      final engine = NavigationInstructionEngine();
      final steps = [
        RouteStep(
          instruction: 'Start on Path',
          shortInstruction: 'Start',
          maneuverType: 'depart',
          location: const LatLng(13.08, 80.27),
          roadName: 'Path',
          distanceMeters: 600.0,
          durationSeconds: 50.0,
          icon: Icons.navigation_rounded,
        ),
        RouteStep(
          instruction: 'Turn right onto Alley',
          shortInstruction: 'Turn right',
          maneuverType: 'turn',
          location: const LatLng(13.07, 80.26),
          roadName: 'Alley',
          distanceMeters: 400.0,
          durationSeconds: 30.0,
          icon: Icons.turn_right_rounded,
        ),
      ];

      engine.initializeRoute(steps, 1000.0);

      // Stale fix: voiceToSpeak must be null
      final staleState = engine.updateGpsPosition(
        userPosition: const LatLng(13.075, 80.265),
        userProgressMeters: 450.0, // within 150m stage
        isStaleGps: true,
      );
      expect(staleState.voiceToSpeak, isNull);

      // Poor accuracy (> 65m): voiceToSpeak must be null
      final poorAccState = engine.updateGpsPosition(
        userPosition: const LatLng(13.075, 80.265),
        userProgressMeters: 450.0,
        gpsAccuracyMeters: 85.0,
      );
      expect(poorAccState.voiceToSpeak, isNull);
    });

    // 9. Destination arrival
    test('9. Destination arrival marks isDestinationReached and announces arrival once', () {
      final engine = NavigationInstructionEngine();
      final steps = [
        RouteStep(
          instruction: 'Start on Highway',
          shortInstruction: 'Start',
          maneuverType: 'depart',
          location: const LatLng(13.08, 80.27),
          roadName: 'Highway',
          distanceMeters: 200.0,
          durationSeconds: 15.0,
          icon: Icons.navigation_rounded,
        ),
        RouteStep(
          instruction: 'Arrive at destination',
          shortInstruction: 'Arrive',
          maneuverType: 'arrive',
          location: const LatLng(13.079, 80.269),
          roadName: '',
          distanceMeters: 0.0,
          durationSeconds: 0.0,
          icon: Icons.place_rounded,
        ),
      ];

      engine.initializeRoute(steps, 200.0);

      // At 180m progress (remaining 20m <= 35m): reached!
      final stateArrival = engine.updateGpsPosition(
        userPosition: const LatLng(13.079, 80.269),
        userProgressMeters: 180.0,
      );
      expect(stateArrival.isDestinationReached, isTrue);
      expect(stateArrival.voiceToSpeak, equals('You have arrived at your destination.'));

      // Subsequent update at 190m progress: no duplicate arrival speech
      final stateArrival2 = engine.updateGpsPosition(
        userPosition: const LatLng(13.079, 80.269),
        userProgressMeters: 190.0,
      );
      expect(stateArrival2.isDestinationReached, isTrue);
      expect(stateArrival2.voiceToSpeak, isNull);
    });

    // 10. Speech resource cleanup
    test('10. Speech resource cleanup calls stop on navigation stop', () {
      final engine = NavigationInstructionEngine();
      // Test that stop() executes safely without throwing on any platform
      expect(() => engine.stop(), returnsNormally);
      expect(() => engine.setVoiceEnabled(false), returnsNormally);
    });

    // 11. Multilingual localized instruction generation across all 6 languages
    test('11. Multilingual localized instruction generation across all 6 languages', () {
      final turnLeftStep = RouteStep(
        instruction: 'Turn left onto Anna Salai',
        shortInstruction: 'Turn left',
        maneuverType: 'turn',
        maneuverModifier: 'left',
        location: const LatLng(13.0827, 80.2707),
        roadName: 'Anna Salai',
        distanceMeters: 300.0,
        durationSeconds: 25.0,
        icon: Icons.turn_left_rounded,
      );

      // Tamil (ta-IN): natural script and sentence
      expect(turnLeftStep.localizedInstruction(NavLanguage.tamil), equals('Anna Salai-ல் இடதுபுறம் திரும்பவும்'));
      expect(turnLeftStep.localizedShortInstruction(NavLanguage.tamil), equals('இடதுபுறம் திரும்பவும்'));

      // English (en-IN)
      expect(turnLeftStep.localizedInstruction(NavLanguage.english), equals('Turn left onto Anna Salai'));
      expect(turnLeftStep.localizedShortInstruction(NavLanguage.english), equals('Turn left'));

      // Hindi (hi-IN)
      expect(turnLeftStep.localizedInstruction(NavLanguage.hindi), equals('Anna Salai पर बाएं मुड़ें'));
      expect(turnLeftStep.localizedShortInstruction(NavLanguage.hindi), equals('बाएं मुड़ें'));

      // Telugu (te-IN)
      expect(turnLeftStep.localizedInstruction(NavLanguage.telugu), equals('Anna Salai వైపు ఎడమవైపు తిరగండి'));
      expect(turnLeftStep.localizedShortInstruction(NavLanguage.telugu), equals('ఎడమవైపు తిరగండి'));

      // Malayalam (ml-IN)
      expect(turnLeftStep.localizedInstruction(NavLanguage.malayalam), equals('Anna Salai-ലേക്ക് ഇടത്തോട്ട് തിരിയുക'));
      expect(turnLeftStep.localizedShortInstruction(NavLanguage.malayalam), equals('ഇടത്തോട്ട് തിരിയുക'));

      // Kannada (kn-IN)
      expect(turnLeftStep.localizedInstruction(NavLanguage.kannada), equals('Anna Salai ಕಡೆಗೆ ಎಡಕ್ಕೆ ತಿರುಗಿ'));
      expect(turnLeftStep.localizedShortInstruction(NavLanguage.kannada), equals('ಎಡಕ್ಕೆ ತಿರುಗಿ'));
    });

    // 12. Road names and roundabout exit preservation without translating proper nouns
    test('12. Road names and roundabout exits are preserved without translating proper nouns', () {
      final roundaboutStep = RouteStep(
        instruction: 'At the roundabout, take exit 2 onto GST Road',
        shortInstruction: 'Take exit 2',
        maneuverType: 'roundabout',
        maneuverModifier: null,
        exitNumber: 2,
        location: const LatLng(13.0400, 80.2300),
        roadName: 'GST Road',
        distanceMeters: 350.0,
        durationSeconds: 30.0,
        icon: Icons.roundabout_right_rounded,
      );

      // Tamil: preserves GST Road and exit 2
      final taText = roundaboutStep.localizedInstruction(NavLanguage.tamil);
      expect(taText, contains('GST Road'));
      expect(taText, contains('2'));
      expect(taText, equals('வட்டச்சாலையில் வெளியேறு 2-ல் GST Road-ல் செல்லவும்'));

      // Hindi: preserves GST Road and exit 2
      final hiText = roundaboutStep.localizedInstruction(NavLanguage.hindi);
      expect(hiText, contains('GST Road'));
      expect(hiText, contains('2'));
      expect(hiText, equals('गोलचक्कर पर निकास 2 लेकर GST Road पर जाएं'));

      // Telugu: preserves GST Road and exit 2
      final teText = roundaboutStep.localizedInstruction(NavLanguage.telugu);
      expect(teText, contains('GST Road'));
      expect(teText, contains('2'));
      expect(teText, equals('రౌండ్‌అబౌట్ వద్ద ఎగ్జిట్ 2 తీసుకొని GST Road లోకి వెళ్లండి'));

      // Malayalam: preserves GST Road and exit 2
      final mlText = roundaboutStep.localizedInstruction(NavLanguage.malayalam);
      expect(mlText, contains('GST Road'));
      expect(mlText, contains('2'));
      expect(mlText, equals('റൗണ്ട് എബൗട്ടിൽ നിന്ന് എക്സിറ്റ് 2 വഴി GST Road-ലേക്ക് പോവുക'));

      // Kannada: preserves GST Road and exit 2
      final knText = roundaboutStep.localizedInstruction(NavLanguage.kannada);
      expect(knText, contains('GST Road'));
      expect(knText, contains('2'));
      expect(knText, equals('ರೌಂಡ್‌ಅಬೌಟ್‌ನಲ್ಲಿ ಎಕ್ಸಿಟ್ 2 ತೆಗೆದುಕೊಂಡು GST Road ಗೆ ತೆರಳಿ'));
    });

    // 13. Multilingual 500m, 150m, and 35m distance stage announcements
    test('13. Multilingual 500m, 150m, and 35m distance stage announcements', () {
      final step = RouteStep(
        instruction: 'Turn right onto Mount Road',
        shortInstruction: 'Turn right',
        maneuverType: 'turn',
        maneuverModifier: 'right',
        location: const LatLng(13.0700, 80.2600),
        roadName: 'Mount Road',
        distanceMeters: 600.0,
        durationSeconds: 50.0,
        icon: Icons.turn_right_rounded,
      );

      // Tamil
      expect(
        NavigationLocalizer.generateVoiceAnnouncement(
          step: step,
          stage: AnnouncementStage.stage500m,
          distanceMeters: 500.0,
          lang: NavLanguage.tamil,
        ),
        equals('500 மீட்டரில் Mount Road-ல் வலதுபுறம் திரும்பவும்.'),
      );
      expect(
        NavigationLocalizer.generateVoiceAnnouncement(
          step: step,
          stage: AnnouncementStage.stage150m,
          distanceMeters: 150.0,
          lang: NavLanguage.tamil,
        ),
        equals('முன்னால் Mount Road-ல் வலதுபுறம் திரும்பவும்.'),
      );
      expect(
        NavigationLocalizer.generateVoiceAnnouncement(
          step: step,
          stage: AnnouncementStage.stageNow,
          distanceMeters: 30.0,
          lang: NavLanguage.tamil,
        ),
        equals('இப்போது Mount Road-ல் வலதுபுறம் திரும்பவும்.'),
      );

      // English
      expect(
        NavigationLocalizer.generateVoiceAnnouncement(
          step: step,
          stage: AnnouncementStage.stage500m,
          distanceMeters: 500.0,
          lang: NavLanguage.english,
        ),
        equals('In 500 metres, turn right onto Mount Road.'),
      );
      expect(
        NavigationLocalizer.generateVoiceAnnouncement(
          step: step,
          stage: AnnouncementStage.stage150m,
          distanceMeters: 150.0,
          lang: NavLanguage.english,
        ),
        equals('Turn right ahead onto Mount Road.'),
      );
      expect(
        NavigationLocalizer.generateVoiceAnnouncement(
          step: step,
          stage: AnnouncementStage.stageNow,
          distanceMeters: 30.0,
          lang: NavLanguage.english,
        ),
        equals('Turn right now onto Mount Road.'),
      );

      // Hindi
      expect(
        NavigationLocalizer.generateVoiceAnnouncement(
          step: step,
          stage: AnnouncementStage.stage500m,
          distanceMeters: 500.0,
          lang: NavLanguage.hindi,
        ),
        equals('500 मीटर में Mount Road पर दाएं मुड़ें।'),
      );
    });

    // 14. Multilingual destination arrival announcements
    test('14. Multilingual destination arrival announcements', () {
      expect(
        NavigationLocalizer.getDestinationArrivalAnnouncement(NavLanguage.tamil),
        equals('நீங்கள் உங்கள் இலக்கை அடைந்துவிட்டீர்கள்.'),
      );
      expect(
        NavigationLocalizer.getDestinationArrivalAnnouncement(NavLanguage.english),
        equals('You have arrived at your destination.'),
      );
      expect(
        NavigationLocalizer.getDestinationArrivalAnnouncement(NavLanguage.hindi),
        equals('आप अपने गंतव्य पर पहुंच गए हैं।'),
      );
      expect(
        NavigationLocalizer.getDestinationArrivalAnnouncement(NavLanguage.telugu),
        equals('మీరు మీ గమ్యాన్ని చేరుకున్నారు.'),
      );
      expect(
        NavigationLocalizer.getDestinationArrivalAnnouncement(NavLanguage.malayalam),
        equals('നിങ്ങൾ ലക്ഷ്യസ്ഥാനത്ത് എത്തിച്ചേർന്നു.'),
      );
      expect(
        NavigationLocalizer.getDestinationArrivalAnnouncement(NavLanguage.kannada),
        equals('ನೀವು ನಿಮ್ಮ ಗಮ್ಯಸ್ಥಾನವನ್ನು ತಲುಪಿದ್ದೀರಿ.'),
      );
    });

    // 15. Voice selection with BCP-47 and fallback when voice is unavailable
    test('15. Voice selection with BCP-47 and fallback when voice is unavailable', () {
      WebSpeechHelper.resetMock();
      WebSpeechHelper.mockSupported = true;

      // Scenario A: Only English voice is installed in browser
      WebSpeechHelper.mockAvailableVoices = {
        'en-IN': true,
        'en-US': true,
      };

      final engine = NavigationInstructionEngine();
      engine.setLanguage(NavLanguage.tamil); // ta-IN

      // Since ta-IN is not available, isVoiceUnavailable must be true
      expect(engine.isVoiceUnavailable, isTrue);

      // Verify WebSpeechHelper does NOT speak in wrong language when ta-IN is requested
      final spokenSuccess = WebSpeechHelper.speak('500 மீட்டரில் வலதுபுறம் திரும்பவும்', lang: 'ta-IN');
      expect(spokenSuccess, isFalse);
      expect(WebSpeechHelper.spokenTexts, isEmpty);

      // Scenario B: User switches to English which IS installed
      engine.setLanguage(NavLanguage.english);
      expect(engine.isVoiceUnavailable, isFalse);
      final spokenEn = WebSpeechHelper.speak('In 500 metres, turn right', lang: 'en-IN');
      expect(spokenEn, isTrue);
      expect(WebSpeechHelper.spokenTexts.length, equals(1));
      expect(WebSpeechHelper.spokenLangs.last, equals('en-IN'));

      // Scenario C: Browser fires voiceschanged event and installs Tamil voice
      WebSpeechHelper.mockAvailableVoices!['ta-IN'] = true;
      WebSpeechHelper.triggerVoicesChanged();
      engine.setLanguage(NavLanguage.tamil);
      expect(engine.isVoiceUnavailable, isFalse);

      WebSpeechHelper.resetMock();
    });

    // 16. Dynamic language switching preserves route progress and updates instructions
    test('16. Dynamic language switching preserves route progress and updates instructions', () {
      final engine = NavigationInstructionEngine();
      final steps = [
        RouteStep(
          instruction: 'Start route on Anna Salai',
          shortInstruction: 'Start route',
          maneuverType: 'depart',
          location: const LatLng(13.0827, 80.2707),
          roadName: 'Anna Salai',
          distanceMeters: 500.0,
          durationSeconds: 40.0,
          icon: Icons.navigation_rounded,
        ),
        RouteStep(
          instruction: 'Turn right onto Mount Road',
          shortInstruction: 'Turn right',
          maneuverType: 'turn',
          maneuverModifier: 'right',
          location: const LatLng(13.0700, 80.2600),
          roadName: 'Mount Road',
          distanceMeters: 400.0,
          durationSeconds: 35.0,
          icon: Icons.turn_right_rounded,
        ),
      ];

      engine.initializeRoute(steps, 900.0);
      expect(engine.language, equals(NavLanguage.english));

      // User has traveled 200m
      final state1 = engine.updateGpsPosition(
        userPosition: const LatLng(13.078, 80.268),
        userProgressMeters: 200.0,
      );
      expect(state1.activeStepIndex, equals(1));
      expect(state1.currentStep!.shortInstruction, equals('Turn right'));

      // Switch language to Tamil while navigation is active
      engine.setLanguage(NavLanguage.tamil);
      expect(engine.language, equals(NavLanguage.tamil));

      // Route progress is maintained at 200m; state reflects Tamil instructions
      final state2 = engine.updateGpsPosition(
        userPosition: const LatLng(13.078, 80.268),
        userProgressMeters: 200.0,
      );
      expect(state2.activeStepIndex, equals(1));
      expect(state2.language, equals(NavLanguage.tamil));
      expect(state2.currentStep!.localizedShortInstruction(NavLanguage.tamil), equals('வலதுபுறம் திரும்பவும்'));
      expect(state2.currentStep!.localizedInstruction(NavLanguage.tamil), equals('Mount Road-ல் வலதுபுறம் திரும்பவும்'));
    });

    // 17. NavigationInstructionCard renders language selector and voice unavailable indicator
    testWidgets('17. NavigationInstructionCard renders language selector and handles voice unavailable state', (tester) async {
      final step = RouteStep(
        instruction: 'Turn left onto Anna Salai',
        shortInstruction: 'Turn left',
        maneuverType: 'turn',
        maneuverModifier: 'left',
        location: const LatLng(13.0827, 80.2707),
        roadName: 'Anna Salai',
        distanceMeters: 250.0,
        durationSeconds: 20.0,
        icon: Icons.turn_left_rounded,
      );

      NavLanguage? selectedLang;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavigationInstructionCard(
              currentStep: step,
              distanceToStepMeters: 250.0,
              isVoiceEnabled: true,
              onToggleVoice: () {},
              isDarkMode: true,
              language: NavLanguage.tamil,
              isVoiceUnavailable: true,
              onSelectLanguage: (lang) => selectedLang = lang,
            ),
          ),
        ),
      );

      // Verify Tamil short instruction is displayed in main title
      expect(find.text('இடதுபுறம் திரும்பவும்'.toUpperCase()), findsOneWidget);

      // Verify Tamil road sub-details is displayed
      expect(find.text('Anna Salai-ல் செல்லவும்'), findsOneWidget);

      // Verify TA language pill badge is present
      expect(find.text('TA'), findsOneWidget);

      // Verify Voice Unavailable advisory notice is displayed
      expect(find.textContaining('தமிழ் குரல் கிடைக்கவில்லை'), findsOneWidget);

      // Tap language selector pill to open popup menu
      await tester.tap(find.text('TA'));
      await tester.pumpAndSettle();

      // Verify English option is listed in the menu
      expect(find.text('English (English)'), findsOneWidget);
      expect(find.text('हिन्दी (Hindi)'), findsOneWidget);

      // Tap English from menu
      await tester.tap(find.text('English (English)'));
      await tester.pumpAndSettle();

      expect(selectedLang, equals(NavLanguage.english));
    });

    // 18. Cockpit instructions in Tamil and English (short distance ahead vs future distance)
    test('18. Cockpit instructions in Tamil and English (short distance ahead vs future distance)', () {
      final turnRightStep = RouteStep(
        instruction: 'Turn right onto Magudanchavadi - Edappadi - Komarapalayam Road',
        shortInstruction: 'Turn right',
        maneuverType: 'turn',
        maneuverModifier: 'right',
        location: const LatLng(11.5500, 77.9500),
        roadName: 'Magudanchavadi - Edappadi - Komarapalayam Road',
        distanceMeters: 250.0,
        durationSeconds: 20.0,
        icon: Icons.turn_right_rounded,
      );

      // Distance > 40m
      expect(
        NavigationLocalizer.getCockpitInstruction(
          step: turnRightStep,
          fallbackInstruction: turnRightStep.instruction,
          isOffRoute: false,
          isDestinationReached: false,
          lang: NavLanguage.tamil,
        ),
        equals('250 மீ-ல் வலதுபுறம் திரும்பவும்'),
      );
      expect(
        NavigationLocalizer.getCockpitInstruction(
          step: turnRightStep,
          fallbackInstruction: turnRightStep.instruction,
          isOffRoute: false,
          isDestinationReached: false,
          lang: NavLanguage.english,
        ),
        equals('Turn right in 250 m'),
      );

      // Distance <= 40m (immediate maneuver ahead)
      final immediateStep = RouteStep(
        instruction: 'Turn right onto Magudanchavadi - Edappadi - Komarapalayam Road',
        shortInstruction: 'Turn right',
        maneuverType: 'turn',
        maneuverModifier: 'right',
        location: const LatLng(11.5500, 77.9500),
        roadName: 'Magudanchavadi - Edappadi - Komarapalayam Road',
        distanceMeters: 30.0,
        durationSeconds: 3.0,
        icon: Icons.turn_right_rounded,
      );

      expect(
        NavigationLocalizer.getCockpitInstruction(
          step: immediateStep,
          fallbackInstruction: immediateStep.instruction,
          isOffRoute: false,
          isDestinationReached: false,
          lang: NavLanguage.tamil,
        ),
        equals('முன்னால் வலதுபுறம் திரும்பவும்'),
      );
      expect(
        NavigationLocalizer.getCockpitInstruction(
          step: immediateStep,
          fallbackInstruction: immediateStep.instruction,
          isOffRoute: false,
          isDestinationReached: false,
          lang: NavLanguage.english,
        ),
        equals('Turn right ahead'),
      );

      // Off-route state
      expect(
        NavigationLocalizer.getCockpitInstruction(
          step: turnRightStep,
          fallbackInstruction: turnRightStep.instruction,
          isOffRoute: true,
          isDestinationReached: false,
          lang: NavLanguage.tamil,
        ),
        equals('வழியை விட்டு விலகிவிட்டீர்கள் — மீண்டும் இணைய திரும்பவும்'),
      );
      expect(
        NavigationLocalizer.getCockpitInstruction(
          step: turnRightStep,
          fallbackInstruction: turnRightStep.instruction,
          isOffRoute: true,
          isDestinationReached: false,
          lang: NavLanguage.english,
        ),
        equals('Off Route — Turn around to rejoin'),
      );

      // Destination reached state
      expect(
        NavigationLocalizer.getCockpitInstruction(
          step: turnRightStep,
          fallbackInstruction: turnRightStep.instruction,
          isOffRoute: false,
          isDestinationReached: true,
          lang: NavLanguage.tamil,
        ),
        equals('இலக்கை அடைந்துவிட்டீர்கள்!'),
      );
      expect(
        NavigationLocalizer.getCockpitInstruction(
          step: turnRightStep,
          fallbackInstruction: turnRightStep.instruction,
          isOffRoute: false,
          isDestinationReached: true,
          lang: NavLanguage.english,
        ),
        equals('Destination reached!'),
      );
    });

    // 19. Road name and proper noun preservation in cockpit road direction context
    test('19. Road name and proper noun preservation in cockpit road direction context', () {
      const road = 'Magudanchavadi - Edappadi - Komarapalayam Road';
      const destination = 'Kallakuruchi';

      // Tamil: preserves exact road name and destination with Tamil case suffixes
      final tamilContext = NavigationLocalizer.getCockpitRoadDirectionContext(
        roadName: road,
        destinationName: destination,
        isOffRoute: false,
        offRouteDistanceMeters: null,
        lang: NavLanguage.tamil,
      );
      expect(tamilContext, equals('Magudanchavadi - Edappadi - Komarapalayam Road-ல் • Kallakuruchi நோக்கி'));
      expect(tamilContext, contains(road));
      expect(tamilContext, contains(destination));

      // English: standard prepositions
      final englishContext = NavigationLocalizer.getCockpitRoadDirectionContext(
        roadName: road,
        destinationName: destination,
        isOffRoute: false,
        offRouteDistanceMeters: null,
        lang: NavLanguage.english,
      );
      expect(englishContext, equals('On Magudanchavadi - Edappadi - Komarapalayam Road • Toward Kallakuruchi'));
      expect(englishContext, contains(road));
      expect(englishContext, contains(destination));

      // Off-route context
      final offRouteTa = NavigationLocalizer.getCockpitRoadDirectionContext(
        roadName: road,
        destinationName: destination,
        isOffRoute: true,
        offRouteDistanceMeters: 85.0,
        lang: NavLanguage.tamil,
      );
      expect(offRouteTa, equals('பரிந்துரைக்கப்பட்ட பாதையிலிருந்து 85 மீ தொலைவில்'));

      final offRouteEn = NavigationLocalizer.getCockpitRoadDirectionContext(
        roadName: road,
        destinationName: destination,
        isOffRoute: true,
        offRouteDistanceMeters: 85.0,
        lang: NavLanguage.english,
      );
      expect(offRouteEn, equals('85 m away from recommended route'));
    });

    // 20. Distance formatting across Tamil and English
    test('20. Distance formatting across Tamil and English', () {
      // Meters (< 1000m)
      expect(NavigationLocalizer.formatDistance(250.0, lang: NavLanguage.tamil), equals('250 மீ'));
      expect(NavigationLocalizer.formatDistance(250.0, lang: NavLanguage.english), equals('250 m'));
      expect(NavigationLocalizer.formatDistance(45.0, lang: NavLanguage.hindi), equals('45 मी'));

      // Kilometers (>= 1000m)
      expect(NavigationLocalizer.formatDistance(1400.0, lang: NavLanguage.tamil), equals('1.4 கி.மீ'));
      expect(NavigationLocalizer.formatDistance(1400.0, lang: NavLanguage.english), equals('1.4 km'));
      expect(NavigationLocalizer.formatDistance(2500.0, lang: NavLanguage.hindi), equals('2.5 किमी'));

      // Zero / null
      expect(NavigationLocalizer.formatDistance(0.0, lang: NavLanguage.tamil), equals('0 மீ'));
      expect(NavigationLocalizer.formatDistance(null, lang: NavLanguage.english), equals('0 m'));
    });

    // 21. Cockpit action labels and status badges localization
    test('21. Cockpit action labels and status badges localization', () {
      // Stop button
      expect(
        NavigationLocalizer.getCockpitActionLabel('stop', state: false, lang: NavLanguage.tamil, fallback: 'Stop'),
        equals('நிறுத்து'),
      );
      expect(
        NavigationLocalizer.getCockpitActionLabel('stop', state: false, lang: NavLanguage.english, fallback: 'Stop'),
        equals('Stop'),
      );

      // Following / Recenter
      expect(
        NavigationLocalizer.getCockpitActionLabel('following', state: true, lang: NavLanguage.tamil, fallback: 'Following'),
        equals('பின்தொடர்கிறது'),
      );
      expect(
        NavigationLocalizer.getCockpitActionLabel('following', state: false, lang: NavLanguage.tamil, fallback: 'Recenter'),
        equals('மறுசீரமை'),
      );

      // Voice
      expect(
        NavigationLocalizer.getCockpitActionLabel('voice', state: true, lang: NavLanguage.tamil, fallback: 'Voice On'),
        equals('குரல் ஆன்'),
      );
      expect(
        NavigationLocalizer.getCockpitActionLabel('voice', state: false, lang: NavLanguage.tamil, fallback: 'Muted'),
        equals('மௌனம்'),
      );

      // Report & Share
      expect(
        NavigationLocalizer.getCockpitActionLabel('report', state: false, lang: NavLanguage.tamil, fallback: 'Report Issue'),
        equals('சிக்கல் புகாரளி'),
      );
      expect(
        NavigationLocalizer.getCockpitActionLabel('share', state: true, lang: NavLanguage.tamil, fallback: 'Live Sharing'),
        equals('நேரலை பகிர்வு'),
      );

      // Badges
      expect(NavigationLocalizer.getSharingBadge(NavLanguage.tamil), equals('பகிர்வு'));
      expect(NavigationLocalizer.getSharingBadge(NavLanguage.english), equals('SHARING'));
      expect(NavigationLocalizer.getRouteNumberBadge(1, NavLanguage.tamil), equals('வழிப்பாதை 1'));
      expect(NavigationLocalizer.getVehicleName('Car', NavLanguage.tamil), equals('கார்'));
      expect(NavigationLocalizer.getVehicleName('Bike', NavLanguage.tamil), equals('இருசக்கர வாகனம்'));
      expect(NavigationLocalizer.getGpsWaitingMessage(NavLanguage.tamil), equals('சாதனத்தின் ஜிபிஎஸ் சிக்னலுக்காக காத்திருக்கிறது...'));
      expect(NavigationLocalizer.getGpsStatusLabel('on_route', lang: NavLanguage.tamil), equals('சரியான பாதையில் • ஜிபிஎஸ்'));
    });

    // 22. Widget test verifying simultaneous Tamil rendering and immediate English switching
    testWidgets('22. Simultaneous Tamil rendering across navigation components and dynamic English switching', (tester) async {
      final step = RouteStep(
        instruction: 'Turn right onto Magudanchavadi - Edappadi - Komarapalayam Road',
        shortInstruction: 'Turn right',
        maneuverType: 'turn',
        maneuverModifier: 'right',
        location: const LatLng(11.5500, 77.9500),
        roadName: 'Magudanchavadi - Edappadi - Komarapalayam Road',
        distanceMeters: 30.0,
        durationSeconds: 3.0,
        icon: Icons.turn_right_rounded,
      );

      var currentLang = NavLanguage.tamil;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    // Top Card
                    NavigationInstructionCard(
                      currentStep: step,
                      distanceToStepMeters: 30.0,
                      isVoiceEnabled: true,
                      onToggleVoice: () {},
                      isDarkMode: true,
                      language: currentLang,
                      isVoiceUnavailable: true,
                      onSelectLanguage: (lang) {
                        setState(() => currentLang = lang);
                      },
                    ),
                    // Bottom Cockpit Mock Widget
                    Builder(
                      builder: (ctx) {
                        final instruction = NavigationLocalizer.getCockpitInstruction(
                          step: step,
                          fallbackInstruction: step.instruction,
                          isOffRoute: false,
                          isDestinationReached: false,
                          lang: currentLang,
                        );
                        final roadContext = NavigationLocalizer.getCockpitRoadDirectionContext(
                          roadName: step.roadName,
                          destinationName: 'Kallakuruchi',
                          isOffRoute: false,
                          offRouteDistanceMeters: null,
                          lang: currentLang,
                        );
                        final stopLabel = NavigationLocalizer.getCockpitActionLabel(
                          'stop',
                          state: false,
                          lang: currentLang,
                          fallback: 'Stop',
                        );
                        return Column(
                          children: [
                            Text(instruction, key: const Key('cockpit_instruction')),
                            Text(roadContext, key: const Key('cockpit_road_context')),
                            Text(stopLabel, key: const Key('cockpit_stop_button')),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      // Verify TOP Card displays Tamil
      expect(find.text('வலதுபுறம் திரும்பவும்'.toUpperCase()), findsOneWidget);

      // Verify BOTTOM Cockpit displays Tamil
      expect(find.text('முன்னால் வலதுபுறம் திரும்பவும்'), findsOneWidget);
      expect(find.text('Magudanchavadi - Edappadi - Komarapalayam Road-ல் • Kallakuruchi நோக்கி'), findsOneWidget);
      expect(find.text('நிறுத்து'), findsOneWidget);

      // Tap language selector to switch to English
      await tester.tap(find.text('TA'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English (English)'));
      await tester.pumpAndSettle();

      // Verify BOTH components immediately switched to English
      expect(find.text('TURN RIGHT'), findsOneWidget);
      expect(find.text('Turn right ahead'), findsOneWidget);
      expect(find.text('On Magudanchavadi - Edappadi - Komarapalayam Road • Toward Kallakuruchi'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });

  });
}