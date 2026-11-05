import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/roadmap_plan.dart';
import '../ids/id_details_screen.dart';

/// Presentation only: keeps the server's acquisition steps and their order.
class SuggestedJourneyView extends StatelessWidget {
  const SuggestedJourneyView({super.key, required this.plan, this.onResolve});
  final RoadmapPlan plan;
  final ValueChanged<RoadmapPlanStep>? onResolve;

  bool _isGoal(RoadmapPlanStep step) => step.type == 'government_id'
      ? plan.targetIds.contains(step.id)
      : step.type == 'document' && plan.targetDocumentIds.contains(step.id);

  @override
  Widget build(BuildContext context) {
    final goals = plan.steps
        .where(_isGoal)
        .map((step) => step.name)
        .join(' + ');
    final setupCards = plan.steps
        .where((step) => step.isUnresolved && step.resolutionKind == 'path')
        .toList();
    final actionableSteps = plan.steps
        .where((step) => !(step.isUnresolved && step.resolutionKind == 'path'))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoadmapGoalCard(title: goals, stepCount: actionableSteps.length),
        const SizedBox(height: 18),
        for (final step in setupCards) ...[
          JourneyResolutionCard(
            key: ValueKey(step.identity),
            step: step,
            onOptions: onResolve == null ? null : () => onResolve!(step),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Your next steps',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        if (plan.blocked)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Please check the requirements with the issuing office before starting this roadmap.',
              style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.navy),
            ),
          ),
        for (var i = 0; i < actionableSteps.length; i++)
          if (actionableSteps[i].isUnresolved)
            JourneyResolutionCard(
              key: ValueKey(actionableSteps[i].identity),
              step: actionableSteps[i],
              number: i + 1,
              isLast: i == actionableSteps.length - 1,
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

/// Temporary step with no catalog identity and no Inventory ownership action.
class JourneyResolutionCard extends StatelessWidget {
  const JourneyResolutionCard({
    super.key,
    required this.step,
    this.onOptions,
    this.number,
    this.isLast = false,
  });
  final RoadmapPlanStep step;
  final VoidCallback? onOptions;
  final int? number;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: number == null ? null : EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(step.message ?? ''),
            TextButton(
              onPressed: onOptions,
              child: Text(
                step.resolutionKind == 'path'
                    ? 'Choose Request Path'
                    : 'See Suggested Options',
              ),
            ),
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
  });
  final String title;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final passport =
        title.toLowerCase().contains('passport') && !title.contains(' + ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? colors.surfaceContainer
            : AppTheme.primaryBlue.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.flag_outlined, size: 22, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GoalBadge(),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: colors.primary,
                  ),
                ),
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
                const SizedBox(height: 8),
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
    );
  }
}

class _GoalBadge extends StatelessWidget {
  const _GoalBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.accentGold.withValues(alpha: .4),
      borderRadius: BorderRadius.circular(5),
    ),
    child: const Text(
      'YOUR TARGET',
      style: TextStyle(
        fontSize: 9,
        letterSpacing: .7,
        fontWeight: FontWeight.w800,
        color: AppTheme.navy,
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
  });
  final int number, earlierSteps;
  final int? recordId;
  final String name, recordType, goalName;
  final bool isGoal, isLast, needsAttention, informational;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: colors.brightness == Brightness.dark
              ? colors.surfaceContainer
              : isGoal
              ? AppTheme.pageBackground
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isGoal) ...[const _GoalBadge(), const SizedBox(height: 5)],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  recordType == 'document'
                      ? Icons.description_outlined
                      : Icons.badge_outlined,
                  size: 22,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              instruction,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (recordId != null)
              Align(
                alignment: Alignment.centerLeft,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                      color: colors.primary.withValues(alpha: .15),
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
