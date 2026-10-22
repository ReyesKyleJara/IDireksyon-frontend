import '../auth/auth_service.dart';
import '../../models/applicant_context.dart';
import '../../models/resident_inventory.dart';

/// One binding per flow; all bindings share AuthService's single in-flight load.
class InventoryBinding {
  final AuthService auth;
  final void Function(bool sessionChanged) changed;
  late int _generation;
  late InventoryLoadState _state;
  ResidentInventory? _snapshot;
  bool _hadSession = false;
  InventoryBinding(this.auth, this.changed) {
    _generation = auth.sessionGeneration;
    _state = auth.ownershipState;
    _snapshot = auth.ownership;
    _hadSession = auth.hadAuthenticatedSession;
    auth.addListener(_change);
  }
  bool get ready =>
      auth.token == null || auth.ownershipState == InventoryLoadState.loaded;
  bool get unavailable =>
      auth.token != null &&
      auth.ownershipState == InventoryLoadState.unavailable;
  Future<void> load({bool force = false}) => auth.loadOwnership(force: force);
  ApplicantContext apply(ApplicantContext facts) {
    if (auth.token != null && ready) {
      return facts.withOwnership(
        auth.ownership!.governmentIds,
        auth.ownership!.documentIds,
      );
    }
    // Standalone fixture ownership is allowed only until a real session takes over.
    return _hadSession ? facts.withOwnership([], []) : facts;
  }

  void _change() {
    final switched = _generation != auth.sessionGeneration;
    if (!switched &&
        _state == auth.ownershipState &&
        _snapshot == auth.ownership) {
      return;
    }
    _generation = auth.sessionGeneration;
    _state = auth.ownershipState;
    _snapshot = auth.ownership;
    _hadSession = _hadSession || auth.token != null;
    changed(switched);
  }

  void dispose() => auth.removeListener(_change);
}
