/// Journey state retained while navigating within the current app session.
class IdJourney {
  IdJourney({
    List<String> targetIds = const ['Passport ID'],
    List<String> ownedItems = const [],
    this.progress = 0,
  }) : targetIds = List.unmodifiable(targetIds),
       ownedItems = List.unmodifiable(ownedItems);

  final List<String> targetIds;
  final List<String> ownedItems;

  /// Readiness from 0 to 1; new journeys start with no completed steps.
  final double progress;
  double get readiness => progress.isFinite ? progress.clamp(0.0, 1.0) : 0;
  String get readinessLabel => '${(readiness * 100).round()}%';
  bool minimized = false;

  String get title => targetIds
      .map((id) => id == 'Passport ID' ? 'Philippine Passport' : id)
      .join(' + ');
}
