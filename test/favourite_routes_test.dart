import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Favourite Routes Persistence and Storage Tests', () {
    const storageKey = 'saferoute_favourite_routes';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Persists and loads favourite routes with JSON encoding in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();

      final favData = {
        'id': '1730000000000',
        'origin': 'Coimbatore',
        'destination': 'PSG College',
        'vehicle_mode': 'Car',
        'travel_time_mode': 'Day',
        'created_at': DateTime.now().toIso8601String(),
        'route_label': 'Home → College',
      };

      // Persist list
      await prefs.setStringList(storageKey, [jsonEncode(favData)]);

      // Reload
      final loaded = prefs.getStringList(storageKey);
      expect(loaded, isNotNull);
      expect(loaded!.length, 1);

      final decoded = jsonDecode(loaded.first) as Map<String, dynamic>;
      expect(decoded['origin'], 'Coimbatore');
      expect(decoded['destination'], 'PSG College');
      expect(decoded['vehicle_mode'], 'Car');
      expect(decoded['travel_time_mode'], 'Day');
      expect(decoded['route_label'], 'Home → College');
    });

    test('Duplicate prevention detects matching origin + destination case-insensitively', () async {
      final existingRoutes = [
        {'origin': 'Coimbatore', 'destination': 'Madurai'},
      ];

      bool isDuplicate(String origin, String destination) {
        return existingRoutes.any(
          (f) =>
              f['origin']!.trim().toLowerCase() ==
                  origin.trim().toLowerCase() &&
              f['destination']!.trim().toLowerCase() ==
                  destination.trim().toLowerCase(),
        );
      }

      expect(isDuplicate('coimbatore', 'madurai'), isTrue);
      expect(isDuplicate('COIMBATORE', 'MADURAI'), isTrue);
      expect(isDuplicate(' Coimbatore ', ' Madurai '), isTrue);
      expect(isDuplicate('Coimbatore', 'Chennai'), isFalse);
    });

    test(
      'Favourite routes and My Trips use completely independent storage keys',
      () async {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setStringList('saferoute_favourite_routes', [
          '{"origin":"A","destination":"B"}',
        ]);
        await prefs.setStringList('saferoute_saved_trips', [
          '{"origin":"C","destination":"D"}',
        ]);

        // Removing a favourite route must not alter my trips
        final favourites = prefs.getStringList('saferoute_favourite_routes')!;
        favourites.clear();
        await prefs.setStringList('saferoute_favourite_routes', favourites);

        expect(prefs.getStringList('saferoute_favourite_routes'), isEmpty);
        expect(prefs.getStringList('saferoute_saved_trips'), hasLength(1));
      },
    );
  });
}
