/// Entered facts and explicit choices only. Applicability is evaluated by Laravel.
class ApplicantContext {
  final int? age;
  final String? applicationType;
  final List<int> ownedGovernmentIdIds, ownedDocumentIds;
  final int? selectedProfileId;

  ApplicantContext({
    this.age,
    this.applicationType,
    List<int> ownedGovernmentIdIds = const [],
    List<int> ownedDocumentIds = const [],
    this.selectedProfileId,
  }) : ownedGovernmentIdIds = List.unmodifiable(ownedGovernmentIdIds),
       ownedDocumentIds = List.unmodifiable(ownedDocumentIds);

  ApplicantContext withOwnership(
    List<int> governmentIds,
    List<int> documents,
  ) => ApplicantContext(
    age: age,
    applicationType: applicationType,
    selectedProfileId: selectedProfileId,
    ownedGovernmentIdIds: governmentIds,
    ownedDocumentIds: documents,
  );

  ApplicantContext selectProfile(int id) => ApplicantContext(
    age: age,
    applicationType: applicationType,
    ownedGovernmentIdIds: ownedGovernmentIdIds,
    ownedDocumentIds: ownedDocumentIds,
    selectedProfileId: id,
  );

  Map<String, Object> toJson() => {
    'age': ?age,
    if (applicationType != null && applicationType!.isNotEmpty)
      'application_type': applicationType!,
    if (ownedGovernmentIdIds.isNotEmpty)
      'owned_government_id_ids': ownedGovernmentIdIds,
    if (ownedDocumentIds.isNotEmpty) 'owned_document_ids': ownedDocumentIds,
    'selected_profile_id': ?selectedProfileId,
  };
}
