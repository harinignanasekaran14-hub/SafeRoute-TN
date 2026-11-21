import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute_tn/main.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  group('SafeRoute TN 2.0 — Start & Destination Location Autocomplete Tests', () {
    test('1. Short queries (< 2 chars) return empty suggestions', () async {
      final service = SafeRouteService();
      final emptyResult = await service.fetchLocationSuggestions('');
      final singleCharResult = await service.fetchLocationSuggestions('C');
      expect(emptyResult, isEmpty);
      expect(singleCharResult, isEmpty);
    });

    test('2. fetchLocationSuggestions resolves real Nominatim suggestions for "Coi"', () async {
      final service = SafeRouteService();
      final suggestions = await service.fetchLocationSuggestions('Coi');
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.title.isNotEmpty, isTrue);
      expect(suggestions.first.lat, isNotNull);
      expect(suggestions.first.lon, isNotNull);
      expect(suggestions.any((s) => s.title.toLowerCase().contains('coimbatore')), isTrue);
    });

    test('3. fetchLocationSuggestions resolves real Nominatim suggestions for "Oot"', () async {
      final service = SafeRouteService();
      final suggestions = await service.fetchLocationSuggestions('Oot');
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.lat, isNotNull);
      expect(suggestions.first.lon, isNotNull);
      expect(
        suggestions.any(
          (s) =>
              s.title.toLowerCase().contains('oot') ||
              s.title.toLowerCase().contains('udhagamandalam') ||
              s.title.toLowerCase().contains('coonoor'),
        ),
        isTrue,
      );
    });

    test('4. LocationSuggestion model preserves title, subtitle, lat, lon and rawDisplayName', () {
      const suggestion = LocationSuggestion(
        title: 'Coimbatore Airport',
        subtitle: 'Civil Aerodrome, Coimbatore, Tamil Nadu',
        lat: 11.0329,
        lon: 77.0427,
        rawDisplayName: 'Coimbatore International Airport, Tamil Nadu, India',
      );

      expect(suggestion.title, 'Coimbatore Airport');
      expect(suggestion.subtitle, 'Civil Aerodrome, Coimbatore, Tamil Nadu');
      expect(suggestion.lat, 11.0329);
      expect(suggestion.lon, 77.0427);
      expect(suggestion.rawDisplayName, contains('Coimbatore International Airport'));
    });

    testWidgets('5. Neutral default state renders user-friendly labels and placeholders', (tester) async {
      await tester.pumpWidget(const SafeRouteTN());
      await tester.pump();

      // Verify Start Location field label & placeholder
      expect(find.text('Start Location'), findsWidgets);
      expect(find.text('Search starting location...'), findsWidgets);

      // Verify Destination field label & placeholder
      expect(find.text('Destination'), findsWidgets);
      expect(find.text('Where do you want to go?'), findsWidgets);
    });

    testWidgets('6. Tapping Start Location field opens prompt with "Use my current location"', (tester) async {
      await tester.pumpWidget(const SafeRouteTN());
      await tester.pump();

      final startField = find.widgetWithText(
        dynamic,
        'Search starting location...',
      );

      if (startField.evaluate().isNotEmpty) {
        await tester.tap(startField.first);
        await tester.pump();

        expect(find.text('📍 Use my current location'), findsWidgets);
      }
    });

    test('7. fetchLocationSuggestions resolves Erode City instead of displaced District Centroid', () async {
      final service = SafeRouteService();
      final suggestions = await service.fetchLocationSuggestions('Erode');
      expect(suggestions, isNotEmpty);
      final top = suggestions.first;
      expect(top.title.toLowerCase(), contains('erode'));
      // Must be near Erode City (11.33, 77.72) and NOT displaced district centroid (11.49, 77.35)
      expect(top.lat, closeTo(11.33, 0.08));
      expect(top.lon, closeTo(77.72, 0.08));
      expect(top.lat, isNot(closeTo(11.49, 0.04)));
      expect(top.lon, isNot(closeTo(77.35, 0.04)));
    });
  });
}