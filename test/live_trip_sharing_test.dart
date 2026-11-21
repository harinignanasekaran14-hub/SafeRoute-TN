import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saferoute_tn/live_trip_sharing.dart';

void main() {
  group('SafeRoute TN 2.0 – Live Trip Sharing & Safe Arrival Unit Tests', () {
    test('1. LiveSharedTripSession model parses valid JSON and sets 12h expiration', () {
      final json = {
        'share_token': 'share_abc123',
        'update_token': 'update_xyz789',
        'destination': 'Marina Beach, Chennai',
        'origin': 'Chennai Central',
        'vehicle': 'Car',
        'eta_minutes': 22,
        'created_at': '2026-11-07T12:00:00Z',
        'expires_at': '2026-11-08T00:00:00Z',
        'status': 'active',
      };

      final session = LiveSharedTripSession.fromJson(json);
      expect(session.shareToken, equals('share_abc123'));
      expect(session.updateToken, equals('update_xyz789'));
      expect(session.destination, equals('Marina Beach, Chennai'));
      expect(session.origin, equals('Chennai Central'));
      expect(session.vehicle, equals('Car'));
      expect(session.etaMinutes, equals(22));
      expect(session.status, equals('active'));
    });

    test('2. LiveSharedTripStatus parses statuses and detects coordinate validity and staleness', () {
      final activeJson = {
        'status': 'active',
        'destination': 'Airport Terminal 2',
        'origin': 'Guindy',
        'vehicle': 'Car',
        'eta_minutes': 15,
        'latitude': 12.9850,
        'longitude': 80.1650,
        'heading': 180.0,
        'speed': 14.5,
        'accuracy': 8.0,
        'updated_at': '2026-11-07T12:05:00Z',
        'is_stale': false,
        'stale_seconds': 20,
      };

      final activeStatus = LiveSharedTripStatus.fromJson(activeJson);
      expect(activeStatus.status, equals('active'));
      expect(activeStatus.hasValidCoordinates, isTrue);
      expect(activeStatus.latitude, equals(12.9850));
      expect(activeStatus.longitude, equals(80.1650));
      expect(activeStatus.isStale, isFalse);

      // Stale status
      final staleJson = Map<String, dynamic>.from(activeJson);
      staleJson['is_stale'] = true;
      staleJson['stale_seconds'] = 190;
      final staleStatus = LiveSharedTripStatus.fromJson(staleJson);
      expect(staleStatus.isStale, isTrue);
      expect(staleStatus.staleSeconds, equals(190));

      // Stopped status (no coordinates exposed)
      final stoppedJson = {
        'status': 'stopped',
        'destination': 'Airport Terminal 2',
        'message': 'Trip sharing was stopped by the user.',
      };
      final stoppedStatus = LiveSharedTripStatus.fromJson(stoppedJson);
      expect(stoppedStatus.status, equals('stopped'));
      expect(stoppedStatus.hasValidCoordinates, isFalse);
      expect(stoppedStatus.latitude, isNull);
      expect(stoppedStatus.longitude, isNull);
    });

    test('3. LiveTripSharingService builds correct share URLs and messages (Bilingual)', () {
      final url = LiveTripSharingService.buildShareUrl('token_demo_456');
      expect(url.contains('share_token=token_demo_456'), isTrue);

      // English Share message
      final msgEn = LiveTripSharingService.buildShareMessage(
        destination: 'Marina Beach',
        shareUrl: url,
        etaMinutes: 20,
        vehicle: 'Car',
        isTamil: false,
      );
      expect(msgEn.contains('Marina Beach'), isTrue);
      expect(msgEn.contains('ETA: ~20 min'), isTrue);
      expect(msgEn.contains(url), isTrue);
      expect(msgEn.contains('Automatically expires in 12h'), isTrue);

      // Tamil Share message
      final msgTa = LiveTripSharingService.buildShareMessage(
        destination: 'மெரினா கடற்கரை',
        shareUrl: url,
        etaMinutes: 20,
        vehicle: 'Car',
        isTamil: true,
      );
      expect(msgTa.contains('நேரலை பயணப் பகிர்வு'), isTrue);
      expect(msgTa.contains('மெரினா கடற்கரை'), isTrue);
      expect(msgTa.contains('12 மணி நேரத்தில் தானாக காலாவதியாகும்'), isTrue);

      // Safe Arrival messages
      final arrEn = LiveTripSharingService.buildSafeArrivalMessage(
        destination: 'Marina Beach',
        isTamil: false,
      );
      expect(arrEn.contains('Safe Arrival'), isTrue);
      expect(arrEn.contains('I have arrived safely at Marina Beach'), isTrue);

      final arrTa = LiveTripSharingService.buildSafeArrivalMessage(
        destination: 'மெரினா கடற்கரை',
        isTamil: true,
      );
      expect(arrTa.contains('பாதுகாப்பான வருகை'), isTrue);
      expect(arrTa.contains('பத்திரமாக அடைந்துவிட்டேன்'), isTrue);
    });

    test('4. LiveTripSharingService API operations with MockClient', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/trip/create_share') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['destination'] == 'Invalid') {
            return http.Response(jsonEncode({'success': false, 'error': 'error'}), 400);
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'share_token': 'sh_123',
              'update_token': 'up_456',
              'destination': body['destination'],
              'status': 'active',
              'created_at': DateTime.now().toIso8601String(),
              'expires_at': DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
            }),
            200,
          );
        }

        if (request.url.path == '/api/trip/update_location') {
          return http.Response(jsonEncode({'success': true, 'status': 'active'}), 200);
        }

        if (request.url.path == '/api/trip/status/sh_123') {
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'active',
              'destination': 'Marina Beach',
              'latitude': 13.08,
              'longitude': 80.27,
              'is_stale': false,
            }),
            200,
          );
        }

        if (request.url.path == '/api/trip/stop_sharing') {
          return http.Response(jsonEncode({'success': true, 'status': 'stopped'}), 200);
        }

        if (request.url.path == '/api/trip/complete_trip') {
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'completed',
              'destination': 'Marina Beach',
              'message': 'Arrived safely at Marina Beach.',
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      // 1. Create Share
      final session = await LiveTripSharingService.createShareSession(
        destination: 'Marina Beach',
        client: mockClient,
      );
      expect(session, isNotNull);
      expect(session!.shareToken, equals('sh_123'));
      expect(session.updateToken, equals('up_456'));

      // 2. Update Location
      final updated = await LiveTripSharingService.updateLocation(
        updateToken: session.updateToken,
        latitude: 13.0827,
        longitude: 80.2707,
        client: mockClient,
      );
      expect(updated, isTrue);

      // 3. Fetch Status
      final status = await LiveTripSharingService.fetchTripStatus('sh_123', client: mockClient);
      expect(status, isNotNull);
      expect(status!.status, equals('active'));
      expect(status.latitude, equals(13.08));

      // 4. Stop Sharing
      final stopped = await LiveTripSharingService.stopSharing(session.updateToken, client: mockClient);
      expect(stopped, isTrue);

      // 5. Complete Trip
      final completed = await LiveTripSharingService.completeTrip(session.updateToken, client: mockClient);
      expect(completed, isTrue);
    });

    testWidgets('5. LiveTripSharingConsentDialog renders destination and disclosure items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveTripSharingConsentDialog(
              destination: 'Marina Beach',
              vehicle: 'Car',
              etaMinutes: 25,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Share Live Trip'), findsOneWidget);
      expect(find.text('Marina Beach'), findsOneWidget);
      expect(find.text('~25 min'), findsOneWidget);
      expect(find.text('Secure Token-Based Link'), findsOneWidget);
      expect(find.text('Auto-Expires in 12 Hours'), findsOneWidget);
      expect(find.text('Requires Active Browser Tab'), findsOneWidget);
      expect(find.text('Enable Live Sharing'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('6. LiveTripSharingActiveDialog renders active sharing controls and stop button', (tester) async {
      final session = LiveSharedTripSession(
        shareToken: 'test_token',
        updateToken: 'update_tok',
        destination: 'Marina Beach',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      );

      var stoppedCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveTripSharingActiveDialog(
              session: session,
              onStopSharing: () => stoppedCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Live Sharing Active'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Stop Sharing Trip Now'), findsOneWidget);
      await tester.tap(find.text('Stop Sharing Trip Now'));
      await tester.pump();
      expect(stoppedCalled, isTrue);
    });

    testWidgets('7. SafeArrivalDialog renders safe arrival confirmation and notification options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeArrivalDialog(
              destination: 'Marina Beach',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Safe Arrival Confirmed!'), findsOneWidget);
      expect(find.text('Notify contacts of your safe arrival:'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Copy Arrival Message'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
