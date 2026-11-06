/// The catalog's short durations only; longer text is a research note, not a time.
String? displayProcessingTime(String? text) {
  final value = text?.trim() ?? '';
  return value.isEmpty || value.length > 40 ? null : value;
}

class RoadmapPlan {
  RoadmapPlan.fromJson(Map<String, dynamic> json)
    : targetIds = List<int>.from(json['target_government_id_ids'] as List),
      targetDocumentIds = List<int>.from(
        json['target_document_ids'] as List? ?? const [],
      ),
      steps = (json['steps'] as List)
          .map(
            (row) => RoadmapPlanStep.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList() {
    if (steps.isEmpty ||
        steps.map((step) => step.identity).toSet().length != steps.length ||
        targetDocumentIds.any(
          (id) =>
              !steps.any((step) => step.type == 'document' && step.id == id),
        ) ||
        targetIds.any(
          (id) => !steps.any(
            (step) => step.type == 'government_id' && step.id == id,
          ),
        )) {
      throw const FormatException('Invalid roadmap plan');
    }
  }

  final List<int> targetIds;
  final List<int> targetDocumentIds;
  final List<RoadmapPlanStep> steps;
  bool get blocked => steps.any((step) => step.blocked);
}

class RoadmapPlanStep {
  RoadmapPlanStep.fromJson(Map<String, dynamic> json)
    : type = json['type'] as String,
      id = json['id'] as int,
      name = json['name'] as String,
      processingTime = displayProcessingTime(json['processing_time'] as String?),
      ownerKey = json['owner_key'] as String?,
      resolutionKey = json['resolution_key'] as String?,
      resolutionKind = json['kind'] as String?,
      message = json['message'] as String?,
      suggestions = (json['suggestions'] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      guidanceMode = json['guidance_mode'] as String? ?? 'guided',
      alreadyOwned = json['already_owned'] == true,
      blocked = json['blocked'] as bool,
      selected = json['selected'] as bool,
      issues = List<String>.from(json['issues'] as List),
      prerequisites = (json['prerequisites'] as List)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
      readiness = Map<String, dynamic>.from(
        json['prerequisite_readiness'] as Map,
      ) {
    if (![
          'government_id',
          'document',
          'unresolved_requirement',
        ].contains(type) ||
        id <= 0 ||
        (isUnresolved &&
            (resolutionKey == null ||
                !['path', 'requirement'].contains(resolutionKind) ||
                message == null ||
                suggestions.any(
                  (option) =>
                      option['name'] is! String ||
                      (resolutionKind == 'path'
                          ? option['set_id'] is! int
                          : ![
                                  'government_id',
                                  'document',
                                ].contains(option['type']) ||
                                option['id'] is! int),
                ))) ||
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

  final String type, name, guidanceMode;
  final String? resolutionKey, resolutionKind, message, processingTime, ownerKey;
  final List<Map<String, dynamic>> suggestions;
  bool get isUnresolved => type == 'unresolved_requirement';
  String get identity => isUnresolved ? resolutionKey! : '$type:$id';
  bool get isInformational => guidanceMode == 'informational_only';
  bool get isActionable =>
      !isUnresolved && !isInformational && !blocked && !alreadyOwned;
  final int id;
  final bool blocked, selected, alreadyOwned;
  final List<String> issues;
  final List<Map<String, dynamic>> prerequisites;
  final Map<String, dynamic> readiness;
}

/// Actionable steps this step still depends on, matching the server's completion
/// rule. Steps that do not depend on each other can finish in any order.
List<RoadmapPlanStep> waitingOnSteps(
  RoadmapPlanStep step,
  List<RoadmapPlanStep> steps,
  Set<String> completed,
) {
  final waiting = <RoadmapPlanStep>[];
  for (final row in step.prerequisites) {
    if (row['status'] != 'missing' ||
        row['resolution'] == 'reference_only' ||
        !['government_id', 'document'].contains(row['type'])) {
      continue;
    }
    final identity = '${row['type']}:${row['id']}';
    if (completed.contains(identity)) continue;
    waiting.addAll(
      steps.where((item) => item.isActionable && item.identity == identity),
    );
  }
  return waiting;
}
