import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute_tn/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SafeRoute TN 2.0 — Facility Auto-Selection & State Tests', () {
    testWidgets('1. Initial facility selection is strictly empty, no hospital auto-selection', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SafeRouteTN());
      await tester.pump();

      // Route facilities section shows empty state
      expect(
        find.textContaining('Select a facility category'),
        findsOneWidget,
      );
      expect(
        find.textContaining('to view places along your route'),
        findsOneWidget,
      );

      // Verify "0 found" is NOT shown for hospitals when nothing is selected
      expect(find.text('Hospitals 0 found'), findsNothing);
      expect(find.text('0 found'), findsNothing);
    });

    testWidgets('2. Clean empty state renders pin icon and guidance message', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SafeRouteTN());
      await tester.pump();

      expect(find.byIcon(Icons.location_on_outlined), findsWidgets);
      expect(
        find.text('Select a facility category\nto view places along your route.'),
        findsOneWidget,
      );
    });

    testWidgets('3. Tapping a facility category pill toggles selection', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SafeRouteTN());
      await tester.pump();

      // Find the Hospitals pill in the Route Facilities section
      final hospitalPills = find.text('Hospitals');
      expect(hospitalPills, findsWidgets);

      // Ensure the Hospitals pill in Route Facilities is scrolled into view before interaction
      final hospitalChip = hospitalPills.last;
      await tester.ensureVisible(hospitalChip);
      await tester.pump();

      // Tap Hospitals
      await tester.tap(hospitalChip);
      await tester.pump();

      // Empty state prompt should no longer be present
      expect(
        find.text('Select a facility category\nto view places along your route.'),
        findsNothing,
      );

      // Tap Hospitals again to deselect
      await tester.ensureVisible(hospitalChip);
      await tester.pump();
      await tester.tap(hospitalChip);
      await tester.pump();

      // Clean empty state prompt should be restored
      expect(
        find.text('Select a facility category\nto view places along your route.'),
        findsOneWidget,
      );
    });
  });
}