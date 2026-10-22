import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/models/applicant_context.dart';
import 'package:idireksyon_frontend/models/government_id_sequence.dart';
import 'package:idireksyon_frontend/services/roadmap_goal_service.dart';
import 'package:idireksyon_frontend/services/api_service.dart';
import 'package:idireksyon_frontend/features/roadmap/sequence_controller.dart';
import 'package:idireksyon_frontend/features/roadmap/sequence_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/saved_goals_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/saved_goals_controller.dart';

import 'sequence_test.dart' show payload, node, decision;

Map<String, dynamic> goal({
  int target = 1,
  String name = 'Target application',
  Map<int, int> selections = const {},
  bool discarded = false,
  bool completed = false,
}) => {
  'government_id': {'id': target, 'name': name},
  'application_type': 'new',
  'profile_selections': {
    for (final row in selections.entries) '${row.key}': row.value,
  },
  'discarded_profile_selections': discarded,
  'is_completed': completed,
};
Map<String, dynamic> inventory({
  List<int> ids = const [],
  List<int> docs = const [],
}) => {
  'government_ids': [
    for (final id in ids) {'id': id, 'owned': true},
  ],
  'documents': [
    for (final id in docs) {'id': id, 'owned': true},
  ],
};
http.Response data(Object value) =>
    http.Response(jsonEncode({'data': value}), 200);
AuthService auth(Future<http.Response> Function(http.Request) handler) =>
    AuthService(client: MockClient(handler), baseUrl: 'http://local.test/api')
      ..token = 'resident-a';
Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  testWidgets(
    'Save Goal uses idempotent PUT and reflects already-saved state',
    (tester) async {
      Map<String, dynamic>? stored;
      final writes = <Map<String, dynamic>>[];
      final session = auth((request) async {
        if (request.url.path.endsWith('/inventory')) {
          return data(inventory(ids: [2], docs: [3]));
        }
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          writes.add(body);
          stored = goal();
          return data(stored!);
        }
        return stored == null ? http.Response('{}', 404) : data(stored!);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: SequenceScreen(
            governmentId: 1,
            targetName: 'Target application',
            applicantContext: ApplicantContext(age: 25, applicationType: 'new'),
            goalService: RoadmapGoalService(session),
            evaluate: (_, _, _) async =>
                GovernmentIdSequence.fromJson(payload()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Goal'));
      await tester.pumpAndSettle();
      expect(find.text('Goal saved'), findsOneWidget);
      expect(find.text('Update Saved Goal'), findsOneWidget);
      expect(writes.single, {
        'application_type': 'new',
        'profile_selections': <String, dynamic>{},
      });
      await tester.tap(find.text('Update Saved Goal'));
      await tester.pumpAndSettle();
      expect(writes.length, 2);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  test('opening saved goal restores selections but requests current inventory and a fresh sequence', () async {
    final paths = <String>[];
    final session = auth((request) async {
      paths.add(request.url.path);
      return request.url.path.endsWith('/inventory')
          ? data(inventory(ids: [2], docs: [3]))
          : data(goal(selections: {2: 20}));
    });
    final flow = SequenceController(1, ApplicantContext(), (
      _,
      facts,
      selections,
    ) async {
      expect(facts.age, isNull);
      expect(facts.applicationType, 'new');
      expect(facts.ownedGovernmentIdIds, [2]);
      expect(facts.ownedDocumentIds, [3]);
      expect(selections, {2: 20});
      return GovernmentIdSequence.fromJson(payload());
    }, goalService: RoadmapGoalService(session));
    await flow.initialize(restoreSaved: true);
    expect(flow.result!.complete, isTrue);
    expect(paths, ['/api/auth/roadmap-goals/1', '/api/auth/inventory']);
    flow.dispose();
    session.dispose();
  });
  test('logout clears applicant facts restored from a resident goal', () async {
    final session = auth(
      (request) async => request.url.path.endsWith('/inventory')
          ? data(inventory())
          : data(goal(selections: {2: 20})),
    );
    final flow = SequenceController(
      1,
      ApplicantContext(),
      (_, _, _) async => GovernmentIdSequence.fromJson(payload()),
      goalService: RoadmapGoalService(session),
    );
    await flow.initialize(restoreSaved: true);
    expect(flow.context.applicationType, 'new');
    session.token = null;
    await flush();
    expect(flow.savedGoal, isNull);
    expect(flow.selections, isEmpty);
    expect(flow.context.applicationType, isNull);
    flow.dispose();
    session.dispose();
  });
  test('opening a temporary flow preserves current facts and marks a differing saved goal unsaved', () async {
    final session = auth(
      (request) async => request.url.path.endsWith('/inventory')
          ? data(inventory())
          : data(goal(selections: {2: 20})),
    );
    final flow = SequenceController(
      1,
      ApplicantContext(age: 25, applicationType: 'renewal'),
      (_, _, _) async => GovernmentIdSequence.fromJson(payload()),
      goalService: RoadmapGoalService(session),
    );
    await flow.initialize();
    expect(flow.context.applicationType, 'renewal');
    expect(flow.context.age, 25);
    expect(flow.selections, isEmpty);
    expect(flow.savedGoal, isNotNull);
    expect(flow.goalDirty, isTrue);
    flow.dispose();
    session.dispose();
  });
  test(
    'saved roadmap uses fresh backend ordering when configuration changes',
    () async {
      var graph = 0;
      final session = auth(
        (request) async => request.url.path.endsWith('/inventory')
            ? data(inventory())
            : data(goal()),
      );
      final client = MockClient(
        (request) async => data(
          payload(
            plan: graph == 0
                ? [node(1, 'Target application', target: true)]
                : [
                    node(3, 'New document', type: 'document'),
                    node(2, 'Permit', order: 2),
                    node(1, 'Target application', target: true, order: 3),
                  ],
          ),
        ),
      );
      final flow = SequenceController(
        1,
        ApplicantContext(),
        (id, context, selections) =>
            ApiService.buildSequence(id, context, selections, client: client),
        goalService: RoadmapGoalService(session),
      );
      await flow.initialize(restoreSaved: true);
      expect(flow.result!.plan.map((n) => n.id), [1]);
      graph = 1;
      await flow.refresh();
      expect(flow.result!.plan.map((n) => n.id), [3, 2, 1]);
      flow.dispose();
      session.dispose();
      client.close();
    },
  );
  test('new recursive choices on a saved goal are retained and persisted progressively', () async {
    var stored = goal(selections: {2: 20});
    final writes = <Map<String, dynamic>>[];
    final session = auth((request) async {
      if (request.url.path.endsWith('/inventory')) return data(inventory());
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        writes.add(body);
        stored = {...goal(), 'profile_selections': body['profile_selections']};
      }
      return data(stored);
    });
    final flow = SequenceController(
      1,
      ApplicantContext(),
      (_, _, selections) async => GovernmentIdSequence.fromJson(
        selections.containsKey(3)
            ? payload()
            : payload(
                status: 'manual_confirmation_required',
                complete: false,
                pending: [decision(3)],
              ),
      ),
      goalService: RoadmapGoalService(session),
    );
    await flow.initialize(restoreSaved: true);
    expect(flow.result!.complete, isFalse);
    await flow.choose(3, 30);
    expect(writes.single['profile_selections'], {'2': 20, '3': 30});
    expect(flow.result!.complete, isTrue);
    expect(flow.goalDirty, isFalse);
    await flow.updateFacts(26, 'renewal');
    expect(writes.last['application_type'], 'renewal');
    expect(writes.last.containsKey('age'), isFalse);
    flow.dispose();
    session.dispose();
  });
  test('stale saved selection is discarded and returned clarification is not auto-selected', () async {
    final session = auth(
      (request) async => request.url.path.endsWith('/inventory')
          ? data(inventory())
          : data(goal(discarded: true)),
    );
    final flow = SequenceController(1, ApplicantContext(), (
      _,
      _,
      choices,
    ) async {
      expect(choices, isEmpty);
      return GovernmentIdSequence.fromJson(
        payload(
          status: 'manual_confirmation_required',
          complete: false,
          pending: [decision(2)],
        ),
      );
    }, goalService: RoadmapGoalService(session));
    await flow.initialize(restoreSaved: true);
    expect(flow.savedChoicesChanged, isTrue);
    expect(flow.selections, isEmpty);
    expect(flow.result!.pending.single.name, 'Application 2');
    flow.dispose();
    session.dispose();
  });
  test('profile deleted between restore and sequence triggers a fresh sanitized decision', () async {
    var reads = 0, calls = 0;
    final session = auth(
      (request) async => request.url.path.endsWith('/inventory')
          ? data(inventory())
          : data(
              ++reads == 1 ? goal(selections: {2: 20}) : goal(discarded: true),
            ),
    );
    final flow = SequenceController(1, ApplicantContext(), (
      _,
      _,
      choices,
    ) async {
      if (++calls == 1) throw const FormatException('selection was deleted');
      expect(choices, isEmpty);
      return GovernmentIdSequence.fromJson(
        payload(
          status: 'manual_confirmation_required',
          complete: false,
          pending: [decision(2)],
        ),
      );
    }, goalService: RoadmapGoalService(session));
    await flow.initialize(restoreSaved: true);
    expect(calls, 2);
    expect(flow.error, isNull);
    expect(flow.result!.complete, isFalse);
    flow.dispose();
    session.dispose();
  });
  test('inventory updates refresh a saved plan without writing ownership or progress to the goal', () async {
    var owned = <int>[];
    var goalWrites = 0;
    final session = auth((request) async {
      if (request.url.path.endsWith('/inventory')) {
        if (request.method == 'PUT') owned = [2];
        return data(inventory(ids: owned));
      }
      if (request.method == 'PUT') goalWrites++;
      return data(goal());
    });
    final backend = MockClient((request) async {
      final facts = jsonDecode(request.body);
      final satisfied =
          (facts['owned_government_id_ids'] as List?)?.contains(2) ?? false;
      return data(
        payload(
          plan: satisfied
              ? [node(1, 'Target application', target: true)]
              : [
                  node(2, 'Permit'),
                  node(1, 'Target application', target: true, order: 2),
                ],
          satisfied: satisfied
              ? [node(2, 'Permit', owned: true, order: null)]
              : [],
        ),
      );
    });
    final flow = SequenceController(
      1,
      ApplicantContext(),
      (id, context, selections) =>
          ApiService.buildSequence(id, context, selections, client: backend),
      goalService: RoadmapGoalService(session),
    );
    await flow.initialize(restoreSaved: true);
    expect(flow.result!.plan.length, 2);
    await session.saveInventory(governmentIdIds: [2], documentIds: []);
    await flush();
    expect(flow.result!.satisfied.single.id, 2);
    expect(flow.result!.plan.single.isTarget, isTrue);
    expect(goalWrites, 0);
    flow.dispose();
    session.dispose();
    backend.close();
  });
  test('save failure preserves current plan and retry can save it', () async {
    var fail = true;
    final session = auth(
      (request) async => request.method == 'PUT'
          ? (fail ? http.Response('{}', 503) : data(goal()))
          : data(inventory()),
    );
    final flow = SequenceController(
      1,
      ApplicantContext(),
      (_, _, _) async => GovernmentIdSequence.fromJson(payload()),
      goalService: RoadmapGoalService(session),
    );
    await flow.refresh();
    final current = flow.result;
    expect(await flow.saveGoal(), isFalse);
    expect(flow.result, same(current));
    expect(flow.saveError, isNotNull);
    fail = false;
    expect(await flow.saveGoal(), isTrue);
    expect(flow.savedGoal, isNotNull);
    flow.dispose();
    session.dispose();
  });
  test(
    'logged-out temporary roadmap remains usable and cannot persist directly',
    () async {
      final session = AuthService(
        client: MockClient(
          (_) async => throw StateError('No authenticated request allowed'),
        ),
      );
      final flow = SequenceController(
        1,
        ApplicantContext(),
        (_, _, _) async => GovernmentIdSequence.fromJson(payload()),
        goalService: RoadmapGoalService(session),
      );
      await flow.initialize();
      expect(flow.result!.complete, isTrue);
      expect(await flow.saveGoal(), isFalse);
      expect(flow.savedGoal, isNull);
      flow.dispose();
      session.dispose();
    },
  );
  test('list account switch and logout discard both cache and late prior-account responses', () async {
    final old = Completer<http.Response>();
    final session = auth(
      (request) async => request.headers['Authorization'] == 'Bearer resident-a'
          ? old.future
          : data([goal(target: 2, name: 'Resident B goal')]),
    );
    final flow = SavedGoalsController(RoadmapGoalService(session));
    final first = flow.refresh();
    session.token = 'resident-b';
    await flush();
    expect(flow.goals.single.name, 'Resident B goal');
    old.complete(data([goal(name: 'Resident A goal')]));
    await first;
    expect(flow.goals.single.name, 'Resident B goal');
    session.token = null;
    expect(flow.goals, isEmpty);
    flow.dispose();
    session.dispose();
  });
  test(
    'pending save response cannot restore prior residents saved state',
    () async {
      final old = Completer<http.Response>();
      final session = auth(
        (request) async =>
            request.method == 'PUT' ? old.future : data(inventory()),
      );
      final flow = SequenceController(
        1,
        ApplicantContext(),
        (_, _, _) async => GovernmentIdSequence.fromJson(payload()),
        goalService: RoadmapGoalService(session),
      );
      await flow.refresh();
      final save = flow.saveGoal();
      session.token = 'resident-b';
      await flush();
      old.complete(data(goal()));
      await save;
      expect(flow.savedGoal, isNull);
      expect(flow.saveError, isNull);
      flow.dispose();
      session.dispose();
    },
  );
  testWidgets(
    'My Roadmaps opens a saved goal and recalculates only when opened',
    (tester) async {
      var calls = 0;
      final session = auth(
        (request) async => request.url.path.endsWith('/inventory')
            ? data(inventory())
            : request.url.path.endsWith('/roadmap-goals')
            ? data([
                goal(selections: {2: 20}),
              ])
            : data(goal(selections: {2: 20})),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SavedGoalsScreen(
            service: RoadmapGoalService(session),
            evaluate: (_, _, selections) async {
              calls++;
              expect(selections, {2: 20});
              return GovernmentIdSequence.fromJson(payload());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My Roadmaps'), findsOneWidget);
      expect(calls, 0);
      await tester.tap(find.text('Target application'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Goal saved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('owned target shows Goal completed and remains saved', (
    tester,
  ) async {
    var deletes = 0;
    final session = auth((request) async {
      if (request.method == 'DELETE') deletes++;
      return request.url.path.endsWith('/inventory')
          ? data(inventory(ids: [1]))
          : data(goal(completed: true));
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SequenceScreen(
          governmentId: 1,
          targetName: 'Target',
          applicantContext: ApplicantContext(),
          restoreSaved: true,
          goalService: RoadmapGoalService(session),
          evaluate: (_, _, _) async => GovernmentIdSequence.fromJson(
            payload(
              plan: [],
              satisfied: [
                node(
                  1,
                  'Target application',
                  target: true,
                  owned: true,
                  order: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Goal completed'), findsOneWidget);
    expect(find.text('Goal saved'), findsOneWidget);
    expect(deletes, 0);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets(
    'reopening asks only for missing age and never persists that age',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final session = auth((request) async {
        if (request.url.path.endsWith('/inventory')) return data(inventory());
        if (request.method == 'PUT') {
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
        }
        return data(goal());
      });
      await tester.pumpWidget(
        MaterialApp(
          home: SequenceScreen(
            governmentId: 1,
            targetName: 'Target',
            applicantContext: ApplicantContext(),
            restoreSaved: true,
            goalService: RoadmapGoalService(session),
            evaluate: (_, context, _) async => GovernmentIdSequence.fromJson(
              context.age == null
                  ? payload(
                      status: 'insufficient_context',
                      complete: false,
                      missing: ['age'],
                      pending: [
                        decision(
                          1,
                          state: 'insufficient_context',
                          missing: ['age'],
                        ),
                      ],
                    )
                  : payload(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Your age'), findsOneWidget);
      expect(find.text('What type of application is this?'), findsNothing);
      await tester.enterText(find.byType(TextField), '25');
      await tester.tap(find.text('Update application'));
      await tester.pumpAndSettle();
      expect(writes.single.containsKey('age'), isFalse);
      expect(find.text('Your Steps'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('public Save action uses existing login route', (tester) async {
    final session = AuthService();
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/login': (_) => const Scaffold(body: Text('Existing login'))},
        home: SequenceScreen(
          governmentId: 1,
          targetName: 'Target',
          applicantContext: ApplicantContext(),
          goalService: RoadmapGoalService(session),
          evaluate: (_, _, _) async => GovernmentIdSequence.fromJson(payload()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to save'));
    await tester.pumpAndSettle();
    expect(find.text('Existing login'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets('saved list failure supports retry and explicit remove', (
    tester,
  ) async {
    var fail = true, removed = false;
    final session = auth((request) async {
      if (request.method == 'DELETE') {
        removed = true;
        return http.Response('', 204);
      }
      return fail ? http.Response('{}', 503) : data(removed ? [] : [goal()]);
    });
    await tester.pumpWidget(
      MaterialApp(home: SavedGoalsScreen(service: RoadmapGoalService(session))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Refresh roadmaps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove saved goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(find.textContaining('No saved roadmaps yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
