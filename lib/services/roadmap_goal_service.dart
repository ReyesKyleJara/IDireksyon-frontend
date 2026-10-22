import 'dart:convert';

import '../core/auth/auth_service.dart';
import '../models/roadmap_goal.dart';

class RoadmapGoalService {
  final AuthService auth;
  RoadmapGoalService(this.auth);
  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool optional = false,
  }) async {
    final response = await auth.residentRequest(
      method,
      'roadmap-goals$path',
      body: body,
    );
    if (optional && response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AuthException(
        'Could not update your saved roadmaps. Please try again.',
      );
    }
    if (response.statusCode == 204) return null;
    return (jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>)['data'];
  }

  Future<List<RoadmapGoal>> list() async =>
      ((await _request('GET', '')) as List)
          .map((row) => RoadmapGoal.fromJson(row))
          .toList();
  Future<RoadmapGoal?> get(int target) async {
    final data = await _request('GET', '/$target', optional: true);
    return data == null ? null : RoadmapGoal.fromJson(data);
  }

  Future<RoadmapGoal> save(
    int target,
    String? applicationType,
    Map<int, int> selections,
  ) async => RoadmapGoal.fromJson(
    await _request(
      'PUT',
      '/$target',
      body: {
        'application_type': applicationType,
        'profile_selections': {
          for (final row in selections.entries) '${row.key}': row.value,
        },
      },
    ),
  );
  Future<void> remove(int target) async {
    await _request('DELETE', '/$target');
  }
}
