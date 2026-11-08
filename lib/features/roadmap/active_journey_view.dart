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
    if (step.isManualPreparation) {
      return 'Requirement needs manual preparation. Prepare ${step.name} and mark this step as completed when ready.';
    }
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
    final count = steps.isEmpty
        ? fallbackTitles.length
        : steps.where((step) => step.countsForProgress).length;
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
          goals: goals,
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
                  : steps
                        .take(i + 1)
                        .where((step) => !step.alreadyOwned)
                        .length,
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
              resolveLabel:
                  steps.isNotEmpty && steps[i].resolutionKind == 'path'
                  ? 'Choose Application Requirements'
                  : 'See Suggested Options',
              onResolve:
                  steps.isNotEmpty &&
                      steps[i].isUnresolved &&
                      !steps[i].isManualPreparation &&
                      onResolve != null
                  ? () => onResolve!(steps[i])
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

/// Target on the left, progress on the right; stacks when that would not fit.
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
  final List<RoadmapPlanStep> goals;
  final double progress;
  final int completed, count;
  final bool expanded;
  final VoidCallback? onOpen;

  /// Space three columns need, so a long word in a name is never split.
  static const _minThreeColumnWidth = 289.0;
  static const _chevronWidth = 24.0;
  static const _maxThreeColumnTextScale = 1.15;
  static const _minProgressWidth = 96.0;
  static const _maxProgressWidth = 180.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final percent =
        '${completed < count ? (progress * 100).round().clamp(0, 99) : (progress * 100).round()}%';
    final divider = colors.outlineVariant.withValues(alpha: .6);
    final target = _JourneyTarget(title: title, goals: goals);
    Widget summaryProgress({required bool narrow}) => _JourneyProgress(
      title: title,
      percent: percent,
      progress: progress,
      completed: completed,
      count: count,
      narrow: narrow,
    );
    final chevron = expanded
        ? const <Widget>[]
        : [
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.onSurfaceVariant,
              size: 20,
            ),
          ];
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needed = _minThreeColumnWidth + (expanded ? 0 : _chevronWidth);
          final textFits =
              MediaQuery.textScalerOf(context).scale(10) / 10 <=
              _maxThreeColumnTextScale;
          if (goals.length <= 1 && constraints.maxWidth >= needed && textFits) {
            // Share spare width so the name column does not absorb all of it.
            final progressWidth =
                (_minProgressWidth + (constraints.maxWidth - needed) / 2).clamp(
                  _minProgressWidth,
                  _maxProgressWidth,
                );
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: Center(child: target)),
                  const SizedBox(width: 10),
                  Container(width: 1, color: divider),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: progressWidth,
                    child: summaryProgress(narrow: true),
                  ),
                  ...chevron,
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: target),
                  ...chevron,
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: divider),
              const SizedBox(height: 12),
              summaryProgress(narrow: false),
            ],
          );
        },
      ),
    );
    return RoadmapCard(
      child: expanded ? content : MotionInkWell(onTap: onOpen, child: content),
    );
  }
}

/// One target as icon and name; several targets as a short labeled list.
class _JourneyTarget extends StatelessWidget {
  const _JourneyTarget({required this.title, required this.goals});

  final String title;
  final List<RoadmapPlanStep> goals;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = TextStyle(fontSize: 12, color: colors.onSurfaceVariant);
    if (goals.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${goals.length} targets', style: label),
          for (final goal in goals)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  RoadmapRecordIcon(
                    document: goal.type == 'document',
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goal.name,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Row(
      children: [
        RoadmapRecordIcon(
          document: goals.isNotEmpty && goals.first.type == 'document',
          size: 52,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Target', style: label),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Explicit step completion; a narrow column puts the percentage on its own line.
class _JourneyProgress extends StatelessWidget {
  const _JourneyProgress({
    required this.title,
    required this.percent,
    required this.progress,
    required this.completed,
    required this.count,
    required this.narrow,
  });

  final String title, percent;
  final double progress;
  final int completed, count;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = Text(
      'Overall Progress',
      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
    );
    final value = Text(
      percent,
      style: TextStyle(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: colors.primary,
      ),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (narrow) ...[
          label,
          const SizedBox(height: 2),
          value,
        ] else
          Row(
            children: [
              Expanded(child: label),
              value,
            ],
          ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: colors.primary.withValues(alpha: .1),
          color: colors.primary,
          semanticsLabel: '$title journey progress',
          semanticsValue: percent,
        ),
        const SizedBox(height: 6),
        Text(
          '$completed of $count completed',
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
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
    required this.ready,
    required this.last,
    this.owned = false,
    this.processingTime,
    this.detail,
    this.onTap,
    this.onComplete,
    this.onResolve,
    this.resolveLabel = 'See Suggested Options',
    this.saving = false,
    this.savingThis = false,
  });
  final int number;
  final String name;
  final bool completed, current, ready, last, owned;
  final String? processingTime, detail;
  final VoidCallback? onTap, onComplete, onResolve;
  final String resolveLabel;
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
                              if (onResolve != null) ...[
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: saving ? null : onResolve,
                                  child: Text(resolveLabel),
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
                                    savingThis
                                        ? 'Saving…'
                                        : 'Mark as Completed',
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
