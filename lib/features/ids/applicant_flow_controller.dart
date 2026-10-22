import '../../core/auth/auth_service.dart';
import '../../core/inventory/inventory_binding.dart';

import 'package:flutter/foundation.dart';

import '../../models/applicant_context.dart';
import '../../models/government_id_applicability.dart';

typedef EvaluateApplicant = Future<GovernmentIdApplicability> Function(
  int id,
  ApplicantContext context,
);

/// One screen-session owner for both tabs. No profile rules or persistent cache.
class ApplicantFlowController extends ChangeNotifier {
  final int governmentId;
  final EvaluateApplicant evaluate;
  ApplicantContext context;
  ApplicantContext? successfulContext;
  GovernmentIdApplicability? result;
  bool loading = false, editing = false;
  String? error;
  String draftAge = '';
  String? draftApplicationType;
  int editorRevision = 0;
  int _request = 0;
  bool _disposed = false;
  late final InventoryBinding _inventory;
  int? _ownershipWait;
  bool get ownershipReady => _inventory.ready;
  bool get ownershipUnavailable => _inventory.unavailable;
  Future<void> retryOwnership() => _inventory.load(force: true);

  void _ownershipChanged(bool sessionChanged) {
    if (_disposed) return;
    if (_ownershipWait == _request && !sessionChanged) {
      notifyListeners();
      return;
    }
    _request++;
    _ownershipWait = null;
    loading = false;
    result = null;
    error = null;
    context = _inventory.apply(context);
    successfulContext = null;
    if (_inventory.ready || !_inventory.unavailable) {
      refresh();
    } else {
      notifyListeners();
    }
  }

  ApplicantFlowController(
    this.governmentId,
    this.evaluate, {
    AuthService? auth,
    ApplicantContext? initialContext,
  }) : context = initialContext ?? ApplicantContext() {
    draftAge = context.age?.toString() ?? '';
    draftApplicationType = context.applicationType;
    _inventory = InventoryBinding(
      auth ?? AuthService.instance,
      _ownershipChanged,
    );
  }
  bool get stale => result != null && (loading || error != null);

  Future<void> refresh() async {
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (!_inventory.ready) {
        _ownershipWait = request;
        await _inventory.load();
        if (_ownershipWait == request) _ownershipWait = null;
        if (_disposed || request != _request || !_inventory.ready) return;
      }
      context = _inventory.apply(context);
      final submitted = context;
      final next = await evaluate(governmentId, submitted);
      if (_disposed || request != _request) return;
      if (next.governmentId != governmentId ||
          next.status == ApplicabilityStatus.unknown) {
        throw const FormatException('Unsupported applicability response');
      }
      result = next;
      successfulContext = submitted;
      editing = false;
    } catch (failure) {
      if (_disposed || request != _request) return;
      error = failure is ApplicabilityRequestException ? failure.message : 'Could not update your application. Check your connection and try again.';
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void change() {
    draftAge = context.age?.toString() ?? '';
    draftApplicationType = context.applicationType;
    editing = true;
    editorRevision++;
    notifyListeners();
  }

  void cancelEdit() {
    editing = false;
    notifyListeners();
  }

  Future<void> submitFacts() async {
    final age = draftAge.trim().isEmpty ? null : int.tryParse(draftAge.trim());
    if (draftAge.trim().isNotEmpty && (age == null || age < 0 || age > 65535)) {
      error = 'Enter your age as a whole number.';
      notifyListeners();
      return;
    }
    // Fact edits clear an earlier manual choice; the backend must resolve again.
    context = ApplicantContext(
      age: age,
      applicationType: draftApplicationType,
      ownedGovernmentIdIds: context.ownedGovernmentIdIds,
      ownedDocumentIds: context.ownedDocumentIds,
    );
    await refresh();
  }

  Future<void> choose(int id) async {
    context = context.selectProfile(id);
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _inventory.dispose();
    _request++;
    super.dispose();
  }
}
