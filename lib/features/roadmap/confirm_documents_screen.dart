import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../profile/manage_inventory_screen.dart';
import 'roadmap_widgets.dart';
import 'suggested_roadmap_screen.dart';
import 'id_journey.dart';

class ConfirmDocumentsScreen extends StatefulWidget {
  const ConfirmDocumentsScreen({
    super.key,
    this.targetIds = const ['Passport ID'],
    this.targetCatalogIds = const [],
    this.targetDocumentIds = const [],
    this.existingJourneys = const [],
  });
  final List<String> targetIds;
  final List<int> targetCatalogIds;
  final List<int> targetDocumentIds;
  final List<IdJourney> existingJourneys;
  @override
  State<ConfirmDocumentsScreen> createState() => _ConfirmDocumentsScreenState();
}

class _ConfirmDocumentsScreenState extends State<ConfirmDocumentsScreen> {
  List<({String type, int id, String name})> _owned = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _owned = [];
    });
    try {
      final data = await AuthService.instance.getInventory();
      final owned = <({String type, int id, String name})>[];
      for (final type in ['government_id', 'document']) {
        final rows =
            data[type == 'government_id' ? 'government_ids' : 'documents'];
        if (rows is! List) throw const FormatException('Invalid Inventory');
        for (final row in rows) {
          if (row is! Map ||
              row['id'] is! int ||
              row['name'] is! String ||
              row['owned'] is! bool) {
            throw const FormatException('Invalid Inventory item');
          }
          if (row['owned'] == true) {
            owned.add((
              type: type,
              id: row['id'] as int,
              name: row['name'] as String,
            ));
          }
        }
      }
      if (mounted) {
        setState(() {
          _owned = owned;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is AuthException
              ? error.message
              : 'Unable to load saved Inventory.';
        });
      }
    }
  }

  void _continue() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SuggestedRoadmapScreen(
        targetIds: widget.targetIds,
        targetCatalogIds: widget.targetCatalogIds,
        targetDocumentIds: widget.targetDocumentIds,
        ownedItems: _owned.map((item) => item.name).toList(),
        existingJourneys: widget.existingJourneys,
      ),
    ),
  );

  Widget _section(String title, String type) {
    final colors = Theme.of(context).colorScheme;
    final items = _owned.where((item) => item.type == type).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        RoadmapCard(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No saved items.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final (index, item) in items.indexed) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          color: colors.outlineVariant.withValues(alpha: .35),
                        ),
                      Padding(
                        key: ValueKey((item.type, item.id)),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            RoadmapRecordIcon(
                              document: type == 'document',
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const RoadmapStepHeader(
                      step: 'STEP 2 OF 3',
                      title: 'Confirm your current documents',
                      subtitle:
                          'Review your saved IDs and documents before we build your roadmap.',
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Your roadmap will cover: '),
                          TextSpan(
                            text: widget.targetIds.join(', '),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Loading saved Inventory…',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_error != null) ...[
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Retry Inventory'),
                      ),
                    ],
                    if (!_loading && _error == null) ...[
                      _section('Owned IDs', 'government_id'),
                      const SizedBox(height: 16),
                      _section('Owned Documents', 'document'),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ManageInventoryScreen(),
                          ),
                        );
                        if (mounted) await _load();
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Manage Inventory'),
                    ),
                  ],
                ),
              ),
            ),
            RoadmapBottomBar(
              action: ElevatedButton(
                onPressed: _loading || _error != null ? null : _continue,
                style: roadmapPrimaryButtonStyle(context),
                child: const Text('Save & Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
