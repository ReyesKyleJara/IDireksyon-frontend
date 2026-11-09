import 'dart:async';

import 'package:flutter/material.dart';

import 'id_details_screen.dart';
import '../../models/government_id.dart';
import '../../core/theme/app_theme.dart';
import '../../core/auth/auth_service.dart';
import '../../services/application_preparation.dart';
import '../../services/requirement_readiness.dart';

Color _accent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFA8CCFA)
    : AppTheme.primaryBlue;

class RequirementsTab extends StatefulWidget {
  final GovernmentIdDetails governmentId;
  final Future<Map<String, dynamic>> Function()? loadInventory;
  final Future<Map<String, dynamic>> Function()? loadPreparation;
  final Future<Map<String, dynamic>> Function(int itemId, bool prepared)?
  savePreparation;
  const RequirementsTab({
    super.key,
    required this.governmentId,
    this.loadInventory,
    this.loadPreparation,
    this.savePreparation,
  });
  @override
  State<RequirementsTab> createState() => _RequirementsTabState();
}

/// Assistance remains explanatory content, outside the saved application checklist.
class AssistanceRequirements extends StatelessWidget {
  final GovernmentIdDetails record;
  const AssistanceRequirements({super.key, required this.record});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final set in record.requirementSets)
        for (final group in set.groups)
          _RequirementSection(group: group, checklist: false),
    ],
  );
}

class _RequirementsTabState extends State<RequirementsTab> {
  late final AuthService _auth = AuthService.instance;
  RequirementReadiness? _inventory;
  ApplicationPreparation? _preparation;
  bool _loading = false,
      _saving = false,
      _loadError = false,
      _inventoryError = false;
  int _generation = 0, _revision = -1, _inventoryRevision = -1;
  String? _session;

  @override
  void initState() {
    super.initState();
    _session = _auth.token;
    _revision = _auth.preparationRevision;
    _inventoryRevision = _auth.inventoryRevision;
    _auth.addListener(_authChanged);
    unawaited(_load());
  }

  void _authChanged() {
    if (_session == _auth.token &&
        _revision == _auth.preparationRevision &&
        _inventoryRevision == _auth.inventoryRevision) {
      return;
    }
    final changedSession = _session != _auth.token;
    _session = _auth.token;
    _revision = _auth.preparationRevision;
    _inventoryRevision = _auth.inventoryRevision;
    if (!_saving || changedSession) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant RequirementsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.governmentId.id != widget.governmentId.id ||
        oldWidget.governmentId.recordType != widget.governmentId.recordType) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _generation++;
    _auth.removeListener(_authChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final record = widget.governmentId;
    final canLoad = widget.loadPreparation != null || _auth.token != null;
    setState(() {
      _preparation = null;
      _inventory = null;
      _loading = canLoad;
      _saving = false;
      _loadError = false;
      _inventoryError = false;
    });
    await Future.wait([
      if (canLoad)
        (() async {
          try {
            final data =
                await (widget.loadPreparation?.call() ??
                    _auth.getRequirementPreparation(
                      record.recordType,
                      record.id,
                    ));
            final parsed = ApplicationPreparation.fromJson(data);
            if (mounted && generation == _generation) {
              setState(() => _preparation = parsed);
            }
          } catch (_) {
            if (mounted && generation == _generation) {
              setState(() => _loadError = true);
            }
          }
        })(),
      if (widget.loadInventory != null || _auth.token != null)
        (() async {
          try {
            final data =
                await (widget.loadInventory?.call() ?? _auth.getInventory());
            final parsed = RequirementReadiness.fromInventory(data);
            if (mounted && generation == _generation) {
              setState(() => _inventory = parsed);
            }
          } catch (_) {
            if (mounted && generation == _generation) {
              setState(() => _inventoryError = true);
            }
          }
        })(),
    ]);
    if (mounted && generation == _generation) setState(() => _loading = false);
  }

  Future<void> _toggle(RequirementItem item) async {
    final before = _preparation;
    if (_saving || before == null || item.id == null) return;
    final generation = _generation;
    final prepared = before.owns(item);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 420),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        titleTextStyle: const TextStyle(
          fontFamily: 'Google Sans',
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: AppTheme.navy,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Google Sans',
          fontSize: 14,
          height: 1.5,
          color: Color(0xFF42556C),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          prepared ? 'Remove from checklist?' : 'Confirm requirement',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prepared
                  ? 'This requirement will no longer count toward your readiness for this application.'
                  : 'Are you sure you already have this requirement and want to mark it as prepared for this application?',
            ),
            if (prepared && _inventory?.owns(item) == true) ...[
              const SizedBox(height: 12),
              const Text(
                'This requirement is already added to your Own IDs/Documents. Unchecking it only removes it from this application’s checklist.',
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              prepared ? 'Your saved Inventory will not be changed.' : 'This only updates your checklist for this application. It will not change your saved Inventory.',
              style: const TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF607089),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF42556C),
              textStyle: const TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              prepared ? 'Remove from checklist' : 'Yes, mark as prepared',
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || generation != _generation) return;
    final record = widget.governmentId;
    setState(() {
      _preparation = before.withItem(item.id!, !prepared);
      _saving = true;
    });
    try {
      final data =
          await (widget.savePreparation?.call(item.id!, !prepared) ??
              _auth.saveRequirementPreparation(
                record.recordType,
                record.id,
                item.id!,
                !prepared,
              ));
      final saved = ApplicationPreparation.fromJson(data);
      if (saved.owns(item) != !prepared) {
        throw const FormatException('Unsaved selection');
      }
      if (mounted && generation == _generation) {
        setState(() => _preparation = saved);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _preparation = before);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your checklist. Your previous selection was restored. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.governmentId;
    final sets = record.requirementSets;
    final colors = Theme.of(context).colorScheme;
    if (sets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(record.requirements ?? 'Requirements are not available yet.'),
        ],
      );
    }
    final selected = sets.first;
    final preparation = _preparation;
    final canSave =
        preparation != null &&
        !_saving &&
        (widget.savePreparation != null || _auth.token != null);
    return ListView(
      key: ValueKey((record.recordType, record.id)),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Choose the requirements you have prepared for this application.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: colors.onSurfaceVariant,
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Loading saved checklist…',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (_loadError)
          TextButton(
            onPressed: _load,
            child: const Text('Could not load your checklist. Retry'),
          ),
        if (_inventoryError)
          TextButton(
            onPressed: _load,
            child: const Text('Could not load Inventory availability. Retry'),
          ),
        if (_auth.token == null && widget.loadPreparation == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Sign in to save your checklist.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (preparation != null && selected.groups.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _saving
                  ? 'Saving…'
                  : '${preparationSummary(selected, preparation).complete} of ${preparationSummary(selected, preparation).total} required groups prepared',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _accent(context),
              ),
            ),
          ),
        if (selected.groups.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Requirements for this application are not available yet.',
            ),
          ),
        for (final group in selected.groups)
          _RequirementSection(
            key: ValueKey((selected.id, group.id)),
            group: group,
            preparation: preparation,
            inventory: _inventory,
            onToggle: canSave ? _toggle : null,
          ),
        Container(
          key: const ValueKey('readiness-explanation'),
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accent(context).withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: _accent(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Items you own show “You have this” and stay unchecked until you confirm them for this application. Checklist changes do not change Inventory. Conditional and issuing-office checks still apply.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequirementSection extends StatelessWidget {
  final RequirementGroup group;
  final RequirementReadiness? inventory;
  final ApplicationPreparation? preparation;
  final Future<void> Function(RequirementItem)? onToggle;
  final bool checklist;
  const _RequirementSection({
    super.key,
    required this.group,
    this.inventory,
    this.preparation,
    this.onToggle,
    this.checklist = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = preparation?.group(group) ?? 0;
    final best = group.ways.fold<RequirementWay?>(
      null,
      (best, way) =>
          best == null ||
              (preparation?.way(way) ?? 0) > (preparation?.way(best) ?? 0)
          ? way
          : best,
    );
    final met = preparation != null && progress == 1;
    final count = best == null ? 0 : (progress * best.requiredCount).round();
    final status = met
        ? 'Requirement met'
        : count > 0
        ? '$count of ${best!.requiredCount} prepared'
        : 'Not yet complete';
    final statusColor = met
        ? (colors.brightness == Brightness.dark
              ? const Color(0xFF81C784)
              : AppTheme.completedGreen)
        : colors.onSurfaceVariant;
    final single =
        group.ways.length == 1 &&
        group.ways.single.items.length == 1 &&
        group.displayName == group.ways.single.items.single.name;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? colors.surfaceContainer
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!single)
            Text(
              group.displayName,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: _accent(context),
              ),
            ),
          if (checklist)
            Padding(
              padding: EdgeInsets.only(top: single ? 0 : 4, bottom: 6),
              child: Row(
                children: [
                  Icon(
                    met
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (group.conditionType != 'always')
            Text(
              group.condition == null
                  ? 'Check when this condition applies.'
                  : 'Only if: ${group.condition}',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colors.onSurfaceVariant,
              ),
            ),
          if (group.ways.length > 1)
            Text(
              'Meet one of these alternatives, not all of them.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colors.onSurfaceVariant,
              ),
            ),
          for (var i = 0; i < group.ways.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: colors.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _accent(context),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: colors.outlineVariant)),
                  ],
                ),
              ),
            if (group.ways.length > 1)
              Text(
                'Option ${i + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            _WayView(
              key: ValueKey((group.ways[i].id, i)),
              way: group.ways[i],
              alternative: group.ways.length > 1,
              inventory: inventory,
              preparation: preparation,
              onToggle: onToggle,
              checklist: checklist,
            ),
          ],
        ],
      ),
    );
  }
}

class _WayView extends StatelessWidget {
  final RequirementWay way;
  final bool alternative, checklist;
  final RequirementReadiness? inventory;
  final ApplicationPreparation? preparation;
  final Future<void> Function(RequirementItem)? onToggle;
  const _WayView({
    super.key,
    required this.way,
    required this.alternative,
    required this.checklist,
    this.inventory,
    this.preparation,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final choice = way.items.length > 1 && way.requiredCount < way.items.length;
    final items = [
      for (final item in way.items)
        _ItemView(
          item: item,
          inventory: inventory,
          preparation: preparation,
          checklist: checklist,
          onToggle: onToggle,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (way.items.length != 1 || alternative)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              way.instruction,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: _accent(context),
              ),
            ),
          ),
        if (way.qualification != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              way.qualification!,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        if (choice || way.items.length > 3)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            dense: true,
            visualDensity: VisualDensity.compact,
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: _accent(context),
            collapsedIconColor: _accent(context),
            title: Text(
              choice
                  ? 'View ${way.items.length} accepted items'
                  : 'View all ${way.items.length} required items',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _accent(context),
              ),
            ),
            children: items,
          )
        else
          ...items,
      ],
    );
  }
}

class _ItemView extends StatelessWidget {
  final RequirementItem item;
  final RequirementReadiness? inventory;
  final ApplicationPreparation? preparation;
  final bool checklist;
  final Future<void> Function(RequirementItem)? onToggle;
  const _ItemView({
    required this.item,
    this.inventory,
    this.preparation,
    required this.checklist,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final owned = inventory?.owns(item) == true;
    final checked = preparation?.owns(item) == true;
    final style = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: colors.onSurfaceVariant,
    );
    final linked =
        (item.type == 'document' && item.documentId != null) ||
        (item.type == 'government_id' && item.governmentIdId != null);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (checklist)
            SizedBox(
              width: 44,
              height: 44,
              child: Checkbox(
                key: ValueKey('prepare-item-${item.id}'),
                value: checked,
                activeColor: _accent(context),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                semanticLabel:
                    '${checked ? 'Unprepare' : 'Prepare'} ${item.name}',
                onChanged: onToggle == null || item.id == null
                    ? null
                    : (_) => onToggle!(item),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: checklist ? 12 : 4, bottom: 2),
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                if (owned)
                  const Text(
                    'You have this',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                      height: 1.3,
                    ),
                  ),
                if (item.quantity != null)
                  Text('Quantity: ${item.quantity}', style: style),
                if (item.submission != null)
                  Text(item.submission!, style: style),
                if (item.instructions != null)
                  Text(item.instructions!, style: style),
                if (linked)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IdDetailsScreen(
                          idName: item.name,
                          recordType: item.type,
                          governmentId: item.type == 'document'
                              ? item.documentId
                              : item.governmentIdId,
                        ),
                      ),
                    ),
                    child: Text('View ${item.name}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
