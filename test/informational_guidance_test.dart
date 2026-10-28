import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/models/roadmap_plan.dart';
import 'package:idireksyon_frontend/services/requirement_readiness.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';
import 'package:idireksyon_frontend/features/ids/requirements_tab.dart';
import 'package:idireksyon_frontend/features/ids/fees_tab.dart';
import 'package:idireksyon_frontend/features/roadmap/roadmap_plan_panel.dart';
import 'fixtures/roadmap_auth.dart';

GovernmentIdDetails referenceRecord(String guidance) => GovernmentIdDetails.fromJson({
  'id': 34, 'name': 'Specialized credential', 'guidance_mode': guidance,
  'include_in_smart_sequencing': true, 'application_availability': 'available',
  'acquisition_type': 'profession_based', 'target_group': 'Licensed professionals',
  'level': 'National', 'category': 'Professional Credential', 'issued_by': 'Issuing institution',
  'description': 'Factual reference description', 'validity': 'Three years',
  'official_link': 'https://example.test/reference',
  'requirements': 'Saved acquisition requirement',
  'fee': 'Saved acquisition fee',
  'requirement_sets': [{'id': 1, 'groups': []}],
});

void main() {
  testWidgets('informational details show facts and notice while hiding every acquisition tab and readiness', (tester) async {
    final record = referenceRecord('informational_only');
    await tester.pumpWidget(MaterialApp(home: IdDetailsScreen(idName: record.name, governmentId: record.id, loadDetail: (_) async => record)));
    await tester.pumpAndSettle();
    expect(find.text('Informational Record'), findsOneWidget);
    expect(find.textContaining('does not currently provide step-by-step acquisition guidance'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(RequirementsTab), findsNothing);
    expect(find.byType(FeesTab), findsNothing);
    for (final label in ['Requirements', 'Estimated Cost', 'Offices', 'Guide', 'Preview Guide', 'Prerequisite Readiness']) {
      expect(find.text(label), findsNothing);
    }
    for (final fact in ['Issuing institution', 'National', 'Professional Credential', 'Factual reference description', 'Available', 'Profession-Based', 'Licensed professionals', 'Three years']) {
      await tester.scrollUntilVisible(find.text(fact), 180, scrollable: find.byType(Scrollable).first);
      expect(find.text(fact), findsOneWidget);
    }
    expect(find.text('Saved acquisition requirement'), findsNothing);
    expect(record.requirements, 'Saved acquisition requirement');
    expect(record.legacyFee, 'Saved acquisition fee');
    expect(record.includeInSmartSequencing, isTrue);
  });

  testWidgets('switching back to guided restores normal retained acquisition presentation', (tester) async {
    for (final (index, mode) in ['guided', 'informational_only', 'guided'].indexed) {
      final record = referenceRecord(mode);
      await tester.pumpWidget(MaterialApp(home: IdDetailsScreen(key: ValueKey(index), idName: record.name, governmentId: record.id, loadDetail: (_) async => record)));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), mode == 'guided' ? findsOneWidget : findsNothing);
      expect(find.text('Informational Record'), mode == 'informational_only' ? findsOneWidget : findsNothing);
      if (mode == 'guided') {
        for (final label in ['Requirements', 'Estimated Cost', 'Offices', 'Guide']) {
          expect(find.text(label), findsOneWidget);
        }
      }
    }
  });

  testWidgets('informational record remains browsable in the normal directory', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: IdsScreen(loadIds: () async => [referenceRecord('informational_only')]))));
    await tester.pumpAndSettle();
    expect(find.text('Specialized credential'), findsWidgets);
  });

  testWidgets('missing informational dependencies are reference messages rather than guide steps', (tester) async {
    final data = planStep(1, 'Guided target', total: 1, prerequisites: [
      {'type': 'government_id', 'id': 34, 'name': 'Specialized credential', 'status': 'missing',
        'resolution': 'reference_only', 'message': 'This prerequisite must be obtained through its issuing institution or professional process.', 'condition': 'If required'},
    ]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: RoadmapPlanView(plan: RoadmapPlan.fromJson(planData([1], [data])))))));
    expect(find.text('Specialized credential'), findsNothing);
    expect(find.textContaining('Specialized credential: Not in Inventory — reference prerequisite.'), findsOneWidget);
    expect(find.textContaining('issuing institution or professional process'), findsOneWidget);
    expect(find.textContaining('Applies when: If required'), findsOneWidget);
    expect(find.textContaining('0 of 1 verified — 0%'), findsOneWidget);
    expect(find.text('Preview Guide'), findsOneWidget); // Only the guided target.
  });

  testWidgets('previously selected informational targets hide guide actions and prerequisite scoring', (tester) async {
    final data = planStep(34, 'Now informational', blocked: true)..['guidance_mode'] = 'informational_only';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: RoadmapPlanView(plan: RoadmapPlan.fromJson(planData([34], [data]))))));
    expect(find.text('Informational Record'), findsOneWidget);
    expect(find.text('Preview Guide'), findsNothing);
    expect(find.text('View information'), findsOneWidget);
    expect(find.textContaining('Prerequisite Readiness'), findsNothing);
  });

  test('owned informational credentials still satisfy exact linked Requirement matching', () {
    final inventory = RequirementReadiness(governmentIds: [34], documents: [7]);
    final ownedId = RequirementItem.fromJson({'type': 'government_id', 'government_id_id': 34, 'name': 'Reference credential', 'guidance_mode': 'informational_only'});
    final otherId = RequirementItem.fromJson({'type': 'government_id', 'government_id_id': 35, 'name': 'Reference credential'});
    final ownedDoc = RequirementItem.fromJson({'type': 'document', 'document_id': 7, 'name': 'Reference document', 'guidance_mode': 'informational_only'});
    expect(inventory.owns(ownedId), isTrue);
    expect(inventory.owns(ownedDoc), isTrue);
    expect(inventory.owns(otherId), isFalse);
  });

  testWidgets('informational facts fit narrow screens and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
      home: IdDetailsScreen(idName: 'Reference', governmentId: 34, loadDetail: (_) async => referenceRecord('informational_only'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -2500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
