import 'package:flutter/foundation.dart';

/// Only explicit inventory ownership counts; catalog presence alone means nothing.
class ResidentInventory {
  final List<int> governmentIds, documentIds;
  ResidentInventory.fromJson(Map<String, dynamic> json)
    : governmentIds = _owned(json['government_ids']),
      documentIds = _owned(json['documents']);

  static List<int> _owned(Object? rows) {
    if (rows is! List) throw const FormatException('Invalid inventory');
    final owned = <int>{};
    final seen = <int>{};
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! int ||
          row['id'] <= 0 ||
          row['owned'] is! bool ||
          !seen.add(row['id'])) {
        throw const FormatException('Invalid inventory item');
      }
      if (row['owned'] == true) owned.add(row['id']);
    }
    return List.unmodifiable(owned.toList()..sort());
  }

  @override
  bool operator ==(Object other) =>
      other is ResidentInventory &&
      listEquals(governmentIds, other.governmentIds) &&
      listEquals(documentIds, other.documentIds);
  @override
  int get hashCode =>
      Object.hash(Object.hashAll(governmentIds), Object.hashAll(documentIds));
}

enum InventoryLoadState { idle, loading, loaded, unavailable }
