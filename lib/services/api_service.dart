import 'dart:convert';
import '../models/government_id.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api',
  );

  static Future<dynamic> _get(String path, {http.Client? client}) async {
    final activeClient = client ?? http.Client();
    try {
      final response = await activeClient.get(
        Uri.parse('$baseUrl/$path'), headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));
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

  static Future<List<GovernmentIdDetails>> getGovernmentIds({http.Client? client}) async {
    final data = await _get('government-ids', client: client);
    if (data is! List) throw const FormatException('Invalid ID directory');
    return data.map((row) => GovernmentIdDetails.fromJson(row as Map<String, dynamic>)).toList();
  }

  static Future<GovernmentIdDetails> getGovernmentId(int id, {http.Client? client}) async {
    final data = await _get('government-ids/$id', client: client);
    if (data is! Map<String, dynamic>) throw const FormatException('Invalid ID detail');
    return GovernmentIdDetails.fromJson(data);
  }

  static Future<Map<String, dynamic>> checkHealth() async {
    final response = await http.get(
      Uri.parse('$baseUrl/health'),
      headers: {
        'Accept': 'application/json',
      },
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