import '../models/government_id.dart';
import 'checklist_readiness_summary.dart';
import 'requirement_readiness.dart';

/// "Suggested for You" selection shared by the ID Directory and Home.
/// Moved unchanged out of the Directory screen, so both show the same picks.

bool isSupportedRecord(GovernmentIdDetails record) =>
    !record.isInformational &&
    [
      'available',
      'limited_conditional',
    ].contains(record.applicationAvailability);

/// Small editorial pool, resolved against real catalog records. Records the
/// resident already owns are skipped.
List<GovernmentIdDetails> suggestionCandidates(
  List<GovernmentIdDetails> records,
  RequirementReadiness? inventory,
) {
  final result = <GovernmentIdDetails>[];
  // Editorial names locate real catalog records; numeric IDs come from APIs.
  const choices = [
    ('government_id', ['philsys national id', 'national id']),
    ('government_id', ['philippine passport', 'passport']),
    ('document', ['nbi clearance']),
    ('document', ['national police clearance']),
  ];
  for (final (type, names) in choices) {
    final record = records
        .where(
          (r) =>
              r.recordType == type &&
              names.contains(r.name.trim().toLowerCase()) &&
              isSupportedRecord(r) &&
              r.guidanceMode == 'guided',
        )
        .firstOrNull;
    if (record == null) continue;
    final owned = type == 'document'
        ? inventory?.documents
        : inventory?.governmentIds;
    if (owned?.contains(record.id) == true) continue;
    result.add(record);
  }
  return result;
}

/// Presentation summary of the same group/way inventory completion used in
/// RequirementsTab. This never infers applicability or evaluates eligibility.
ChecklistReadinessSummary? suggestionReadiness(
  GovernmentIdDetails record,
  GovernmentIdDetails? detail,
  RequirementReadiness? inventory,
) {
  if (inventory == null ||
      detail == null ||
      !isSupportedRecord(record) ||
      !isSupportedRecord(detail) ||
      detail.guidanceMode != 'guided') {
    return null;
  }
  final owned = record.recordType == 'document'
      ? inventory.documents
      : inventory.governmentIds;
  if (owned.contains(record.id)) return null;
  return summarizeChecklistReadiness(record, detail, inventory);
}

/// Records with a readiness summary, most complete first, then by name.
List<GovernmentIdDetails> rankedSuggestions(
  Iterable<GovernmentIdDetails> records,
  ChecklistReadinessSummary? Function(GovernmentIdDetails) readiness,
) => records.where((r) => readiness(r) != null).toList()
  ..sort((a, b) {
    final score = readiness(b)!.completion.compareTo(readiness(a)!.completion);
    return score == 0 ? a.name.compareTo(b.name) : score;
  });
