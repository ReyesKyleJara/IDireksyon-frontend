import '../../models/roadmap_plan.dart';

/// Account-backed journey snapshot; legacy unsaved journeys may have no ID.
class IdJourney {
  IdJourney({
    List<String> targetIds = const ['Passport ID'],
    List<int> targetCatalogIds = const [],
    List<int> targetDocumentIds = const [],
    List<String> ownedItems = const [],
    this.progress = 0,
    this.id,
    this.confirmedPlan,
    Set<String> completedStepIdentities = const {},
  }) : targetIds = List.unmodifiable(targetIds),
       targetCatalogIds = List.unmodifiable(targetCatalogIds),
       targetDocumentIds = List.unmodifiable(targetDocumentIds),
       ownedItems = List.unmodifiable(ownedItems),
       _completedStepIdentities = Set.unmodifiable(completedStepIdentities);

  final List<String> targetIds;
  final List<int> targetCatalogIds;
  final List<int> targetDocumentIds;
  final List<String> ownedItems;

  /// Reviewed steps, retained independently of later Inventory readiness.
  final RoadmapPlan? confirmedPlan;

  /// Explicit journey completion only. Confirmation and Inventory never add here.
  /// Restored from the account API; never inferred from Inventory.
  final int? id;
  Set<String> _completedStepIdentities;
  Set<String> get completedStepIdentities => _completedStepIdentities;

  factory IdJourney.fromJson(Map<String, dynamic> json) {
    try {
      final plan = RoadmapPlan.fromJson(
        Map<String, dynamic>.from(json['plan'] as Map),
      );
      final id = json['id'];
      if (id is! int || id <= 0) {
        throw const FormatException('Invalid saved journey');
      }
      final names = plan.steps
          .where(
            (step) =>
                step.type == 'government_id' &&
                    plan.targetIds.contains(step.id) ||
                step.type == 'document' &&
                    plan.targetDocumentIds.contains(step.id),
          )
          .map((step) => step.name)
          .toList();
      return IdJourney(
        id: id,
        targetIds: names,
        targetCatalogIds: plan.targetIds,
        targetDocumentIds: plan.targetDocumentIds,
        confirmedPlan: plan,
        completedStepIdentities: Set<String>.from(
          json['completed_step_identities'] as List,
        ),
      );
    } on Object {
      throw const FormatException('Invalid saved journey');
    }
  }

  void applyCompletion(IdJourney saved) {
    if (id == null || id != saved.id) {
      throw const FormatException('Journey identity changed');
    }
    _completedStepIdentities = Set.unmodifiable(saved.completedStepIdentities);
  }

  int get totalSteps =>
      confirmedPlan?.steps.where((step) => step.isActionable).length ??
      targetIds.length;
  int get completedSteps =>
      confirmedPlan?.steps
          .where(
            (step) =>
                step.isActionable &&
                completedStepIdentities.contains(step.identity),
          )
          .length ??
      0;
  double get completionProgress =>
      totalSteps == 0 ? 0 : completedSteps / totalSteps;
  String get completionLabel => '${(completionProgress * 100).round()}%';

  /// Readiness from 0 to 1; new journeys start with no completed steps.
  final double progress;
  double get readiness => progress.isFinite ? progress.clamp(0.0, 1.0) : 0;
  String get readinessLabel => '${(readiness * 100).round()}%';
  bool minimized = false;

  String get title => targetIds
      .map((id) => id == 'Passport ID' ? 'Philippine Passport' : id)
      .join(' + ');
}
