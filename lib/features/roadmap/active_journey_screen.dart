import 'package:flutter/material.dart';

import '../../core/widgets/page_header.dart';
import '../loading/loading_screen.dart';
import 'active_journey_view.dart';
import '../../core/auth/auth_service.dart';
import '../../models/roadmap_plan.dart';
import '../shell/resident_app_shell.dart';
import 'build_roadmap_screen.dart';
import 'id_journey.dart';
import 'roadmap_plan_panel.dart';
import 'roadmap_widgets.dart';
import 'suggested_options_dialog.dart';

class JourneyLoadingScreen extends StatelessWidget {
  const JourneyLoadingScreen({
    super.key,
    this.journey,
    this.existingJourneys = const [],
  });
  final IdJourney? journey;
  final List<IdJourney> existingJourneys;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: LoadingScreen(
      onComplete: (context) {
        for (final existing in existingJourneys) {
          existing.minimized = true;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ResidentAppShell(
              initialIndex: 1,
              journeys: [...existingJourneys, journey ?? IdJourney()],
            ),
          ),
          (_) => false,
        );
      },
    ),
  );
}

class ActiveJourneyScreen extends StatefulWidget {
  const ActiveJourneyScreen({
    super.key,
    this.journeys = const [],
    this.initialJourney,
    this.onJourneyChanged,
  });
  final List<IdJourney> journeys;
  final IdJourney? initialJourney;
  final VoidCallback? onJourneyChanged;

  @override
  State<ActiveJourneyScreen> createState() => _ActiveJourneyScreenState();
}

class _ActiveJourneyScreenState extends State<ActiveJourneyScreen> {
  late final List<IdJourney> _journeys = widget.journeys.isEmpty
      ? [IdJourney()]
      : widget.journeys;
  late IdJourney _openJourney =
      widget.initialJourney != null && _journeys.contains(widget.initialJourney)
      ? widget.initialJourney!
      : _journeys.lastWhere(
          (journey) => !journey.minimized,
          orElse: () => _journeys.last,
        );

  late bool _showCompleted =
      widget.initialJourney?.isCompleted ??
      _journeys.every((journey) => journey.isCompleted);

  bool _saving = false;
  String? _savingStep;
  bool _confirming = false;

  List<IdJourney> get _inProgress =>
      _journeys.where((journey) => !journey.isCompleted).toList();

  /// Finished journeys, the most recently finished first.
  List<IdJourney> get _completed =>
      _journeys.where((journey) => journey.isCompleted).toList()..sort((a, b) {
        final first = a.completedAt, second = b.completedAt;
        return first != null && second != null
            ? second.compareTo(first)
            : (b.id ?? 0).compareTo(a.id ?? 0);
      });

  /// Shows a journey in its new tab right after its last step is finished.
  void _applySaved(IdJourney journey, IdJourney saved) {
    final finishedNow = !journey.isCompleted;
    setState(() {
      journey.applyCompletion(saved);
      if (finishedNow && journey.isCompleted) {
        _showCompleted = true;
        _openJourney = journey;
      }
    });
  }

  Future<void> _complete(IdJourney journey, RoadmapPlanStep step) async {
    if (_saving || _confirming || journey.id == null) return;
    _confirming = true;
    final session = AuthService.instance.token;
    final waiting = waitingOnSteps(
      step,
      journey.confirmedPlan?.steps ?? const [],
      journey.completedStepIdentities,
    );
    final outOfOrder = waiting.isEmpty
        ? ''
        : 'The suggested order is to finish ${waiting.map((item) => item.name).join(', ')} first. If this already happened, you can still record it.\n\n';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          step.needsConfirmation ? 'Confirm ${step.name}?' : 'Complete ${step.name}?',
        ),
        content: Text(
          step.needsConfirmation
              ? '$outOfOrder${step.message} This is saved to this Roadmap only. It does not change your Inventory or checklist, and it is not an official verification.'
              : '${outOfOrder}Mark this journey step as completed? This updates your journey progress only and does not add anything to Inventory. It does not confirm that an agency accepted or issued anything.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark as Completed'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (confirmed != true ||
        !mounted ||
        _saving ||
        AuthService.instance.token != session) {
      return;
    }
    setState(() {
      _saving = true;
      _savingStep = step.identity;
    });
    try {
      final saved = IdJourney.fromJson(
        await AuthService.instance.completeJourneyStep(
          journey.id!,
          step.identity,
          acknowledgeOrder: waiting.isNotEmpty,
        ),
      );
      if (!mounted) return;
      _applySaved(journey, saved);
      widget.onJourneyChanged?.call();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to read saved progress. Please reload your journeys.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _savingStep = null;
        });
      }
    }
  }

  Future<void> _resolve(IdJourney journey, RoadmapPlanStep requested) async {
    if (_saving || _confirming || journey.id == null) return;
    _confirming = true;
    final auth = AuthService.instance;
    final session = auth.token;
    try {
      // Review the current account-owned choice, including legacy snapshots
      // and choices that another device may already have resolved.
      final rows = await auth.getJourneys();
      final row = rows.where((item) => item['id'] == journey.id).firstOrNull;
      if (row == null) {
        throw const AuthException('Please reload your journeys.');
      }
      if (!mounted || auth.token != session) return;
      setState(() => journey.applyCompletion(IdJourney.fromJson(row)));
      final plan = journey.confirmedPlan;
      final step = plan?.steps
          .where((item) => item.identity == requested.identity)
          .firstOrNull;
      if (step == null || step.isManualPreparation || plan == null) return;
      if (!mounted || auth.token != session) return;
      final resolution = await showSuggestedRoadmapOptions(
        context,
        plan: plan,
        step: step,
      );
      if (resolution == null || !mounted || auth.token != session) return;
      setState(() {
        _saving = true;
        _savingStep = step.identity;
      });
      final saved = IdJourney.fromJson(
        await auth.resolveJourneyStep(journey.id!, resolution),
      );
      if (!mounted || auth.token != session) return;
      _applySaved(journey, saved);
      widget.onJourneyChanged?.call();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to read the updated journey. Please reload your journeys.',
            ),
          ),
        );
      }
    } finally {
      _confirming = false;
      if (mounted) {
        setState(() {
          _saving = false;
          _savingStep = null;
        });
      }
    }
  }

  /// Saves one resident action and keeps earlier state if it fails.
  Future<void> _save(
    IdJourney journey,
    Future<Map<String, dynamic>> Function() request,
  ) async {
    if (_saving || _confirming) return;
    setState(() => _saving = true);
    try {
      final saved = IdJourney.fromJson(await request());
      if (!mounted) return;
      setState(() => journey.applyCompletion(saved));
      widget.onJourneyChanged?.call();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to read your Roadmap. Please reload it.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _ask(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _undo(IdJourney journey, RoadmapPlanStep step) async {
    if (!await _ask(
          'Undo ${step.name}?',
          'This step will be marked as not completed. Your Inventory and checklist will not change.',
          'Undo',
        ) ||
        !mounted) {
      return;
    }
    await _save(
      journey,
      () => AuthService.instance.undoJourneyStep(journey.id!, step.identity),
    );
  }

  Future<void> _changeChoice(
    IdJourney journey,
    Map<String, dynamic> choice,
  ) async {
    if (!await confirmChangeChoice(context) || !mounted) return;
    await _save(
      journey,
      () => AuthService.instance.resolveJourneyStep(journey.id!, {
        'key': choice['key'],
        'reset': true,
      }),
    );
  }

  Future<void> _refresh(IdJourney journey) async {
    if (!await _ask(
          'Review updated Roadmap?',
          'Your steps will use your current Inventory and the latest listed requirements. Steps you already completed stay saved.',
          'Update Roadmap',
        ) ||
        !mounted) {
      return;
    }
    await _save(
      journey,
      () => AuthService.instance.refreshJourney(journey.id!),
    );
  }

  Future<void> _remove(IdJourney journey) async {
    if (_saving || _confirming) return;
    if (!await _ask(
          'Remove this Roadmap?',
          'This permanently removes ${journey.title}, its progress and its saved choices. Your Inventory and application checklists stay the same.',
          'Remove',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService.instance.removeJourney(journey.id!);
      if (!mounted) return;
      setState(() => _journeys.remove(journey));
      widget.onJourneyChanged?.call();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _open(IdJourney journey) => setState(() {
    _openJourney = journey;
    for (final item in _journeys) {
      item.minimized = item != journey;
    }
  });

  @override
  Widget build(BuildContext context) {
    final inProgress = _inProgress;
    final completed = _completed;
    final shown = _showCompleted ? completed : inProgress;
    // The log opens collapsed; In Progress always has one journey open.
    final open = shown.contains(_openJourney)
        ? _openJourney
        : _showCompleted
        ? null
        : inProgress.lastOrNull;
    final ordered = _showCompleted || open == null
        ? shown
        : [open, ...shown.where((item) => item != open)];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          const PageHeader('My ID Journey'),
          const SizedBox(height: 6),
          Text(
            'Track your progress and get to the IDs you need.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          const RoadmapSuggestionNotice(),
          const SizedBox(height: 16),
          JourneyStatusTabs(
            showCompleted: _showCompleted,
            inProgress: inProgress.length,
            completed: completed.length,
            onChanged: (value) => setState(() => _showCompleted = value),
          ),
          const SizedBox(height: 20),
          if (shown.isEmpty) ...[
            JourneyLogEmpty(
              title: _showCompleted
                  ? 'No completed journeys yet'
                  : 'No journeys in progress',
              message: _showCompleted
                  ? 'Journeys you finish will be saved here.'
                  : 'Start a new journey whenever you need another ID or document.',
            ),
            const SizedBox(height: 18),
          ],
          for (final journey in ordered) ...[
            if (_showCompleted && journey.completedDateLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Completed ${journey.completedDateLabel}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (journey.confirmedPlan != null ||
                (journey.targetCatalogIds.isEmpty &&
                    journey.targetDocumentIds.isEmpty))
              ActiveJourneyView(
                key: ObjectKey(journey),
                title: journey.title,
                steps: journey.confirmedPlan?.steps ?? const [],
                fallbackTitles: journey.targetIds,
                completedStepIdentities: journey.completedStepIdentities,
                expanded: journey == open,
                onOpen: () => _open(journey),
                onResolve: journey.id == null
                    ? null
                    : (step) => _resolve(journey, step),
                saving: _saving,
                savingStep: _savingStep,
                onComplete: journey.id == null
                    ? null
                    : (step) => _complete(journey, step),
                onUndo: journey.id == null
                    ? null
                    : (step) => _undo(journey, step),
                savedChoices: journey.confirmedPlan?.savedChoices ?? const [],
                onChangeChoice: journey.id == null
                    ? null
                    : (choice) => _changeChoice(journey, choice),
                onRefresh: journey.id == null
                    ? null
                    : () => _refresh(journey),
                onRemove: journey.id == null ? null : () => _remove(journey),
              )
            else if (journey == open)
              RoadmapPlanPanel(
                key: ObjectKey(journey),
                targetIds: journey.targetCatalogIds,
                targetDocumentIds: journey.targetDocumentIds,
                activeJourneyTitle: journey.title,
                completedStepIdentities: journey.completedStepIdentities,
              )
            else
              TextButton.icon(
                onPressed: () => _open(journey),
                icon: const Icon(Icons.alt_route_rounded, size: 18),
                label: Text(journey.title),
              ),
            const SizedBox(height: 18),
          ],
          if (!_showCompleted)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        BuildRoadmapScreen(existingJourneys: _journeys),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add another ID journey'),
              ),
            ),
        ],
      ),
    );
  }
}
