import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/roadmap_plan.dart';
import '../ids/id_details_screen.dart';
import 'roadmap_widgets.dart';

/// Presentation only: keeps the server's acquisition steps and their order.
class SuggestedJourneyView extends StatelessWidget {
  const SuggestedJourneyView({super.key, required this.plan, this.onResolve});
  final RoadmapPlan plan;
  final ValueChanged<RoadmapPlanStep>? onResolve;

  bool _isGoal(RoadmapPlanStep step) => step.type == 'government_id'
      ? plan.targetIds.contains(step.id)
      : step.type == 'document' && plan.targetDocumentIds.contains(step.id);

  /// Which goal a choice belongs to; only worth saying with several goals.
  String? _neededFor(RoadmapPlanStep step, List<String> goals) {
    if (goals.length < 2 || step.resolutionKind == 'path') return null;
    final owner = plan.steps.where((item) => item.identity == step.ownerKey);
    return owner.isEmpty ? null : owner.first.name;
  }

  /// With several goals, each step says what it really depends on, so its
  /// place in the list isn't mistaken for a required order.
  String? _relationship(RoadmapPlanStep step) {
    if (plan.targetIds.length + plan.targetDocumentIds.length < 2) return null;
    final needs = waitingOnSteps(step, plan.steps, const {});
    final neededBy = plan.steps.where(
      (other) => waitingOnSteps(
        other,
        plan.steps,
        const {},
      ).any((item) => item.identity == step.identity),
    );
    return [
      if (needs.isNotEmpty)
        'Complete ${needs.map((item) => item.name).join(', ')} first.',
      if (neededBy.isNotEmpty)
        'Needed for ${neededBy.map((item) => item.name).join(', ')}.',
      if (needs.isEmpty && neededBy.isEmpty)
        'No required order. You can work on this anytime.',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final owned = plan.steps.where((step) => step.alreadyOwned).toList();
    final goalNames = plan.steps
        .where((step) => _isGoal(step) && !step.alreadyOwned)
        .map((step) => step.name)
        .toList();
    final goals = goalNames.join(' + ');
    final setupCards = plan.steps
        .where((step) => step.isUnresolved && step.resolutionKind == 'path')
        .toList();
    final actionableSteps = plan.steps
        .where(
          (step) =>
              !step.alreadyOwned &&
              !(step.isUnresolved && step.resolutionKind == 'path'),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoadmapGoalCard(
          title: goals,
          goals: goalNames,
          stepCount: actionableSteps.length,
        ),
        const SizedBox(height: 12),
        if (owned.isNotEmpty) ...[
          _OwnedTargets(names: [for (final step in owned) step.name]),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 6),
        for (final step in setupCards) ...[
          JourneyResolutionCard(
            key: ValueKey(step.identity),
            step: step,
            onOptions: onResolve == null ? null : () => onResolve!(step),
          ),
          const SizedBox(height: 12),
        ],
        Semantics(
          header: true,
          child: const Text(
            'Your next steps',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 14),
        if (plan.blocked)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Please check the requirements with the issuing office before starting this roadmap.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        for (var i = 0; i < actionableSteps.length; i++)
          if (actionableSteps[i].isUnresolved)
            JourneyResolutionCard(
              key: ValueKey(actionableSteps[i].identity),
              step: actionableSteps[i],
              number: i + 1,
              isLast: i == actionableSteps.length - 1,
              neededFor: _neededFor(actionableSteps[i], goalNames),
              onOptions: onResolve == null
                  ? null
                  : () => onResolve!(actionableSteps[i]),
            )
          else
            SuggestedJourneyStep(
              key: ValueKey(
                'suggested-step-${actionableSteps[i].type}-${actionableSteps[i].id}',
              ),
              number: i + 1,
              name: actionableSteps[i].name,
              recordId: actionableSteps[i].id,
              recordType: actionableSteps[i].type,
              processingTime: actionableSteps[i].processingTime,
              relationship: _relationship(actionableSteps[i]),
              goalName:
                  goals.toLowerCase().contains('passport') &&
                      plan.targetIds.length == 1
                  ? 'Passport'
                  : 'next',
              isGoal: _isGoal(actionableSteps[i]),
              isLast: i == actionableSteps.length - 1,
              needsAttention: actionableSteps[i].blocked,
              informational: actionableSteps[i].isInformational,
              earlierSteps: actionableSteps
                  .take(i)
                  .where((step) => !_isGoal(step))
                  .length,
            ),
      ],
    );
  }
}

/// Selected items the resident already holds: no steps are planned for them.
class _OwnedTargets extends StatelessWidget {
  const _OwnedTargets({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RoadmapCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: colors.brightness == Brightness.dark
                  ? const Color(0xFF81C784)
                  : AppTheme.completedGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Already in your Inventory, so no steps needed: ${names.join(', ')}',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Temporary step with no catalog identity and no Inventory ownership action.
class JourneyResolutionCard extends StatelessWidget {
  const JourneyResolutionCard({
    super.key,
    required this.step,
    this.onOptions,
    this.number,
    this.isLast = false,
    this.neededFor,
  });
  final RoadmapPlanStep step;
  final VoidCallback? onOptions;
  final int? number;
  final bool isLast;
  final String? neededFor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = RoadmapCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.isManualPreparation ? 'MANUAL PREPARATION' : 'YOUR CHOICE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              step.name,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (neededFor != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Needed for $neededFor',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              step.isManualPreparation
                  ? 'Requirement needs manual preparation. Prepare this requirement and mark its journey step as completed when ready.'
                  : step.message ?? '',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (!step.isManualPreparation) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: onOptions,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 40),
                  textStyle: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  step.resolutionKind == 'path'
                      ? 'Choose Application Requirements'
                      : 'See Suggested Options',
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (number == null) return card;
    return _JourneyTimelineRow(
      number: number!,
      isGoal: false,
      isLast: isLast,
      child: Padding(padding: const EdgeInsets.only(bottom: 10), child: card),
    );
  }
}

class RoadmapGoalCard extends StatelessWidget {
  const RoadmapGoalCard({
    super.key,
    required this.title,
    required this.stepCount,
    this.goals = const [],
  });
  final String title;
  final int stepCount;
  final List<String> goals;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final passport =
        title.toLowerCase().contains('passport') && !title.contains(' + ');
    final nameStyle = TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: colors.onSurface,
    );
    return RoadmapCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  size: 22,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GoalBadge(plural: goals.length > 1),
                  const SizedBox(height: 6),
                  if (goals.length > 1)
                    for (final goal in goals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(goal, style: nameStyle),
                      )
                  else
                    Text(title, style: nameStyle),
                  if (passport)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Department of Foreign Affairs',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '$stepCount ${stepCount == 1 ? 'step' : 'steps'} to complete',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalBadge extends StatelessWidget {
  const _GoalBadge({this.plural = false});
  final bool plural;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.accentGold.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      plural ? 'YOUR TARGETS' : 'YOUR TARGET',
      style: TextStyle(
        fontSize: 9,
        letterSpacing: .7,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppTheme.navy,
      ),
    ),
  );
}

class SuggestedJourneyStep extends StatelessWidget {
  const SuggestedJourneyStep({
    super.key,
    required this.number,
    required this.name,
    required this.isGoal,
    required this.isLast,
    this.recordId,
    this.recordType = 'government_id',
    this.goalName = 'next',
    this.needsAttention = false,
    this.informational = false,
    this.earlierSteps = 0,
    this.processingTime,
    this.relationship,
  });
  final int number, earlierSteps;
  final int? recordId;
  final String name, recordType, goalName;
  final String? processingTime, relationship;
  final bool isGoal, isLast, needsAttention, informational;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: colors.onSurfaceVariant,
    );
    final instruction = needsAttention
        ? 'Check availability with the issuing office before continuing.'
        : informational
        ? 'Review the issuing institution’s instructions before continuing.'
        : isGoal
        ? (earlierSteps > 0
              ? 'Continue here once your required documents are ready.'
              : 'Start preparing your application here.')
        : 'Get this ${recordType == 'document' ? 'document' : 'ID'} first before continuing with your $goalName application.';
    return _JourneyTimelineRow(
      number: number,
      isGoal: isGoal,
      isLast: isLast,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RoadmapCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGoal) ...[const _GoalBadge(), const SizedBox(height: 8)],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RoadmapRecordIcon(
                      document: recordType == 'document',
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            needsAttention || informational
                                ? instruction
                                : relationship ?? instruction,
                            style: muted,
                          ),
                          if (processingTime != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Listed processing time: $processingTime',
                                style: muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (recordId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IdDetailsScreen(
                            governmentId: recordId,
                            recordType: recordType,
                            idName: name,
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 38),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(
                        informational ? 'View information' : 'View Guide',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared visible number and connector for both catalog and unresolved steps.
class _JourneyTimelineRow extends StatelessWidget {
  const _JourneyTimelineRow({
    required this.number,
    required this.isGoal,
    required this.isLast,
    required this.child,
  });
  final int number;
  final bool isGoal, isLast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isGoal ? AppTheme.accentGold : AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isGoal ? AppTheme.navy : Colors.white,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: colors.outlineVariant.withValues(alpha: .6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}
