import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/roadmap/build_roadmap_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

GovernmentIdDetails record(int id, String name, [String type = 'government_id']) =>
    GovernmentIdDetails.fromJson({
      'id': id,
      'name': name,
      'record_type': type,
      'guidance_mode': 'guided',
    });

void main() {
  final records = [
    for (var i = 1; i <= 30; i++) record(i, 'Government ID $i'),
    record(1, 'Birth Certificate', 'document'),
  ];

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    List<GovernmentIdDetails>? catalog,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: BuildRoadmapScreen(loadIds: () async => catalog ?? records),
      ),
    );
    await tester.pumpAndSettle();
  }

  VoidCallback? continueAction(WidgetTester tester) => tester
      .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue'))
      .onPressed;

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets('Continue stays on screen while scrolling: $size x$scale', (
      tester,
    ) async {
      await open(tester, size: size, textScale: scale);
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('Continue').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('search stays pinned above the list on a regular phone', (
    tester,
  ) async {
    await open(tester);
    final top = tester.getTopLeft(find.byType(TextField)).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TextField)).dy, top);
  });

  testWidgets('footer names the selection even when search hides its row', (
    tester,
  ) async {
    await open(tester);
    expect(
      find.text('Select one or more IDs or documents to continue'),
      findsOneWidget,
    );
    expect(continueAction(tester), isNull);

    await tester.tap(find.text('Government ID 1'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: Government ID 1'), findsOneWidget);
    expect(continueAction(tester), isNotNull);

    await tester.enterText(find.byType(TextField), 'birth');
    await tester.pumpAndSettle();
    expect(find.text('Government ID 1'), findsNothing);
    expect(find.text('Selected: Government ID 1'), findsOneWidget);
    expect(continueAction(tester), isNotNull);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Government ID 1'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('several selections are listed and Clear removes them all', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Government ID 1'));
    await tester.tap(find.text('Government ID 2'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 selected: Government ID 1, Government ID 2'),
      findsOneWidget,
    );
    await tester.tap(find.text('Government ID 1'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: Government ID 2'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(continueAction(tester), isNull);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('filters separate IDs from documents', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Documents'));
    await tester.pumpAndSettle();
    expect(find.text('Birth Certificate'), findsOneWidget);
    expect(find.text('Government ID 1'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'IDs'));
    await tester.pumpAndSettle();
    expect(find.text('Government ID 1'), findsOneWidget);
    expect(find.text('Birth Certificate'), findsNothing);
  });

  testWidgets('filters are hidden when there is only one kind of record', (
    tester,
  ) async {
    await open(tester, catalog: [record(1, 'Government ID 1')]);
    expect(find.byType(ChoiceChip), findsNothing);
  });
}
