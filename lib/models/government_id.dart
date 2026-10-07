// Read-only API models. Conditions and qualifications are displayed, not evaluated.
String? _text(dynamic value) => value is String && value.trim().isNotEmpty ? value.trim() : null;
int? _integer(dynamic value) => value is int ? value : null;
List<T> _rows<T>(dynamic value, T Function(Map<String, dynamic>) parse) =>
    value is List ? value.whereType<Map<String, dynamic>>().map(parse).toList() : <T>[];

class GovernmentIdDetails {
  final int id;
  final String name;
  final String? issuedBy, description, purpose, validity, requirements;
  final List<RequirementSet> requirementSets;

  GovernmentIdDetails.fromJson(Map<String, dynamic> json)
      : id = _integer(json['id']) ?? (throw const FormatException('Missing ID')),
        name = _text(json['name']) ?? 'Government ID',
        issuedBy = _text(json['issued_by']),
        description = _text(json['description']),
        purpose = _text(json['purpose']),
        validity = json['validity_type'] == 'not_applicable' ? null : _text(json['validity']),
        requirements = _text(json['requirements']),
        requirementSets = _rows(json['requirement_sets'], RequirementSet.fromJson);
}

class RequirementSet {
  final int id;
  final String applicationType, applicantType, applicationLabel, applicantLabel, label;
  final int? minAge, maxAge;
  final List<RequirementGroup> groups;

  RequirementSet.fromJson(Map<String, dynamic> json)
      : id = _integer(json['id']) ?? (throw const FormatException('Missing checklist ID')),
        applicationType = _text(json['application_type']) ?? '',
        applicantType = _text(json['applicant_type']) ?? '',
        applicationLabel = _text(json['application_type_label']) ?? 'Application',
        applicantLabel = _text(json['applicant_type_label']) ?? 'Applicant',
        label = _text(json['display_label']) ?? 'Application requirements',
        minAge = _integer(json['min_age']),
        maxAge = _integer(json['max_age']),
        groups = _rows(json['groups'], RequirementGroup.fromJson);
}

class RequirementGroup {
  final int? id;
  final String? title, condition;
  final String conditionType;
  final List<RequirementWay> ways;

  RequirementGroup.fromJson(Map<String, dynamic> json)
      : id = _integer(json['id']),
        title = _text(json['title']),
        conditionType = _text(json['condition_type']) ?? 'always',
        condition = json['condition_type'] == 'always' ? null : _text(json['condition_label']),
        ways = _rows(json['ways'], RequirementWay.fromJson);

  String get displayName => title ??
      (ways.length == 1 && ways.first.items.length == 1
          ? ways.first.items.first.name : 'Supporting requirement');
}

class RequirementWay {
  final int? id;
  final int requiredCount;
  final String qualificationType, qualificationScope;
  final String? qualification;
  final List<RequirementItem> items;

  RequirementWay.fromJson(Map<String, dynamic> json)
      : id = _integer(json['id']),
        requiredCount = _integer(json['required_count']) ?? 1,
        qualificationType = _text(json['qualification_type']) ?? 'none',
        qualificationScope = _text(json['qualification_scope']) ?? 'every',
        qualification = json['qualification_type'] == 'none' ? null : _text(json['qualification_label']),
        items = _rows(json['items'], RequirementItem.fromJson);

  String get instruction {
    if (items.isEmpty) return 'Accepted items are not available yet.';
    if (items.length == 1 && requiredCount == 1) return 'Required';
    if (requiredCount == items.length) return 'Provide all listed items';
    final noun = items.every((item) => item.type == 'government_id') ? 'ID' : 'item';
    final label = requiredCount == 1 ? noun : '${noun}s';
    return 'Choose $requiredCount accepted $label';
  }
}

class RequirementItem {
  final int? id, governmentIdId, documentId, copies, quantity;
  final String type, name, submissionFormat;
  final String? submissionLabel, instructions;

  RequirementItem.fromJson(Map<String, dynamic> json)
      : id = _integer(json['id']),
        governmentIdId = _integer(json['government_id_id']),
        documentId = _integer(json['document_id']),
        type = _text(json['type']) ?? 'custom',
        name = _text(json['name']) ?? 'Supporting item',
        submissionFormat = _text(json['submission_format']) ?? 'not_specified',
        submissionLabel = json['submission_format'] == 'not_specified' ? null : _text(json['submission_label']),
        copies = _integer(json['copies']),
        quantity = _integer(json['quantity']),
        instructions = _text(json['instructions']);

  String? get submission {
    if (submissionFormat == 'original_photocopy' && copies != null) {
      return 'Original + $copies ${copies == 1 ? 'photocopy' : 'photocopies'}';
    }
    final parts = <String>[
      ?submissionLabel,
      if (copies != null) '$copies ${copies == 1 ? 'copy' : 'copies'}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
