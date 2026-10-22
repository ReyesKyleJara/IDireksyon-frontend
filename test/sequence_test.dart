import 'applicant_flow_test.dart' show evaluation;

import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:idireksyon_frontend/models/applicant_context.dart';
import 'package:idireksyon_frontend/models/government_id_sequence.dart';
import 'package:idireksyon_frontend/features/roadmap/sequence_controller.dart';
import 'package:idireksyon_frontend/features/roadmap/sequence_screen.dart';
import 'package:idireksyon_frontend/services/api_service.dart';

Map<String, dynamic> node(
  int id,
  String name, {
  String type = 'government_id',
  bool target = false,
  int? order = 1,
  bool owned = false,
}) => {
  'id': id,
  'name': name,
  'type': type,
  'status': owned
      ? 'satisfied'
      : target
      ? 'target'
      : 'missing',
  'order': order,
  'depth': target ? 0 : 1,
  'is_target': target,
};
Map<String, dynamic> decision(
  int id, {
  String state = 'manual_confirmation_required',
  List<String> missing = const [],
}) => {
  'government_id': {'id': id, 'name': 'Application $id'},
  'applicability': {
    'status': state,
    'missing_context': missing,
    'available_profiles': [
      {
        'id': id * 10,
        'label': 'Custom resident situation',
        'application_type': 'new',
      },
    ],
    'matched_profiles': [
      {
        'id': id * 10,
        'label': 'Custom resident situation',
        'application_type': 'new',
      },
    ],
  },
};
Map<String, dynamic> payload({
  String status = 'ready',
  bool complete = true,
  List<Map<String, dynamic>>? plan,
  List<Map<String, dynamic>> satisfied = const [],
  List<Map<String, dynamic>> pending = const [],
  List<String> missing = const [],
}) => {
  'government_id': {'id': 1, 'name': 'Target application'},
  'status': status,
  'plan_is_complete': complete,
  'plan': plan ?? [node(1, 'Target application', target: true)],
  'satisfied': satisfied,
  'pending_applicability': pending,
  'missing_context': missing,
};
GovernmentIdSequence result({
  String status = 'ready',
  bool complete = true,
  List<Map<String, dynamic>>? plan,
  List<Map<String, dynamic>> satisfied = const [],
  List<Map<String, dynamic>> pending = const [],
  List<String> missing = const [],
}) => GovernmentIdSequence.fromJson(
  payload(
    status: status,
    complete: complete,
    plan: plan,
    satisfied: satisfied,
    pending: pending,
    missing: missing,
  ),
);

void main() {
  test(
    'API sends shared facts and per-ID choices without legacy or placeholders',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/government-ids/1/sequence');
        expect(jsonDecode(request.body), {
          'age': 25,
          'owned_government_id_ids': [3],
          'owned_document_ids': [4],
          'profile_selections': {'1': 10, '2': 20},
        });
        return http.Response(jsonEncode({'data': payload()}), 200);
      });
      final response = await ApiService.buildSequence(
        1,
        ApplicantContext(
          age: 25,
          selectedProfileId: 10,
          ownedGovernmentIdIds: [3],
          ownedDocumentIds: [4],
        ),
        {1: 10, 2: 20},
        client: client,
      );
      expect(response.complete, isTrue);
      client.close();
    },
  );
  test(
    'root context reused and recursive B then C selections retained',
    () async {
      final facts = ApplicantContext(
        age: 25,
        applicationType: 'new',
        selectedProfileId: 10,
      );
      final maps = <Map<int, int>>[];
      final flow = SequenceController(1, facts, (_, context, selections) async {
        expect(identical(context, facts), isTrue);
        maps.add(selections);
        if (!selections.containsKey(2)) {
          return result(
            status: 'manual_confirmation_required',
            complete: false,
            pending: [decision(2)],
          );
        }
        if (!selections.containsKey(3)) {
          return result(
            status: 'multiple_matches',
            complete: false,
            pending: [decision(3, state: 'multiple_matches')],
          );
        }
        return result();
      });
      await flow.refresh();
      expect(flow.result!.complete, isFalse);
      await flow.choose(2, 20);
      expect(flow.result!.pending.single.governmentId, 3);
      await flow.choose(3, 30);
      expect(flow.result!.complete, isTrue);
      expect(maps, [
        {1: 10},
        {1: 10, 2: 20},
        {1: 10, 2: 20, 3: 30},
      ]);
      flow.dispose();
    },
  );
  test('late responses never replace newer selection', () async {
    final old = Completer<GovernmentIdSequence>();
    var calls = 0;
    final flow = SequenceController(
      1,
      ApplicantContext(),
      (_, _, _) => ++calls == 1 ? old.future : Future.value(result()),
    );
    final first = flow.refresh();
    await flow.choose(2, 20);
    old.complete(result(status: 'no_match', complete: false));
    await first;
    expect(flow.result!.complete, isTrue);
    flow.dispose();
  });
  test('failure preserves successful result and retry recovers; facts preserve ownership', () async {
    var fail = false;
    final flow = SequenceController(
      1,
      ApplicantContext(ownedDocumentIds: [8]),
      (_, _, _) async {
        if (fail) throw Exception('private');
        return result();
      },
    );
    await flow.refresh();
    final previous = flow.result;
    fail = true;
    await flow.updateFacts(20, 'new');
    expect(flow.context.ownedDocumentIds, [8]);
    expect(flow.result, same(previous));
    expect(flow.stale, isTrue);
    expect(flow.error, isNot(contains('private')));
    fail = false;
    await flow.refresh();
    expect(flow.stale, isFalse);
    flow.dispose();
  });
  testWidgets(
    'detail entry reuses context and synchronizes changed facts to both tabs',
    (tester) async {
      final facts = ApplicantContext(
        age: 24,
        applicationType: 'new',
        ownedDocumentIds: [8],
      );
      final observed = <ApplicantContext>[];
      await tester.pumpWidget(
        MaterialApp(
          home: IdDetailsScreen(
            governmentId: 1,
            idName: 'Target application',
            initialApplicantContext: facts,
            loadDetail: (_) async => GovernmentIdDetails.fromJson({
              'id': 1,
              'name': 'Target application',
            }),
            evaluateApplicant: (_, context) async {
              observed.add(context);
              return evaluation(id: 1);
            },
            evaluateSequence: (_, context, _) async {
              return result(
                status: 'insufficient_context',
                complete: false,
                missing: ['age'],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build My Roadmap'));
      await tester.pumpAndSettle();
      final roadmap = tester.widget<SequenceScreen>(
        find.byType(SequenceScreen),
      );
      expect(identical(roadmap.applicantContext, facts), isTrue);
      await tester.enterText(find.byType(TextField), '26');
      await tester.tap(find.text('Update application'));
      await tester.pumpAndSettle();
      expect(observed.last.age, 26);
      expect(observed.last.ownedDocumentIds, [8]);
      await tester.tap(find.text('Back to Requirements and Application Guide'));
      await tester.pumpAndSettle();
      expect(find.byType(IdDetailsScreen), findsOneWidget);
    },
  );
  testWidgets('root manual choice uses map and backend labels', (tester) async {
    Map<int, int>? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: SequenceScreen(
          governmentId: 1,
          targetName: 'Target',
          applicantContext: ApplicantContext(),
          evaluate: (_, _, selections) async {
            sent = selections;
            return selections.isEmpty
                ? result(
                    status: 'manual_confirmation_required',
                    complete: false,
                    pending: [decision(1)],
                  )
                : result();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom resident situation'));
    await tester.pumpAndSettle();
    expect(sent, {1: 10});
  });
  testWidgets(
    'government ID node opens matching detail and carries shared facts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SequenceScreen(
            governmentId: 1,
            targetName: 'Target',
            applicantContext: ApplicantContext(age: 24),
            evaluate: (_, _, _) async => result(
              plan: [
                node(2, 'Permit'),
                node(1, 'Target', target: true, order: 2),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Permit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final detail = tester.widget<IdDetailsScreen>(
        find.byType(IdDetailsScreen),
      );
      expect(detail.governmentId, 2);
      expect(detail.initialApplicantContext!.age, 24);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 21));
    },
  );
  testWidgets('roadmap fits narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: SequenceScreen(
          governmentId: 1,
          targetName: 'Target',
          applicantContext: ApplicantContext(),
          evaluate: (_, _, _) async => result(
            status: 'manual_confirmation_required',
            complete: false,
            pending: [decision(2)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'manual-only completion can change backend-provided application facts',
    (tester) async {
      final requests = <ApplicantContext>[];
      final data = payload();
      data['applicability'] = {
        'available_profiles': [
          {
            'id': 10,
            'label': 'Backend application option',
            'application_type': 'new',
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: SequenceScreen(
            governmentId: 1,
            targetName: 'Target',
            applicantContext: ApplicantContext(selectedProfileId: 10),
            evaluate: (_, facts, selections) async {
              requests.add(facts);
              return GovernmentIdSequence.fromJson(data);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('What type of application is this?'), findsNothing);
      await tester.tap(find.text('Change application details'));
      await tester.pumpAndSettle();
      expect(find.text('What type of application is this?'), findsOneWidget);
      expect(find.text('Your age'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New application').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update application'));
      await tester.pumpAndSettle();
      expect(requests.last.applicationType, 'new');
    },
  );
  Future<void> screen(
    WidgetTester tester,
    GovernmentIdSequence response,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SequenceScreen(
          governmentId: 1,
          targetName: 'Target application',
          applicantContext: ApplicantContext(),
          evaluate: (_, _, _) async => response,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('target-only roadmap and return action', (tester) async {
    await screen(tester, result());
    expect(
      find.textContaining("You don't need another configured"),
      findsOneWidget,
    );
    expect(find.text('Your target'), findsOneWidget);
    expect(
      find.text('Back to Requirements and Application Guide'),
      findsOneWidget,
    );
  });
  testWidgets('ID and Document order stays backend order; satisfied separate', (
    tester,
  ) async {
    await screen(
      tester,
      result(
        plan: [
          node(3, 'Document first', type: 'document'),
          node(2, 'Permit second', order: 2),
          node(1, 'Target application', target: true, order: 3),
        ],
        satisfied: [node(8, 'Already owned', owned: true, order: null)],
      ),
    );
    expect(find.text('Already Have'), findsOneWidget);
    expect(find.text('Already available'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Document first')).dy,
      lessThan(tester.getTopLeft(find.text('Permit second')).dy),
    );
    final document = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Document first'),
        matching: find.byType(ListTile),
      ),
    );
    expect(document.onTap, isNull);
  });
  testWidgets(
    'only missing age asked and manual labels have no raw terminology',
    (tester) async {
      await screen(
        tester,
        result(
          status: 'insufficient_context',
          complete: false,
          missing: ['age'],
          pending: [
            decision(2, state: 'insufficient_context', missing: ['age']),
          ],
        ),
      );
      expect(find.widgetWithText(TextField, 'Your age'), findsOneWidget);
      expect(find.text('What type of application is this?'), findsNothing);
      expect(find.text('Custom resident situation'), findsOneWidget);
      expect(find.text('Your Steps'), findsNothing);
      expect(find.textContaining('profile'), findsNothing);
      expect(find.textContaining('requirement_set'), findsNothing);
    },
  );
  testWidgets('multiple match waits for explicit choice and progresses', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SequenceScreen(
          governmentId: 1,
          targetName: 'Target',
          applicantContext: ApplicantContext(),
          evaluate: (_, _, selections) async {
            calls++;
            return selections.containsKey(2)
                ? result()
                : result(
                    status: 'multiple_matches',
                    complete: false,
                    pending: [decision(2, state: 'multiple_matches')],
                  );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.tap(find.text('Custom resident situation'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Your Steps'), findsOneWidget);
  });
  for (final state in ['no_match', 'configuration_error']) {
    testWidgets('safe $state state', (tester) async {
      await screen(tester, result(status: state, complete: false));
      expect(find.text('Your Steps'), findsNothing);
      expect(
        find.textContaining(
          state == 'no_match' ? 'does not match' : "couldn't build",
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets('incomplete ready response never shown as final', (tester) async {
    await screen(tester, result(complete: false));
    expect(find.text('Your Steps'), findsNothing);
    expect(find.textContaining('not complete yet'), findsOneWidget);
  });
  testWidgets('network failure supports retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SequenceScreen(
          governmentId: 1,
          targetName: 'Target',
          applicantContext: ApplicantContext(),
          evaluate: (_, _, _) async {
            if (++calls == 1) throw Exception('SQL private');
            return result();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('SQL'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Your Steps'), findsOneWidget);
  });
}
