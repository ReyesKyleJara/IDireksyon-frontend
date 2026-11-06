import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';
import '../../models/roadmap_plan.dart';
import '../ids/id_details_screen.dart';

/// Active progress is explicit completion, never Inventory or prerequisite readiness.
class ActiveJourneyView extends StatelessWidget {
  const ActiveJourneyView({
    super.key,
    required this.title,
    required this.steps,
    this.fallbackTitles = const [],
    this.completedStepIdentities = const {},
    this.expanded = true,
    this.onOpen,
    this.onResolve,
    this.onComplete,
    this.saving = false,
  });

  final String title;
  final List<RoadmapPlanStep> steps;
  final List<String> fallbackTitles;
  final Set<String> completedStepIdentities;
  final bool expanded;
  final VoidCallback? onOpen;
  final ValueChanged<RoadmapPlanStep>? onResolve;
  final ValueChanged<RoadmapPlanStep>? onComplete;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actionable = steps
        .where(
          (step) =>
              !step.isUnresolved && !step.isInformational && !step.blocked,
        )
        .toList();
    final count = steps.isEmpty ? fallbackTitles.length : actionable.length;
    final rowCount = steps.isEmpty ? fallbackTitles.length : steps.length;
    final completed = actionable
        .where((step) => completedStepIdentities.contains(step.identity))
        .length;
    final progress = count == 0 ? 0.0 : completed / count;
    final current = steps.isEmpty
        ? 0
        : steps.indexWhere(
            (step) =>
                !step.isUnresolved &&
                !step.isInformational &&
                !step.blocked &&
                !completedStepIdentities.contains(step.identity),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: expanded
                  ? colors.primary.withValues(alpha: .35)
                  : colors.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: MotionInkWell(
            onTap: expanded ? null : onOpen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.badge_outlined,
                          size: 26,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target ID',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!expanded)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.primary,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Overall Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: colors.primary.withValues(alpha: .1),
                    color: colors.primary,
                    semanticsLabel: '$title journey progress',
                    semanticsValue: '${(progress * 100).round()}%',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$completed of $count completed',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 20),
          for (var i = 0; i < rowCount; i++)
            _ActiveStep(
              key: ValueKey(
                'active-step-${steps.isEmpty ? 'legacy:$i' : steps[i].identity}',
              ),
              number: i + 1,
              name: steps.isEmpty ? fallbackTitles[i] : steps[i].name,
              completed:
                  steps.isNotEmpty &&
                  completedStepIdentities.contains(steps[i].identity),
              current: i == current,
              last: i == rowCount - 1,
              saving: saving,
              onComplete: i == current && steps.isNotEmpty && onComplete != null
                  ? () => onComplete!(steps[i])
                  : null,
              detail: steps.isNotEmpty && steps[i].isUnresolved
                  ? 'Review this requirement before continuing with your journey.'
                  : i == current
                  ? 'Prepare this step first so you can continue your journey.'
                  : null,
              onTap: steps.isEmpty
                  ? null
                  : steps[i].isUnresolved
                  ? (onResolve == null ? null : () => onResolve!(steps[i]))
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IdDetailsScreen(
                          governmentId: steps[i].id,
                          recordType: steps[i].type,
                          idName: steps[i].name,
                        ),
                      ),
                    ),
            ),
        ],
      ],
    );
  }
}

class _ActiveStep extends StatelessWidget {
  const _ActiveStep({
    super.key,
    required this.number,
    required this.name,
    required this.completed,
    required this.current,
    required this.last,
    this.detail,
    this.onTap,
    this.onComplete,
    this.saving = false,
  });
  final int number;
  final String name;
  final bool completed, current, last;
  final String? detail;
  final VoidCallback? onTap, onComplete;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final nodeColor = completed
        ? AppTheme.completedGreen
        : current
        ? colors.primary
        : colors.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nodeColor,
                  ),
                  child: completed
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: current
                                ? colors.onPrimary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: colors.primary.withValues(alpha: .2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: current && !completed
                    ? Color.alphaBlend(
                        colors.primary.withValues(alpha: .03),
                        colors.surface,
                      )
                    : colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: current && !completed
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: .6),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: MotionInkWell(
                  onTap: saving ? null : onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                  color: current
                                      ? colors.primary
                                      : colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                completed
                                    ? 'Completed'
                                    : current
                                    ? 'Current step'
                                    : 'Upcoming',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: completed
                                      ? AppTheme.completedGreen
                                      : current
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                              if (detail != null && !completed) ...[
                                const SizedBox(height: 6),
                                Text(
                                  detail!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (onComplete != null && !completed) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: saving ? null : onComplete,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(0, 40),
                                  ),
                                  child: Text(
                                    saving ? 'Saving…' : 'Mark as Completed',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
