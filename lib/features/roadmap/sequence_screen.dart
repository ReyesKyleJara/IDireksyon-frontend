import '../../services/roadmap_goal_service.dart';
import '../ids/inventory_context_notice.dart';

import 'package:flutter/material.dart';

import '../../models/applicant_context.dart';
import '../../models/government_id_sequence.dart';
import '../../services/api_service.dart';
import '../ids/id_details_screen.dart';
import 'sequence_controller.dart';

class SequenceScreen extends StatefulWidget {
  final int governmentId;
  final String targetName;
  final ApplicantContext applicantContext;
  final BuildSequence? evaluate;
  final bool restoreSaved;
  final RoadmapGoalService? goalService;
  final ValueChanged<ApplicantContext>? onContextChanged;
  const SequenceScreen({
    super.key,
    required this.governmentId,
    required this.targetName,
    required this.applicantContext,
    this.evaluate,
    this.restoreSaved = false,
    this.goalService,
    this.onContextChanged,
  });
  @override
  State<SequenceScreen> createState() => _SequenceScreenState();
}

class _SequenceScreenState extends State<SequenceScreen> {
  late final SequenceController flow;
  @override
  void initState() {
    super.initState();
    flow = SequenceController(
      widget.governmentId,
      widget.applicantContext,
      widget.evaluate ?? ApiService.buildSequence,
      goalService: widget.goalService,
    );
    flow.initialize(restoreSaved: widget.restoreSaved);
  }

  @override
  void dispose() {
    flow.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final previous = flow.context;
    await flow.submitFacts();
    if (!identical(previous, flow.context)) {
      widget.onContextChanged?.call(flow.context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your Roadmap')),
    body: AnimatedBuilder(
      animation: flow,
      builder: (context, _) {
        if (flow.goalLoading && widget.restoreSaved && flow.result == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (flow.restoreFailed) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(flow.saveError ?? 'Could not open your saved goal.'),
              TextButton(
                onPressed: flow.openSavedGoal,
                child: const Text('Retry saved goal'),
              ),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Back'),
              ),
            ],
          );
        }
        if (!flow.ownershipReady) {
          return ListView(
            children: [
              InventoryContextNotice(
                unavailable: flow.ownershipUnavailable,
                retry: flow.retryOwnership,
              ),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Back to Requirements and Application Guide'),
              ),
            ],
          );
        }
        final result = flow.result;
        final missing = result?.missingContext ?? <String>[];
        final askAge =
            missing.contains('age') ||
            (flow.editing && flow.context.age != null);
        final types = <String>{
          if (flow.context.applicationType != null)
            flow.context.applicationType!,
          for (final profile in result?.rootProfiles ?? [])
            if (profile.applicationType != null) profile.applicationType!,
          for (final decision in result?.pending ?? <SequenceDecision>[])
            for (final option in decision.available)
              if (option.applicationType != null) option.applicationType!,
        };
        final askType =
            missing.contains('application_type') ||
            (flow.editing && types.isNotEmpty);
        const labels = {
          'new': 'New application',
          'renewal': 'Renewal',
          'replacement': 'Replacement',
          'custom': 'Other application',
        };
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Target: ${result?.name ?? widget.targetName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (flow.savedGoal != null)
              Text(flow.goalDirty ? 'Changes not saved' : 'Goal saved'),
            if (flow.saveError != null) Text(flow.saveError!),
            if (flow.savedChoicesChanged)
              const Text(
                'Some saved application choices changed. Please confirm your situation again.',
              ),
            FilledButton.icon(
              icon: const Icon(Icons.bookmark_outline),
              label: Text(
                flow.goals.auth.token == null
                    ? 'Sign in to save'
                    : flow.saving
                    ? 'Saving…'
                    : flow.savedGoal == null
                    ? 'Save Goal'
                    : 'Update Saved Goal',
              ),
              onPressed: flow.loading || flow.saving || flow.goalLoading
                  ? null
                  : () {
                      if (flow.goals.auth.token == null) {
                        Navigator.pushNamed(context, '/login');
                      } else {
                        flow.saveGoal();
                      }
                    },
            ),
            if (result?.complete == true &&
                result!.satisfied.any((node) => node.isTarget))
              const Text(
                'Goal completed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            TextButton(
              onPressed: flow.loading || flow.saving || flow.goalLoading
                  ? null
                  : flow.change,
              child: const Text('Change application details'),
            ),
            if (flow.loading) const LinearProgressIndicator(),
            if (flow.stale)
              const Text(
                'Showing your previous roadmap. It has not been freshly updated.',
              ),
            if (flow.error != null) ...[
              Text(flow.error!),
              TextButton(
                onPressed: flow.loading ? null : flow.refresh,
                child: const Text('Retry'),
              ),
            ],
            if (result?.status == SequenceStatus.configurationError) ...[
              const Text("We couldn't build this roadmap right now."),
              TextButton(
                onPressed: flow.loading ? null : flow.refresh,
                child: const Text('Retry'),
              ),
            ] else ...[
              if (result?.status == SequenceStatus.noMatch)
                const Text(
                  'Your application information does not match a configured roadmap. You can change your application details or return to the ID guide.',
                ),
              if (askAge)
                TextFormField(
                  key: ValueKey(flow.editorRevision),
                  initialValue: flow.draftAge,
                  onChanged: (value) => flow.draftAge = value,
                  keyboardType: TextInputType.number,
                  enabled: !flow.loading,
                  decoration: const InputDecoration(labelText: 'Your age'),
                ),
              if (askType)
                DropdownButtonFormField<String>(
                  initialValue: types.contains(flow.draftApplicationType)
                      ? flow.draftApplicationType
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'What type of application is this?',
                  ),
                  items: [
                    for (final type in types)
                      DropdownMenuItem(
                        value: type,
                        child: Text(labels[type] ?? 'Application option'),
                      ),
                  ],
                  onChanged: flow.loading
                      ? null
                      : (value) => flow.draftApplicationType = value,
                ),
              if (askAge || askType)
                FilledButton(
                  onPressed: flow.loading || flow.saving || flow.goalLoading
                      ? null
                      : submit,
                  child: const Text('Update application'),
                ),
              for (final decision
                  in result?.pending ?? <SequenceDecision>[]) ...[
                Text('We need one more detail for ${decision.name}'),
                if (decision.options.isNotEmpty) ...[
                  const Text(
                    'Choose the option that best matches your application',
                  ),
                  for (final option in decision.options)
                    OutlinedButton(
                      onPressed: flow.loading || flow.saving || flow.goalLoading
                          ? null
                          : () => flow.choose(decision.governmentId, option.id),
                      child: Text(option.label),
                    ),
                ],
              ],
              if (result != null &&
                  !result.complete &&
                  result.status != SequenceStatus.noMatch)
                const Text(
                  'This roadmap is not complete yet. Confirm the details above to continue.',
                ),
              if (result != null &&
                  result.status != SequenceStatus.noMatch) ...[
                if (result.satisfied.isNotEmpty) ...[
                  const Text(
                    'Already Have',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final node in result.satisfied)
                    _node(node, satisfied: true),
                ],
                if (result.complete &&
                    result.plan.length == 1 &&
                    result.plan.single.isTarget &&
                    result.satisfied.isEmpty)
                  Text(
                    "You don't need another configured ID or document before starting this application. Next: Prepare the requirements for ${result.name}.",
                  ),
                Text(
                  result.complete ? 'Your Steps' : 'Steps confirmed so far',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final node in result.plan) _node(node),
                if (result.complete && result.plan.isEmpty)
                  const Text('Your target is already available.'),
              ],
            ],
            TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Back to Requirements and Application Guide'),
            ),
          ],
        );
      },
    ),
  );

  Widget _node(SequenceNode node, {bool satisfied = false}) => Card(
    child: ListTile(
      leading: satisfied
          ? const Icon(Icons.check_circle_outline)
          : Text('${node.order ?? ''}'),
      title: Text(node.name),
      subtitle: Text(
        satisfied
            ? 'Already available'
            : node.isTarget
            ? 'Your target'
            : 'Get this first',
      ),
      trailing: node.type == 'government_id'
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: node.type != 'government_id'
          ? null
          : () {
              if (node.isTarget) {
                Navigator.maybePop(context);
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => IdDetailsScreen(
                    idName: node.name,
                    governmentId: node.id,
                    initialApplicantContext: ApplicantContext(
                      age: flow.context.age,
                      applicationType: flow.context.applicationType,
                      ownedGovernmentIdIds: flow.context.ownedGovernmentIdIds,
                      ownedDocumentIds: flow.context.ownedDocumentIds,
                    ),
                  ),
                ),
              );
            },
    ),
  );
}
