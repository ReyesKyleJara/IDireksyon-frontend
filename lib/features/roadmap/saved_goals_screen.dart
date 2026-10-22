import 'sequence_controller.dart';

import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../models/applicant_context.dart';
import '../../services/roadmap_goal_service.dart';
import 'saved_goals_controller.dart';
import 'sequence_screen.dart';

class SavedGoalsScreen extends StatefulWidget {
  final RoadmapGoalService? service;
  final BuildSequence? evaluate;
  const SavedGoalsScreen({super.key, this.service, this.evaluate});
  @override
  State<SavedGoalsScreen> createState() => _SavedGoalsScreenState();
}

class _SavedGoalsScreenState extends State<SavedGoalsScreen> {
  late final SavedGoalsController flow;
  @override
  void initState() {
    super.initState();
    flow = SavedGoalsController(
      widget.service ?? RoadmapGoalService(AuthService.instance),
    );
    flow.refresh();
  }

  @override
  void dispose() {
    flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Roadmaps')),
    body: AnimatedBuilder(
      animation: flow,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (flow.service.auth.token == null)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Sign in to view your roadmaps'),
            )
          else ...[
            if (flow.loading) const LinearProgressIndicator(),
            if (flow.error != null) Text(flow.error!),
            TextButton(
              onPressed: flow.loading ? null : flow.refresh,
              child: const Text('Refresh roadmaps'),
            ),
            if (!flow.loading && flow.error == null && flow.goals.isEmpty)
              const Text(
                'No saved roadmaps yet. Open a Government ID and build your roadmap to save a goal.',
              ),
            for (final goal in flow.goals)
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(goal.name),
                      subtitle: Text(
                        goal.completed
                            ? 'Goal completed'
                            : 'Recalculate when opened',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: flow.loading
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SequenceScreen(
                                    governmentId: goal.governmentId,
                                    targetName: goal.name,
                                    applicantContext: ApplicantContext(),
                                    restoreSaved: true,
                                    goalService: flow.service,
                                    evaluate: widget.evaluate,
                                  ),
                                ),
                              );
                              if (mounted) flow.refresh();
                            },
                    ),
                    TextButton(
                      onPressed: flow.loading
                          ? null
                          : () async {
                              final remove = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove saved goal?'),
                                  content: Text(goal.name),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Keep'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (remove == true && mounted) {
                                flow.remove(goal.governmentId);
                              }
                            },
                      child: const Text('Remove saved goal'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
