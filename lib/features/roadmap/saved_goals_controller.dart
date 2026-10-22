import 'package:flutter/foundation.dart';

import '../../models/roadmap_goal.dart';
import '../../services/roadmap_goal_service.dart';

class SavedGoalsController extends ChangeNotifier {
  final RoadmapGoalService service;
  List<RoadmapGoal> goals = [];
  bool loading = false;
  String? error;
  int _request = 0;
  late int _session;
  bool _disposed = false;
  SavedGoalsController(this.service) {
    _session = service.auth.sessionGeneration;
    service.auth.addListener(_changed);
  }
  void _changed() {
    if (_session == service.auth.sessionGeneration) return;
    _session = service.auth.sessionGeneration;
    _request++;
    goals = [];
    error = null;
    loading = false;
    if (service.auth.token != null) {
      refresh();
    } else {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final request = ++_request;
    if (service.auth.token == null) {
      goals = [];
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final next = await service.list();
      if (!_disposed && request == _request) goals = next;
    } catch (_) {
      if (!_disposed && request == _request) {
        error = 'Could not load your saved roadmaps. Please try again.';
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> remove(int target) async {
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await service.remove(target);
      if (!_disposed && request == _request) await refresh();
    } catch (_) {
      if (!_disposed && request == _request) {
        loading = false;
        error = 'Could not remove this saved goal. Please try again.';
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    service.auth.removeListener(_changed);
    super.dispose();
  }
}
