class RoadmapGoal {
  final int governmentId;
  final String name;
  final String? applicationType;
  final Map<int, int> selections;
  final bool discardedSelections, completed;
  RoadmapGoal.fromJson(Map<String, dynamic> json)
    : governmentId = json['government_id']['id'] as int,
      name = json['government_id']['name'] as String,
      applicationType = json['application_type'] as String?,
      selections = Map.unmodifiable(
        (json['profile_selections'] as Map).map(
          (key, value) => MapEntry(int.parse(key as String), value as int),
        ),
      ),
      discardedSelections = json['discarded_profile_selections'] as bool,
      completed = json['is_completed'] as bool;
}
