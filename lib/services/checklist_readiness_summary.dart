import '../models/government_id.dart';
import 'requirement_readiness.dart';

typedef ChecklistReadinessSummary = ({
  double completion,
  bool ready,
  String status,
  String message,
});

/// Existing Directory presentation score, shared with the detail Overview.
/// Group/way completion and ownership matching remain in RequirementReadiness.
ChecklistReadinessSummary? summarizeChecklistReadiness(
  GovernmentIdDetails record,
  GovernmentIdDetails detail,
  RequirementReadiness inventory,
) {
  bool supported(GovernmentIdDetails value) =>
      !value.isInformational &&
      [
        'available',
        'limited_conditional',
      ].contains(value.applicationAvailability);
  if (!supported(record) ||
      !supported(detail) ||
      detail.guidanceMode != 'guided') {
    return null;
  }
  final hidden = detail.research['hidden_sections'];
  if (hidden is List && hidden.contains('requirements')) return null;

  // Do not pick an applicant scenario or request channel on the resident's
  // behalf. A single universal acquisition checklist is the safe small pool.
  final paths = detail.requestPaths;
  if (paths.length > 1) return null;
  final scoped = paths.isEmpty ? detail : detail.forPath(paths.single);
  final sets = scoped.requirementSets;
  if (sets.length != 1) return null;
  final set = sets.single;
  if (set.applicationType != 'new' ||
      set.applicantType != 'all' ||
      set.minAge != null ||
      set.maxAge != null) {
    return null;
  }
  final groups = set.groups.where((g) => g.conditionType == 'always').toList();
  if (groups.isEmpty) return null;

  bool linked(RequirementItem item) => switch (item.type) {
    'government_id' => (item.governmentIdId ?? 0) > 0,
    'document' => (item.documentId ?? 0) > 0,
    _ => false,
  };
  if (!groups.any(
    (g) => g.ways.any((w) => w.requiredCount > 0 && w.items.any(linked)),
  )) {
    return null;
  }
  var review =
      groups.length != set.groups.length ||
      record.applicationAvailability != 'available' ||
      detail.applicationAvailability != 'available';
  var completion = 0.0;
  var matched = 0;
  for (final group in groups) {
    // group() already handles best alternative, choose-N and duplicate refs.
    final value = inventory.group(group);
    completion += value;
    if (value == 1) matched++;
    if (group.ways.isEmpty ||
        group.ways.any(
          (way) =>
              way.requiredCount <= 0 ||
              way.requiredCount > way.items.length ||
              way.qualificationType != 'none' ||
              way.items.any(
                (item) =>
                    !linked(item) ||
                    item.copies != null ||
                    item.quantity != null ||
                    item.submissionFormat != 'not_specified' ||
                    item.instructions != null,
              ),
        )) {
      review = true;
    }
  }
  completion /= groups.length;
  final ready = matched == groups.length && !review;
  final status = ready
      ? 'Ready Now'
      : completion >= .5
      ? 'Almost Ready'
      : 'Needs Preparation';
  final message =
      '$matched of ${groups.length} checklist groups matched.'
      '${review ? ' Review other checks.' : ''}';
  return (
    completion: completion,
    ready: ready,
    status: status,
    message: message,
  );
}
