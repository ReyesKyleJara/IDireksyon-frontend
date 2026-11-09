import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/roadmap/roadmap_plan_panel.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_journey_view.dart';
import 'package:idireksyon_frontend/models/roadmap_plan.dart';

import 'fixtures/roadmap_auth.dart';

Map<String, dynamic> unresolved({bool path = false, bool empty = false}) => {
  ...planStep(
    12,
    path ? 'Choose application requirements' : 'Valid ID / Supporting ID',
    type: 'unresolved_requirement',
    selected: false,
  ),
  'resolution_key': path
      ? 'government_id:1:path'
      : 'government_id:1:set:3:group:12',
  'kind': path ? 'path' : 'requirement',
  'owner_key': 'government_id:1',
  'manual_preparation': empty && !path,
  'message': path
      ? 'Select the application and applicant path that applies to you.'
      : 'You still need at least one accepted option.',
  'suggestions': empty
      ? []
      : [
          if (path)
            {
              'set_id': 3,
              'name': 'Adult first-time requirements',
              'needs_review': false,
            }
          else
            {
              'type': 'document',
              'id': 4,
              'name': 'Accepted document',
              'way_id': 8,
            },
        ],
};

void main() {
  late AuthService previous;
  late List<Map<String, dynamic>> requests;
  var saved = false;
  var selectedId = 4;
  var selectedName = 'Accepted document';
  var selectedType = 'document';
  Map<String, dynamic> modalOverrides = {};

  setUp(() {
    previous = AuthService.instance;
    requests = [];
    saved = false;
    selectedId = 4;
    selectedName = 'Accepted document';
    selectedType = 'document';
    modalOverrides = {};
  });
  tearDown(() {
    if (!identical(AuthService.instance, previous)) {
      AuthService.instance.dispose();
    }
    AuthService.instance = previous;
  });

  void connect({bool path = false, bool empty = false, bool reject = false}) {
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        // Journey choices must never use the Inventory or preparation endpoints.
        expect(request.url.path, '/api/auth/roadmap-plan');
        expect(request.method, 'POST');
        final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        requests.add(body);
        if (body['resolution'] != null) {
          if (reject) {
            return http.Response(
              '{"message":"This option is no longer available."}',
              422,
            );
          }
          saved = true;
          final resolution = body['resolution'] as Map;
          if (resolution['id'] is int) {
            selectedId = resolution['id'] as int;
            selectedType = resolution['type'] as String;
            final options = modalOverrides['suggestions'] as List? ?? const [];
            final selected = options
                .cast<Map>()
                .where(
                  (option) =>
                      option['id'] == selectedId &&
                      option['type'] == selectedType,
                )
                .firstOrNull;
            selectedName = selected?['name'] as String? ?? 'Accepted document';
          }
        }
        return http.Response(
          jsonEncode({
            'data': planData(
              [1],
              [
                if (!saved)
                  {...unresolved(path: path, empty: empty), ...modalOverrides},
                if (saved)
                  planStep(
                    selectedId,
                    selectedName,
                    type: selectedType,
                    selected: false,
                  ),
                planStep(1, 'Target'),
              ],
            ),
          }),
          200,
        );
      }),
    )..token = 'resident';
  }

  Future<void> show(WidgetTester tester, {bool guided = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoadmapPlanPanel(
              targetIds: const [1],
              guidedPresentation: guided,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final guided in [true, false]) {
    testWidgets(
      'confirmation adds an actual step and reload restores its path guided=$guided',
      (tester) async {
        connect();
        await show(tester, guided: guided);
        expect(
          find.text('You still need at least one accepted option.'),
          findsOneWidget,
        );
        if (guided) {
          expect(find.text('2 steps to complete'), findsOneWidget);
          expect(
            tester
                .widget<JourneyResolutionCard>(
                  find.byType(JourneyResolutionCard),
                )
                .number,
            1,
          );
          expect(
            tester
                .widget<SuggestedJourneyStep>(find.byType(SuggestedJourneyStep))
                .number,
            2,
          );
        }
        await tester.tap(find.text('See Suggested Options'));
        await tester.pumpAndSettle();
        expect(find.text('Accepted document'), findsOneWidget);
        await tester.ensureVisible(find.text('Add to Journey'));
        await tester.tap(find.text('Add to Journey'));
        await tester.pumpAndSettle();
        expect(find.text('Add Accepted document to Journey?'), findsOneWidget);
        expect(
          find.text(
            'IDireksyon will add this before your target and recalculate your roadmap.',
          ),
          findsOneWidget,
        );
        expect(requests, hasLength(1));
        await tester.ensureVisible(find.text('Add to Journey'));
        await tester.tap(find.text('Add to Journey'));
        await tester.pumpAndSettle();
        expect(requests.last['resolution'], {
          'key': 'government_id:1:set:3:group:12',
          'type': 'document',
          'id': 4,
          'way_id': 8,
        });
        expect(find.text('Valid ID / Supporting ID'), findsNothing);
        expect(find.text('Accepted document'), findsOneWidget);
        // Destroy local widget state; restored choices come from the account response.
        if (guided) {
          expect(find.text('2 steps to complete'), findsOneWidget);
          expect(
            tester
                .widgetList<SuggestedJourneyStep>(
                  find.byType(SuggestedJourneyStep),
                )
                .map((step) => step.number),
            [1, 2],
          );
        }
        await tester.pumpWidget(const SizedBox());
        await show(tester, guided: guided);
        expect(requests.last.containsKey('resolution'), isFalse);
        expect(find.text('Accepted document'), findsOneWidget);
        expect(find.text('See Suggested Options'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cancel does not save or replace the unresolved step', (
    tester,
  ) async {
    connect();
    await show(tester);
    await tester.tap(find.text('See Suggested Options'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add to Journey'));
    await tester.tap(find.text('Add to Journey'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(saved, isFalse);
    expect(find.text('Valid ID / Supporting ID'), findsOneWidget);
  });

  testWidgets(
    'path selection confirms and sends only the selected requirement set',
    (tester) async {
      connect(path: true);
      await show(tester);
      await tester.tap(find.text('Choose Application Requirements'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use This Checklist'));
      await tester.tap(find.text('Use This Checklist'));
      await tester.pumpAndSettle();
      expect(find.text('Use Adult first-time requirements?'), findsOneWidget);
      await tester.ensureVisible(find.text('Use This Checklist'));
      await tester.tap(find.text('Use This Checklist'));
      await tester.pumpAndSettle();
      expect(requests.last['resolution'], {
        'key': 'government_id:1:path',
        'set_id': 3,
      });
      expect(find.text('Choose application requirements'), findsNothing);
    },
  );

  testWidgets(
    'empty suggestions explain manual preparation without inventing an option',
    (tester) async {
      connect(empty: true);
      await show(tester);
      expect(
        find.textContaining('yourself'),
        findsOneWidget,
      );
      expect(find.text('See Suggested Options'), findsNothing);
      expect(find.text('Add to Journey'), findsNothing);
      expect(requests, hasLength(1));
    },
  );

  testWidgets(
    'a rejected stale selection shows an error and retry reloads current options',
    (tester) async {
      connect(reject: true);
      await show(tester);
      await tester.tap(find.text('See Suggested Options'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add to Journey'));
      await tester.tap(find.text('Add to Journey'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add to Journey'));
      await tester.tap(find.text('Add to Journey'));
      await tester.pumpAndSettle();
      expect(saved, isFalse);
      expect(find.text('This option is no longer available.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('See Suggested Options'), findsOneWidget);
      expect(requests.last.containsKey('resolution'), isFalse);
    },
  );

  test('unresolved steps require a stable resolution identity and never impersonate a catalog record', () {
    final row = unresolved();
    final plan = RoadmapPlan.fromJson(
      planData([1], [row, planStep(1, 'Target')]),
    );
    expect(plan.steps.first.isUnresolved, isTrue);
    row.remove('resolution_key');
    expect(
      () => RoadmapPlan.fromJson(planData([1], [row, planStep(1, 'Target')])),
      throwsFormatException,
    );
  });

  testWidgets(
    'a request-path placeholder cannot impersonate a same-ID document goal',
    (tester) async {
      final row = unresolved(path: true);
      final plan = RoadmapPlan.fromJson({
        ...planData([], [
          row,
          planStep(12, 'Document target', type: 'document'),
        ]),
        'target_document_ids': [12],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SuggestedJourneyView(plan: plan)),
        ),
      );
      final card = tester.widget<RoadmapGoalCard>(find.byType(RoadmapGoalCard));
      expect(card.title, 'Document target');
      expect(card.stepCount, 1);
    },
  );

  testWidgets(
    'options explain the requirement and target and label ownership',
    (tester) async {
      modalOverrides = {
        'suggestions': [
          {
            'type': 'document',
            'id': 4,
            'name': 'Shared proof',
            'way_id': 8,
            'in_journey': true,
            'processing_time': '3 working days',
          },
          {
            'type': 'government_id',
            'id': 5,
            'name': 'Owned proof',
            'way_id': 8,
            'already_owned': true,
            'processing_time': '2 weeks',
          },
          {
            'type': 'document',
            'id': 6,
            'name': 'New proof',
            'way_id': 8,
            'processing_time': 'Varies',
          },
        ],
      };
      connect();
      await show(tester);
      await tester.tap(find.text('See Suggested Options'));
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Choose one accepted option'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('REQUIREMENT')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Valid ID / Supporting ID'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('For Target')),
        findsOneWidget,
      );
      expect(find.text('Already in your Roadmap'), findsOneWidget);
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('roadmap-options-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Already in Inventory'),
        150,
        scrollable: scroll,
      );
      expect(find.text('Already in Inventory'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('New proof'),
        150,
        scrollable: scroll,
      );
      expect(find.text('Varies'), findsNothing);
      expect(find.text('2 weeks'), findsNothing);
      expect(find.text('Not in Inventory'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
    },
  );

  for (final dark in [false, true]) {
    testWidgets('options scroll on a narrow screen at large text dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      modalOverrides = {
        'suggestions': [
          for (var i = 0; i < 6; i++)
            {
              'type': 'document',
              'id': i + 4,
              'name': 'Accepted supporting document $i',
              'way_id': 8,
              'processing_time': i == 0 ? 'Same day' : 'Not applicable',
              'recommended': i < 3,
              'recommendation_reasons': [
                'Uses documents you already have',
                'Fewer preparation steps',
              ],
              'known_cost': {'min': 0, 'max': 100, 'currency': 'PHP'},
            },
        ],
      };
      connect();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: RoadmapPlanPanel(targetIds: [1], guidedPresentation: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('See Suggested Options'));
      await tester.tap(find.text('See Suggested Options'));
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('roadmap-options-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('View other accepted options').hitTestable(),
        200,
        scrollable: scroll,
      );
      await tester.tap(find.text('View other accepted options'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Accepted supporting document 5'),
        200,
        scrollable: scroll,
      );
      expect(
        find.text('Accepted supporting document 5').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Not applicable'), findsNothing);
      expect(tester.getSize(find.byType(Dialog)).width, lessThanOrEqualTo(320));
      expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Choose N and incomplete combinations explain the remaining items',
    (tester) async {
      modalOverrides = {
        'remaining_count': 2,
        'suggestions': [
          {
            'type': 'document',
            'id': 4,
            'name': 'Birth record',
            'way_id': 8,
            'in_journey': true,
            'remaining_count': 2,
          },
        ],
      };
      connect();
      await show(tester);
      await tester.tap(find.text('See Suggested Options'));
      await tester.pumpAndSettle();
      expect(find.text('Choose 2 accepted options'), findsOneWidget);
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('roadmap-options-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Use This Option'),
        150,
        scrollable: scroll,
      );
      expect(
        find.text('This accepted combination still needs 2 items.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Use This Option'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('still needs 1 additional item.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
    },
  );

  testWidgets('shows a small recommended shortlist and explains the facts', (
    tester,
  ) async {
    modalOverrides = {
      'suggestions': [
        for (var i = 0; i < 5; i++)
          {
            'type': 'document',
            'id': i + 4,
            'name': 'Accepted option $i',
            'way_id': 8,
            'recommended': i < 3,
            if (i == 0)
              'recommendation_reasons': [
                'Uses documents you already have',
                'No additional ID required',
              ],
            if (i == 0)
              'known_cost': {'min': 100, 'max': 100, 'currency': 'PHP'},
            if (i == 1) 'unresolved_choices': 1,
            if (i == 2) 'manual_review_steps': 1,
          },
      ],
    };
    connect();
    await show(tester);
    await tester.tap(find.text('See Suggested Options'));
    await tester.pumpAndSettle();
    expect(find.text('Recommended for your Roadmap'), findsNothing);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Accepted option 0'), findsOneWidget);
    expect(find.text('Accepted option 2'), findsOneWidget);
    expect(find.text('Accepted option 3'), findsNothing);
    expect(find.text('Accepted option 4'), findsNothing);
    expect(find.text('View other accepted options'), findsOneWidget);
    expect(find.text('Uses documents you already have'), findsOneWidget);
    expect(find.text('No additional ID required'), findsOneWidget);
    expect(find.text('Additional fees: ₱100.00'), findsOneWidget);
    expect(find.text('Another requirement needs a choice.'), findsOneWidget);
    expect(find.text('Some requirements need review.'), findsOneWidget);
    expect(requests, hasLength(1));
  });

  testWidgets(
    'another accepted option remains selectable and adds its actual record',
    (tester) async {
      modalOverrides = {
        'suggestions': [
          for (var i = 0; i < 4; i++)
            {
              'type': 'document',
              'id': i + 4,
              'name': i == 3 ? 'Alternative document' : 'Suggested document $i',
              'way_id': 8,
              'recommended': i < 3,
            },
        ],
      };
      connect();
      await show(tester);
      await tester.tap(find.text('See Suggested Options'));
      await tester.pumpAndSettle();
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('roadmap-options-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('View other accepted options').hitTestable(),
        200,
        scrollable: scroll,
      );
      await tester.tap(find.text('View other accepted options'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Alternative document'),
        200,
        scrollable: scroll,
      );
      await tester.ensureVisible(find.text('Add to Journey').last);
      await tester.tap(find.text('Add to Journey').last);
      await tester.pumpAndSettle();
      expect(find.text('Add Alternative document to Journey?'), findsOneWidget);
      await tester.tap(find.text('Add to Journey'));
      await tester.pumpAndSettle();
      expect(requests.last['resolution'], {
        'key': 'government_id:1:set:3:group:12',
        'type': 'document',
        'id': 7,
        'way_id': 8,
      });
      expect(find.text('Alternative document'), findsOneWidget);
      expect(find.text('Valid ID / Supporting ID'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown time and invalid or missing cost never produce price or speed claims',
    (tester) async {
      modalOverrides = {
        'suggestions': [
          {
            'type': 'document',
            'id': 4,
            'name': 'Unknown facts',
            'way_id': 8,
            'recommended': true,
            'processing_time': 'Varies',
            'known_cost': null,
          },
          {
            'type': 'document',
            'id': 5,
            'name': 'Invalid price',
            'way_id': 8,
            'recommended': true,
            'known_cost': {'min': -1, 'max': 10, 'currency': 'PHP'},
          },
        ],
      };
      connect();
      await show(tester);
      await tester.tap(find.text('See Suggested Options'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Additional fees:'), findsNothing);
      expect(find.text('Varies'), findsNothing);
      expect(find.textContaining('fastest'), findsNothing);
      expect(find.textContaining('cheapest'), findsNothing);
      expect(
        find.textContaining('Shorter known processing time'),
        findsNothing,
      );
      expect(find.textContaining('Lower known cost'), findsNothing);
    },
  );

  testWidgets(
    'application checklists are not ranked as acquisition alternatives',
    (tester) async {
      modalOverrides = {
        'suggestions': [
          for (var i = 0; i < 5; i++)
            {
              'set_id': i + 3,
              'name': 'Applicant checklist $i',
              'recommended': true,
              'recommendation_reasons': ['No additional ID required'],
            },
        ],
      };
      connect(path: true);
      await show(tester);
      await tester.tap(find.text('Choose Application Requirements'));
      await tester.pumpAndSettle();
      expect(find.text('Applicant checklist 4'), findsOneWidget);
      expect(find.textContaining('Other accepted options'), findsNothing);
      expect(find.text('Recommended'), findsNothing);
      expect(find.text('No additional ID required'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
