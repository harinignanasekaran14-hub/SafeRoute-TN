import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:saferoute_tn/emergency_assistance.dart';
import 'package:saferoute_tn/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmergencyContact Model Tests', () {
    test('JSON serialization and deserialization', () {
      final contact = EmergencyContact(
        id: '123456789',
        name: 'Amma',
        phone: '9876543210',
        createdAt: DateTime(2026, 10, 11, 10, 0),
      );

      final json = contact.toJson();
      expect(json['id'], '123456789');
      expect(json['name'], 'Amma');
      expect(json['phone'], '9876543210');
      expect(json['created_at'], isNotNull);

      final decoded = EmergencyContact.fromJson(json);
      expect(decoded.id, '123456789');
      expect(decoded.name, 'Amma');
      expect(decoded.phone, '9876543210');
      expect(decoded.createdAt.year, 2026);
    });

    test('copyWith works correctly', () {
      final original = EmergencyContact(
        id: '1',
        name: 'Test',
        phone: '112',
        createdAt: DateTime(2026, 1, 1),
      );
      final copied = original.copyWith(name: 'Updated Test');
      expect(copied.id, '1');
      expect(copied.name, 'Updated Test');
      expect(copied.phone, '112');
      expect(copied.createdAt, original.createdAt);
    });
  });

  group('EmergencyContactsStorage SharedPreferences Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads empty list by default', () async {
      final contacts = await EmergencyContactsStorage.loadContacts();
      expect(contacts, isEmpty);
    });

    test('Saves and loads emergency contacts locally', () async {
      final contact1 = EmergencyContact(
        id: 'c1',
        name: 'Family Doctor',
        phone: '+91 94440 12345',
        createdAt: DateTime.now(),
      );
      final contact2 = EmergencyContact(
        id: 'c2',
        name: 'Brother',
        phone: '9840012345',
        createdAt: DateTime.now(),
      );

      await EmergencyContactsStorage.saveContacts([contact1, contact2]);
      final loaded = await EmergencyContactsStorage.loadContacts();

      expect(loaded.length, 2);
      expect(loaded[0].name, 'Family Doctor');
      expect(loaded[0].phone, '+91 94440 12345');
      expect(loaded[1].name, 'Brother');
      expect(loaded[1].phone, '9840012345');
    });

    test(
      'Isolated from other keys such as favourite routes and saved trips',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('saferoute_favourite_routes', [
          '{"origin":"A"}',
        ]);
        await prefs.setStringList('saferoute_saved_trips', ['{"origin":"B"}']);

        final contact = EmergencyContact(
          id: 'c_test',
          name: 'Emergency Friend',
          phone: '9999999999',
          createdAt: DateTime.now(),
        );
        await EmergencyContactsStorage.saveContacts([contact]);

        // Verify contact saved under its own key
        final loadedContacts = await EmergencyContactsStorage.loadContacts();
        expect(loadedContacts.length, 1);
        expect(loadedContacts.first.name, 'Emergency Friend');

        // Verify other keys remain untouched
        expect(prefs.getStringList('saferoute_favourite_routes'), hasLength(1));
        expect(prefs.getStringList('saferoute_saved_trips'), hasLength(1));
      },
    );
  });

  group('EmergencyAssistanceLocalization Tests', () {
    test('English strings are accurate and non-empty', () {
      expect(
        EmergencyAssistanceLocalization.title(false),
        'Emergency Assistance',
      );
      expect(
        EmergencyAssistanceLocalization.subtitle(false),
        'Quick access to emergency services',
      );
      expect(EmergencyAssistanceLocalization.police(false), 'Police');
      expect(EmergencyAssistanceLocalization.ambulance(false), 'Ambulance');
      expect(EmergencyAssistanceLocalization.fire(false), 'Fire & Rescue');
      expect(
        EmergencyAssistanceLocalization.hospital(false),
        'Nearby Hospital',
      );
      expect(EmergencyAssistanceLocalization.quickSos(false), 'Quick SOS');
      expect(
        EmergencyAssistanceLocalization.noRouteHeading(false),
        'No active route',
      );
      expect(
        EmergencyAssistanceLocalization.noRoutePrompt(false),
        'Plan a route to see route-specific emergency context.',
      );
      expect(
        EmergencyAssistanceLocalization.hospitalUnavailable(false),
        'Nearby hospital information is currently unavailable.',
      );
    });

    test('Tamil strings are accurate and non-empty', () {
      expect(EmergencyAssistanceLocalization.title(true), 'அவசர உதவி');
      expect(
        EmergencyAssistanceLocalization.subtitle(true),
        'அவசர சேவைகளை விரைவாக அணுகவும்',
      );
      expect(EmergencyAssistanceLocalization.police(true), 'காவல்துறை');
      expect(EmergencyAssistanceLocalization.ambulance(true), 'ஆம்புலன்ஸ்');
      expect(EmergencyAssistanceLocalization.fire(true), 'தீயணைப்பு & மீட்பு');
      expect(
        EmergencyAssistanceLocalization.hospital(true),
        'அருகிலுள்ள மருத்துவமனை',
      );
      expect(EmergencyAssistanceLocalization.quickSos(true), 'விரைவு SOS');
      expect(
        EmergencyAssistanceLocalization.noRouteHeading(true),
        'செயலில் உள்ள வழி இல்லை',
      );
      expect(
        EmergencyAssistanceLocalization.hospitalUnavailable(true),
        'அருகிலுள்ள மருத்துவமனை தகவல் தற்போது கிடைக்கவில்லை.',
      );
    });

    test('Call confirmation prompts include service name and number', () {
      expect(
        EmergencyAssistanceLocalization.callConfirmTitle('Police', false),
        'Call Police?',
      );
      expect(
        EmergencyAssistanceLocalization.callConfirmPrompt('112', false),
        'Do you want to call 112?',
      );
      expect(
        EmergencyAssistanceLocalization.callConfirmTitle('காவல்துறை', true),
        'காவல்துறை-ஐ அழைக்கவா?',
      );
      expect(
        EmergencyAssistanceLocalization.callConfirmPrompt('112', true),
        '112 எண்ணை அழைக்க விரும்புகிறீர்களா?',
      );
    });
  });

  group('EmergencyAssistanceDialog Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'Renders all emergency services and inactive route context correctly',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmergencyAssistanceDialog(
                isDarkMode: true,
                routeOrigin: null,
                routeDestination: null,
                formatDurationFn: (mins) => '${mins.round()}m',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Header
        expect(find.text('Emergency Assistance'), findsOneWidget);
        expect(find.text('Quick access to emergency services'), findsOneWidget);

        // Check Quick SOS
        expect(find.text('Quick SOS'), findsOneWidget);
        expect(find.text('112'), findsWidgets);
        expect(find.text('108'), findsWidgets);
        expect(find.text('101'), findsWidgets);

        // Check 3 core emergency services (each appears in Quick SOS and service card)
        expect(find.text('Police'), findsWidgets);
        expect(find.text('Ambulance'), findsWidgets);
        expect(find.text('Fire & Rescue'), findsWidgets);

        // Check Hospital unavailable fallback when no facilities provided
        expect(find.text('Nearby Hospital'), findsOneWidget);
        expect(
          find.text('Nearby hospital information is currently unavailable.'),
          findsOneWidget,
        );

        // Check Route Context empty state
        expect(find.text('No active route'), findsOneWidget);
        expect(
          find.text('Plan a route to see route-specific emergency context.'),
          findsOneWidget,
        );

        // Check Emergency Contacts section header
        expect(find.text('Emergency Contacts'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders active route context and nearby hospital when available',
      (tester) async {
        const sampleHospital = Facility(
          id: 'hosp_01',
          categoryId: 'hospital',
          name: 'Coimbatore Medical College Hospital',
          lat: 11.001,
          lon: 76.966,
          phone: '0422 230 1393',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmergencyAssistanceDialog(
                isDarkMode: true,
                routeOrigin: 'Gandhipuram',
                routeDestination: 'Singanallur',
                vehicleMode: 'Car',
                travelTimeMode: 'Day',
                distanceKm: 8.5,
                durationMinutes: 22.0,
                safetyScore: 84.0,
                nearbyFacilities: const [sampleHospital],
                formatDurationFn: (mins) => '${mins.round()}m',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Active Route details
        expect(find.text('Gandhipuram → Singanallur'), findsOneWidget);
        expect(find.textContaining('8.5 km'), findsOneWidget);
        expect(find.textContaining('22m'), findsOneWidget);
        expect(find.textContaining('84 / 100'), findsOneWidget);

        // Hospital information from real facility
        expect(
          find.text('Coimbatore Medical College Hospital'),
          findsOneWidget,
        );
        expect(find.text('0422 230 1393'), findsWidgets);
      },
    );

    testWidgets('Toggles language between English and Tamil', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyAssistanceDialog(
              isDarkMode: true,
              formatDurationFn: (mins) => '${mins.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially English
      expect(find.text('Emergency Assistance'), findsOneWidget);

      // Tap Tamil toggle
      final translateBtn = find.text('English');
      expect(translateBtn, findsOneWidget);
      await tester.tap(translateBtn);
      await tester.pumpAndSettle();

      // Now Tamil
      expect(find.text('அவசர உதவி'), findsOneWidget);
      expect(find.text('அவசர சேவைகளை விரைவாக அணுகவும்'), findsOneWidget);
      expect(find.text('விரைவு SOS'), findsOneWidget);

      // Tap back to English
      final tamilBtn = find.text('தமிழ்');
      expect(tamilBtn, findsOneWidget);
      await tester.tap(tamilBtn);
      await tester.pumpAndSettle();

      expect(find.text('Emergency Assistance'), findsOneWidget);
    });

    testWidgets('Allows adding an emergency contact locally', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyAssistanceDialog(
              isDarkMode: true,
              formatDurationFn: (mins) => '${mins.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Add Contact button
      final addBtn = find.text('Add Contact');
      expect(addBtn, findsOneWidget);
      await tester.ensureVisible(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Form text fields should be visible
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'Appa');
      await tester.enterText(textFields.at(1), '9443322110');
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.text('Save');
      expect(saveBtn, findsOneWidget);
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify contact appears in list
      expect(find.text('Appa'), findsOneWidget);
      expect(find.text('9443322110'), findsOneWidget);
    });
  });

  group('EmergencyLocationHelper Tests', () {
    test('buildGoogleMapsUrl generates correct URL for valid coordinates', () {
      final url = EmergencyLocationHelper.buildGoogleMapsUrl(11.016844, 76.955832);
      expect(url, 'https://maps.google.com/?q=11.016844,76.955832');
    });

    test('buildGoogleMapsUrl returns empty string for invalid coordinates', () {
      expect(EmergencyLocationHelper.buildGoogleMapsUrl(95.0, 76.0), isEmpty);
      expect(EmergencyLocationHelper.buildGoogleMapsUrl(11.0, 200.0), isEmpty);
      expect(EmergencyLocationHelper.buildGoogleMapsUrl(double.nan, 76.0), isEmpty);
    });

    test('buildSosMessage formats comprehensive message with accuracy and route', () {
      final msg = EmergencyLocationHelper.buildSosMessage(
        latitude: 11.016844,
        longitude: 76.955832,
        accuracyMeters: 12.4,
        routeOrigin: 'Coimbatore Junction',
        routeDestination: 'RS Puram',
        timestamp: DateTime(2026, 11, 6, 14, 30),
      );

      expect(msg, contains('Emergency SOS – SafeRoute TN'));
      expect(msg, contains('https://maps.google.com/?q=11.016844,76.955832'));
      expect(msg, contains('Coordinates: 11.016844, 76.955832'));
      expect(msg, contains('(±12m accuracy)'));
      expect(msg, contains('Route: Coimbatore Junction → RS Puram'));
      expect(msg, contains('Not continuous live tracking'));
    });

    test('buildSosMessage gracefully handles missing route and accuracy', () {
      final msg = EmergencyLocationHelper.buildSosMessage(
        latitude: 13.0827,
        longitude: 80.2707,
        accuracyMeters: null,
        routeOrigin: null,
        routeDestination: null,
        timestamp: DateTime(2026, 11, 6, 14, 30),
      );

      expect(msg, contains('Emergency SOS – SafeRoute TN'));
      expect(msg, contains('https://maps.google.com/?q=13.082700,80.270700'));
      expect(msg, contains('Coordinates: 13.082700, 80.270700'));
      expect(msg, isNot(contains('accuracy')));
      expect(msg, isNot(contains('Route:')));
      expect(msg, contains('Not continuous live tracking'));
    });

    test('buildSosMessage returns location unavailable for invalid coordinates', () {
      final msg = EmergencyLocationHelper.buildSosMessage(
        latitude: 100.0,
        longitude: 80.0,
      );
      expect(msg, contains('Location unavailable'));
    });

    test('buildWhatsAppUri and buildSmsUri construct properly encoded intents', () {
      const msg = 'Emergency SOS – SafeRoute TN: Help!';
      final waUri = EmergencyLocationHelper.buildWhatsAppUri(msg);
      expect(waUri.scheme, 'https');
      expect(waUri.host, 'wa.me');
      expect(waUri.queryParameters['text'], msg);

      final waContactUri = EmergencyLocationHelper.buildWhatsAppUri(msg, phoneNumber: '+91 98765 43210');
      expect(waContactUri.path, '/919876543210');
      expect(waContactUri.queryParameters['text'], msg);

      final smsUri = EmergencyLocationHelper.buildSmsUri(msg, phoneNumber: '9876543210');
      expect(smsUri.scheme, 'sms');
      expect(smsUri.path, '9876543210');
      expect(smsUri.queryParameters['body'], msg);
    });
  });

  group('Emergency Location Sharing & Nearest Police Station Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Renders Emergency Location Sharing with valid position and nearest police station', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testPosition = Position(
        latitude: 11.016844,
        longitude: 76.955832,
        timestamp: DateTime(2026, 11, 6, 14, 0),
        accuracy: 15.0,
        altitude: 400.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      const samplePolice = Facility(
        id: 'police_01',
        categoryId: 'police',
        name: 'B1 Bazaar Police Station',
        lat: 11.018,
        lon: 76.958,
        phone: '0422 230 0100',
      );

      const sampleHospital = Facility(
        id: 'hosp_01',
        categoryId: 'hospital',
        name: 'Government Hospital',
        lat: 11.020,
        lon: 76.960,
        phone: '0422 230 0200',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyAssistanceDialog(
              isDarkMode: true,
              routeOrigin: 'Gandhipuram',
              routeDestination: 'Railway Station',
              currentPosition: testPosition,
              nearbyFacilities: const [samplePolice, sampleHospital],
              formatDurationFn: (mins) => '${mins.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Location Sharing Section
      expect(find.text('Emergency Location Sharing'), findsOneWidget);
      expect(find.textContaining('11.01684, 76.95583'), findsOneWidget);
      expect(find.textContaining('±15m'), findsOneWidget);

      // Check Action Buttons
      expect(find.text('Share via WhatsApp'), findsOneWidget);
      expect(find.text('Share via SMS'), findsOneWidget);
      expect(find.text('Copy Location Link'), findsOneWidget);
      expect(find.text('Copy Emergency Message'), findsOneWidget);

      // Check Nearest Police Station rendered alongside Nearest Hospital
      expect(find.text('Nearby Police Station'), findsOneWidget);
      expect(find.text('B1 Bazaar Police Station'), findsOneWidget);
      expect(find.text('Nearby Hospital'), findsOneWidget);
      expect(find.text('Government Hospital'), findsOneWidget);
    });

    testWidgets('Displays GPS unavailable message when position is null', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyAssistanceDialog(
              isDarkMode: true,
              currentPosition: null,
              formatDurationFn: (mins) => '${mins.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Location Sharing'), findsOneWidget);
      expect(
        find.text('GPS location unavailable. Please enable browser location permissions.'),
        findsOneWidget,
      );
    });
  });
}
