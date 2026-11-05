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

  bool _saving = false;
  bool _confirming = false;

  Future<void> _complete(IdJourney journey, RoadmapPlanStep step) async {
    if (_saving || _confirming || journey.id == null) return;
    _confirming = true;
    final session = AuthService.instance.token;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Complete ${step.name}?'),
        content: const Text(
          'Mark this journey step as completed? This updates your journey progress only and does not add anything to Inventory.',
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
    setState(() => _saving = true);
    try {
      final saved = IdJourney.fromJson(
        await AuthService.instance.completeJourneyStep(
          journey.id!,
          step.identity,
        ),
      );
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
            content: Text(
              'Unable to read saved progress. Please reload your journeys.',
            ),
          ),
        );
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
  Widget build(BuildContext context) => SafeArea(
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
        const SizedBox(height: 20),
        for (final journey in [
          _openJourney,
          ..._journeys.where((item) => item != _openJourney),
        ]) ...[
          if (journey.confirmedPlan != null ||
              (journey.targetCatalogIds.isEmpty &&
                  journey.targetDocumentIds.isEmpty))
            ActiveJourneyView(
              key: ObjectKey(journey),
              title: journey.title,
              steps: journey.confirmedPlan?.steps ?? const [],
              fallbackTitles: journey.targetIds,
              completedStepIdentities: journey.completedStepIdentities,
              expanded: journey == _openJourney,
              onOpen: () => _open(journey),
              saving: _saving,
              onComplete: journey.id == null
                  ? null
                  : (step) => _complete(journey, step),
            )
          else if (journey == _openJourney)
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BuildRoadmapScreen(existingJourneys: _journeys),
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
