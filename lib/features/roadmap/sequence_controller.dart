import '../../models/roadmap_goal.dart';
import '../../services/roadmap_goal_service.dart';
import '../../core/auth/auth_service.dart';
import '../../core/inventory/inventory_binding.dart';

import 'package:flutter/foundation.dart';

import '../../models/applicant_context.dart';
import '../../models/government_id_sequence.dart';

typedef BuildSequence = Future<GovernmentIdSequence> Function(
  int id,
  ApplicantContext context,
  Map<int, int> selections,
);

class SequenceController extends ChangeNotifier {
  final int governmentId;
  final BuildSequence evaluate;
  ApplicantContext context;
  final Map<int, int> _selections = {};
  Map<int, int> get selections => Map.unmodifiable(_selections);
  GovernmentIdSequence? result;
  bool loading = false, editing = false;
  late String draftAge;
  String? draftApplicationType;
  int editorRevision = 0;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  late final RoadmapGoalService goals;
  RoadmapGoal? savedGoal;
  bool goalLoading = false, saving = false, goalDirty = false;
  bool savedChoicesChanged = false;
  String? saveError;
  int _goalRequest = 0;
  bool _restoredGoalContext = false;
  bool _initialized = false,
      _restoreFailed = false,
      _recoveringSelections = false;
  late final InventoryBinding _inventory;
  int? _ownershipWait;
  bool get ownershipReady => _inventory.ready;
  bool get ownershipUnavailable => _inventory.unavailable;
  Future<void> retryOwnership() => _inventory.load(force: true);

  void _ownershipChanged(bool sessionChanged) {
    if (_disposed) return;
    if (_ownershipWait == _generation && !sessionChanged) {
      notifyListeners();
      return;
    }
    _generation++;
    _ownershipWait = null;
    loading = false;
    result = null;
    error = null;
    context = _inventory.apply(context);
    if (sessionChanged) {
      if (_restoredGoalContext) {
        context = ApplicantContext();
        draftAge = '';
        draftApplicationType = null;
        editorRevision++;
        _restoredGoalContext = false;
      }
      _selections.clear();
      _goalRequest++;
      savedGoal = null;
      saveError = null;
      goalLoading = false;
      saving = false;
      goalDirty = false;
      savedChoicesChanged = false;
      _restoreFailed = false;
      if (_initialized && goals.auth.token != null) _findExistingGoal();
    }
    if (_inventory.ready || !_inventory.unavailable) {
      refresh();
    } else {
      notifyListeners();
    }
  }

  SequenceController(
    this.governmentId,
    this.context,
    this.evaluate, {
    AuthService? auth,
    RoadmapGoalService? goalService,
  }) {
    goals = goalService ?? RoadmapGoalService(auth ?? AuthService.instance);
    _inventory = InventoryBinding(goals.auth, _ownershipChanged);
    draftAge = context.age?.toString() ?? '';
    draftApplicationType = context.applicationType;
    if (context.selectedProfileId != null) {
      _selections[governmentId] = context.selectedProfileId!;
    }
  }
  bool get stale => result != null && (loading || error != null);
  bool get restoreFailed => _restoreFailed;
  Future<void> initialize({bool restoreSaved = false}) async {
    _initialized = true;
    if (restoreSaved) {
      await openSavedGoal();
      return;
    }
    final lookup = _findExistingGoal();
    await refresh();
    await lookup;
  }

  Future<void> _findExistingGoal() async {
    if (goals.auth.token == null) return;
    final request = ++_goalRequest;
    goalLoading = true;
    notifyListeners();
    try {
      final goal = await goals.get(governmentId);
      if (!_disposed && request == _goalRequest) {
        savedGoal = goal;
        goalDirty =
            goal != null &&
            (goal.applicationType != context.applicationType ||
                !mapEquals(goal.selections, selections));
      }
    } catch (_) {
      if (!_disposed && request == _goalRequest) {
        saveError = 'Could not check your saved goal. Saving will retry.';
      }
    } finally {
      if (!_disposed && request == _goalRequest) {
        goalLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> openSavedGoal() async {
    final request = ++_goalRequest;
    goalLoading = true;
    saveError = null;
    notifyListeners();
    var restored = false;
    try {
      final goal = await goals.get(governmentId);
      if (_disposed || request != _goalRequest) return;
      if (goal == null) throw const FormatException('Saved goal unavailable');
      savedGoal = goal;
      goalDirty = false;
      _restoredGoalContext = true;
      context = ApplicantContext(
        age: context.age,
        applicationType: goal.applicationType,
        ownedGovernmentIdIds: context.ownedGovernmentIdIds,
        ownedDocumentIds: context.ownedDocumentIds,
      );
      _selections
        ..clear()
        ..addAll(goal.selections);
      savedChoicesChanged = goal.discardedSelections;
      draftAge = context.age?.toString() ?? '';
      draftApplicationType = context.applicationType;
      editorRevision++;
      _restoreFailed = false;
      restored = true;
    } catch (_) {
      if (!_disposed && request == _goalRequest) {
        _restoreFailed = true;
        saveError = 'Could not open your saved goal. Please try again.';
      }
    } finally {
      if (!_disposed && request == _goalRequest) {
        goalLoading = false;
        notifyListeners();
      }
    }
    if (restored && !_disposed) await refresh(refreshInventory: true);
  }

  Future<bool> saveGoal({bool recalculate = true}) async {
    if (saving) return false;
    final request = ++_goalRequest;
    saving = true;
    saveError = null;
    notifyListeners();
    var changed = false, saved = false;
    try {
      final next = await goals.save(
        governmentId,
        context.applicationType,
        selections,
      );
      if (_disposed || request != _goalRequest) return false;
      changed = !mapEquals(selections, next.selections);
      savedGoal = next;
      _selections
        ..clear()
        ..addAll(next.selections);
      savedChoicesChanged = next.discardedSelections;
      goalDirty = false;
      saved = true;
    } catch (_) {
      if (!_disposed && request == _goalRequest) {
        saveError = 'Could not save your roadmap. Your current roadmap is still available. Please try again.';
      }
    } finally {
      if (!_disposed && request == _goalRequest) {
        saving = false;
        notifyListeners();
      }
    }
    if (saved && changed && recalculate) await refresh();
    return saved;
  }

  Future<void> refresh({bool refreshInventory = false}) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (!_inventory.ready || refreshInventory) {
        _ownershipWait = generation;
        await _inventory.load(force: refreshInventory);
        if (_ownershipWait == generation) _ownershipWait = null;
        if (_disposed || generation != _generation || !_inventory.ready) return;
      }
      context = _inventory.apply(context);
      final submitted = context;
      final next = await evaluate(governmentId, submitted, selections);
      if (_disposed || generation != _generation) return;
      if (next.governmentId != governmentId) {
        throw const FormatException('Mismatched roadmap');
      }
      result = next;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      if (savedGoal != null && !_recoveringSelections) {
        try {
          final latest = await goals.get(governmentId);
          if (_disposed || generation != _generation) return;
          if (latest != null && !mapEquals(selections, latest.selections)) {
            savedGoal = latest;
            _selections
              ..clear()
              ..addAll(latest.selections);
            savedChoicesChanged = true;
            _recoveringSelections = true;
            try {
              await refresh();
            } finally {
              _recoveringSelections = false;
            }
            return;
          }
        } catch (_) {
          /* Keep the previous result and safe retry state. */
        }
      }
      error =
          'Could not update your roadmap. Check your connection and try again.';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> choose(int id, int profile) async {
    _selections[id] = profile;
    savedChoicesChanged = false;
    if (savedGoal != null) {
      goalDirty = true;
      await saveGoal(recalculate: false);
    }
    await refresh();
  }

  void change() {
    draftAge = context.age?.toString() ?? '';
    draftApplicationType = context.applicationType;
    editing = !editing;
    editorRevision++;
    notifyListeners();
  }

  Future<void> submitFacts() async {
    final age = draftAge.trim().isEmpty ? null : int.tryParse(draftAge.trim());
    if (draftAge.trim().isNotEmpty && (age == null || age < 0 || age > 65535)) {
      error = 'Enter your age as a whole number.';
      notifyListeners();
      return;
    }
    editing = false;
    await updateFacts(age, draftApplicationType);
  }

  Future<void> updateFacts(int? age, String? applicationType) async {
    if (age != null && (age < 0 || age > 65535)) {
      error = 'Enter your age as a whole number.';
      notifyListeners();
      return;
    }
    context = ApplicantContext(
      age: age,
      applicationType: applicationType,
      ownedGovernmentIdIds: context.ownedGovernmentIdIds,
      ownedDocumentIds: context.ownedDocumentIds,
    );
    _selections.clear();
    if (savedGoal != null) {
      goalDirty = true;
      await saveGoal(recalculate: false);
    }
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _inventory.dispose();
    _generation++;
    _goalRequest++;
    super.dispose();
  }
}
