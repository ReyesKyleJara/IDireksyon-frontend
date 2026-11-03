import '../models/government_id.dart';
import 'requirement_readiness.dart';

/// Explicit, application-scoped selections. Never represents Inventory ownership.
/// Inherits group() so the existing best-OR-path rule remains shared.
class ApplicationPreparation extends RequirementReadiness {
  ApplicationPreparation(Iterable<int> itemIds)
    : preparedItems = Set.unmodifiable(itemIds);

  final Set<int> preparedItems;

  factory ApplicationPreparation.fromJson(Map<String, dynamic> data) {
    final rows = data['items'];
    if (rows is! List ||
        rows.any(
          (row) =>
              row is! Map ||
              row['item_id'] is! int ||
              (row['item_id'] as int) <= 0 ||
              row['prepared'] is! bool,
        )) {
      throw const FormatException('Invalid application preparation');
    }
    return ApplicationPreparation([
      for (final row in rows)
        if (row['prepared'] == true) row['item_id'] as int,
    ]);
  }

  ApplicationPreparation withItem(int id, bool prepared) =>
      ApplicationPreparation({
        ...preparedItems.where((item) => item != id),
        if (prepared) id,
      });

  @override
  bool owns(RequirementItem item) =>
      item.id != null && preparedItems.contains(item.id);

  @override
  double way(RequirementWay way) {
    if (way.requiredCount <= 0 || way.items.isEmpty) return 0;
    final matches = <(String, int?)>{
      for (final item in way.items)
        if (owns(item))
          (
            item.type,
            switch (item.type) {
              'government_id' => item.governmentIdId ?? item.id,
              'document' => item.documentId ?? item.id,
              _ => item.id,
            },
          ),
    };
    return (matches.length / way.requiredCount).clamp(0.0, 1.0);
  }
}

typedef PreparationSummary = ({
  int complete,
  int total,
  double completion,
  bool conditional,
});

PreparationSummary preparationSummary(
  RequirementSet set,
  ApplicationPreparation preparation,
) {
  final groups = set.groups
      .where((group) => group.conditionType == 'always')
      .toList();
  return (
    complete: groups.where((group) => preparation.group(group) == 1).length,
    total: groups.length,
    completion: groups.isEmpty
        ? 0
        : groups.fold<double>(
                0,
                (sum, group) => sum + preparation.group(group),
              ) /
              groups.length,
    conditional: groups.length != set.groups.length,
  );
}
