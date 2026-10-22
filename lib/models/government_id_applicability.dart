import 'government_id.dart';

enum ApplicabilityStatus {
  matched,
  multipleMatches,
  insufficientContext,
  manualConfirmationRequired,
  manualSelected,
  noMatch,
  unknown;

  static ApplicabilityStatus parse(Object? value) => switch (value) {
    'matched' => matched,
    'multiple_matches' => multipleMatches,
    'insufficient_context' => insufficientContext,
    'manual_confirmation_required' => manualConfirmationRequired,
    'manual_selected' => manualSelected,
    'no_match' => noMatch,
    _ => unknown,
  };
}

Map<String, dynamic> _map(Object? value) => value is Map<String, dynamic>
    ? value
    : throw const FormatException('Invalid applicability response');
List<T> _rows<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    value is List
    ? value.map((row) => parse(_map(row))).toList()
    : throw const FormatException('Invalid applicability list');

class ApplicantProfile {
  final int id;
  final String label;
  final String? applicationType;
  ApplicantProfile.fromJson(Map<String, dynamic> json)
    : id = json['id'] is int
          ? json['id']
          : throw const FormatException('Missing profile'),
      label = json['label'] is String ? json['label'] : 'Application option',
      applicationType = json['application_type'] is String
          ? json['application_type']
          : null;
}

class GovernmentIdApplicability {
  final int governmentId;
  final ApplicabilityStatus status;
  final List<String> missingContext;
  final List<ApplicantProfile> availableProfiles,
      matchedProfiles,
      manualProfiles;
  final ApplicantProfile? selectedProfile;
  final List<RequirementSet> requirements, pendingRequirements;
  final List<ApplicationStep> steps, pendingSteps;

  GovernmentIdApplicability.fromJson(Map<String, dynamic> json)
    : governmentId = _map(json['government_id'])['id'] is int
          ? _map(json['government_id'])['id']
          : throw const FormatException('Missing Government ID'),
      status = ApplicabilityStatus.parse(_map(json['applicability'])['status']),
      missingContext = (_map(json['applicability'])['missing_context'] as List)
          .cast<String>(),
      availableProfiles = _rows(
        _map(json['applicability'])['available_profiles'],
        ApplicantProfile.fromJson,
      ),
      matchedProfiles = _rows(
        _map(json['applicability'])['matched_profiles'],
        ApplicantProfile.fromJson,
      ),
      manualProfiles = _rows(
        _map(json['applicability'])['manual_profiles'],
        ApplicantProfile.fromJson,
      ),
      selectedProfile = _map(json['applicability'])['selected_profile'] == null
          ? null
          : ApplicantProfile.fromJson(
              _map(_map(json['applicability'])['selected_profile']),
            ),
      requirements = _rows(
        _map(json['requirements'])['profiles'],
        RequirementSet.fromJson,
      ),
      pendingRequirements = _rows(
        _map(json['requirements'])['pending_profiles'],
        RequirementSet.fromJson,
      ),
      steps = _rows(
        _map(json['application_guide'])['steps'],
        ApplicationStep.fromJson,
      ),
      pendingSteps = _rows(
        _map(json['application_guide'])['pending_steps'],
        ApplicationStep.fromJson,
      );
}

class ApplicabilityRequestException implements Exception {
  final Map<String, List<String>> validationErrors;
  const ApplicabilityRequestException([this.validationErrors = const {}]);
  String get message => validationErrors.isNotEmpty
      ? 'Please check your application details and try again.'
      : 'Could not update your application. Check your connection and try again.';
}
