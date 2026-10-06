import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';

void main() {
  test('login submits credentials and retains the returned session', () async {
    final auth = AuthService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/login');
        expect(jsonDecode(request.body), {
          'identifier': 'juan@example.com',
          'password': 'password123',
        });
        return http.Response('{"token":"abc","user":{"id":1}}', 200);
      }),
    );
    await auth.login(' juan@example.com ', 'password123');
    expect(auth.token, 'abc');
    expect(auth.user?['id'], 1);
  });

  test('backend validation is shown without creating a session', () async {
    final auth = AuthService(
      client: MockClient(
        (_) async => http.Response(
          '{"errors":{"email":["The email has already been taken."]}}',
          422,
        ),
      ),
    );
    await expectLater(
      auth.login('juan@example.com', 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'The email has already been taken.',
        ),
      ),
    );
    expect(auth.token, isNull);
  });

  test('connection failures have a readable message', () async {
    final auth = AuthService(
      client: MockClient((_) async {
        throw http.ClientException('network failure');
      }),
    );
    await expectLater(
      auth.login('juan@example.com', 'password123'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Cannot connect'),
        ),
      ),
    );
  });
}
