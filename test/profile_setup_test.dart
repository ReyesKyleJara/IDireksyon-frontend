import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';
import 'package:idireksyon_frontend/features/profile/profile_setup_screen.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/features/loading/loading_screen.dart';
import 'package:idireksyon_frontend/features/profile/profile_complete_screen.dart';

void main() {
  late List<http.Request> requests;
  setUp(() {
    requests = [];
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"user":{"id":1},"token":"test"}', 200);
      }),
    )..token = 'test';
  });

  Widget app(Widget home) => MaterialApp(
    home: home,
    routes: {'/home': (_) => const Scaffold(body: Text('Resident home'))},
    onGenerateRoute: AppRouter.generateRoute,
  );

  Future<void> finishSetup(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoadingScreen), findsOneWidget);
    expect(find.text('Resident home'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ProfileCompleteScreen), findsOneWidget);
    expect(find.text('You’re all set'), findsOneWidget);
    expect(find.text('Resident home'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'IDs then documents preserve selection on back and save to account',
    (tester) async {
      await tester.pumpWidget(app(const ProfileSetupScreen()));
      await tester.tap(find.text('PhilSys ID'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Birth Certificate'));
      await tester.tap(find.byTooltip('Back to IDs'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('Let’s start your ID Journey'));
      await finishSetup(tester);
      expect(find.text('Resident home'), findsOneWidget);
      expect(requests.single.headers['Authorization'], 'Bearer test');
      expect(jsonDecode(requests.single.body), {
        'ids': ['PhilSys ID'],
        'documents': ['Birth Certificate'],
      });
    },
  );

  testWidgets('skip advances each step and saves empty selections', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ProfileSetupScreen()));
    await tester.tap(find.text('PhilSys ID'));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Birth Certificate'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await finishSetup(tester);
    expect(jsonDecode(requests.single.body), {'ids': [], 'documents': []});
    expect(find.text('Resident home'), findsOneWidget);
  });

  testWidgets('login goes directly home without setup', (tester) async {
    await tester.pumpWidget(app(const LoginScreen()));
    await tester.enterText(
      find.byType(TextFormField).first,
      'juan@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log In'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Resident home'), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
  });

  testWidgets('save failure keeps selections and permits retry', (
    tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient((_) async => http.Response('{}', 500)),
    )..token = 'test';
    await tester.pumpWidget(app(const ProfileSetupScreen()));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Birth Certificate'));
    await tester.tap(find.text('Let’s start your ID Journey'));
    await tester.pumpAndSettle();
    expect(
      find.text('The server is unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('small screens with large text scroll without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
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
        home: const ProfileSetupScreen(),
      ),
    );
    await tester.ensureVisible(find.text('Driver’s License'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('NBI Clearance'));
    expect(tester.takeException(), isNull);
  });
}
