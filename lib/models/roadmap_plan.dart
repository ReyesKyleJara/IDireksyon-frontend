class RoadmapPlan {
  RoadmapPlan.fromJson(Map<String, dynamic> json)
    : targetIds = List<int>.from(json['target_government_id_ids'] as List),
      steps = (json['steps'] as List)
          .map(
            (row) => RoadmapPlanStep.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList() {
    if (steps.isEmpty ||
        steps.map((step) => (step.type, step.id)).toSet().length !=
            steps.length ||
        targetIds.any(
          (id) => !steps.any(
            (step) => step.type == 'government_id' && step.id == id,
          ),
        )) {
      throw const FormatException('Invalid roadmap plan');
    }
  }

  final List<int> targetIds;
  final List<RoadmapPlanStep> steps;
  bool get blocked => steps.any((step) => step.blocked);
}

class RoadmapPlanStep {
  RoadmapPlanStep.fromJson(Map<String, dynamic> json)
    : type = json['type'] as String,
      id = json['id'] as int,
      name = json['name'] as String,
      blocked = json['blocked'] as bool,
      selected = json['selected'] as bool,
      issues = List<String>.from(json['issues'] as List),
      prerequisites = (json['prerequisites'] as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
      readiness = Map<String, dynamic>.from(
        json['prerequisite_readiness'] as Map,
      ) {
    if (!['government_id', 'document'].contains(type) ||
        id <= 0 ||
        prerequisites.any(
          (row) => !['satisfied', 'missing', 'manual'].contains(row['status']),
        ) ||
        readiness['satisfied'] is! int ||
        readiness['total'] is! int ||
        readiness['manual'] is! int ||
        (readiness['percentage'] != null && readiness['percentage'] is! int)) {
      throw const FormatException('Invalid roadmap step');
    }
  }

  final String type, name;
  final int id;
  final bool blocked, selected;
  final List<String> issues;
  final List<Map<String, dynamic>> prerequisites;
  final Map<String, dynamic> readiness;
}
