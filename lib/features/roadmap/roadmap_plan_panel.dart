import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../models/roadmap_plan.dart';
import '../ids/id_details_screen.dart';
import '../profile/manage_inventory_screen.dart';
import 'suggested_journey_view.dart';

/// Fresh Inventory-backed plan, shared by suggested and active journeys.
class RoadmapPlanPanel extends StatefulWidget {
  const RoadmapPlanPanel({
    super.key,
    required this.targetIds,
    this.targetDocumentIds = const [],
    this.onPlan,
    this.guidedPresentation = false,
  });
  final List<int> targetIds;
  final List<int> targetDocumentIds;
  final bool guidedPresentation;
  final ValueChanged<RoadmapPlan?>? onPlan;
  @override
  State<RoadmapPlanPanel> createState() => _RoadmapPlanPanelState();
}

class _RoadmapPlanPanelState extends State<RoadmapPlanPanel> {
  RoadmapPlan? _plan;
  String? _error;
  bool _loading = true;
  int _generation = 0;
  late final AuthService _auth = AuthService.instance;
  late int _revision;

  @override
  void initState() {
    super.initState();
    _revision = _auth.inventoryRevision;
    _auth.addListener(_inventoryChanged);
    Future.microtask(_reload);
  }

  void _inventoryChanged() {
    if (_revision == _auth.inventoryRevision) return;
    _revision = _auth.inventoryRevision;
    _reload();
  }

  @override
  void didUpdateWidget(covariant RoadmapPlanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.targetIds, widget.targetIds) ||
        !listEquals(oldWidget.targetDocumentIds, widget.targetDocumentIds)) {
      Future.microtask(_reload);
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_inventoryChanged);
    super.dispose();
  }

  Future<void> _reload({Map<String, dynamic>? resolution}) async {
    if (!mounted) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _plan = null;
    });
    widget.onPlan?.call(null);
    try {
      final plan = await _auth.roadmapPlan(
        widget.targetIds,
        documentTargets: widget.targetDocumentIds,
        resolution: resolution,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
      widget.onPlan?.call(plan);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error is AuthException
            ? error.message
            : widget.guidedPresentation
            ? 'Unable to load your roadmap.'
            : 'Unable to load the prerequisite plan.';
      });
    }
  }

  Future<void> _showOptions(RoadmapPlanStep step) async {
    final path = step.resolutionKind == 'path';
    final option = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(path ? 'Choose Request Path' : 'Suggested Options'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (step.suggestions.isEmpty)
                  const Text(
                    'No guided options are currently available. Review the requirement in the target’s guide or check with the issuing office.',
                  ),
                for (final option in step.suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (option['needs_review'] == true)
                          const Text(
                            'Confirm that this applicant path applies to you.',
                          ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, option),
                          child: Text(
                            path ? 'Use This Path' : 'Add to Journey',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (option == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          path ? 'Use ${option['name']}?' : 'Add ${option['name']} to Journey?',
        ),
        content: Text(
          path
              ? 'IDireksyon will use this requirement path and recalculate your roadmap.'
              : 'IDireksyon will add this before your target and recalculate your roadmap.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(path ? 'Use This Path' : 'Add to Journey'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _reload(
      resolution: {
        'key': step.resolutionKey,
        if (path)
          'set_id': option['set_id']
        else ...{
          'type': option['type'],
          'id': option['id'],
          'way_id': option['way_id'],
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_loading)
        Text(
          widget.guidedPresentation
              ? 'Preparing your next steps…'
              : 'Checking saved Inventory and prerequisites…',
        ),
      if (_error != null) ...[
        Text(_error!),
        TextButton(
          onPressed: _reload,
          child: Text(
            widget.guidedPresentation
                ? 'Try again'
                : 'Retry prerequisite check',
          ),
        ),
      ],
      if (_plan != null)
        if (widget.guidedPresentation)
          SuggestedJourneyView(plan: _plan!, onResolve: _showOptions)
        else
          RoadmapPlanView(plan: _plan!, onResolve: _showOptions),
      TextButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ManageInventoryScreen()),
          );
          if (mounted) await _reload();
        },
        child: const Text('Manage Inventory'),
      ),
    ],
  );
}

class RoadmapPlanView extends StatelessWidget {
  const RoadmapPlanView({super.key, required this.plan, this.onResolve});
  final RoadmapPlan plan;
  final ValueChanged<RoadmapPlanStep>? onResolve;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (plan.blocked)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Prerequisite path blocked. Review the notices below before proceeding.',
          ),
        ),
      for (var i = 0; i < plan.steps.length; i++)
        if (plan.steps[i].isUnresolved)
          JourneyResolutionCard(
            key: ValueKey(plan.steps[i].identity),
            step: plan.steps[i],
            onOptions: onResolve == null
                ? null
                : () => onResolve!(plan.steps[i]),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.steps[i].isInformational
                        ? 'Informational Record'
                        : 'STEP ${i + 1} • ${plan.steps[i].type == 'document' ? 'Document' : 'Government ID'}',
                  ),
                  Text(
                    plan.steps[i].name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!plan.steps[i].isInformational)
                    Text(
                      plan.steps[i].selected
                          ? 'Selected target'
                          : 'Required prerequisite — obtain first',
                    ),
                  for (final issue in plan.steps[i].issues)
                    Text('Blocked: $issue'),
                  const SizedBox(height: 8),
                  if (!plan.steps[i].isInformational)
                    Text(
                      'Prerequisite Readiness: ${plan.steps[i].readiness['satisfied']} of ${plan.steps[i].readiness['total']} verified'
                      '${plan.steps[i].readiness['percentage'] == null ? ' — no automatically verifiable prerequisites' : ' — ${plan.steps[i].readiness['percentage']}%'}',
                    ),
                  if (!plan.steps[i].isInformational)
                    for (final row in plan.steps[i].prerequisites)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${row['name']}: ${row['status'] == 'missing' && row['resolution'] == 'reference_only' ? 'Not in Inventory — reference prerequisite. ${row['message']}' : switch (row['status']) {
                                  'satisfied' => 'Already in Inventory',
                                  'missing' => 'Missing — must come first',
                                  _ => 'Needs manual confirmation',
                                }}${row['condition'] == null ? '' : '\nApplies when: ${row['condition']}'}',
                        ),
                      ),
                  if ([
                    'government_id',
                    'document',
                  ].contains(plan.steps[i].type))
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IdDetailsScreen(
                            governmentId: plan.steps[i].id,
                            recordType: plan.steps[i].type,
                            idName: plan.steps[i].name,
                          ),
                        ),
                      ),
                      child: Text(
                        plan.steps[i].isInformational
                            ? 'View information'
                            : 'Preview Guide',
                      ),
                    ),
                ],
              ),
            ),
          ),
    ],
  );
}
