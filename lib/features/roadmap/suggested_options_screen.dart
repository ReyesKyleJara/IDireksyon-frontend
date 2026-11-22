import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/catalog_image.dart';
import '../../models/roadmap_plan.dart';
import 'roadmap_widgets.dart';

/// Full-page chooser for one unresolved requirement, such as the accepted ID a
/// Passport still needs. Pops with the chosen option; the caller confirms and
/// saves it.
class SuggestedOptionsScreen extends StatefulWidget {
  const SuggestedOptionsScreen({
    super.key,
    required this.plan,
    required this.step,
  });

  final RoadmapPlan plan;
  final RoadmapPlanStep step;

  @override
  State<SuggestedOptionsScreen> createState() => _SuggestedOptionsScreenState();
}

class _SuggestedOptionsScreenState extends State<SuggestedOptionsScreen> {
  var _showOtherOptions = false;

  RoadmapPlanStep get step => widget.step;
  bool get _path => step.resolutionKind == 'path';

  /// "ID", "document" or "option", depending on what is being offered.
  ({String one, String many}) get _noun {
    final types = step.suggestions.map((option) => option['type']).toSet();
    if (types.length == 1 && types.first == 'government_id') {
      return (one: 'ID', many: 'IDs');
    }
    if (types.length == 1 && types.first == 'document') {
      return (one: 'document', many: 'Documents');
    }
    return (one: 'option', many: 'Options');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ownerKey =
        step.ownerKey ?? step.resolutionKey?.split(':').take(2).join(':');
    final owner = widget.plan.steps
        .where((item) => item.identity == ownerKey)
        .firstOrNull;
    final journey = owner == null
        ? 'your journey'
        : 'your ${owner.name} journey';
    final noun = _noun;
    final flagged = step.suggestions
        .where((option) => option['recommended'] == true)
        .take(3)
        .toList();
    // Recommended first, then alternatives, so up to three show without
    // tapping "View other accepted options".
    final shortlist = _path
        ? step.suggestions
        : [
            ...flagged,
            ...step.suggestions.where((option) => !flagged.contains(option)),
          ].take(flagged.length > 3 ? flagged.length : 3).toList();
    final otherOptions = step.suggestions
        .where((option) => !shortlist.contains(option))
        .toList();
    final title = _path
        ? 'Choose Application Requirements'
        : 'Suggested ${noun.many} for ${owner?.name ?? 'this target'}';
    final subtitle = _path
        ? 'Choose the applicant checklist that fits you for $journey.'
        : step.remainingCount > 1
        ? 'You still need ${step.remainingCount} accepted ${noun.one == 'ID' ? 'IDs' : '${noun.one}s'} from one accepted combination before continuing $journey.'
        : 'You still need an accepted ${noun.one} before continuing $journey.';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: colors.primary),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('roadmap-options-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.15,
                      letterSpacing: -.4,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (step.suggestions.isEmpty)
                    const Text(
                      'No guided options are currently available. Check the target’s guide or issuing office.',
                    ),
                  for (final option in shortlist) _card(option),
                  if (otherOptions.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => _showOtherOptions = !_showOtherOptions,
                        ),
                        icon: Icon(
                          _showOtherOptions
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                        ),
                        label: Text(
                          _showOtherOptions
                              ? 'Hide other accepted options'
                              : 'View other accepted options',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    if (_showOtherOptions)
                      for (final option in otherOptions) _card(option),
                  ],
                  const SizedBox(height: 12),
                  const RoadmapSuggestionNotice(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? get _ownerName {
    final ownerKey =
        step.ownerKey ?? step.resolutionKey?.split(':').take(2).join(':');
    return widget.plan.steps
        .where((item) => item.identity == ownerKey)
        .firstOrNull
        ?.name;
  }

  /// Asks over this page, so Cancel keeps the resident here to pick again.
  Future<void> _confirm(Map<String, dynamic> option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _AddOptionDialog(
        option: option,
        path: _path,
        ownerName: _ownerName,
        remaining: option['remaining_count'] as int? ?? step.remainingCount,
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context, option);
  }

  Widget _card(Map<String, dynamic> option) {
    final owned = option['already_owned'] == true;
    final inJourney = option['in_journey'] == true;
    final imagePath = option['image_url'] as String?;
    return SuggestedOptionCard(
      name: option['name'] as String,
      document: option['type'] == 'document',
      imageUrl: imagePath == null || imagePath.trim().isEmpty
          ? null
          : Uri.parse(ApiConfig.baseUrl).resolve(imagePath).toString(),
      processingTime: _meaningfulOptionTime(
        option['processing_time'] as String?,
      ),
      inJourney: inJourney,
      owned: owned,
      path: _path,
      needsReview: option['needs_review'] == true,
      remainingCount: option['remaining_count'] as int? ?? step.remainingCount,
      recommended: !_path && option['recommended'] == true,
      reasons: _path
          ? const []
          : (option['recommendation_reasons'] as List? ?? const [])
                .whereType<String>()
                .toList(),
      knownCost: _path ? null : _knownOptionCost(option['known_cost']),
      unresolvedChoices: option['unresolved_choices'] as int? ?? 0,
      manualReviewSteps: option['manual_review_steps'] as int? ?? 0,
      actionLabel: _path
          ? 'Use This Checklist'
          : inJourney || owned
          ? 'Use This Option'
          : 'Add to Journey',
      onSelect: () => _confirm(option),
    );
  }
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

/// One accepted option: picture, name, Recommended/Alternative badge, why it
/// is suggested, and a full-width action.
class SuggestedOptionCard extends StatelessWidget {
  const SuggestedOptionCard({
    super.key,
    required this.name,
    required this.document,
    required this.imageUrl,
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
  final String? imageUrl, processingTime, knownCost;
  final List<String> reasons;
  final bool document, inJourney, owned, path, needsReview, recommended;
  final VoidCallback onSelect;

  Widget _rankBadge(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final tint = recommended
        ? (dark ? const Color(0xFF81C784) : AppTheme.completedGreen)
        : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: dark ? .16 : .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        recommended ? 'Recommended' : 'Alternative',
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, IconData icon, String label) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final body = TextStyle(fontSize: 13, height: 1.4, color: colors.onSurface);
    final muted = TextStyle(
      fontSize: 12,
      height: 1.35,
      color: colors.onSurfaceVariant,
    );
    final facts = <String>[
      if (!owned && processingTime != null) processingTime!,
      if (!owned && knownCost != null) 'Additional fees: $knownCost',
    ];
    final notes = <String>[
      if (!path && unresolvedChoices > 0) 'Another requirement needs a choice.',
      if (!path && manualReviewSteps > 0) 'Some requirements need review.',
      if (!path && remainingCount > 1)
        'This accepted combination still needs $remainingCount items.',
      if (needsReview) 'Confirm this applicant path applies to you.',
    ];
    final nameText = Text(
      name,
      style: const TextStyle(
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: RoadmapCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CatalogImage(
                    url: imageUrl,
                    size: 72,
                    radius: 12,
                    fallback: RoadmapRecordIcon(document: document, size: 72),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (path)
                          nameText
                        else
                          // Badge sits beside the name when there is room,
                          // and under it on narrow screens or large text.
                          LayoutBuilder(
                            builder: (context, constraints) =>
                                constraints.maxWidth >=
                                    MediaQuery.textScalerOf(context).scale(230)
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: nameText),
                                      const SizedBox(width: 8),
                                      _rankBadge(context),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      nameText,
                                      const SizedBox(height: 6),
                                      _rankBadge(context),
                                    ],
                                  ),
                          ),
                        if (!path && (owned || inJourney)) ...[
                          const SizedBox(height: 6),
                          _statusBadge(
                            context,
                            owned
                                ? Icons.check_circle_outline
                                : Icons.route_rounded,
                            owned
                                ? 'Already in Inventory'
                                : 'Already in your Roadmap',
                          ),
                        ],
                        for (final reason in reasons.take(2))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(reason, style: body),
                          ),
                        for (final note in notes)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(note, style: muted),
                          ),
                        if (facts.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 3,
                              children: [
                                for (final fact in facts)
                                  Text(fact, style: muted),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onSelect,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary, width: 1.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Add PhilSys ID to Journey?": icon, what will happen, why it is suggested,
/// then Cancel or the action.
class _AddOptionDialog extends StatelessWidget {
  const _AddOptionDialog({
    required this.option,
    required this.path,
    required this.ownerName,
    required this.remaining,
  });

  final Map<String, dynamic> option;
  final bool path;
  final String? ownerName;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final name = option['name'] as String;
    final owned = option['already_owned'] == true;
    final planned = option['in_journey'] == true;
    final document = option['type'] == 'document';
    final reason = path
        ? null
        : (option['recommendation_reasons'] as List? ?? const [])
              .whereType<String>()
              .firstOrNull;
    final title = path || planned || owned
        ? 'Use $name?'
        : 'Add $name to Journey?';
    final before = ownerName == null ? 'your target' : 'your $ownerName step';
    final message = path
        ? 'IDireksyon will use this application checklist and recalculate your roadmap.'
        : remaining > 1
        ? 'IDireksyon will use this option and recalculate your Roadmap. This accepted combination still needs ${remaining - 1} additional item${remaining == 2 ? '' : 's'}.'
        : owned
        ? 'This is already in your Inventory. No new acquisition is needed.'
        : planned
        ? 'This is already in your roadmap. It will be scheduled before what needs it.'
        : 'IDireksyon will add $name before $before and recalculate the most efficient sequence based on your current documents.';
    // Named apart from the card's button behind this dialog.
    final action = path || planned || owned
        ? 'Use and Recalculate'
        : 'Add and Recalculate';
    final green = dark ? const Color(0xFF81C784) : AppTheme.completedGreen;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonText = TextStyle(
      fontFamily: 'Google Sans',
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 72,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .08),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            document
                                ? Icons.description_outlined
                                : Icons.badge_outlined,
                            size: 38,
                            color: colors.primary,
                          ),
                        ),
                        if (!path && !owned && !planned)
                          Positioned(
                            right: 6,
                            bottom: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surface,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: colors.surface,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: colors.onSurface,
                ),
              ),
              if (reason != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: .12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 30,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Reason: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                              TextSpan(text: reason),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary, width: 1.3),
                        shape: buttonShape,
                        textStyle: buttonText,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 7,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: buttonShape,
                        textStyle: buttonText,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(action, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
