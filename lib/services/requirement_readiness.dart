import '../models/government_id.dart';

/// Ownership progress only; does not verify expiry, copies or qualifications.
class RequirementReadiness {
  final Set<int> governmentIds;
  final Set<int> documents;

  RequirementReadiness({Iterable<int> governmentIds = const [],
    Iterable<int> documents = const []})
      : governmentIds = Set.unmodifiable(governmentIds),
        documents = Set.unmodifiable(documents);

  factory RequirementReadiness.fromInventory(Map<String, dynamic> data) {
    Set<int> owned(String key) {
      final rows = data[key];
      if (rows is! List || rows.any((row) => row is! Map ||
          row['id'] is! int || row['owned'] is! bool)) {
        throw const FormatException('Invalid inventory');
      }
      return {for (final row in rows)
        if (row['owned'] == true) row['id'] as int};
    }
    return RequirementReadiness(governmentIds: owned('government_ids'),
      documents: owned('documents'));
  }

  bool owns(RequirementItem item) => switch (item.type) {
    'government_id' => governmentIds.contains(item.governmentIdId),
    'document' => documents.contains(item.documentId),
    _ => false,
  };

  double way(RequirementWay way) {
    if (way.requiredCount <= 0 || way.items.isEmpty) return 0;
    // Duplicate references cannot turn one owned credential into two choices.
    final matches = <(String, int?)>{
      for (final item in way.items)
        if (owns(item)) (item.type,
          item.type == 'government_id' ? item.governmentIdId : item.documentId),
    };
    return (matches.length / way.requiredCount).clamp(0.0, 1.0);
  }

  double group(RequirementGroup group) => group.ways.fold<double>(0,
    (best, option) { final value = way(option); return value > best ? value : best; });
}
