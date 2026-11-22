import 'package:flutter/material.dart';

import '../../models/roadmap_plan.dart';
import 'suggested_options_screen.dart';

/// One ranked chooser shared by plan review and saved Active Journeys.
/// Opens [SuggestedOptionsScreen], which confirms the tapped option itself.
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
          'Your current Inventory and the latest requirements produce an updated Roadmap. Apply it to this journey? Existing completion history will be retained.',
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
  // The page asks for confirmation itself and pops only with a confirmed option.
  final option = await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (_) => SuggestedOptionsScreen(plan: plan, step: step),
    ),
  );
  if (option == null || !context.mounted) return null;
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
