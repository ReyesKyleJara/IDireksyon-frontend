import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';

Map<String, dynamic> planStep(
  int id,
  String name, {
  String type = 'government_id',
  bool selected = true,
  bool blocked = false,
  List<Map<String, dynamic>> prerequisites = const [],
  int satisfied = 0,
  int total = 0,
  int manual = 0,
}) => {
  'type': type,
  'id': id,
  'name': name,
  'blocked': blocked,
  'selected': selected,
  'issues': blocked
      ? ['This item is currently unavailable for acquisition.']
      : <String>[],
  'prerequisites': prerequisites,
  'prerequisite_readiness': {
    'satisfied': satisfied,
    'total': total,
    'manual': manual,
    'percentage': total == 0 ? null : (100 * satisfied / total).round(),
  },
};

Map<String, dynamic> planData(
  List<int> targets,
  List<Map<String, dynamic>> steps,
) => {
  'target_government_id_ids': targets,
  'blocked': steps.any((step) => step['blocked'] == true),
  'steps': steps,
};

AuthService journeyAuth({
  Map<int, String> names = const {
    55: 'Philippine Passport',
    56: 'PhilSys National ID',
  },
}) => AuthService(
  baseUrl: 'http://localhost:8000/api',
  client: MockClient((request) async {
    if (request.url.path.endsWith('/inventory')) {
      return http.Response(
        jsonEncode({
          'data': {'government_ids': [], 'documents': []},
        }),
        200,
      );
    }
    final targets = List<int>.from(
      jsonDecode(request.body)['target_government_id_ids'],
    );
    return http.Response(
      jsonEncode({
        'data': planData(
          targets,
          targets.map((id) => planStep(id, names[id] ?? 'Target $id')).toList(),
        ),
      }),
      200,
    );
  }),
)..token = 'resident-test-token';
