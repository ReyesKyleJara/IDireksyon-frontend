import 'government_id_applicability.dart';

enum SequenceStatus {
  ready,
  insufficientContext,
  multipleMatches,
  manualConfirmationRequired,
  noMatch,
  configurationError;

  static SequenceStatus parse(String value) => switch (value) {
    'ready' => ready,
    'insufficient_context' => insufficientContext,
    'multiple_matches' => multipleMatches,
    'manual_confirmation_required' => manualConfirmationRequired,
    'no_match' => noMatch,
    'configuration_error' => configurationError,
    _ => throw const FormatException('Unsupported roadmap state'),
  };
}

class SequenceNode {
  final String type, name, status;
  final int id, depth;
  final int? order;
  final bool isTarget;
  SequenceNode.fromJson(Map<String, dynamic> json)
    : type = json['type'] as String,
      id = json['id'] as int,
      name = json['name'] as String,
      status = json['status'] as String,
      depth = json['depth'] as int,
      order = json['order'] as int?,
      isTarget = json['is_target'] as bool {
    if (!['government_id', 'document'].contains(type)) {
      throw const FormatException('Unsupported roadmap item');
    }
  }
}

class SequenceDecision {
  final int governmentId;
  final String name;
  final ApplicabilityStatus status;
  final List<String> missingContext;
  final List<ApplicantProfile> available, matched;
  SequenceDecision.fromJson(Map<String, dynamic> json)
    : governmentId = json['government_id']['id'] as int,
      name = json['government_id']['name'] as String,
      status = ApplicabilityStatus.parse(json['applicability']['status']),
      missingContext = List<String>.from(
        json['applicability']['missing_context'],
      ),
      available = (json['applicability']['available_profiles'] as List)
          .map((row) => ApplicantProfile.fromJson(row))
          .toList(),
      matched = (json['applicability']['matched_profiles'] as List)
          .map((row) => ApplicantProfile.fromJson(row))
          .toList();
  List<ApplicantProfile> get options =>
      status == ApplicabilityStatus.multipleMatches ? matched : available;
}

class GovernmentIdSequence {
  final int governmentId;
  final String name;
  final SequenceStatus status;
  final bool planIsComplete;
  final List<SequenceNode> plan, satisfied;
  final List<SequenceDecision> pending;
  final List<ApplicantProfile> rootProfiles;
  final List<String> missingContext;
  GovernmentIdSequence.fromJson(Map<String, dynamic> json)
    : governmentId = json['government_id']['id'] as int,
      name = json['government_id']['name'] as String,
      status = SequenceStatus.parse(json['status'] as String),
      planIsComplete = json['plan_is_complete'] as bool,
      plan = (json['plan'] as List)
          .map((row) => SequenceNode.fromJson(row))
          .toList(),
      satisfied = (json['satisfied'] as List)
          .map((row) => SequenceNode.fromJson(row))
          .toList(),
      pending = (json['pending_applicability'] as List)
          .map((row) => SequenceDecision.fromJson(row))
          .toList(),
      rootProfiles =
          ((json['applicability']?['available_profiles'] ?? []) as List)
              .map((row) => ApplicantProfile.fromJson(row))
              .toList(),
      missingContext = List<String>.from(json['missing_context']);
  bool get complete => status == SequenceStatus.ready && planIsComplete;
}
