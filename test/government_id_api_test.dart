import 'dart:convert';

import 'package:idireksyon_frontend/models/applicant_context.dart';
import 'package:idireksyon_frontend/models/government_id_applicability.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/services/api_service.dart';

void main() {
  test(
    'parses successful applicability responses and rejects another target ID',
    () async {
      for (final id in [34, 99]) {
        final client = MockClient((request) async {
          expect(jsonDecode(request.body), {});
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': {
                  'government_id': {'id': id},
                  'applicability': {
                    'status': 'matched',
                    'missing_context': [],
                    'available_profiles': [],
                    'matched_profiles': [],
                    'manual_profiles': [],
                    'selected_profile': {'id': 7, 'label': 'Agency — Choice'},
                  },
                  'requirements': {'profiles': [], 'pending_profiles': []},
                  'application_guide': {
                    'steps': [
                      {
                        'id': 8,
                        'title': 'Everyone instructions',
                        'applicability_profile_id': null,
                        'blocks': [],
                      },
                    ],
                    'pending_steps': [],
                  },
                },
              }),
            ),
            200,
          );
        });
        addTearDown(client.close);
        if (id == 34) {
          final result = await ApiService.evaluateApplicant(
            34,
            ApplicantContext(),
            client: client,
          );
          expect(result.status, ApplicabilityStatus.matched);
          expect(result.selectedProfile!.label, 'Agency — Choice');
          expect(result.steps.single.applicabilityProfileId, isNull);
        } else {
          await expectLater(
            ApiService.evaluateApplicant(
              34,
              ApplicantContext(),
              client: client,
            ),
            throwsFormatException,
          );
        }
      }
    },
  );

  test('posts only known applicant facts and handles validation and mismatched IDs', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/government-ids/34/applicability');
      expect(request.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(request.body), {'age': 18, 'selected_profile_id': 7});
      return http.Response(
        jsonEncode({
          'errors': {
            'age': ['Invalid age'],
          },
        }),
        422,
      );
    });
    addTearDown(client.close);
    await expectLater(
      ApiService.evaluateApplicant(
        34,
        ApplicantContext(age: 18, selectedProfileId: 7),
        client: client,
      ),
      throwsA(
        isA<ApplicabilityRequestException>().having(
          (error) => error.validationErrors['age'],
          'age errors',
          ['Invalid age'],
        ),
      ),
    );
    final invalid = MockClient((_) async => http.Response('{}', 503));
    addTearDown(invalid.close);
    await expectLater(
      ApiService.evaluateApplicant(34, ApplicantContext(), client: invalid),
      throwsA(isA<ApplicabilityRequestException>()),
    );
  });

  test('loads the directory and requests the selected numeric ID', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(request.headers['Accept'], 'application/json');
      final record = {
        'id': 34,
        'name': 'Passport',
        'requirements': 'Bring the original',
      };
      if (request.url.path.endsWith('/content')) {
        return http.Response(
          jsonEncode({
            'data': {'id': 34, 'offices': [], 'application_guide': []},
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'data': request.url.path.endsWith('/34') ? record : [record],
        }),
        200,
      );
    });
    addTearDown(client.close);
    final directory = await ApiService.getGovernmentIds(client: client);
    final detail = await ApiService.getGovernmentId(
      directory.single.id,
      client: client,
    );
    expect(paths, [
      '/api/government-ids',
      '/api/government-ids/34',
      '/api/government-ids/34/content',
    ]);
    expect(detail.requirements, 'Bring the original');
  });

  test('rejects HTTP errors and invalid responses instead of showing empty research', () async {
    for (final response in [
      http.Response('{}', 404),
      http.Response('{}', 200),
      http.Response('not JSON', 200),
    ]) {
      final client = MockClient((_) async => response);
      await expectLater(
        ApiService.getGovernmentId(34, client: client),
        throwsException,
      );
      client.close();
    }
  });

  test('preserves UTF8 names and does not fetch referenced requirements separately', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'data': {
              'id': 34,
              'name': 'Philippine Passport — Example',
              'requirement_sets': [],
            },
          }),
        ),
        200,
      );
    });
    addTearDown(client.close);
    expect(
      (await ApiService.getGovernmentId(34, client: client)).name,
      'Philippine Passport — Example',
    );
    expect(calls, 2);
  });
  test('rejects failed or mismatched supplementary content rather than showing fake empty sections', () async {
    for (final fail in [true, false]) {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/content')) {
          return fail
              ? http.Response('{}', 503)
              : http.Response(
                  jsonEncode({
                    'data': {'id': 99},
                  }),
                  200,
                );
        }
        return http.Response(
          jsonEncode({
            'data': {'id': 34, 'name': 'Real record'},
          }),
          200,
        );
      });
      await expectLater(
        ApiService.getGovernmentId(34, client: client),
        throwsException,
      );
      client.close();
    }
  });
}
