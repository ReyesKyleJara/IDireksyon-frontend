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

  setUp(() {
    previous = AuthService.instance;
    requests = [];
    saved = false;
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
        }
        return http.Response(
          jsonEncode({
            'data': planData(
              [1],
              [
                if (!saved) unresolved(path: path, empty: empty),
                if (saved)
                  planStep(
                    4,
                    'Accepted document',
                    type: 'document',
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
      await tester.tap(find.text('Use This Checklist'));
      await tester.pumpAndSettle();
      expect(find.text('Use Adult first-time requirements?'), findsOneWidget);
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
        find.textContaining('Requirement needs manual preparation'),
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
      await tester.tap(find.text('Add to Journey'));
      await tester.pumpAndSettle();
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
}
