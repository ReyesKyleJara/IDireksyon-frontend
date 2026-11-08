import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';
import '../ids/ids_screen.dart';
import 'confirm_documents_screen.dart';
import 'id_journey.dart';
import 'roadmap_widgets.dart';
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

  @override
  State<BuildRoadmapScreen> createState() => _BuildRoadmapScreenState();
}

class _BuildRoadmapScreenState extends State<BuildRoadmapScreen> {
  // Keeps the order they were picked in; the server decides the final sequence.
  final _selected = <(String, int)>{};
  late Future<List<GovernmentIdDetails>> _catalog;
  final _searchController = TextEditingController();
  String _search = '';
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _catalog = _loadCandidates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _continue(List<GovernmentIdDetails> records) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmDocumentsScreen(
          targetIds: [for (final record in records) record.name],
          targetCatalogIds: [
            for (final record in records)
              if (record.recordType != 'document') record.id,
          ],
          targetDocumentIds: [
            for (final record in records)
              if (record.recordType == 'document') record.id,
          ],
          existingJourneys: widget.existingJourneys,
        ),
      ),
    );
  }

  void _openDirectory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('ID Directory')),
          body: const IdsScreen(),
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _search = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        bottom: false,
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
            final selected = [
              for (final key in _selected)
                ...records.where((r) => (r.recordType, r.id) == key),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _body(context, records)),
                _ContinueBar(
                  selected: selected,
                  onClear: () => setState(_selected.clear),
                  onContinue: selected.isEmpty
                      ? null
                      : () => _continue(selected),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<GovernmentIdDetails> records) {
    bool isDocument(GovernmentIdDetails r) => r.recordType == 'document';
    final mixed = records.any(isDocument) && records.any((r) => !isDocument(r));
    final visible = records
        .where(
          (record) =>
              record.name.toLowerCase().contains(_search) &&
              (_filter == 'All' ||
                  (_filter == 'Documents') == isDocument(record)),
        )
        .toList();
    final ids = visible.where((r) => !isDocument(r)).toList();
    final documents = visible.where(isDocument).toList();
    final grouped = ids.isNotEmpty && documents.isNotEmpty;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchHeader(
            controller: _searchController,
            hasText: _search.isNotEmpty,
            onChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
            onClear: _clearSearch,
          ),
          if (mixed) ...[
            const SizedBox(height: 14),
            _FilterChips(
              value: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
          ],
        ],
      ),
    );

    Widget row(GovernmentIdDetails record) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _TargetRow(
        record: record,
        selected: _selected.contains((record.recordType, record.id)),
        onTap: () => setState(() {
          final key = (record.recordType, record.id);
          if (!_selected.remove(key)) _selected.add(key);
        }),
      ),
    );

    // The pinned header would leave little room for the list on short screens
    // or at large text, so there it scrolls away with the list.
    final compact =
        MediaQuery.textScalerOf(context).scale(1) >= 1.4 ||
        MediaQuery.sizeOf(context).height < 700;

    final list = CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (compact) SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          sliver: SliverList.list(
            children: [
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    records.isEmpty
                        ? 'No acquisition targets are currently available for roadmap planning.'
                        : 'No matching IDs or documents.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (grouped) const _GroupLabel('Government IDs'),
              ...ids.map(row),
              if (grouped) const _GroupLabel('Documents', top: 10),
              ...documents.map(row),
              const SizedBox(height: 8),
              RoadmapDirectoryCard(onTap: _openDirectory),
            ],
          ),
        ),
      ],
    );

    if (compact) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: list),
      ],
    );
  }
}

/// The page title and search, on the same navy card as the Roadmap banner.
class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return RoadmapStepHeader(
      step: 'STEP 1 OF 3',
      title: 'Build My Roadmap',
      subtitle:
          'Choose the IDs or documents you want to get. You can pick more than one.',
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppTheme.navy, fontSize: 14),
        cursorColor: AppTheme.primaryBlue,
        decoration: InputDecoration(
          hintText: 'Search IDs or documents',
          hintStyle: const TextStyle(
            color: Color(0xFF5B6B7E),
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.navy,
          ),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.navy,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: noBorder,
          enabledBorder: noBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppTheme.accentGold,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// All / IDs / Documents, styled like IDirectory's filters.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final filter in const ['All', 'IDs', 'Documents'])
          ChoiceChip(
            label: Text(
              filter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: value == filter ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            selected: value == filter,
            showCheckmark: false,
            selectedColor: AppTheme.accentGold,
            backgroundColor: colors.surface,
            labelStyle: TextStyle(
              color: value == filter ? AppTheme.navy : colors.onSurfaceVariant,
            ),
            onSelected: (_) => onChanged(filter),
          ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label, {this.top = 0});

  final String label;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.selected,
    required this.onClear,
    required this.onContinue,
  });

  final List<GovernmentIdDetails> selected;
  final VoidCallback onClear;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final names = selected.map((record) => record.name).join(', ');
    return RoadmapBottomBar(
      note: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text.rich(
                selected.isEmpty
                    ? const TextSpan(
                        text: 'Select one or more IDs or documents to continue',
                      )
                    : TextSpan(
                        children: [
                          TextSpan(
                            text: selected.length == 1
                                ? 'Selected: '
                                : '${selected.length} selected: ',
                          ),
                          TextSpan(
                            text: names,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (selected.isNotEmpty)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Clear'),
            ),
        ],
      ),
      action: ElevatedButton(
        onPressed: onContinue,
        style: roadmapPrimaryButtonStyle(context),
        child: const Text('Continue'),
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
    final dark = colors.brightness == Brightness.dark;
    final document = record.recordType == 'document';
    final issuer = record.issuedBy?.trim();
    final shape = BorderRadius.circular(16);
    return Semantics(
      selected: selected,
      checked: selected,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: dark ? .14 : .07)
            : dark
            ? colors.surfaceContainer
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(
            width: selected ? 1.5 : 1,
            color: selected
                ? colors.primary
                : dark
                ? colors.outlineVariant.withValues(alpha: .35)
                : const Color(0xFFE3ECF7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: MotionInkWell(
          onTap: onTap,
          borderRadius: shape,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                RoadmapRecordIcon(document: document),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        issuer == null || issuer.isEmpty
                            ? (document ? 'Document' : 'Government ID')
                            : issuer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
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
