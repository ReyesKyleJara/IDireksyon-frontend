import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/profile/account_details_screen.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';

void main() {
  testWidgets('saved account updates persistent Home and Profile without tab requests', (tester) async {
    final original = AuthService.instance;
    addTearDown(() => AuthService.instance = original);
    var accountRequests = 0;
    var directoryRequests = 0;
    AuthService.instance = AuthService(client: MockClient((request) async {
      accountRequests++;
      expect(request.url.path, '/api/auth/account');
      return http.Response(jsonEncode({'user': {
        'id': 1, ...jsonDecode(request.body) as Map<String, dynamic>,
      }}), 200);
    }))..token = 'test'
      ..user = {'id': 1, 'name': 'Kai', 'email': 'kai@example.com'};

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ResidentAppShell(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Kai'), findsOneWidget);

      for (final name in ['Kyle', 'Kai']) {
        await tester.tap(find.text('Profile').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Account Details'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, name);
        await tester.ensureVisible(find.text('Save account details'));
        await tester.tap(find.text('Save account details'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text, name);
        // Both headers must update even while covered by the account route.
        expect(find.text(name, skipOffstage: false), findsNWidgets(3));
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text(name), findsOneWidget);
        await tester.tap(find.text('Home').last);
        await tester.pumpAndSettle();
        expect(find.text(name), findsOneWidget);
      }
      expect(accountRequests, 2);
      expect(directoryRequests, 1);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      directoryRequests++;
      expect(request.url.path, '/api/government-ids');
      return http.Response('{"data":[]}', 200);
    }));
  });

  for (final offline in [false, true]) {
    testWidgets('directory button selects directory tab: offline=$offline', (tester) async {
      var requests = 0;
      await http.runWithClient(() async {
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
          tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex,
          2,
        );
        final directory = find.byType(IdsScreen);
        expect(directory, findsOneWidget);
        expect(find.descendant(of: directory, matching: find.text('ID Directory')), findsOneWidget);
        expect(find.descendant(of: directory, matching: find.byType(TextField)), findsOneWidget);
        if (offline) {
          expect(find.text('Could not load the ID directory.'), findsOneWidget);
          expect(find.text('Retry'), findsOneWidget);
        } else {
          expect(find.text('Directory test credential'), findsWidgets);
          expect(find.text('Could not load the ID directory.'), findsNothing);
        }
        expect(requests, 1);
        expect(tester.takeException(), isNull);
      }, () => MockClient((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.url.path, '/api/government-ids');
        return offline
            ? http.Response('Unavailable', 503)
            : http.Response(jsonEncode({'data': [
                {'id': 34, 'name': 'Directory test credential'},
              ]}), 200);
      }));
    });
  }

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
