import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/features/roadmap/build_roadmap_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/confirm_documents_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';

GovernmentIdDetails catalog(int id, String name, {bool? include}) => GovernmentIdDetails.fromJson({
  'id': id, 'name': name, 'include_in_smart_sequencing': ?include,
  'application_availability': 'discontinued', 'acquisition_type': 'profession_based',
  'guidance_mode': 'informational_only', 'target_group': 'Special group',
  'prerequisites': [{'type': 'custom', 'name': 'Uncompleted activity'}],
});

void main() {
  testWidgets('only inclusion filters candidates and real IDs reach the suggested journey', (tester) async {
    final records = [catalog(55, 'Allowed', include: true), catalog(70, 'Excluded', include: false), catalog(56, 'Legacy')];
    await tester.pumpWidget(MaterialApp(home: BuildRoadmapScreen(loadIds: () async => records)));
    await tester.pumpAndSettle();
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('Legacy'), findsOneWidget);
    expect(find.text('Excluded'), findsNothing);
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next')).onPressed, isNull);
    await tester.tap(find.text('Allowed')); await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final confirmation = tester.widget<ConfirmDocumentsScreen>(find.byType(ConfirmDocumentsScreen));
    expect(confirmation.targetIds, ['Allowed']); expect(confirmation.targetCatalogIds, [55]);
    await tester.ensureVisible(find.text('Save & Continue'));
    await tester.tap(find.text('Save & Continue')); await tester.pumpAndSettle();
    final suggested = tester.widget<SuggestedRoadmapScreen>(find.byType(SuggestedRoadmapScreen));
    expect(suggested.targetCatalogIds, [55]);
    expect(find.text('Birth Certificate'), findsNothing);
    expect(find.text('PhilSys National ID Registration'), findsNothing);
    await tester.ensureVisible(find.text('Preview Guide'));
    await tester.tap(find.text('Preview Guide')); await tester.pumpAndSettle();
    expect(tester.widget<IdDetailsScreen>(find.byType(IdDetailsScreen)).governmentId, 55);
  });

  testWidgets('normal directory still displays excluded record', (tester) async {
    final excluded = catalog(70, 'Excluded reference', include: false);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: IdsScreen(loadIds: () async => [excluded]))));
    await tester.pumpAndSettle();
    expect(find.text('Excluded reference'), findsWidgets);
  });

  testWidgets('all excluded gives empty state and reloading after re-inclusion restores candidacy', (tester) async {
    await tester.pumpWidget(MaterialApp(home: BuildRoadmapScreen(key: const ValueKey(false), loadIds: () async => [catalog(70, 'Restored record', include: false)])));
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsNothing);
    expect(find.textContaining('No acquisition targets'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: BuildRoadmapScreen(key: const ValueKey(true), loadIds: () async => [catalog(70, 'Restored record', include: true)])));
    await tester.pumpAndSettle(); expect(find.text('Restored record'), findsOneWidget);
  });

  testWidgets('catalog errors show retry without falling back to hardcoded targets', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: BuildRoadmapScreen(loadIds: () async {
      if (++calls == 1) throw Exception('Offline');
      return [catalog(1, 'Retry success')];
    })));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load roadmap candidates.'), findsOneWidget);
    expect(find.text('Passport ID'), findsNothing);
    await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(find.text('Retry success'), findsOneWidget); expect(calls, 2);
  });
}
