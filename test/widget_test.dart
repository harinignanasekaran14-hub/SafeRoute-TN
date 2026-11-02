import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute_tn/main.dart';

void main() {
  testWidgets('SafeRouteTN smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const SafeRouteTN());
    await tester.pump();

    expect(find.text('SafeRoute TN'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Desktop layout at 1366x768 does not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const SafeRouteTN());
    await tester.pump();

    expect(find.text('SafeRoute TN'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Desktop layout at 1536x864 does not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1536, 864);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const SafeRouteTN());
    await tester.pump();

    expect(find.text('SafeRoute TN'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tablet layout at 800x600 does not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const SafeRouteTN());
    await tester.pump();

    expect(find.text('SafeRoute TN'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile layout at 360x800 does not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const SafeRouteTN());
    await tester.pump();

    expect(find.text('SafeRoute TN'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile layout at 390x844 does not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const SafeRouteTN());
    await tester.pump();

    expect(find.text('SafeRoute TN'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile layout at 400x800 does not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const SafeRouteTN());
    await tester.pump();

    expect(find.text('SafeRoute TN'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile layout at 430x932 does not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const SafeRouteTN());
    await tester.pump();

    expect(find.text('SafeRoute TN'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile section order strictly follows priority hierarchy', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const SafeRouteTN());
    await tester.pump();

    // Verify all key sections exist
    expect(find.text('Plan Your Safe Journey'), findsOneWidget);
    expect(find.text('Route Summary'), findsOneWidget);
    expect(find.text('OPTIONAL FACILITIES'), findsOneWidget);
    expect(find.text('SMART ROUTE INSIGHTS'), findsOneWidget);
    expect(find.text('ROUTE FACILITIES'), findsOneWidget);
    expect(find.text('Personal Safety Profile'), findsOneWidget);

    // Verify vertical order in scrollable view
    final planTop = tester.getTopLeft(find.text('Plan Your Safe Journey')).dy;
    final summaryTop = tester.getTopLeft(find.text('Route Summary')).dy;
    final optFacTop = tester.getTopLeft(find.text('OPTIONAL FACILITIES')).dy;

    // Plan Card appears before Route Summary
    expect(planTop < summaryTop, isTrue);
    // Route Summary appears before Optional Facilities
    expect(summaryTop < optFacTop, isTrue);
    expect(tester.takeException(), isNull);
  });
}
