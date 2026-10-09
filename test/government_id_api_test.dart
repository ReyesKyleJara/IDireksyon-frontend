import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/services/api_service.dart';

void main() {
  test('loads the directory and requests the selected numeric ID', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(request.headers['Accept'], 'application/json');
      final record = {'id': 34, 'name': 'Passport', 'requirements': 'Bring the original'};
      return http.Response(jsonEncode({'data': request.url.path.endsWith('/34') ? record : [record]}), 200);
    });
    addTearDown(client.close);
    final directory = await ApiService.getGovernmentIds(client: client);
    final detail = await ApiService.getGovernmentId(directory.single.id, client: client);
    expect(paths, ['/api/government-ids', '/api/government-ids/34']);
    expect(detail.requirements, 'Bring the original');
  });

  test('rejects HTTP errors and invalid responses instead of showing empty research', () async {
    for (final response in [http.Response('{}', 404), http.Response('{}', 200), http.Response('not JSON', 200)]) {
      final client = MockClient((_) async => response);
      await expectLater(ApiService.getGovernmentId(34, client: client), throwsException);
      client.close();
    }
  });

  test('preserves UTF8 names and does not fetch referenced requirements separately', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response.bytes(utf8.encode(jsonEncode({'data': {
        'id': 34, 'name': 'Philippine Passport — Example', 'requirement_sets': [],
      }})), 200);
    });
    addTearDown(client.close);
    expect((await ApiService.getGovernmentId(34, client: client)).name, 'Philippine Passport — Example');
    expect(calls, 1);
  });
}
