import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/profile/account_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthService previous;
  late List<Map<String, dynamic>> writes;

  void signIn(Map<String, dynamic> profile) {
    AuthService.instance =
        AuthService(
            client: MockClient((request) async {
              if (request.url.path.endsWith('/barangays')) {
                return http.Response('{"data":[]}', 200);
              }
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              writes.add(body);
              return http.Response(
                jsonEncode({
                  'user': {...profile, ...body},
                }),
                200,
              );
            }),
          )
          ..token = 'resident-token'
          ..user = profile;
  }

  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AccountDetailsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = AuthService.instance;
    writes = [];
  });
  tearDown(() => AuthService.instance = previous);

  testWidgets('shows the saved birthday, edits it, and saves it', (
    tester,
  ) async {
    signIn({
      'id': 7,
      'name': 'Resident',
      'email': 'resident@example.com',
      'date_of_birth': '2000-01-15',
    });
    await open(tester);
    expect(find.text('Birthday'), findsOneWidget);
    expect(find.text('01/15/2000'), findsOneWidget);

    await tester.ensureVisible(find.text('01/15/2000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('01/15/2000'));
    await tester.pumpAndSettle();
    expect(find.text('Select your birthday'), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('01/20/2000'), findsOneWidget);
    expect(writes, isEmpty);

    await save(tester);
    expect(writes.single['date_of_birth'], '2000-01-20');
    expect(AuthService.instance.user?['date_of_birth'], '2000-01-20');
    expect(find.text('01/20/2000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling the calendar keeps the birthday', (tester) async {
    signIn({
      'id': 7,
      'name': 'Resident',
      'email': 'resident@example.com',
      'date_of_birth': '2000-01-15',
    });
    await open(tester);
    await tester.ensureVisible(find.text('01/15/2000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('01/15/2000'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('01/15/2000'), findsOneWidget);
  });

  testWidgets('a time in the saved value never shifts the birthday', (
    tester,
  ) async {
    signIn({
      'id': 7,
      'name': 'Resident',
      'email': 'resident@example.com',
      'date_of_birth': '2000-01-15T00:00:00.000000Z',
    });
    await open(tester);
    expect(find.text('01/15/2000'), findsOneWidget);
  });

  testWidgets('an account without a birthday can still save other changes', (
    tester,
  ) async {
    signIn({'id': 7, 'name': 'Resident', 'email': 'resident@example.com'});
    await open(tester);
    expect(find.text('MM/DD/YYYY'), findsOneWidget);
    await save(tester);
    expect(writes.single.containsKey('date_of_birth'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    signIn({
      'id': 7,
      'name': 'Resident',
      'email': 'resident@example.com',
      'date_of_birth': '2000-01-15',
    });
    await open(tester, scale: 2);
    await tester.ensureVisible(find.text('Birthday'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
