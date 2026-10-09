import 'package:flutter/material.dart';
import '../../models/government_id.dart';

Color _accent(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFA8CCFA) : const Color(0xFF174B85);

class RequirementsTab extends StatefulWidget {
  final GovernmentIdDetails governmentId;
  const RequirementsTab({super.key, required this.governmentId});
  @override
  State<RequirementsTab> createState() => _RequirementsTabState();
}

class _RequirementsTabState extends State<RequirementsTab> {
  int? selectedSetId;
  @override
  void didUpdateWidget(covariant RequirementsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.governmentId.id != widget.governmentId.id) selectedSetId = null;
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.governmentId;
    final sets = record.requirementSets;
    final colors = Theme.of(context).colorScheme;
    if (sets.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text(record.requirements ?? 'Requirements are not available yet.',
          style: TextStyle(fontSize: 15, height: 1.65, color: colors.onSurface)),
      ]);
    }
    final selected = sets.where((set) => set.id == selectedSetId).firstOrNull ?? sets.first;
    return ListView(
      key: ValueKey(record.id),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final label = Text('Applying for', style: TextStyle(
            fontSize: 12, color: colors.onSurfaceVariant));
          final selector = sets.length > 1
              ? DropdownButtonFormField<int>(
                  initialValue: selected.id,
                  isExpanded: true,
                  isDense: false,
                  itemHeight: null,
                  iconSize: 18,
                  style: TextStyle(fontSize: 12, height: 1.4, color: colors.onSurface),
                  decoration: const InputDecoration(
                    isDense: true, filled: false,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none, enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(),
                  ),
                  items: sets.map((set) => DropdownMenuItem(
                    value: set.id,
                    child: Text(set.label, maxLines: 3, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) => setState(() { selectedSetId = value; }),
                )
              : Text(selected.label, style: TextStyle(
                  fontSize: 12, height: 1.4, color: colors.onSurface));
          final stack = constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(12) > 16;
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [label, const SizedBox(height: 4), selector],
            );
          }
          return Row(children: [
            label, const SizedBox(width: 10), Expanded(child: selector),
          ]);
        }),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Prepare each requirement below. Where choices are offered, only the stated number is needed.',
            style: TextStyle(fontSize: 13, height: 1.5, color: colors.onSurfaceVariant)),
        ),
        if (selected.groups.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 24),
            child: Text('Requirements for this application are not available yet.')),
        for (final group in selected.groups)
          _RequirementSection(key: ValueKey((selected.id, group.id)), group: group),
      ],
    );
  }
}

class _RequirementSection extends StatelessWidget {
  final RequirementGroup group;
  const _RequirementSection({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasAlternatives = group.ways.length > 1;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(
        bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.description_outlined, size: 18, color: _accent(context)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(group.displayName, style: TextStyle(
            fontSize: 16, height: 1.4, fontWeight: FontWeight.w600, color: colors.onSurface))),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (group.conditionType != 'always')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(group.condition == null
                    ? 'Conditional requirement — check when this applies.'
                    : 'Only if: ${group.condition}',
                  style: TextStyle(fontSize: 13, height: 1.5, color: colors.onSurfaceVariant)),
              ),
            if (hasAlternatives)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Meet one of these alternatives, not all of them.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: colors.onSurfaceVariant)),
              ),
            for (var index = 0; index < group.ways.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('OR', style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: _accent(context))),
                ),
              if (hasAlternatives)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Option ${index + 1}', style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: colors.onSurface)),
                ),
              _WayView(key: ValueKey((group.ways[index].id, index)),
                way: group.ways[index], heading: group.displayName,
                alternative: hasAlternatives),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _WayView extends StatelessWidget {
  final RequirementWay way;
  final String heading;
  final bool alternative;
  const _WayView({super.key, required this.way, required this.heading, required this.alternative});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isChoice = way.items.length > 1 && way.requiredCount < way.items.length;
    final collapseItems = isChoice || way.items.length > 3;
    final items = [
      for (final item in way.items)
        _ItemView(item: item,
          showName: alternative || way.items.length != 1 || item.name != heading,
          bullet: way.items.length > 1),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (way.items.length != 1 || alternative)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(way.instruction, style: TextStyle(fontSize: 13, height: 1.5,
            fontWeight: FontWeight.w600, color: _accent(context))),
        ),
      if (way.qualification != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(way.qualification!, style: TextStyle(
            fontSize: 13, height: 1.5, color: colors.onSurfaceVariant)),
        ),
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
                isChoice ? 'View ${way.items.length} accepted items'
                    : 'View all ${way.items.length} required items',
                style: TextStyle(fontSize: 13, height: 1.4,
                  fontWeight: FontWeight.w500, color: _accent(context)),
              ),
              children: items,
            ),
          ),
        )
      else
        ...items,
    ]);
  }
}

class _ItemView extends StatelessWidget {
  final RequirementItem item;
  final bool showName, bullet;
  const _ItemView({required this.item, required this.showName, required this.bullet});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final detailsStyle = TextStyle(fontSize: 13, height: 1.5, color: colors.onSurfaceVariant);
    if (!showName && item.quantity == null && item.submission == null && item.instructions == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (bullet) ...[
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Icon(Icons.circle, size: 4, color: colors.onSurfaceVariant)),
          const SizedBox(width: 8),
        ],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showName) Text(item.name, style: TextStyle(fontSize: 14, height: 1.5,
            fontWeight: FontWeight.w500, color: colors.onSurface)),
          if (item.quantity != null) Text('Quantity: ${item.quantity}', style: detailsStyle),
          if (item.submission != null) Text(item.submission!, style: detailsStyle),
          if (item.instructions != null) Text(item.instructions!, style: detailsStyle),
        ])),
      ]),
    );
  }
}
