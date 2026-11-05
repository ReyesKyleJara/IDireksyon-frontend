import 'package:flutter/material.dart';

import '../ids/ids_screen.dart';
import 'confirm_documents_screen.dart';
import 'id_journey.dart';
import '../../models/government_id.dart';
import '../../services/api_service.dart';

class BuildRoadmapScreen extends StatefulWidget {
  const BuildRoadmapScreen({
    super.key,
    this.existingJourneys = const [],
    this.loadIds,
  });
  final List<IdJourney> existingJourneys;
  final Future<List<GovernmentIdDetails>> Function()? loadIds;
  static const primaryBlue = Color(0xFF12499A);

  @override
  State<BuildRoadmapScreen> createState() => _BuildRoadmapScreenState();
}

class _BuildRoadmapScreenState extends State<BuildRoadmapScreen> {
  (String, int)? _selected;
  late Future<List<GovernmentIdDetails>> _catalog;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _catalog = _loadCandidates();
  }

  Future<List<GovernmentIdDetails>> _loadCandidates() async {
    final records = widget.loadIds != null
        ? await widget.loadIds!()
        : (await Future.wait([
            ApiService.getGovernmentIds(),
            ApiService.getDocuments(),
          ])).expand((rows) => rows).toList();
    return records
        .where(
          (record) =>
              record.includeInSmartSequencing &&
              record.guidanceMode == 'guided' &&
              [
                'available',
                'limited_conditional',
              ].contains(record.applicationAvailability),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<GovernmentIdDetails>>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load roadmap candidates.'),
                    TextButton(
                      onPressed: () => setState(() {
                        _catalog = _loadCandidates();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final records = snapshot.data ?? [];
            final visible = records
                .where((record) => record.name.toLowerCase().contains(_search))
                .toList();
            final selected = records
                .where((record) => _selected == (record.recordType, record.id))
                .toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Build My Roadmap',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose the government ID or document you want to acquire.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search government ID or document...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: colors.primary.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        records.isEmpty
                            ? 'No acquisition targets are currently available for roadmap planning.'
                            : 'No matching IDs or documents.',
                      ),
                    ),
                  for (final record in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TargetRow(
                        record: record,
                        selected: _selected == (record.recordType, record.id),
                        onTap: () => setState(() {
                          _selected = (record.recordType, record.id);
                        }),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.manage_search_rounded,
                          color: colors.primary,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Not sure what to apply for?',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Browse available government IDs and guides',
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(
                                        title: const Text('ID Directory'),
                                      ),
                                      body: const IdsScreen(),
                                    ),
                                  ),
                                ),
                                child: const Text('Open ID Directory'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ConfirmDocumentsScreen(
                                targetIds: selected
                                    .map((record) => record.name)
                                    .toList(),
                                targetCatalogIds: selected
                                    .where(
                                      (record) =>
                                          record.recordType == 'government_id',
                                    )
                                    .map((record) => record.id)
                                    .toList(),
                                targetDocumentIds: selected
                                    .where(
                                      (record) =>
                                          record.recordType == 'document',
                                    )
                                    .map((record) => record.id)
                                    .toList(),
                                existingJourneys: widget.existingJourneys,
                              ),
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: BuildRoadmapScreen.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.record,
    required this.selected,
    required this.onTap,
  });
  final GovernmentIdDetails record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final document = record.recordType == 'document';
    return Semantics(
      selected: selected,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.06)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  document ? Icons.description_outlined : Icons.badge_outlined,
                  color: colors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        document ? 'Document' : 'Government ID',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
