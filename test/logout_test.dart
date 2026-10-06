import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';

void main() {
  for (final offline in [false, true]) {
    testWidgets('logout clears session and navigation, offline: $offline', (
      tester,
    ) async {
      final original = AuthService.instance;
      addTearDown(() => AuthService.instance = original);
      var calls = 0;
      AuthService.instance =
          AuthService(
              client: MockClient((request) async {
                calls++;
                expect(request.url.path, '/api/auth/logout');
                expect(request.headers['Authorization'], 'Bearer test-token');
                if (offline) throw http.ClientException('offline');
                return http.Response('{"message":"Logged out."}', 200);
              }),
            )
            ..token = 'test-token'
            ..user = {'name': 'Resident'};
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          onGenerateRoute: AppRouter.generateRoute,
          home: const ResidentAppShell(initialIndex: 3),
        ),
      );
      await tester.ensureVisible(find.text('Log out'));
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(AuthService.instance.token, isNull);
      expect(AuthService.instance.user, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ResidentAppShell), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
