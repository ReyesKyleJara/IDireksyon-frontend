import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';
import '../../models/roadmap_plan.dart';
import '../ids/id_details_screen.dart';
import 'roadmap_widgets.dart';

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
    this.savingStep,
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

  /// The step being saved; other steps stay disabled but keep their label.
  final String? savingStep;

  List<RoadmapPlanStep> _waitingOn(RoadmapPlanStep step) =>
      waitingOnSteps(step, steps, completedStepIdentities);

  bool _isOpen(RoadmapPlanStep step) =>
      step.isActionable &&
      !completedStepIdentities.contains(step.identity) &&
      _waitingOn(step).isEmpty;

  String? _detail(int index, int current) {
    if (steps.isEmpty) return index == current ? _currentDetail : null;
    final step = steps[index];
    if (step.isUnresolved) {
      return 'Review this requirement before continuing with your journey.';
    }
    final waiting = _waitingOn(step);
    if (waiting.isNotEmpty) {
      return 'Complete ${waiting.map((item) => item.name).join(', ')} first.';
    }
    if (index == current) return _currentDetail;
    return null;
  }

  static const _currentDetail =
      'Prepare this step first so you can continue your journey.';

  @override
  Widget build(BuildContext context) {
    final actionable = steps.where((step) => step.isActionable).toList();
    final count = steps.isEmpty ? fallbackTitles.length : actionable.length;
    final rowCount = steps.isEmpty ? fallbackTitles.length : steps.length;
    final completed = actionable
        .where((step) => completedStepIdentities.contains(step.identity))
        .length;
    final progress = count == 0 ? 0.0 : completed / count;
    final current = steps.isEmpty ? 0 : steps.indexWhere(_isOpen);
    final goals = steps
        .where((step) => step.selected && !step.isUnresolved)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _JourneySummary(
          title: title,
          goals: [for (final goal in goals) goal.name],
          progress: progress,
          completed: completed,
          count: count,
          expanded: expanded,
          onOpen: onOpen,
        ),
        if (expanded) ...[
          const SizedBox(height: 20),
          for (var i = 0; i < rowCount; i++)
            _ActiveStep(
              key: ValueKey(
                'active-step-${steps.isEmpty ? 'legacy:$i' : steps[i].identity}',
              ),
              // Owned items show a check, so they don't use up a step number.
              number: steps.isEmpty
                  ? i + 1
                  : steps.take(i + 1).where((step) => !step.alreadyOwned).length,
              name: steps.isEmpty ? fallbackTitles[i] : steps[i].name,
              processingTime: steps.isEmpty ? null : steps[i].processingTime,
              owned: steps.isNotEmpty && steps[i].alreadyOwned,
              completed:
                  steps.isNotEmpty &&
                  completedStepIdentities.contains(steps[i].identity),
              current: i == current,
              ready: steps.isNotEmpty && _isOpen(steps[i]),
              last: i == rowCount - 1,
              saving: saving,
              savingThis: steps.isNotEmpty && savingStep == steps[i].identity,
              onComplete:
                  steps.isNotEmpty && _isOpen(steps[i]) && onComplete != null
                  ? () => onComplete!(steps[i])
                  : null,
              detail: _detail(i, current),
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

/// Navy while open, like Home's journey banner; a plain card when collapsed.
class _JourneySummary extends StatelessWidget {
  const _JourneySummary({
    required this.title,
    required this.goals,
    required this.progress,
    required this.completed,
    required this.count,
    required this.expanded,
    required this.onOpen,
  });

  final String title;
  final List<String> goals;
  final double progress;
  final int completed, count;
  final bool expanded;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strong = expanded ? Colors.white : colors.onSurface;
    final muted = expanded ? const Color(0xFFD5E7FA) : colors.onSurfaceVariant;
    final percent = '${(progress * 100).round()}%';
    final several = goals.length > 1;
    final content = Padding(
      padding: EdgeInsets.all(expanded ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      several ? '${goals.length} target IDs' : 'Target ID',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    const SizedBox(height: 4),
                    if (several)
                      for (final goal in goals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            goal,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: strong,
                            ),
                          ),
                        )
                    else
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 19,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: strong,
                        ),
                      ),
                  ],
                ),
              ),
              if (!expanded)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
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
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
              Text(
                percent,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: strong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: expanded
                ? Colors.white.withValues(alpha: .2)
                : colors.primary.withValues(alpha: .1),
            color: expanded ? AppTheme.accentGold : colors.primary,
            semanticsLabel: '$title journey progress',
            semanticsValue: percent,
          ),
          const SizedBox(height: 6),
          Text(
            '$completed of $count completed',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
    if (expanded) return RoadmapGradientCard(child: content);
    return RoadmapCard(
      child: MotionInkWell(onTap: onOpen, child: content),
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
    required this.ready,
    required this.last,
    this.owned = false,
    this.processingTime,
    this.detail,
    this.onTap,
    this.onComplete,
    this.saving = false,
    this.savingThis = false,
  });
  final int number;
  final String name;
  final bool completed, current, ready, last, owned;
  final String? processingTime, detail;
  final VoidCallback? onTap, onComplete;
  final bool saving, savingThis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final active = (current || ready) && !completed;
    final done = completed || owned;
    final nodeColor = done
        ? AppTheme.completedGreen
        : active
        ? colors.primary
        : colors.outlineVariant;
    final status = owned
        ? 'Already in your Inventory'
        : completed
        ? 'Completed'
        : current
        ? 'Current step'
        : ready
        ? 'Ready to start'
        : 'Upcoming';
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
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : Text(
                          '$number',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? colors.onPrimary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                ),
                if (!last)
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
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: dark ? colors.surfaceContainer : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    width: current && !completed ? 1.5 : 1,
                    color: current && !completed
                        ? colors.primary
                        : dark
                        ? colors.outlineVariant.withValues(alpha: .35)
                        : const Color(0xFFE3ECF7),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: MotionInkWell(
                  onTap: saving ? null : onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
                                  fontSize: 14.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: done
                                      ? (dark
                                            ? const Color(0xFF81C784)
                                            : AppTheme.completedGreen)
                                      : active
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                              if (detail != null && !done) ...[
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
                              if (processingTime != null && !done) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Listed processing time: $processingTime',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (onComplete != null && !completed) ...[
                                const SizedBox(height: 10),
                                OutlinedButton(
                                  onPressed: saving ? null : onComplete,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.primary,
                                    minimumSize: const Size(0, 40),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    savingThis ? 'Saving…' : 'Mark as Completed',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
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
