import 'package:flutter/material.dart';

import '../../models/government_id_applicability.dart';
import 'applicant_flow_controller.dart';
import 'detail_widgets.dart';

class ApplicantContextCard extends StatelessWidget {
  final ApplicantFlowController flow;
  const ApplicantContextCard({super.key, required this.flow});

  @override
  Widget build(BuildContext context) {
    final result = flow.result;
    final missing = result?.missingContext ?? const <String>[];
    final editing = flow.editing;
    final askAge =
        missing.contains('age') || (editing && flow.context.age != null);
    final askApplication =
        missing.contains('application_type') ||
        (editing && flow.context.applicationType != null);
    final showFields = editing || (missing.isNotEmpty && !flow.stale);
    final options = result == null
        ? const <ApplicantProfile>[]
        : result.status == ApplicabilityStatus.multipleMatches
        ? result.matchedProfiles
        : (result.status == ApplicabilityStatus.manualConfirmationRequired ||
              (result.status == ApplicabilityStatus.insufficientContext &&
                  result.manualProfiles.isNotEmpty))
        ? result.availableProfiles
        : editing
        ? result.availableProfiles
        : const <ApplicantProfile>[];
    final types = <String>{
      for (final profile in result?.availableProfiles ?? <ApplicantProfile>[])
        if (profile.applicationType != null) profile.applicationType!,
    };
    const typeLabels = {
      'new': 'New application',
      'renewal': 'Renewal',
      'replacement': 'Replacement',
      'custom': 'Other application',
    };
    final knownFacts = [
      if (flow.context.age != null) 'Age ${flow.context.age}',
      if (typeLabels[flow.context.applicationType] != null)
        typeLabels[flow.context.applicationType]!,
    ].join(' · ');
    return DetailCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your application',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (result != null && !editing)
                  TextButton(
                    onPressed: flow.loading ? null : flow.change,
                    child: const Text('Change'),
                  ),
              ],
            ),
            if (result?.selectedProfile != null)
              Text(result!.selectedProfile!.label)
            else if (knownFacts.isNotEmpty)
              Text(knownFacts),
            if (flow.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (flow.stale)
              const Text(
                'Showing your previous application information. It has not been verified for these changes.',
              ),
            if (flow.error != null) ...[
              Text(flow.error!),
              TextButton(
                onPressed: flow.loading ? null : flow.refresh,
                child: const Text('Retry application'),
              ),
            ],
            if (result?.status == ApplicabilityStatus.noMatch)
              const Text(
                'No matching application option was found. Change your details or confirm the requirements with the agency.',
              ),
            if (showFields) ...[
              if (askAge)
                TextFormField(
                  key: ValueKey(('applicant-age', flow.editorRevision)),
                  initialValue: flow.draftAge,
                  decoration: const InputDecoration(labelText: 'Your age'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => flow.draftAge = value,
                ),
              if (askApplication)
                DropdownButtonFormField<String>(
                  key: ValueKey(('application-type', flow.editorRevision)),
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
                        child: Text(typeLabels[type] ?? 'Application option'),
                      ),
                  ],
                  onChanged: (value) => flow.draftApplicationType = value,
                ),
              if (askAge || askApplication)
                FilledButton(
                  onPressed: flow.loading ? null : flow.submitFacts,
                  child: const Text('Update application'),
                ),
              if (missing.any(
                (field) => !['age', 'application_type'].contains(field),
              ))
                const Text(
                  'Additional information is needed. Choose your situation or confirm with the agency.',
                ),
              if (editing)
                TextButton(
                  onPressed: flow.cancelEdit,
                  child: const Text('Done'),
                ),
            ],
            if (editing && flow.context.selectedProfileId != null)
              TextButton(
                onPressed: flow.loading ? null : flow.submitFacts,
                child: const Text('Use application details'),
              ),
            if (options.isNotEmpty && !flow.loading) ...[
              const Text('Choose the option that best matches your situation'),
              DropdownButtonFormField<int>(
                key: ValueKey((
                  'application-option',
                  flow.context.selectedProfileId,
                  flow.editorRevision,
                )),
                initialValue:
                    options.any(
                      (option) => option.id == flow.context.selectedProfileId,
                    )
                    ? flow.context.selectedProfileId
                    : null,
                isExpanded: true,
                itemHeight: null,
                decoration: const InputDecoration(labelText: 'Your situation'),
                items: [
                  for (final profile in options)
                    DropdownMenuItem(
                      value: profile.id,
                      child: Text(profile.label),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) flow.choose(id);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
