import 'dart:convert';

import '../models/government_id_sequence.dart';

import '../models/government_id.dart';
import '../models/applicant_context.dart';
import '../models/government_id_applicability.dart';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static Future<dynamic> _get(String path, {http.Client? client}) async {
    final activeClient = client ?? http.Client();
    try {
      final response = await activeClient
          .get(
            Uri.parse('$baseUrl/$path'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Unable to load Government ID information.');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> || !body.containsKey('data')) {
        throw const FormatException('Invalid Government ID response');
      }
      return body['data'];
    } finally {
      if (client == null) activeClient.close();
    }
  }

  static Future<List<GovernmentIdDetails>> getGovernmentIds({
    http.Client? client,
  }) async {
    final data = await _get('government-ids', client: client);
    if (data is! List) throw const FormatException('Invalid ID directory');
    return data
        .map((row) => GovernmentIdDetails.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  static Future<GovernmentIdDetails> getGovernmentId(
    int id, {
    http.Client? client,
  }) async {
    final data = await _get('government-ids/$id', client: client);
    if (data is! Map<String, dynamic> || data['id'] != id) {
      throw const FormatException('Invalid ID detail');
    }
    final content = await _get('government-ids/$id/content', client: client);
    if (content is! Map<String, dynamic> || content['id'] != id) {
      throw const FormatException('Invalid ID content response');
    }
    return GovernmentIdDetails.fromJson({...data, ...content});
  }

  static Future<GovernmentIdApplicability> evaluateApplicant(
    int id,
    ApplicantContext context, {
    http.Client? client,
  }) async {
    final activeClient = client ?? http.Client();
    try {
      final response = await activeClient
          .post(
            Uri.parse('$baseUrl/government-ids/$id/applicability'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(context.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 422) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final errors = <String, List<String>>{};
        if (body is Map && body['errors'] is Map) {
          for (final entry in (body['errors'] as Map).entries) {
            if (entry.key is String && entry.value is List) {
              errors[entry.key] = (entry.value as List)
                  .whereType<String>()
                  .toList();
            }
          }
        }
        throw ApplicabilityRequestException(errors);
      }
      if (response.statusCode != 200) {
        throw const ApplicabilityRequestException();
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> ||
          body['data'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid applicability response');
      }
      final result = GovernmentIdApplicability.fromJson(body['data']);
      if (result.governmentId != id) {
        throw const FormatException('Mismatched applicability response');
      }
      return result;
    } finally {
      if (client == null) activeClient.close();
    }
  }

  static Future<GovernmentIdSequence> buildSequence(
    int id,
    ApplicantContext context,
    Map<int, int> selections, {
    http.Client? client,
  }) async {
    final activeClient = client ?? http.Client();
    try {
      final facts = context.toJson()..remove('selected_profile_id');
      final response = await activeClient
          .post(
            Uri.parse('$baseUrl/government-ids/$id/sequence'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              ...facts,
              'profile_selections': {
                for (final entry in selections.entries)
                  '${entry.key}': entry.value,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const FormatException('Unable to load roadmap');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final result = GovernmentIdSequence.fromJson(body['data']);
      if (result.governmentId != id) {
        throw const FormatException('Mismatched roadmap');
      }
      return result;
    } finally {
      if (client == null) activeClient.close();
    }
  }

  static Future<Map<String, dynamic>> checkHealth() async {
    final response = await http.get(
      Uri.parse('$baseUrl/health'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to connect to backend. Status: ${response.statusCode}',
      );
    }
  }
}
