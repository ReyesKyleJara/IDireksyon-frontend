import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/profile/account_details_screen.dart';
import 'package:idireksyon_frontend/features/profile/profile_screen.dart';

void main() {
  late AuthService previous;
  late AuthService auth;
  late List<Map<String, dynamic>> writes;
  late bool listFails, saveFails;
  late Map<String, dynamic> profile;
  const barangays = [
    {'id': 1, 'name': 'Poblacion'},
    {'id': 2, 'name': 'San Vicente'},
    {'id': 3, 'name': 'Barangay with a much longer descriptive name'},
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = AuthService.instance;
    writes = [];
    listFails = false;
    saveFails = false;
    profile = {
      'id': 7,
      'name': 'Resident',
      'email': 'resident@example.com',
      'barangay_id': 1,
      'barangay_name': 'Poblacion',
    };
    auth =
        AuthService(
            client: MockClient((request) async {
              if (request.url.path.endsWith('/barangays')) {
                return http.Response(
                  listFails ? '{}' : jsonEncode({'data': barangays}),
                  listFails ? 503 : 200,
                );
              }
              expectSync(request.method, 'POST');
              expectSync(request.url.path, '/api/auth/account');
              expectSync(
                request.headers['Authorization'],
                'Bearer resident-token',
              );
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              writes.add(body);
              if (saveFails) {
                return http.Response(
                  '{"message":"Could not update profile."}',
                  422,
                );
              }
              final id = body['barangay_id'] ?? profile['barangay_id'];
              profile = {
                ...profile,
                ...body,
                'barangay_name': barangays.firstWhere(
                  (row) => row['id'] == id,
                )['name'],
              };
              return http.Response(jsonEncode({'user': profile}), 200);
            }),
          )
          ..token = 'resident-token'
          ..user = profile;
    AuthService.instance = auth;
  });

  tearDown(() {
    AuthService.instance = previous;
    auth.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    bool editor = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: editor ? const AccountDetailsScreen() : const ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String name) async {
    final selector = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
  }

  testWidgets('Profile shows onboarding barangay and updates after editing', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('Poblacion'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Personal information'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Personal information'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .initialValue,
      1,
    );
    await choose(tester, 'San Vicente');
    await save(tester);
    expect(writes.single['barangay_id'], 2);
    expect(auth.user?['barangay_name'], 'San Vicente');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-barangay')),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('San Vicente'), findsOneWidget);
  });

  testWidgets('list failure preserves the current barangay and can retry', (
    tester,
  ) async {
    listFails = true;
    await show(tester, editor: true);
    await save(tester);
    expect(writes.single.containsKey('barangay_id'), isFalse);
    expect(auth.user?['barangay_id'], 1);
    listFails = false;
    await tester.ensureVisible(find.text('Could not load barangays. Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Could not load barangays. Retry'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .initialValue,
      1,
    );
  });

  testWidgets('failed save keeps the existing account barangay', (
    tester,
  ) async {
    await show(tester, editor: true);
    await choose(tester, 'San Vicente');
    saveFails = true;
    await save(tester);
    expect(auth.user?['barangay_id'], 1);
    expect(find.text('Could not update profile.'), findsOneWidget);
  });

  testWidgets(
    'barangay selector and profile fit narrow screens with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, editor: true, scale: 2);
      await choose(tester, 'Barangay with a much longer descriptive name');
      await save(tester);
      expect(auth.user?['barangay_id'], 3);
      expect(tester.takeException(), isNull);
      await show(tester, scale: 2);
      expect(
        find.text('Barangay with a much longer descriptive name'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
