import 'package:flutter/material.dart';

import '../../models/government_id.dart';
import 'detail_widgets.dart';

Color _accent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFA8CCFA)
    : const Color(0xFF174B85);

class RequirementsTab extends StatefulWidget {
  final GovernmentIdDetails governmentId;
  final List<RequirementSet>? evaluatedProfiles;
  final List<RequirementSet> pendingProfiles;
  final Widget? applicationCard;
  final int? scenarioId;
  final ValueChanged<int>? onScenarioChanged;
  const RequirementsTab({
    super.key,
    required this.governmentId,
    this.evaluatedProfiles,
    this.pendingProfiles = const [],
    this.applicationCard,
    this.scenarioId,
    this.onScenarioChanged,
  });
  @override
  State<RequirementsTab> createState() => _RequirementsTabState();
}

class _RequirementsTabState extends State<RequirementsTab> {
  int? selectedSetId;
  @override
  void didUpdateWidget(covariant RequirementsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.governmentId.id != widget.governmentId.id) {
      selectedSetId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.governmentId;
    if (widget.evaluatedProfiles != null) {
      return ListView(
        key: ValueKey(('evaluated-requirements', record.id)),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          if (widget.applicationCard != null) widget.applicationCard!,
          if (widget.evaluatedProfiles!.isEmpty &&
              widget.pendingProfiles.isEmpty)
            Text(
              record.requirementSets.isEmpty
                  ? record.requirements ?? 'Requirements are not available yet.'
                  : 'Choose your application details to see the relevant requirements.',
            ),
          for (final profile in widget.evaluatedProfiles!) ...[
            if (widget.evaluatedProfiles!.length > 1) Text(profile.label),
            if (profile.groups.isEmpty)
              const DetailMessage(
                'Requirements for this application are not available yet.',
              ),
            for (final group in profile.groups)
              RequirementCard(
                key: ValueKey((profile.id, group.id)),
                group: group,
              ),
          ],
          if (widget.pendingProfiles.isNotEmpty) ...[
            const Text(
              'Additional requirements may apply',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text('Choose your situation to confirm these requirements.'),
            for (final profile in widget.pendingProfiles)
              ExpansionTile(
                key: PageStorageKey(('pending-requirements', profile.id)),
                title: Text(profile.label),
                children: [
                  for (final group in profile.groups)
                    RequirementCard(group: group),
                ],
              ),
          ],
        ],
      );
    }
    final sets = record.requirementSets;
    final colors = Theme.of(context).colorScheme;
    if (sets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            record.requirements ?? 'Requirements are not available yet.',
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: colors.onSurface,
            ),
          ),
        ],
      );
    }
    final selected =
        sets
            .where((set) => set.id == (widget.scenarioId ?? selectedSetId))
            .firstOrNull ??
        sets.first;
    return ListView(
      key: ValueKey(record.id),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final label = Text(
              'Applying for',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            );
            final selector = sets.length > 1
                ? DropdownButtonFormField<int>(
                    key: ValueKey(selected.id),
                    initialValue: selected.id,
                    isExpanded: true,
                    isDense: false,
                    itemHeight: null,
                    iconSize: 18,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.onSurface,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: UnderlineInputBorder(),
                    ),
                    items: sets
                        .map(
                          (set) => DropdownMenuItem(
                            value: set.id,
                            child: Text(
                              set.label,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedSetId = value;
                        });
                        widget.onScenarioChanged?.call(value);
                      }
                    },
                  )
                : Text(
                    selected.label,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.onSurface,
                    ),
                  );
            final stack =
                constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(12) > 16;
            if (stack) {
              return DetailCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [label, const SizedBox(height: 4), selector],
                  ),
                ),
              );
            }
            return DetailCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    label,
                    const SizedBox(width: 10),
                    Expanded(child: selector),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Prepare each requirement below. Where choices are offered, only the stated number is needed.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        if (selected.groups.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'Requirements for this application are not available yet.',
            ),
          ),
        for (final group in selected.groups)
          RequirementCard(key: ValueKey((selected.id, group.id)), group: group),
      ],
    );
  }
}

class RequirementCard extends StatelessWidget {
  final RequirementGroup group;
  const RequirementCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasAlternatives = group.ways.length > 1;
    return DetailCard(
      child: ExpansionTile(
        key: key,
        initiallyExpanded: group.ways.length == 1,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: detailsBlue,
        leading: const CircleAvatar(
          radius: 14,
          backgroundColor: detailsBlue,
          child: Icon(Icons.fact_check_outlined, size: 17, color: Colors.white),
        ),
        title: Text(
          group.displayName,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.conditionType != 'always')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  group.condition == null
                      ? 'Conditional requirement — check when this applies.'
                      : 'Only if: ${group.condition}',
                  style: const TextStyle(color: Color(0xFF9A3412), height: 1.5),
                ),
              ),
            if (hasAlternatives)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Choose one option. Meet one of these alternatives, not all of them.',
                ),
              ),
            for (var i = 0; i < group.ways.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: detailsBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (hasAlternatives)
                Text(
                  'Option ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (group.ways[i].items.length != 1 || hasAlternatives)
                Text(
                  group.ways[i].instruction,
                  style: const TextStyle(color: detailsBlue, height: 1.5),
                ),
              if (group.ways[i].qualification != null)
                Text(
                  group.ways[i].qualification!,
                  style: const TextStyle(height: 1.5),
                ),
            ],
          ],
        ),
        children: [
          for (var i = 0; i < group.ways.length; i++) ...[
            if (hasAlternatives)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Option ${i + 1} documents',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            _WayView(
              key: ValueKey((group.ways[i].id, i)),
              way: group.ways[i],
              heading: group.displayName,
              alternative: hasAlternatives,
            ),
          ],
        ],
      ),
    );
  }
}

class _WayView extends StatelessWidget {
  final RequirementWay way;
  final String heading;
  final bool alternative;
  const _WayView({
    super.key,
    required this.way,
    required this.heading,
    required this.alternative,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isChoice =
        way.items.length > 1 && way.requiredCount < way.items.length;
    final collapseItems = isChoice || way.items.length > 3;
    final items = [
      for (final item in way.items)
        _ItemView(
          item: item,
          showName:
              alternative || way.items.length != 1 || item.name != heading,
          bullet: way.items.length > 1,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (collapseItems)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: _accent(context),
                collapsedIconColor: _accent(context),
                title: Text(
                  isChoice
                      ? 'View ${way.items.length} accepted items'
                      : 'View all ${way.items.length} required items',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: _accent(context),
                  ),
                ),
                children: items,
              ),
            ),
          )
        else
          ...items,
      ],
    );
  }
}

class _ItemView extends StatelessWidget {
  final RequirementItem item;
  final bool showName, bullet;
  const _ItemView({
    required this.item,
    required this.showName,
    required this.bullet,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final detailsStyle = TextStyle(
      fontSize: 13,
      height: 1.5,
      color: colors.onSurfaceVariant,
    );
    if (!showName &&
        item.quantity == null &&
        item.submission == null &&
        item.instructions == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bullet) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(
                Icons.circle,
                size: 4,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName)
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                if (item.quantity != null)
                  Text('Quantity: ${item.quantity}', style: detailsStyle),
                if (item.submission != null)
                  Text(item.submission!, style: detailsStyle),
                if (item.instructions != null)
                  Text(item.instructions!, style: detailsStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
