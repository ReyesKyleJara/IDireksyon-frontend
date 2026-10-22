import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/models/resident_inventory.dart';
import 'package:idireksyon_frontend/models/applicant_context.dart';
import 'package:idireksyon_frontend/models/government_id_sequence.dart';
import 'package:idireksyon_frontend/features/ids/applicant_flow_controller.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/sequence_controller.dart';
import 'package:idireksyon_frontend/features/roadmap/sequence_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/services/api_service.dart';

import 'applicant_flow_test.dart' show evaluation;
import 'sequence_test.dart' show payload, node;

Map<String, dynamic> inventory({
  List<int> ids = const [2],
  List<int> docs = const [3],
}) => {
  'government_ids': [
    for (final id in ids) {'id': id, 'name': 'Owned ID', 'owned': true},
    {'id': 99, 'name': 'Not owned', 'owned': false},
  ],
  'documents': [
    for (final id in docs) {'id': id, 'name': 'Owned document', 'owned': true},
  ],
};
http.Response response(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'data': data}), 200);
AuthService session(
  Future<http.Response> Function(http.Request) request, {
  String token = 'resident-a',
}) =>
    AuthService(client: MockClient(request), baseUrl: 'http://local.test/api')
      ..token = token;
Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('strict ownership flags only; stable sorted immutable IDs', () {
    final owned = ResidentInventory.fromJson(inventory(ids: [7, 2]));
    expect(owned.governmentIds, [2, 7]);
    expect(owned.documentIds, [3]);
    expect(() => owned.governmentIds.add(9), throwsUnsupportedError);
    for (final data in [
      <String, dynamic>{},
      {
        'government_ids': [
          {'id': 1, 'owned': 'true'},
        ],
        'documents': [],
      },
      {
        'government_ids': [
          {'id': 1, 'owned': true},
          {'id': 1, 'owned': false},
        ],
        'documents': [],
      },
    ]) {
      expect(() => ResidentInventory.fromJson(data), throwsFormatException);
    }
  });
  test('one authenticated load hydrates both flows and preserves facts and choices', () async {
    var reads = 0;
    final pending = Completer<http.Response>();
    final auth = session((request) async {
      expect(request.headers['Authorization'], 'Bearer resident-a');
      reads++;
      return pending.future;
    });
    final contexts = <ApplicantContext>[];
    final facts = ApplicantContext(
      age: 25,
      applicationType: 'new',
      selectedProfileId: 10,
      ownedGovernmentIdIds: [88],
    );
    final details = ApplicantFlowController(
      1,
      (_, facts) async {
        contexts.add(facts);
        return evaluation(id: 1);
      },
      auth: auth,
      initialContext: facts,
    );
    final road = SequenceController(1, facts, (_, facts, choices) async {
      contexts.add(facts);
      expect(choices, {1: 10});
      return GovernmentIdSequence.fromJson(payload());
    }, auth: auth);
    final a = details.refresh(), b = road.refresh();
    expect(contexts, isEmpty);
    expect(details.ownershipReady, isFalse);
    expect(auth.ownership, isNull);
    pending.complete(response(inventory()));
    await Future.wait([a, b]);
    expect(reads, 1);
    expect(contexts.length, 2);
    for (final context in contexts) {
      expect(context.age, 25);
      expect(context.applicationType, 'new');
      expect(context.selectedProfileId, 10);
      expect(context.ownedGovernmentIdIds, [2]);
      expect(context.ownedDocumentIds, [3]);
    }
    details.dispose();
    road.dispose();
    auth.dispose();
  });
  test(
    'confirmed empty resident inventory replaces fixture ownership',
    () async {
      final auth = session((_) async => response(inventory(ids: [], docs: [])));
      final flow = SequenceController(
        1,
        ApplicantContext(ownedGovernmentIdIds: [88], ownedDocumentIds: [89]),
        (_, facts, _) async {
          expect(facts.ownedGovernmentIdIds, isEmpty);
          expect(facts.ownedDocumentIds, isEmpty);
          return GovernmentIdSequence.fromJson(payload());
        },
        auth: auth,
      );
      await flow.refresh();
      expect(flow.ownershipReady, isTrue);
      expect(auth.ownership, isNotNull);
      flow.dispose();
      auth.dispose();
    },
  );
  test(
    'new flow after logout cannot reuse a prior residents context ownership',
    () async {
      final auth = session((_) async => response(inventory()));
      await auth.loadOwnership();
      await auth.logout();
      final flow = SequenceController(
        1,
        ApplicantContext(ownedGovernmentIdIds: [2], ownedDocumentIds: [3]),
        (_, facts, _) async {
          expect(facts.ownedGovernmentIdIds, isEmpty);
          expect(facts.ownedDocumentIds, isEmpty);
          return GovernmentIdSequence.fromJson(payload());
        },
        auth: auth,
      );
      await flow.refresh();
      flow.dispose();
      auth.dispose();
    },
  );
  test(
    'logged out fixture ownership is preserved and no inventory request occurs',
    () async {
      final auth = AuthService(
        client: MockClient((_) async => throw StateError('must not fetch')),
      );
      final flow = SequenceController(
        1,
        ApplicantContext(ownedGovernmentIdIds: [8]),
        (_, context, _) async {
          expect(context.ownedGovernmentIdIds, [8]);
          return GovernmentIdSequence.fromJson(payload());
        },
        auth: auth,
      );
      await flow.refresh();
      expect(flow.result!.complete, isTrue);
      flow.dispose();
      auth.dispose();
    },
  );
  test(
    'inventory failure is unknown, pauses evaluation, and retry recovers',
    () async {
      var fail = true, calls = 0;
      final auth = session(
        (_) async =>
            fail ? http.Response('failure', 503) : response(inventory()),
      );
      final flow = SequenceController(1, ApplicantContext(), (_, _, _) async {
        calls++;
        return GovernmentIdSequence.fromJson(payload());
      }, auth: auth);
      await flow.refresh();
      expect(calls, 0);
      expect(flow.ownershipUnavailable, isTrue);
      expect(auth.ownership, isNull);
      fail = false;
      await flow.retryOwnership();
      await flush();
      expect(calls, 1);
      expect(flow.context.ownedDocumentIds, [3]);
      flow.dispose();
      auth.dispose();
    },
  );
  test('save inventory refreshes open flows without losing facts or manual choices', () async {
    var data = inventory(), calls = 0;
    final auth = session((request) async {
      if (request.method == 'PUT') data = inventory(ids: [5], docs: []);
      return response(data);
    });
    final flow = SequenceController(
      1,
      ApplicantContext(age: 25, selectedProfileId: 10),
      (_, _, _) async {
        calls++;
        return GovernmentIdSequence.fromJson(payload());
      },
      auth: auth,
    );
    await flow.refresh();
    await flow.choose(4, 40);
    await auth.saveInventory(governmentIdIds: [5], documentIds: []);
    await flush();
    expect(calls, 3);
    expect(flow.context.age, 25);
    expect(flow.selections, {1: 10, 4: 40});
    expect(flow.context.ownedGovernmentIdIds, [5]);
    expect(flow.context.ownedDocumentIds, isEmpty);
    flow.dispose();
    auth.dispose();
  });
  test('setup invalidates inventory while preserving same-account application choices', () async {
    var data = inventory();
    final auth = session((request) async {
      if (request.url.path.endsWith('/profile-setup')) {
        data = inventory(ids: [5], docs: [8]);
        return http.Response(
          jsonEncode({
            'user': {'id': 1, 'name': 'Resident'},
          }),
          200,
        );
      }
      return response(data);
    })..user = {'id': 1};
    final flow = SequenceController(
      1,
      ApplicantContext(age: 25, applicationType: 'new', selectedProfileId: 10),
      (_, _, _) async => GovernmentIdSequence.fromJson(payload()),
      auth: auth,
    );
    await flow.refresh();
    await flow.choose(4, 40);
    await auth.saveProfileSetup(
      name: 'Resident',
      dateOfBirth: '2000-01-01',
      barangayId: 1,
      governmentIdIds: [5],
      documentIds: [8],
    );
    await flush();
    expect(flow.context.age, 25);
    expect(flow.context.applicationType, 'new');
    expect(flow.selections, {1: 10, 4: 40});
    expect(flow.context.ownedGovernmentIdIds, [5]);
    expect(flow.context.ownedDocumentIds, [8]);
    flow.dispose();
    auth.dispose();
  });
  test(
    'application choices and refreshes never create inventory ownership',
    () async {
      final methods = <String>[];
      final auth = session((request) async {
        methods.add(request.method);
        return response(inventory());
      });
      final flow = SequenceController(
        1,
        ApplicantContext(),
        (_, _, _) async => GovernmentIdSequence.fromJson(payload()),
        auth: auth,
      );
      await flow.refresh();
      await flow.choose(1, 88);
      await flow.updateFacts(25, 'new');
      await flow.refresh();
      expect(methods, ['GET']);
      expect(auth.ownership!.governmentIds, [2]);
      expect(flow.context.ownedGovernmentIdIds, [2]);
      expect(flow.context.ownedDocumentIds, [3]);
      flow.dispose();
      auth.dispose();
    },
  );
  test(
    'late inventory response after logout cannot restore ownership',
    () async {
      final old = Completer<http.Response>();
      final auth = session(
        (request) async =>
            request.method == 'GET' ? old.future : http.Response('{}', 200),
      );
      final loading = auth.loadOwnership();
      await auth.logout();
      old.complete(response(inventory()));
      await loading;
      expect(auth.ownership, isNull);
      expect(auth.token, isNull);
      expect(auth.ownershipState, InventoryLoadState.idle);
      auth.dispose();
    },
  );
  test('late read before an inventory save cannot overwrite its confirmed ownership', () async {
    final old = Completer<http.Response>();
    final auth = session(
      (request) async =>
          request.method == 'PUT' ? response(inventory(ids: [5])) : old.future,
    );
    final read = auth.loadOwnership();
    await auth.saveInventory(governmentIdIds: [5], documentIds: [3]);
    old.complete(response(inventory(ids: [2])));
    await read;
    expect(auth.ownership!.governmentIds, [5]);
    expect(auth.ownershipState, InventoryLoadState.loaded);
    auth.dispose();
  });
  test(
    'logout immediately clears ownership even when server logout fails',
    () async {
      final auth = session(
        (request) async => request.url.path.endsWith('/logout')
            ? http.Response('failure', 503)
            : response(inventory()),
      );
      await auth.loadOwnership();
      final logout = auth.logout();
      expect(auth.token, isNull);
      expect(auth.ownership, isNull);
      await expectLater(logout, throwsA(isA<AuthException>()));
      auth.dispose();
    },
  );
  test(
    'account switch rejects late A data and uses only B inventory',
    () async {
      final old = Completer<http.Response>();
      final auth = session(
        (request) async =>
            request.headers['Authorization'] == 'Bearer resident-a'
            ? old.future
            : response(inventory(ids: [7], docs: [8])),
      );
      final flow = SequenceController(
        1,
        ApplicantContext(),
        (_, _, _) async => GovernmentIdSequence.fromJson(payload()),
        auth: auth,
      );
      final first = flow.refresh();
      auth.token = 'resident-b';
      await flush();
      expect(flow.context.ownedGovernmentIdIds, [7]);
      expect(flow.context.ownedDocumentIds, [8]);
      old.complete(response(inventory(ids: [2])));
      await first;
      await flush();
      expect(flow.context.ownedGovernmentIdIds, [7]);
      await auth.logout();
      await flush();
      expect(flow.context.ownedGovernmentIdIds, isEmpty);
      expect(flow.context.ownedDocumentIds, isEmpty);
      flow.dispose();
      auth.dispose();
    },
  );
  test(
    'old sequence response cannot restore ownership plan after account switch',
    () async {
      final old = Completer<GovernmentIdSequence>();
      var calls = 0;
      final auth = session(
        (request) async => response(
          inventory(
            ids: request.headers['Authorization'] == 'Bearer resident-a'
                ? [2]
                : [7],
          ),
        ),
      );
      final flow = SequenceController(
        1,
        ApplicantContext(),
        (_, _, _) async => ++calls == 1
            ? old.future
            : GovernmentIdSequence.fromJson(payload()),
        auth: auth,
      );
      final first = flow.refresh();
      await flush();
      auth.token = 'resident-b';
      await flush();
      final current = flow.result;
      old.complete(
        GovernmentIdSequence.fromJson(
          payload(status: 'no_match', complete: false),
        ),
      );
      await first;
      expect(flow.result, same(current));
      expect(flow.context.ownedGovernmentIdIds, [7]);
      flow.dispose();
      auth.dispose();
    },
  );
  test('sequence client automatically sends inventory, backend satisfaction remains authoritative', () async {
    final auth = session((_) async => response(inventory()));
    final client = MockClient((request) async {
      final facts = jsonDecode(request.body);
      expect(facts['owned_government_id_ids'], [2]);
      expect(facts['owned_document_ids'], [3]);
      return response(
        payload(
          plan: [
            node(4, 'Missing permit'),
            node(1, 'Target', target: true, order: 2),
          ],
          satisfied: [
            node(2, 'Recorded ID', owned: true, order: null),
            node(
              3,
              'Recorded document',
              type: 'document',
              owned: true,
              order: null,
            ),
          ],
        ),
      );
    });
    final flow = SequenceController(
      1,
      ApplicantContext(),
      (id, context, choices) =>
          ApiService.buildSequence(id, context, choices, client: client),
      auth: auth,
    );
    await flow.refresh();
    expect(flow.result!.satisfied.map((n) => n.id), [2, 3]);
    expect(flow.result!.plan.map((n) => n.id), [4, 1]);
    flow.dispose();
    auth.dispose();
    client.close();
  });
  testWidgets('roadmap waits for inventory then renders backend Already Have', (
    tester,
  ) async {
    final previous = AuthService.instance;
    final pending = Completer<http.Response>();
    final auth = session((_) => pending.future);
    AuthService.instance = auth;
    addTearDown(() {
      AuthService.instance = previous;
      auth.dispose();
    });
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SequenceScreen(
          governmentId: 1,
          targetName: 'Target',
          applicantContext: ApplicantContext(),
          evaluate: (_, context, _) async {
            requests++;
            expect(context.ownedGovernmentIdIds, [2]);
            return GovernmentIdSequence.fromJson(
              payload(
                satisfied: [
                  node(2, 'Already recorded', owned: true, order: null),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(requests, 0);
    expect(find.textContaining('Loading your inventory'), findsOneWidget);
    expect(find.text('Your Steps'), findsNothing);
    pending.complete(response(inventory()));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Already Have'), findsOneWidget);
    expect(find.text('Already recorded'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'detail inventory unavailable is explicit and retry reuses facts',
    (tester) async {
      final previous = AuthService.instance;
      var fail = true;
      final auth = session(
        (_) async =>
            fail ? http.Response('failure', 503) : response(inventory()),
      );
      AuthService.instance = auth;
      addTearDown(() {
        AuthService.instance = previous;
        auth.dispose();
      });
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: IdDetailsScreen(
            governmentId: 1,
            idName: 'Target',
            initialApplicantContext: ApplicantContext(
              age: 25,
              applicationType: 'new',
            ),
            loadDetail: (_) async =>
                GovernmentIdDetails.fromJson({'id': 1, 'name': 'Target'}),
            evaluateApplicant: (_, context) async {
              calls++;
              expect(context.age, 25);
              expect(context.applicationType, 'new');
              expect(context.ownedDocumentIds, [3]);
              return evaluation(id: 1);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(
        find.textContaining('ownership information is unavailable'),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(find.text('Retry inventory'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Build My Roadmap'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
