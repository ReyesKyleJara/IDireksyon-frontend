import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/models/roadmap_plan.dart';
import 'package:idireksyon_frontend/features/roadmap/confirm_documents_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/roadmap_plan_panel.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';

import 'fixtures/roadmap_auth.dart';

void main() {
  late AuthService previous;
  setUp(() => previous = AuthService.instance);
  tearDown(() {
    AuthService.instance.dispose();
    AuthService.instance = previous;
  });

  testWidgets(
    'confirmation is read-only and displays saved IDs/types without sample ownership',
    (tester) async {
      var writes = 0;
      AuthService.instance = AuthService(
        client: MockClient((request) async {
          if (request.method != 'GET') writes++;
          return http.Response(
            jsonEncode({
              'data': {
                'government_ids': [
                  {'id': 7, 'name': 'Saved ID', 'owned': true},
                ],
                'documents': [
                  {'id': 7, 'name': 'Saved document', 'owned': true},
                  {'id': 8, 'name': 'Not owned', 'owned': false},
                ],
              },
            }),
            200,
          );
        }),
      )..token = 'resident';
      await tester.pumpWidget(
        const MaterialApp(home: ConfirmDocumentsScreen(targetCatalogIds: [55])),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(('government_id', 7))), findsOneWidget);
      expect(find.byKey(const ValueKey(('document', 7))), findsOneWidget);
      expect(find.text('Not owned'), findsNothing);
      expect(find.text('Birth Certificate'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.text('Saved document'));
      expect(writes, 0);
    },
  );

  testWidgets(
    'Manage Inventory saves explicitly and returning refreshes read-only confirmation',
    (tester) async {
      var owned = false;
      var puts = 0;
      var gets = 0;
      AuthService.instance = AuthService(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            puts++;
            expect(jsonDecode(request.body), {
              'government_id_ids': [],
              'document_ids': [7],
            });
            owned = true;
          } else {
            expect(request.method, 'GET');
            gets++;
          }
          return http.Response(
            jsonEncode({
              'data': {
                'government_ids': [],
                'documents': [
                  {'id': 7, 'name': 'Real document B', 'owned': owned},
                ],
              },
            }),
            200,
          );
        }),
      )..token = 'resident';
      await tester.pumpWidget(
        const MaterialApp(home: ConfirmDocumentsScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Real document B'), findsNothing);
      await tester.tap(find.text('Manage Inventory'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Real document B'));
      await tester.tap(find.text('Real document B'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmDocumentsScreen), findsOneWidget);
      expect(find.text('Real document B'), findsOneWidget);
      expect(puts, 1);
      expect(gets, greaterThanOrEqualTo(3));
    },
  );

  testWidgets(
    'ordered mixed-catalog steps show separate readiness, ownership, and manual conditions',
    (tester) async {
      final plan = RoadmapPlan.fromJson(
        planData(
          [1],
          [
            planStep(3, 'Government C', selected: false),
            planStep(2, 'Document B', type: 'document', selected: false),
            planStep(
              1,
              'Target A',
              prerequisites: [
                {
                  'type': 'government_id',
                  'id': 4,
                  'name': 'Owned credential',
                  'status': 'satisfied',
                  'condition': null,
                },
                {
                  'type': 'document',
                  'id': 2,
                  'name': 'Document B',
                  'status': 'missing',
                  'condition': null,
                },
                {
                  'type': 'custom',
                  'id': null,
                  'name': 'Training',
                  'status': 'manual',
                  'condition': 'If required',
                },
              ],
              satisfied: 1,
              total: 2,
              manual: 1,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RoadmapPlanView(plan: plan)),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('Government C')).dy,
        lessThan(tester.getTopLeft(find.text('Document B')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Document B')).dy,
        lessThan(tester.getTopLeft(find.text('Target A')).dy),
      );
      expect(find.textContaining('1 of 2 verified — 50%'), findsOneWidget);
      expect(find.textContaining('Needs manual confirmation'), findsOneWidget);
      expect(find.textContaining('Applies when: If required'), findsOneWidget);
      expect(find.textContaining('Already in Inventory'), findsOneWidget);
      expect(find.text('Preview Guide'), findsNWidgets(2));
    },
  );

  testWidgets(
    'blocked dependency remains visible and prevents journey confirmation',
    (tester) async {
      AuthService.instance = AuthService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': planData(
                [1],
                [
                  planStep(
                    2,
                    'Unavailable B',
                    type: 'document',
                    selected: false,
                    blocked: true,
                  ),
                  planStep(1, 'Selected A', blocked: true),
                ],
              ),
            }),
            200,
          ),
        ),
      )..token = 'resident';
      await tester.pumpWidget(
        const MaterialApp(
          home: SuggestedRoadmapScreen(
            targetIds: ['Selected A'],
            targetCatalogIds: [1],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unavailable B'), findsOneWidget);
      expect(find.textContaining('Prerequisite path blocked.'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Confirm Suggested Journey'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text('0%'),
        findsOneWidget,
      ); // Overall placeholder is unchanged.
    },
  );

  testWidgets(
    'plan errors allow retry and saved Inventory changes refresh the plan',
    (tester) async {
      var requests = 0;
      var owned = false;
      AuthService.instance = AuthService(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            owned = true;
            return http.Response(
              '{"data":{"government_ids":[],"documents":[]}}',
              200,
            );
          }
          requests++;
          if (requests == 1) return http.Response('{}', 503);
          expectSync(jsonDecode(request.body), {
            'target_government_id_ids': [1],
          });
          return http.Response(
            jsonEncode({
              'data': planData(
                [1],
                [
                  if (!owned)
                    planStep(2, 'Missing B', type: 'document', selected: false),
                  planStep(1, 'Target A', satisfied: owned ? 1 : 0, total: 1),
                ],
              ),
            }),
            200,
          );
        }),
      )..token = 'resident';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RoadmapPlanPanel(targetIds: [1]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('The server is unavailable. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry prerequisite check'));
      await tester.pumpAndSettle();
      expect(find.text('Missing B'), findsOneWidget);
      await AuthService.instance.saveInventory(
        governmentIdIds: [],
        documentIds: [2],
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(requests, 3);
      expect(find.text('Missing B'), findsNothing);
      expect(
        find.textContaining('1 of 1 verified — 100%'),
        findsOneWidget,
        reason: find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .join(' | '),
      );
    },
  );

  testWidgets(
    'failed Inventory reads do not enable confirmation or show sample ownership',
    (tester) async {
      AuthService.instance = AuthService(
        client: MockClient((_) async => http.Response('{}', 503)),
      )..token = 'resident';
      await tester.pumpWidget(
        const MaterialApp(home: ConfirmDocumentsScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Birth Certificate'), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Save & Continue'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Retry Inventory'), findsOneWidget);
    },
  );

  test('malformed or wrong-target plans fail safely', () async {
    for (final data in [
      {},
      planData([99], [planStep(99, 'Wrong target')]),
      planData([1], []),
    ]) {
      AuthService.instance = AuthService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'data': data}), 200),
        ),
      )..token = 'resident';
      await expectLater(
        AuthService.instance.roadmapPlan([1]),
        throwsA(isA<AuthException>()),
      );
      AuthService.instance.dispose();
      AuthService.instance = previous;
    }
    // Leave a separate disposable instance for tearDown.
    AuthService.instance = journeyAuth();
  });
}
