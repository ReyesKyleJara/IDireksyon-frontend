import 'applicant_flow_test.dart' show evaluation;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/ids/government_id_content_tabs.dart';
import 'package:idireksyon_frontend/features/ids/guide_content.dart';
import 'package:idireksyon_frontend/features/ids/detail_widgets.dart';

GovernmentIdDetails example() => GovernmentIdDetails.fromJson({
  'id': 35,
  'name': 'A long Government ID name that remains readable on mobile',
  'issued_by': 'Issuing agency from CMS',
  'description': 'Full description from CMS. ' * 8,
  'purpose': 'CMS purpose',
  'fees': [
    {
      'id': 1,
      'label': 'Standard application',
      'type': 'fixed',
      'amount_min': '950.00',
      'currency': 'PHP',
      'notes': 'Only for a standard application.',
    },
    {
      'id': 2,
      'label': 'Alternative service',
      'type': 'range',
      'amount_min': '100.00',
      'amount_max': '200.00',
      'currency': 'PHP',
      'is_optional': true,
    },
  ],
  'offices': [
    {
      'id': 7,
      'name': 'Linked CMS branch',
      'municipality': 'Malolos',
      'province': 'Bulacan',
      'services': {'service_notes': 'Confirm availability.'},
      'schedules': [],
    },
  ],
  'requirement_sets': [
    {'id': 11, 'display_label': 'Adult • New', 'groups': []},
    {'id': 12, 'display_label': 'Minor • New', 'groups': []},
  ],
  'application_guide': [
    {
      'id': 11,
      'display_label': 'Adult • New',
      'steps': [
        {
          'id': 28,
          'title': 'CMS step one',
          'short_description': 'CMS instructions',
          'blocks': [
            {
              'id': 57,
              'type': 'warning',
              'content': {'body': 'Important CMS warning'},
            },
            {
              'id': 58,
              'type': 'official_link',
              'content': {
                'label': 'Official appointment',
                'url': 'https://example.gov.ph/',
              },
            },
            {
              'id': 59,
              'type': 'requirements',
              'content': {
                'intro': {'type': 'doc', 'content': []},
              },
            },
          ],
        },
      ],
    },
    {'id': 12, 'display_label': 'Minor • New', 'steps': []},
  ],
});
void main() {
  testWidgets('evaluated empty guides preserve legacy general instructions', (
    tester,
  ) async {
    final legacy = GovernmentIdDetails.fromJson({
      'id': 34,
      'name': 'ID',
      'application_process': 'Earlier general instructions',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GovernmentGuideTab(record: legacy, evaluatedSteps: const []),
        ),
      ),
    );
    expect(find.text('Earlier general instructions'), findsOneWidget);
  });
  testWidgets(
    'shared linked requirements explain pending content instead of claiming none exists',
    (tester) async {
      final data = GovernmentIdDetails.fromJson({'id': 34, 'name': 'ID'});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GovernmentGuideTab(
              record: data,
              evaluatedSteps: [
                ApplicationStep.fromJson({
                  'id': 1,
                  'title': 'Shared preparation',
                  'blocks': [
                    {'id': 2, 'type': 'requirements', 'content': {}},
                  ],
                }),
              ],
              pendingRequirements: [
                RequirementSet.fromJson({
                  'id': 7,
                  'display_label': 'Other situation',
                  'groups': [],
                }),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Shared preparation'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Additional requirements may apply'),
        findsOneWidget,
      );
      expect(
        find.text('No requirements are configured for this application.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'cost uses actual amounts, never sums alternatives, and expands notes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GovernmentCostTab(record: example())),
        ),
      );
      expect(find.text('₱950.00'), findsOneWidget);
      expect(find.text('₱100.00–₱200.00'), findsOneWidget);
      expect(find.text('₱2350.00'), findsNothing);
      expect(find.text('Optional fee'), findsOneWidget);
      await tester.tap(find.text('Fee details & conditions'));
      await tester.pumpAndSettle();
      expect(find.text('Only for a standard application.'), findsOneWidget);
    },
  );
  testWidgets(
    'offices come from associated records and do not fabricate schedules or distances',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GovernmentOfficesTab(record: example())),
        ),
      );
      expect(find.text('Linked CMS branch'), findsOneWidget);
      expect(find.text('Malolos, Bulacan'), findsOneWidget);
      expect(find.text('Operating hours are not confirmed.'), findsOneWidget);
      expect(find.text('View map & directions'), findsNothing);
      expect(find.textContaining('km away'), findsNothing);
    },
  );
  testWidgets(
    'guide preserves CMS order, warning, official links and scenario-linked requirements',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GovernmentGuideTab(
              record: example(),
              scenarioId: 11,
              onScenarioChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('CMS step one'), findsOneWidget);
      await tester.tap(find.text('CMS step one'));
      await tester.pumpAndSettle();
      expect(find.text('Important CMS warning'), findsOneWidget);
      expect(find.text('Official appointment'), findsOneWidget);
      expect(
        find.text('No requirements are configured for this application.'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GovernmentGuideTab(
              record: example(),
              scenarioId: 12,
              onScenarioChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Application guide steps for this application are not available yet.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('empty sections never use prototype data or assume free', (
    tester,
  ) async {
    final empty = GovernmentIdDetails.fromJson({'id': 1, 'name': 'ID'});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GovernmentCostTab(record: empty)),
      ),
    );
    expect(find.textContaining('does not mean'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GovernmentOfficesTab(record: empty)),
      ),
    );
    expect(find.textContaining('No offices'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GovernmentGuideTab(
            record: empty,
            scenarioId: null,
            onScenarioChanged: (_) {},
          ),
        ),
      ),
    );
    expect(
      find.text('Application guide steps are not available yet.'),
      findsOneWidget,
    );
  });
  testWidgets('details and all tabs fit 320px at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: IdDetailsScreen(
          idName: 'ID',
          governmentId: 35,
          evaluateApplicant: (id, _) async => evaluation(id: id),
          loadDetail: (_) async => example(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).backgroundColor,
      detailsHeaderBlue,
    );
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    for (final tab in ['Estimated Cost', 'Offices', 'Guide']) {
      await tester.ensureVisible(find.text(tab));
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'rich CMS formatting renders safe literal text and never executes markup',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GuideRichContent({
              'type': 'doc',
              'content': [
                {
                  'type': 'paragraph',
                  'content': [
                    {
                      'type': 'text',
                      'text': '<script>literal</script>',
                      'marks': [
                        {'type': 'bold'},
                      ],
                    },
                  ],
                },
              ],
            }),
          ),
        ),
      );
      expect(find.text('<script>literal</script>'), findsOneWidget);
      expect(safeOfficialLink('javascript:alert(1)'), isFalse);
    },
  );
  test('parses decimal coordinates, currency, optional fees and all IDs', () {
    final data = example();
    expect(data.guides.first.id, 11);
    expect(data.guides.first.steps.first.id, 28);
    expect(data.guides.first.steps.first.blocks.first.id, 57);
    expect(
      GovernmentFee.fromJson({
        'type': 'fixed',
        'currency': 'USD',
        'amount_min': '5.50',
      }).amount,
      'USD 5.50',
    );
    expect(
      GovernmentOffice.fromJson({'id': 1, 'latitude': '0', 'longitude': '0'})
          .hasCoordinates,
      isTrue,
    );
    expect(
      GovernmentOffice.fromJson({'id': 1, 'latitude': '91', 'longitude': '0'})
          .hasCoordinates,
      isFalse,
    );
  });
  testWidgets(
    'long CMS timeline titles and previews fit narrow widths without intrinsic-height clipping',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final record = GovernmentIdDetails.fromJson({
        'id': 35,
        'name': 'Live-style ID',
        'application_guide': [
          {
            'id': 11,
            'display_label': 'Actual applicant scenario',
            'steps': [
              {
                'id': 28,
                'title': 'Prepare your supporting documents and complete the correct application process',
                'blocks': [
                  {
                    'id': 57,
                    'type': 'text',
                    'content': {
                      'body':
                          'Complete instructions with long document names and conditions. ' *
                          30,
                    },
                  },
                ],
              },
              {
                'id': 29,
                'title': 'Visit an operational registration center',
                'short_description':
                    'Ask about appointments and schedules before travelling. ' *
                    10,
                'blocks': [],
              },
            ],
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: GovernmentGuideTab(
              record: record,
              scenarioId: 11,
              onScenarioChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.text(
          'Prepare your supporting documents and complete the correct application process',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
