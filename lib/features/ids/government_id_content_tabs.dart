import 'package:flutter/material.dart';

import '../../models/government_id.dart';
import 'detail_widgets.dart';
import 'government_id_map.dart';
import 'guide_content.dart';
import 'requirements_tab.dart';

class GovernmentCostTab extends StatelessWidget {
  final GovernmentIdDetails record;
  const GovernmentCostTab({super.key, required this.record});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [FeeContent(record: record)],
  );
}

class FeeContent extends StatelessWidget {
  final GovernmentIdDetails record;
  const FeeContent({super.key, required this.record});
  @override
  Widget build(BuildContext context) {
    if (record.fees.isEmpty) {
      return DetailMessage(
        record.feeSummary ?? 'Fee information is not available yet. This does not mean the application is free.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: detailsBlue,
                  child: Icon(Icons.payments_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Cost',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (record.feeSummary != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(record.feeSummary!),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'A combined total is not confirmed. Fees may apply to different applications or choices. Check the notes for each fee.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cost Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const Divider(),
        for (final fee in record.fees) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Text(
                      fee.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      fee.amount,
                      style: const TextStyle(
                        color: detailsBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (fee.optional) const Text('Optional fee'),
                if (fee.notes != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: const Text(
                      'Fee details & conditions',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          fee.notes!,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class GovernmentOfficesTab extends StatelessWidget {
  final GovernmentIdDetails record;
  const GovernmentOfficesTab({super.key, required this.record});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [OfficeContent(record: record)],
  );
}

class OfficeContent extends StatelessWidget {
  final GovernmentIdDetails record;
  const OfficeContent({super.key, required this.record});
  @override
  Widget build(BuildContext context) => record.offices.isEmpty
      ? const DetailMessage('No offices are linked to this Government ID yet.')
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final office in record.offices)
              DetailCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: detailsBlue),
                      const SizedBox(height: 8),
                      Text(
                        office.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        office.fullAddress.isEmpty
                            ? 'Address not available yet.'
                            : office.fullAddress,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Operating hours',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (office.schedules.isEmpty)
                        const Text('Operating hours are not confirmed.'),
                      for (final day in office.schedules)
                        Text(
                          '${day.label}: ${day.hours}',
                          style: const TextStyle(height: 1.6),
                        ),
                      if (office.schedules.isNotEmpty)
                        const Text(
                          'Days not listed have no confirmed schedule.',
                          style: TextStyle(fontSize: 12),
                        ),
                      if (office.status != null)
                        Text(
                          'Office information status: ${office.status}',
                          style: const TextStyle(fontSize: 12, height: 1.6),
                        ),
                      if (office.services['service_notes'] is String)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            office.services['service_notes'],
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                      for (final entry in office.services.entries.where(
                        (entry) => entry.key.endsWith('_status'),
                      ))
                        Text(
                          '${entry.key.replaceAll('_status', '').replaceAll('_', ' ')}: ${entry.value == 'unknown' ? 'Availability not confirmed' : entry.value}',
                          style: const TextStyle(fontSize: 12, height: 1.6),
                        ),
                      if (office.notes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(office.notes!),
                        ),
                      if (office.hasCoordinates)
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GovernmentIdMap(office: office),
                            ),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('View map & directions'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
}

class GovernmentGuideTab extends StatelessWidget {
  final GovernmentIdDetails record;
  final List<ApplicationStep>? evaluatedSteps;
  final List<ApplicationStep> pendingSteps;
  final List<RequirementSet> evaluatedRequirements, pendingRequirements;
  final Widget? applicationCard;
  final int? scenarioId;
  final ValueChanged<int>? onScenarioChanged;
  const GovernmentGuideTab({
    super.key,
    required this.record,
    this.scenarioId,
    this.onScenarioChanged,
    this.evaluatedSteps,
    this.pendingSteps = const [],
    this.evaluatedRequirements = const [],
    this.pendingRequirements = const [],
    this.applicationCard,
  });
  @override
  Widget build(BuildContext context) {
    if (evaluatedSteps != null) {
      final profiles = [...evaluatedRequirements, ...pendingRequirements];
      return ListView(
        key: ValueKey(('evaluated-guide', record.id)),
        padding: const EdgeInsets.all(18),
        children: [
          ?applicationCard,
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              '${record.name} Application Guide',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          if (evaluatedSteps!.isEmpty && pendingSteps.isEmpty)
            if (record.guides.every((guide) => guide.steps.isEmpty) &&
                [
                  record.applicationProcess,
                  record.renewalProcess,
                  record.replacementProcess,
                ].any((text) => text != null))
              ..._legacyContent()
            else
              const DetailMessage(
                'Application guide steps are not available for this application yet.',
              ),
          ..._timeline(
            context,
            evaluatedSteps!,
            evaluatedRequirements,
            'applicable',
          ),
          if (pendingSteps.isNotEmpty) ...[
            const Text(
              'Additional steps may apply',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text('Choose your situation to confirm these instructions.'),
            ..._timeline(context, pendingSteps, profiles, 'pending'),
          ],
        ],
      );
    }
    if (record.guides.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: _legacyContent(),
      );
    }
    final guide =
        record.guides.where((row) => row.id == scenarioId).firstOrNull ??
        record.guides.first;
    final requirements = record.requirementSets
        .where((row) => row.id == guide.id)
        .firstOrNull;
    return ListView(
      key: ValueKey(('guide', record.id, guide.id)),
      padding: const EdgeInsets.all(18),
      children: [
        DetailCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: record.guides.length > 1
                ? DropdownButtonFormField<int>(
                    key: ValueKey(guide.id),
                    initialValue: guide.id,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(
                      labelText: 'Applicant / application',
                      border: InputBorder.none,
                    ),
                    items: record.guides
                        .map(
                          (row) => DropdownMenuItem(
                            value: row.id,
                            child: Text(row.label),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id != null) onScenarioChanged?.call(id);
                    },
                  )
                : Text(guide.label),
          ),
        ),
        if (guide.steps.isEmpty)
          const DetailMessage(
            'Application guide steps for this application are not available yet.',
          ),
        ..._timeline(
          context,
          guide.steps,
          requirements == null ? [] : [requirements],
          guide.id,
        ),
      ],
    );
  }

  List<Widget> _legacyContent() {
    final legacy = <String, String?>{
      'Application': record.applicationProcess,
      'Renewal': record.renewalProcess,
      'Replacement': record.replacementProcess,
    };
    return [
      if (legacy.values.every((text) => text == null))
        const DetailMessage('Application guide steps are not available yet.'),
      for (final entry in legacy.entries.where((entry) => entry.value != null))
        DetailCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(entry.value!),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _timeline(
    BuildContext context,
    List<ApplicationStep> steps,
    List<RequirementSet> profiles,
    Object scope,
  ) => [
    for (var i = 0; i < steps.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Stack(
          children: [
            if (i < steps.length - 1)
              Positioned(
                left: 14,
                top: 28,
                bottom: 0,
                child: Container(width: 1, color: const Color(0xFFCBD5E1)),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: detailsBlue,
                  foregroundColor: Colors.white,
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DetailCard(
                    child: ExpansionTile(
                      key: PageStorageKey((scope, record.id, steps[i].id, i)),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                      childrenPadding: const EdgeInsets.all(14),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(
                        steps[i].title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: steps[i].preview == null
                          ? null
                          : Text(
                              steps[i].preview!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      children: [
                        if (steps[i].instructions != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              steps[i].instructions!,
                              style: const TextStyle(height: 1.5),
                            ),
                          ),
                        for (final block in steps[i].blocks)
                          _block(
                            context,
                            block,
                            profiles
                                .where(
                                  (profile) =>
                                      steps[i].applicabilityProfileId == null ||
                                      profile.id ==
                                          steps[i].applicabilityProfileId,
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
  ];

  Widget _block(
    BuildContext context,
    GuideBlock block,
    List<RequirementSet> profiles,
  ) {
    final content = block.content;
    Widget body;
    switch (block.type) {
      case 'official_link':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (safeOfficialLink(content['url']))
              TextButton.icon(
                onPressed: () => openOfficialLink(context, content['url']),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  content['label'] is String
                      ? content['label']
                      : content['url'],
                ),
              ),
            if (content['description'] is String) Text(content['description']),
          ],
        );
      case 'instructions':
      case 'checklist':
        final items = content['items'] is List
            ? content['items'] as List
            : const [];
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(block.type == 'instructions' ? '${i + 1}. ' : '• '),
                  Expanded(
                    child: GuideRichContent(
                      items[i] is Map ? items[i]['body'] : items[i],
                    ),
                  ),
                ],
              ),
          ],
        );
      case 'requirements':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GuideRichContent(content['intro']),
            if (profiles.every((profile) => profile.groups.isEmpty) &&
                pendingRequirements.isEmpty)
              const DetailMessage(
                'No requirements are configured for this application.',
              ),
            if (pendingRequirements.isNotEmpty)
              const DetailMessage(
                'Additional requirements may apply. Choose your situation to confirm them.',
              ),
            for (final profile in profiles)
              for (final group in profile.groups)
                RequirementCard(
                  key: ValueKey((block.id, group.id)),
                  group: group,
                ),
          ],
        );
      case 'fees':
        body = Column(
          children: [
            GuideRichContent(content['intro']),
            FeeContent(record: record),
          ],
        );
      case 'offices':
        body = Column(
          children: [
            GuideRichContent(content['intro']),
            OfficeContent(record: record),
          ],
        );
      case 'processing_time':
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GuideRichContent(content['intro']),
            Text(
              record.processingTime ?? 'Processing time is not available yet.',
            ),
          ],
        );
      case 'text':
      case 'heading':
      case 'note':
      case 'warning':
      case 'reminder':
      case 'custom':
        body = GuideRichContent(content['body']);
      default:
        body = const DetailMessage('This content format is not supported yet.');
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ['warning', 'reminder'].contains(block.type)
            ? const Color(0xFFFFF7ED)
            : block.type == 'note'
            ? const Color(0xFFEFF6FF)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                block.title!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          body,
        ],
      ),
    );
  }
}
