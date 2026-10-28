import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../profile/manage_inventory_screen.dart';
import 'suggested_roadmap_screen.dart';
import 'id_journey.dart';

class ConfirmDocumentsScreen extends StatefulWidget {
  const ConfirmDocumentsScreen({
    super.key,
    this.targetIds = const ['Passport ID'],
    this.targetCatalogIds = const [],
    this.existingJourneys = const [],
  });
  final List<String> targetIds;
  final List<int> targetCatalogIds;
  final List<IdJourney> existingJourneys;
  static const primaryBlue = Color(0xFF12499A);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confirm your current\ndocuments',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'These are your saved Inventory items. Ownership can only be changed in Manage Inventory.',
            ),
            const SizedBox(height: 17),
            if (_loading) const Text('Loading saved Inventory…'),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _load,
                child: const Text('Retry Inventory'),
              ),
            ],
            if (!_loading && _error == null) ...[
              for (final type in ['government_id', 'document']) ...[
                Text(
                  type == 'government_id' ? 'Owned IDs' : 'Owned Documents',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final item in _owned.where((item) => item.type == type))
                  Card(
                    child: ListTile(
                      key: ValueKey((item.type, item.id)),
                      leading: Icon(
                        type == 'government_id'
                            ? Icons.badge_outlined
                            : Icons.description_outlined,
                      ),
                      title: Text(item.name),
                      trailing: const Icon(Icons.check_circle_outline),
                    ),
                  ),
                if (!_owned.any((item) => item.type == type))
                  const Text('No saved items.'),
                const SizedBox(height: 16),
              ],
            ],
            OutlinedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ManageInventoryScreen(),
                  ),
                );
                if (mounted) await _load();
              },
              child: const Text('Manage Inventory'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading || _error != null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SuggestedRoadmapScreen(
                          targetIds: widget.targetIds,
                          targetCatalogIds: widget.targetCatalogIds,
                          ownedItems: _owned.map((item) => item.name).toList(),
                          existingJourneys: widget.existingJourneys,
                        ),
                      ),
                    ),
              child: const Text('Save & Continue'),
            ),
            const Text(
              'Continue uses saved Inventory without changing ownership.',
            ),
          ],
        ),
      ),
    ),
  );
}
