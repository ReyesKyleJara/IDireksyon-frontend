// Read-only API models. Conditions and qualifications are displayed, not evaluated.
String? _text(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
int? _integer(dynamic value) => value is int ? value : null;
List<T> _rows<T>(dynamic value, T Function(Map<String, dynamic>) parse) =>
    value is List
    ? value.whereType<Map<String, dynamic>>().map(parse).toList()
    : <T>[];

class GovernmentIdDetails {
  final int id;
  final String name;
  final String? issuedBy, description, purpose, validity, requirements;
  final String? eligibility,
      feeSummary,
      processingTime,
      applicationProcess,
      renewalProcess,
      replacementProcess;
  final List<GovernmentFee> fees;
  final List<GovernmentOffice> offices;
  final List<GuideScenario> guides;
  final Map<String, dynamic> eligibilityDetails;
  final List<RequirementSet> requirementSets;

  GovernmentIdDetails.fromJson(Map<String, dynamic> json)
    : id = _integer(json['id']) ?? (throw const FormatException('Missing ID')),
      name = _text(json['name']) ?? 'Government ID',
      issuedBy = _text(json['issued_by']),
      description = _text(json['description']),
      purpose = _text(json['purpose']),
      validity = json['validity_type'] == 'not_applicable'
          ? null
          : _text(json['validity']),
      requirements = _text(json['requirements']),
      requirementSets = _rows(
        json['requirement_sets'],
        RequirementSet.fromJson,
      ),
      eligibility = _text(json['eligibility']),
      feeSummary = _text(json['fee']),
      processingTime = _text(json['processing_time']),
      applicationProcess = _text(json['application_process']),
      renewalProcess = _text(json['renewal_process']),
      replacementProcess = _text(json['replacement_process']),
      fees = _rows(json['fees'], GovernmentFee.fromJson),
      offices = _rows(json['offices'], GovernmentOffice.fromJson),
      guides = _rows(json['application_guide'], GuideScenario.fromJson),
      eligibilityDetails = json['eligibility_details'] is Map<String, dynamic>
          ? json['eligibility_details']
          : <String, dynamic>{};
}

class RequirementSet {
  final int id;
  final String applicationType,
      applicantType,
      applicationLabel,
      applicantLabel,
      label;
  final int? minAge, maxAge;
  final List<RequirementGroup> groups;

  RequirementSet.fromJson(Map<String, dynamic> json)
    : id =
          _integer(json['id']) ??
          (throw const FormatException('Missing checklist ID')),
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
      condition = json['condition_type'] == 'always'
          ? null
          : _text(json['condition_label']),
      ways = _rows(json['ways'], RequirementWay.fromJson);

  String get displayName =>
      title ??
      (ways.length == 1 && ways.first.items.length == 1
          ? ways.first.items.first.name
          : 'Supporting requirement');
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
      qualification = json['qualification_type'] == 'none'
          ? null
          : _text(json['qualification_label']),
      items = _rows(json['items'], RequirementItem.fromJson);

  String get instruction {
    if (items.isEmpty) return 'Accepted items are not available yet.';
    if (items.length == 1 && requiredCount == 1) return 'Required';
    if (requiredCount == items.length) return 'Provide all listed items';
    final noun = items.every((item) => item.type == 'government_id')
        ? 'ID'
        : 'item';
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
      submissionLabel = json['submission_format'] == 'not_specified'
          ? null
          : _text(json['submission_label']),
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

class GovernmentFee {
  final int? id;
  final String label, type, currency;
  final String? notes;
  final double? min, max;
  final bool optional;
  GovernmentFee.fromJson(Map<String, dynamic> json)
    : id = _integer(json['id']),
      label = _text(json['label']) ?? 'Fee',
      type = _text(json['type']) ?? 'unknown',
      currency = _text(json['currency']) ?? 'PHP',
      notes = _text(json['notes']),
      optional = json['is_optional'] == true,
      min = double.tryParse('${json['amount_min']}'),
      max = double.tryParse('${json['amount_max']}');
  String money(double value) =>
      '${currency == 'PHP' ? '₱' : '$currency '}${value.toStringAsFixed(2)}';
  String get amount => switch (type) {
    'free' => 'Free',
    'fixed' when min != null => money(min!),
    'range' when min != null && max != null => '${money(min!)}–${money(max!)}',
    'varies' => 'Varies',
    _ => 'Amount unavailable',
  };
}

class GovernmentOffice {
  final int id;
  final String name;
  final String? address, municipality, province, status, notes;
  final double? latitude, longitude;
  final Map<String, dynamic> services;
  final List<OfficeDay> schedules;
  GovernmentOffice.fromJson(Map<String, dynamic> json)
    : id =
          _integer(json['id']) ??
          (throw const FormatException('Missing office ID')),
      name = _text(json['name']) ?? 'Office',
      address = _text(json['address']),
      municipality = _text(json['municipality']),
      province = _text(json['province']),
      status = _text(json['status']),
      notes = _text(json['notes']),
      latitude = double.tryParse('${json['latitude']}'),
      longitude = double.tryParse('${json['longitude']}'),
      services = json['services'] is Map<String, dynamic>
          ? json['services']
          : <String, dynamic>{},
      schedules = _rows(json['schedules'], OfficeDay.fromJson);
  String get fullAddress =>
      [address, municipality, province].whereType<String>().join(', ');
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;
}

class OfficeDay {
  final int day;
  final String status;
  final List<String> intervals;
  OfficeDay.fromJson(Map<String, dynamic> json)
    : day = _integer(json['day_of_week']) ?? -1,
      status = _text(json['status']) ?? 'unknown',
      intervals = _rows<String>(
        json['intervals'],
        (row) => '${row['opens_at']}–${row['closes_at']}',
      );
  String get label => day >= 0 && day <= 6
      ? [
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ][day]
      : 'Day';
  String get hours => status == 'closed'
      ? 'Closed'
      : status == 'open' && intervals.isNotEmpty
      ? intervals.join(', ')
      : 'Hours not confirmed';
}

class GuideScenario {
  final int id;
  final String label;
  final List<ApplicationStep> steps;
  GuideScenario.fromJson(Map<String, dynamic> json)
    : id =
          _integer(json['id']) ??
          (throw const FormatException('Missing guide scenario ID')),
      label = _text(json['display_label']) ?? 'Application',
      steps = _rows(json['steps'], ApplicationStep.fromJson);
}

class ApplicationStep {
  final int? id;
  final int? applicabilityProfileId;
  final String title;
  final String? instructions;
  final List<GuideBlock> blocks;
  String? get preview {
    if (instructions != null) return instructions;
    final text = blocks
        .map((block) => _guidePreview(block.content))
        .where((value) => value.isNotEmpty)
        .join(' ');
    return text.isEmpty ? null : text;
  }

  ApplicationStep.fromJson(Map<String, dynamic> json)
    : id = _integer(json['id']),
      applicabilityProfileId = _integer(json['applicability_profile_id']),
      title = _text(json['title']) ?? 'Application step',
      instructions = _text(json['short_description']),
      blocks = _rows(json['blocks'], GuideBlock.fromJson);
}

String _guidePreview(dynamic value) {
  if (value is String) return value;
  if (value is Map) {
    if (value['text'] is String) return value['text'];
    if (value['content'] is List) {
      return (value['content'] as List).map(_guidePreview).join(' ');
    }
    if (value['body'] != null) return _guidePreview(value['body']);
    if (value['items'] is List) {
      return (value['items'] as List).map(_guidePreview).join(' ');
    }
  }
  return '';
}

class GuideBlock {
  final int? id;
  final String type;
  final String? title;
  final Map<String, dynamic> content;
  GuideBlock.fromJson(Map<String, dynamic> json)
    : id = _integer(json['id']),
      type = _text(json['type']) ?? '',
      title = _text(json['section_title']),
      content = json['content'] is Map<String, dynamic>
          ? json['content']
          : <String, dynamic>{};
}
