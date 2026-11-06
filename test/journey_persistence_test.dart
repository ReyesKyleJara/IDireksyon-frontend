import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';

import 'fixtures/roadmap_auth.dart';

Map<String, dynamic> savedJourney(Set<String> completed) => {
  'id': 12,
  'plan': planData(
    [3],
    [
      planStep(
        1,
        'First document',
        type: 'document',
        selected: false,
        satisfied: 1,
        total: 1,
      ),
      planStep(2, 'Second ID', selected: false),
      planStep(3, 'Target ID'),
    ],
  ),
  'completed_step_identities': completed.toList(),
};

void main() {
  late AuthService previous;
  late Set<String> completed;
  late List<http.Request> requests;
  late bool failCompletion;
  late bool failSave;
  late bool failLoad;
  Completer<void>? completionGate;
  Completer<void>? reloadGate;
  setUp(() {
    previous = AuthService.instance;
    completed = {};
    requests = [];
    failCompletion = false;
    failSave = false;
    failLoad = false;
    completionGate = null;
    reloadGate = null;
  });
  tearDown(() {
    AuthService.instance.dispose();
    AuthService.instance = previous;
  });

  AuthService account() => AuthService(
    client: MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/inventory') && request.method == 'GET') {
        return http.Response(
          '{"data":{"government_ids":[],"documents":[]}}',
          200,
        );
      }
      if (request.url.path.endsWith('/login')) {
        return http.Response(
          '{"token":"account-session","user":{"id":7}}',
          200,
        );
      }
      if (request.url.path.endsWith('/logout')) {
        return http.Response('{"message":"Logged out."}', 200);
      }
      if (request.url.path.endsWith('/roadmap-plan')) {
        return http.Response(
          jsonEncode({'data': savedJourney({})['plan']}),
          200,
        );
      }
      if (request.url.path.endsWith('/journeys') && request.method == 'GET') {
        if (failLoad) return http.Response('{}', 503);
        final snapshot =
            request.headers['Authorization'] == 'Bearer different-account'
            ? []
            : [savedJourney(completed)];
        if (reloadGate != null) await reloadGate!.future;
        return http.Response(jsonEncode({'data': snapshot}), 200);
      }
      if (request.url.path.endsWith('/journeys') && request.method == 'POST') {
        return failSave
            ? http.Response('{}', 503)
            : http.Response(jsonEncode({'data': savedJourney(completed)}), 201);
      }
      if (request.url.path.endsWith('/completion')) {
        expect(request.method, 'PUT');
        expect(request.headers['Authorization'], 'Bearer account-session');
        if (failCompletion) return http.Response('{}', 503);
        if (completionGate != null) await completionGate!.future;
        completed.add(
          (jsonDecode(request.body) as Map)['step_identity'] as String,
        );
        return http.Response(
          jsonEncode({'data': savedJourney(completed)}),
          200,
        );
      }
      fail(
        'Unexpected authenticated request: ${request.method} ${request.url.path}',
      );
    }),
  )..token = 'account-session';

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: const ResidentAppShell(initialIndex: 1),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> complete(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Mark as Completed').first);
    await tester.tap(find.text('Mark as Completed').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Mark as Completed'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'confirmed completion advances 0/33/67/100 and survives reload and login without Inventory writes',
    (tester) async {
      AuthService.instance = account();
      await open(tester);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Current step'), findsOneWidget);
      expect(find.text('Upcoming'), findsNWidgets(2));
      for (final percentage in [33, 67, 100]) {
        await complete(tester);
        expect(find.text('$percentage%'), findsOneWidget);
      }
      expect(find.text('Completed'), findsNWidgets(3));
      expect(find.text('Current step'), findsNothing);
      expect(find.text('Mark as Completed'), findsNothing);
      await open(tester); // A new shell reloads entirely from the API.
      expect(find.text('3 of 3 completed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await AuthService.instance.logout();
      AuthService.instance.dispose();
      AuthService.instance = account()
        ..token = null; // Fresh service simulates a new app/device.
      await AuthService.instance.login('resident@example.com', 'Password123!');
      await open(tester);
      expect(find.text('100%'), findsOneWidget);
      expect(AuthService.instance.inventoryRevision, 0);
      expect(
        requests.where(
          (r) =>
              r.method != 'GET' &&
              (r.url.path.contains('inventory') ||
                  r.url.path.contains('requirement-preparation')),
        ),
        isEmpty,
      );
      expect(requests.where((r) => r.method == 'PUT').length, 3);
    },
  );

  testWidgets(
    'cancel or failed save leaves completion and current step unchanged',
    (tester) async {
      AuthService.instance = account();
      await open(tester);
      await tester.tap(find.text('Mark as Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'PUT'), isEmpty);
      expect(find.text('0%'), findsOneWidget);
      failCompletion = true;
      await complete(tester);
      expect(completed, isEmpty);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
      expect(find.text('Current step'), findsOneWidget);
      expect(
        find.text('Unable to save or load your journey. Please try again.'),
        findsOneWidget,
      );
      failCompletion = false;
      await complete(tester);
      expect(find.text('33%'), findsOneWidget);
    },
  );

  testWidgets('account change clears the previous account journey', (
    tester,
  ) async {
    AuthService.instance = account();
    await open(tester);
    expect(find.text('First document'), findsOneWidget);
    AuthService.instance.token = 'different-account';
    AuthService.instance.user = {'id': 9};
    await tester.pumpAndSettle();
    expect(find.text('First document'), findsNothing);
    expect(find.text('Mark as Completed'), findsNothing);
    expect(requests.last.headers['Authorization'], 'Bearer different-account');
  });

  testWidgets(
    'failed journey confirmation stays on preview without inventing completion',
    (tester) async {
      failSave = true;
      AuthService.instance = account();
      await tester.pumpWidget(
        const MaterialApp(
          home: SuggestedRoadmapScreen(
            targetIds: ['Target ID'],
            targetCatalogIds: [3],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm Suggested Journey'));
      await tester.tap(find.text('Confirm Suggested Journey'));
      await tester.pumpAndSettle();
      expect(find.byType(SuggestedRoadmapScreen), findsOneWidget);
      expect(
        find.text('Unable to save or load your journey. Please try again.'),
        findsOneWidget,
      );
      expect(completed, isEmpty);
      expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    },
  );

  testWidgets(
    'partial progress restores the next current step and failed loads can retry',
    (tester) async {
      completed.add('document:1');
      failLoad = true;
      AuthService.instance = account();
      await open(tester);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Mark as Completed'), findsNothing);
      failLoad = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('active-step-government_id:2')),
          matching: find.text('Current step'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('duplicate taps while saving issue only one completion request', (
    tester,
  ) async {
    completionGate = Completer<void>();
    AuthService.instance = account();
    await open(tester);
    await complete(tester);
    expect(find.text('Saving…'), findsOneWidget);
    await tester.tap(find.text('Saving…'));
    await tester.pump();
    expect(requests.where((r) => r.method == 'PUT').length, 1);
    expect(find.text('0%'), findsOneWidget);
    completionGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('33%'), findsOneWidget);
  });

  testWidgets('older list refresh cannot erase a newly saved completion', (
    tester,
  ) async {
    AuthService.instance = account();
    await open(tester);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    reloadGate = Completer<void>();
    await tester.tap(find.text('Roadmap').last);
    await tester.pumpAndSettle();
    await complete(tester);
    expect(find.text('33%'), findsOneWidget);
    reloadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  test(
    'response from the previous session cannot populate the next account',
    () async {
      final response = Completer<http.Response>();
      final auth = AuthService(client: MockClient((_) => response.future))
        ..token = 'first-account';
      final pending = auth.getJourneys();
      auth.token = 'second-account';
      response.complete(
        http.Response(
          jsonEncode({
            'data': [savedJourney({})],
          }),
          200,
        ),
      );
      await expectLater(pending, throwsA(isA<AuthException>()));
      auth.dispose();
    },
  );
}
