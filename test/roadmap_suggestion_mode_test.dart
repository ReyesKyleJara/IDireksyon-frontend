import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/id_journey.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_journey_view.dart';
import 'package:idireksyon_frontend/models/roadmap_plan.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';

import 'fixtures/roadmap_auth.dart';

const notice =
    'Suggested based on currently available information. Confirm requirements with the issuing agency.';
const confirmKey = 'government_id:3:set:1:group:2';
const utf8Json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> manualRow(String name, String kind) => {
  'type': 'custom',
  'id': null,
  'name': name,
  'status': 'manual',
  'condition': null,
  'manual_kind': kind,
};

Map<String, dynamic> plan() {
  final data = planData(
    [3],
    [
      planStep(1, 'First document', type: 'document', selected: false),
      {
        ...planStep(
          2,
          'Accepted proof',
          type: 'unresolved_requirement',
          selected: false,
        ),
        'resolution_key': confirmKey,
        'owner_key': 'government_id:3',
        'kind': 'requirement',
        'manual_preparation': true,
        'message': 'You listed Card A in your Inventory. Confirm it.',
        'suggestions': <Map<String, dynamic>>[],
        'confirmation': {
          'qualification': 'Be valid',
          'owned_names': ['Card A'],
        },
      },
      {
        ...planStep(
          3,
          'Target ID',
          prerequisites: [
            missingPrerequisite(1, type: 'document'),
            manualRow('Appear in person', 'task'),
            manualRow('Marriage record', 'conditional'),
            manualRow('Accepted proof', 'confirmation'),
          ],
        ),
        'guidance_incomplete': true,
      },
    ],
  );
  return {
    ...data,
    'saved_choices': [
      {
        'key': 'government_id:3:path',
        'kind': 'path',
        'name': 'Application requirements for Target ID',
        'selected': 'Adult • Renewal',
      },
    ],
  };
}

Map<String, dynamic> journey(Set<String> done, {String? changed}) {
  final data = plan();
  if (changed != null) {
    (data['steps'] as List).last['catalog_notice'] = changed;
  }
  return {'id': 12, 'plan': data, 'completed_step_identities': done.toList()};
}

void main() {
  late AuthService previous;
  late List<http.Request> requests;
  late Set<String> done;

  setUp(() {
    previous = AuthService.instance;
    requests = [];
    done = {};
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (request.method == 'DELETE') {
          return http.Response('{"data":{"removed":true}}', 200);
        }
        if (path.endsWith('/completion')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final identity = body['step_identity'] as String;
          body['completed'] == false
              ? done.remove(identity)
              : done.add(identity);
        }
        return http.Response(
          jsonEncode({'data': journey(done)}),
          200,
          headers: utf8Json,
        );
      }),
    )..token = 'resident';
  });
  tearDown(() {
    AuthService.instance.dispose();
    AuthService.instance = previous;
  });

  Future<IdJourney> open(
    WidgetTester tester, {
    Set<String> completed = const {},
    String? changed,
  }) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = IdJourney.fromJson(journey(completed, changed: changed));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActiveJourneyScreen(journeys: [saved])),
      ),
    );
    await tester.pumpAndSettle();
    return saved;
  }

  Map<String, dynamic> body(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  Future<void> tapLast(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows one notice and keeps unverifiable requirements visible', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(notice), findsOneWidget);
    expect(find.text('Also needed for this application'), findsOneWidget);
    expect(find.text('• Appear in person'), findsOneWidget);
    expect(find.text('May apply to you'), findsOneWidget);
    expect(find.text('• Marriage record'), findsOneWidget);
    expect(find.text('• Accepted proof'), findsNothing);
    expect(
      find.text('Details for this item are still incomplete.'),
      findsOneWidget,
    );
  });

  testWidgets('warns about the suggested order and records what is confirmed', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Mark as Completed').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The suggested order is to finish'),
      findsOneWidget,
    );
    expect(find.textContaining('issued anything'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);

    await tester.tap(find.text('Mark as Completed').last);
    await tester.pumpAndSettle();
    await tapLast(tester, 'Mark as Completed');
    expect(body(requests.single)['step_identity'], 'government_id:3');
    expect(body(requests.single)['acknowledge_order'], isTrue);
  });

  testWidgets('does not send an order acknowledgement when none is needed', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Mark as Completed').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('The suggested order'), findsNothing);
    await tapLast(tester, 'Mark as Completed');
    expect(body(requests.single).containsKey('acknowledge_order'), isFalse);
  });

  testWidgets('asks the resident to confirm an owned accepted item', (
    tester,
  ) async {
    await open(tester);
    expect(
      find.text('You listed Card A in your Inventory. Confirm it.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Mark as Completed').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Accepted proof?'), findsOneWidget);
    expect(find.textContaining('not an official verification'), findsOneWidget);
  });

  testWidgets('undoes a completed step after confirmation', (tester) async {
    await open(tester, completed: {'document:1'});
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Inventory and checklist will not'),
      findsOneWidget,
    );
    await tapLast(tester, 'Undo');
    expect(body(requests.single)['completed'], isFalse);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('clears a saved choice only after confirmation', (tester) async {
    await open(tester);
    expect(
      find.text('Application requirements for Target ID: Adult • Renewal'),
      findsOneWidget,
    );
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tapLast(tester, 'Change');
    expect(requests.single.url.path, '/api/auth/journeys/12/resolution');
    expect(body(requests.single)['resolution'], {
      'key': 'government_id:3:path',
      'reset': true,
    });
  });

  testWidgets('shows outdated guidance and refreshes only when asked', (
    tester,
  ) async {
    await open(tester, changed: 'Requirements for this item changed.');
    expect(find.text('Requirements for this item changed.'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.tap(find.byTooltip('Roadmap options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review updated Roadmap'));
    await tester.pumpAndSettle();
    await tapLast(tester, 'Update Roadmap');
    expect(requests.single.url.path, '/api/auth/journeys/12/refresh');
  });

  testWidgets('removes a Roadmap only after a clear warning', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Roadmap options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove this Roadmap'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your Inventory and application checklists'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);

    await tester.tap(find.byTooltip('Roadmap options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove this Roadmap'));
    await tester.pumpAndSettle();
    await tapLast(tester, 'Remove');
    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/api/auth/journeys/12');
    expect(find.text('Remove this Roadmap'), findsNothing);
  });

  testWidgets('suggested Roadmap shows the notice, choices and confirm card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SuggestedJourneyView(
              plan: RoadmapPlan.fromJson(plan()),
              onChangeChoice: (choice) => changed = choice,
            ),
          ),
        ),
      ),
    );
    expect(find.text(notice), findsOneWidget);
    expect(find.text('PLEASE CONFIRM'), findsOneWidget);
    expect(find.text('• Appear in person'), findsOneWidget);
    await tester.tap(find.text('Change'));
    expect(changed?['key'], 'government_id:3:path');
  });

  testWidgets('one unreadable Roadmap does not hide the others', (
    tester,
  ) async {
    AuthService.instance.dispose();
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 99, 'plan': 'broken'},
              journey({}),
            ],
          }),
          200,
          headers: utf8Json,
        );
      }),
    )..token = 'resident';
    await tester.pumpWidget(
      const MaterialApp(home: ResidentAppShell(initialIndex: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Target ID'), findsWidgets);
    expect(
      find.text('A saved Roadmap could not be loaded. Please try again.'),
      findsOneWidget,
    );
  });
}
