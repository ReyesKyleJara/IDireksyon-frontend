import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/profile/account_details_screen.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';

void main() {
  testWidgets('directory button selects directory tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ResidentAppShell(initialIndex: 1),
      ),
    );
    await tester.ensureVisible(find.text('Open ID Directory'));
    await tester.tap(find.text('Open ID Directory'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      2,
    );
    expect(
      find.text('Browse supported government IDs and application guides'),
      findsOneWidget,
    );
  });

  testWidgets('account details save real data and display server errors', (
    tester,
  ) async {
    final original = AuthService.instance;
    addTearDown(() => AuthService.instance = original);
    var requests = 0;
    AuthService.instance =
        AuthService(
            client: MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer test');
              requests++;
              if (requests == 2) {
                return http.Response(
                  '{"message":"Email already in use."}',
                  422,
                );
              }
              expect(request.url.path, '/api/auth/account');
              return http.Response(
                jsonEncode({'user': jsonDecode(request.body)}),
                200,
              );
            }),
          )
          ..token = 'test'
          ..user = {'name': 'Resident', 'email': 'resident@example.com'};
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AccountDetailsScreen(),
      ),
    );
    expect(find.text('resident@example.com'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'New Name');
    await tester.ensureVisible(find.text('Save account details'));
    await tester.tap(find.text('Save account details'));
    await tester.pumpAndSettle();
    expect(AuthService.instance.user?['name'], 'New Name');
    expect(find.text('Account details updated.'), findsOneWidget);
    await tester.tap(find.text('Save account details'));
    await tester.pumpAndSettle();
    expect(find.text('Email already in use.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account form scrolls with large text and validates password', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const AccountDetailsScreen(),
      ),
    );
    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your current password'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
