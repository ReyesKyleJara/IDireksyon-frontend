import 'package:flutter/material.dart';

import '../../models/roadmap_plan.dart';
import 'roadmap_widgets.dart';

/// One ranked chooser shared by plan review and saved Active Journeys.
/// Returns a confirmed selection; the caller decides where to save it.
Future<Map<String, dynamic>?> showSuggestedRoadmapOptions(
  BuildContext context, {
  required RoadmapPlan plan,
  required RoadmapPlanStep step,
}) async {
  if (step.resolutionReady) {
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review updated Roadmap'),
        content: const Text(
          'Your current Inventory and CMS requirements produce an updated Roadmap. Apply it to this journey? Existing completion history will be retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use Updated Roadmap'),
          ),
        ],
      ),
    );
    return apply == true && context.mounted
        ? {'key': step.resolutionKey}
        : null;
  }
  final path = step.resolutionKind == 'path';
  final ownerKey =
      step.ownerKey ?? step.resolutionKey?.split(':').take(2).join(':');
  final owner = plan.steps
      .where((item) => item.identity == ownerKey)
      .firstOrNull;
  final flagged = step.suggestions
      .where((option) => option['recommended'] == true)
      .take(3)
      .toList();
  final shortlist = path
      ? step.suggestions
      : flagged.isNotEmpty
      ? flagged
      : step.suggestions.take(3).toList();
  final otherOptions = step.suggestions
      .where((option) => !shortlist.contains(option))
      .toList();
  var showOtherOptions = false;
  Widget optionCard(
    BuildContext dialogContext,
    Map<String, dynamic> option,
  ) => _OptionRow(
    name: option['name'] as String,
    processingTime: _meaningfulOptionTime(option['processing_time'] as String?),
    inJourney: option['in_journey'] == true,
    owned: option['already_owned'] == true,
    path: path,
    needsReview: option['needs_review'] == true,
    remainingCount: option['remaining_count'] as int? ?? step.remainingCount,
    recommended: !path && option['recommended'] == true,
    reasons: path
        ? const []
        : (option['recommendation_reasons'] as List? ?? const [])
              .whereType<String>()
              .toList(),
    knownCost: path ? null : _knownOptionCost(option['known_cost']),
    unresolvedChoices: option['unresolved_choices'] as int? ?? 0,
    manualReviewSteps: option['manual_review_steps'] as int? ?? 0,
    actionLabel: path
        ? 'Use This Checklist'
        : option['in_journey'] == true || option['already_owned'] == true
        ? 'Use This Option'
        : 'Add to Journey',
    onSelect: () => Navigator.pop(dialogContext, option),
  );
  final option = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .35),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final colors = Theme.of(context).colorScheme;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: (MediaQuery.sizeOf(context).height * .8)
                  .clamp(0, 600)
                  .toDouble(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          path
                              ? 'Choose Application Requirements'
                              : 'Suggested Options',
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    key: const ValueKey('roadmap-options-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.onSurface.withValues(alpha: .035),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.name,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'For ${owner?.name ?? 'this target'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          path
                              ? 'Choose an applicant checklist'
                              : step.remainingCount == 1
                              ? 'Choose one accepted option'
                              : 'Choose ${step.remainingCount} accepted options',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!path && step.remainingCount > 1) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Choose from one accepted combination.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (step.suggestions.isEmpty)
                          const Text(
                            'No guided options are currently available. Check the target’s guide or issuing office.',
                          ),
                        if (!path && flagged.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Recommended',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        for (final option in shortlist)
                          optionCard(context, option),
                        if (otherOptions.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setModalState(
                                () => showOtherOptions = !showOtherOptions,
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                              ),
                              icon: Icon(
                                showOtherOptions
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                              ),
                              label: Text(
                                showOtherOptions
                                    ? 'Hide other accepted options'
                                    : 'View other accepted options',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ),
                          if (showOtherOptions)
                            for (final option in otherOptions)
                              optionCard(context, option),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (option == null || !context.mounted) return null;
  final planned = option['in_journey'] == true;
  final owned = option['already_owned'] == true;
  final remaining = option['remaining_count'] as int? ?? step.remainingCount;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        path || planned || owned
            ? 'Use ${option['name']}?'
            : 'Add ${option['name']} to Journey?',
      ),
      content: Text(
        path
            ? 'IDireksyon will use this application checklist and recalculate your roadmap.'
            : remaining > 1
            ? 'IDireksyon will use this option and recalculate your Roadmap. This accepted combination still needs ${remaining - 1} additional item${remaining == 2 ? '' : 's'}.'
            : owned
            ? 'This is already in your Inventory. No new acquisition is needed.'
            : planned
            ? 'This is already in your roadmap. It will be scheduled before what needs it.'
            : 'IDireksyon will add this before your target and recalculate your roadmap.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            path
                ? 'Use This Checklist'
                : planned || owned
                ? 'Use This Option'
                : 'Add to Journey',
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return null;
  return {
    'key': step.resolutionKey,
    if (path)
      'set_id': option['set_id']
    else ...{
      'type': option['type'],
      'id': option['id'],
      'way_id': option['way_id'],
    },
  };
}

String? _meaningfulOptionTime(String? text) {
  final value = displayProcessingTime(text);
  if (value == null) return null;
  return RegExp(
        r'\b(same[- ]day|on[- ]the[- ]spot)\b|\d+\s*(?:[-–—]\s*\d+)?\s*(?:(?:calendar|working|business)\s+)?(?:hours?|days?|weeks?|months?|years?)\b',
        caseSensitive: false,
      ).hasMatch(value)
      ? value
      : null;
}

String? _knownOptionCost(dynamic value) {
  if (value is! Map ||
      value['min'] is! num ||
      value['max'] is! num ||
      value['currency'] is! String) {
    return null;
  }
  final minimum = (value['min'] as num).toDouble();
  final maximum = (value['max'] as num).toDouble();
  final currency = (value['currency'] as String).trim();
  if (!minimum.isFinite ||
      !maximum.isFinite ||
      minimum < 0 ||
      maximum < minimum ||
      currency.isEmpty) {
    return null;
  }
  final prefix = currency == 'PHP' ? '₱' : '$currency ';
  final amount = minimum == maximum
      ? minimum.toStringAsFixed(2)
      : '${minimum.toStringAsFixed(2)}–${maximum.toStringAsFixed(2)}';
  return '$prefix$amount';
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.name,
    required this.processingTime,
    required this.inJourney,
    required this.owned,
    required this.path,
    required this.remainingCount,
    required this.needsReview,
    required this.recommended,
    required this.reasons,
    required this.knownCost,
    required this.unresolvedChoices,
    required this.manualReviewSteps,
    required this.actionLabel,
    required this.onSelect,
  });

  final String name, actionLabel;
  final int remainingCount, unresolvedChoices, manualReviewSteps;
  final String? processingTime, knownCost;
  final List<String> reasons;
  final bool inJourney, owned, path, needsReview, recommended;
  final VoidCallback onSelect;

  Widget _badge(BuildContext context, IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.25,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(
      fontSize: 11.5,
      height: 1.3,
      color: colors.onSurfaceVariant,
    );
    final facts = <String>[
      if (!owned && processingTime != null) processingTime!,
      if (!owned && knownCost != null) 'Additional fees: $knownCost',
    ];
    final action = TextButton(
      onPressed: onSelect,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        backgroundColor: colors.primary.withValues(alpha: .045),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
      child: Text(actionLabel),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RoadmapCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: recommended ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              if (!path && (owned || inJourney)) ...[
                const SizedBox(height: 5),
                _badge(
                  context,
                  owned ? Icons.check_circle_outline : Icons.route_rounded,
                  owned ? 'Already in Inventory' : 'Already in your Roadmap',
                ),
              ],
              if (!path && reasons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final reason in reasons.take(2))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(reason, style: muted),
                        ),
                    ],
                  ),
                ),
              if (!path && unresolvedChoices > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'Another requirement needs a choice.',
                    style: muted,
                  ),
                ),
              if (!path && manualReviewSteps > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text('Some requirements need review.', style: muted),
                ),
              if (!path && remainingCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'This accepted combination still needs $remainingCount items.',
                    style: muted,
                  ),
                ),
              if (needsReview)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'Confirm this applicant path applies to you.',
                    style: muted,
                  ),
                ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth >= 280 &&
                      MediaQuery.textScalerOf(context).scale(12) <= 15;
                  final details = Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      for (final fact in facts) Text(fact, style: muted),
                    ],
                  );
                  if (compact && facts.isNotEmpty) {
                    return Row(
                      children: [
                        Expanded(child: details),
                        const SizedBox(width: 8),
                        action,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (facts.isNotEmpty) ...[
                        details,
                        const SizedBox(height: 3),
                      ],
                      Align(alignment: Alignment.centerRight, child: action),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
