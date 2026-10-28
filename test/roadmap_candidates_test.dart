import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/features/roadmap/build_roadmap_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/confirm_documents_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';

GovernmentIdDetails catalog(int id, String name, {bool? include, String? availability}) => GovernmentIdDetails.fromJson({
  'id': id, 'name': name, 'include_in_smart_sequencing': ?include,
  'application_availability': ?availability, 'acquisition_type': 'profession_based',
  'guidance_mode': 'informational_only', 'target_group': 'Special group',
  'prerequisites': [{'type': 'custom', 'name': 'Uncompleted activity'}],
});

void main() {
  testWidgets('allowed candidates retain other metadata and real IDs reach the suggested journey', (tester) async {
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

  testWidgets('availability and inclusion jointly filter only acquisition targets', (tester) async {
    final records = [
      catalog(1, 'Available target', include: true, availability: 'available'),
      catalog(2, 'Conditional target', include: true, availability: 'limited_conditional'),
      catalog(3, 'Temporary target', include: true, availability: 'temporarily_unavailable'),
      catalog(4, 'Discontinued target', include: true, availability: 'discontinued'),
      catalog(5, 'Opted out target', include: false, availability: 'available'),
      catalog(6, 'Legacy target'),
    ];
    await tester.pumpWidget(MaterialApp(home: BuildRoadmapScreen(loadIds: () async => records)));
    await tester.pumpAndSettle();
    for (final name in ['Available target', 'Conditional target', 'Legacy target']) {
      expect(find.text(name), findsOneWidget);
    }
    for (final name in ['Temporary target', 'Discontinued target', 'Opted out target']) {
      expect(find.text(name), findsNothing);
    }
  });

  testWidgets('availability changes hide and restore the same target on catalog reload', (tester) async {
    for (final availability in ['available', 'temporarily_unavailable', 'discontinued', 'available']) {
      await tester.pumpWidget(MaterialApp(home: BuildRoadmapScreen(
        key: UniqueKey(), loadIds: () async => [catalog(8, 'Changing target', include: true, availability: availability)],
      )));
      await tester.pumpAndSettle();
      expect(find.text('Changing target'), availability == 'available' ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('unavailable and discontinued records remain in the normal directory', (tester) async {
    final records = [catalog(1, 'Temporary reference', availability: 'temporarily_unavailable'),
      catalog(2, 'Discontinued reference', availability: 'discontinued')];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: IdsScreen(loadIds: () async => records))));
    await tester.pumpAndSettle();
    expect(find.text('Temporary reference'), findsWidgets);
    expect(find.text('Discontinued reference'), findsWidgets);
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
