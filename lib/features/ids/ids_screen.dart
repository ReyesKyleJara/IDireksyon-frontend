import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';
import '../../models/government_id.dart';
import '../../services/api_service.dart';
import '../../services/requirement_readiness.dart';
import '../../services/checklist_readiness_summary.dart';
import '../../services/directory_suggestions.dart';
import 'id_details_screen.dart';

class IdsScreen extends StatefulWidget {
  final bool documents;
  final String? initialFilter;
  // An injected loader supplies the complete catalog in widget tests.
  final Future<List<GovernmentIdDetails>> Function()? loadIds;
  final Future<GovernmentIdDetails> Function(int)? loadDetail;
  // Typed loader also keeps same-number ID/document records distinct in tests.
  final Future<GovernmentIdDetails> Function(String, int)? loadRecordDetail;
  final Future<Map<String, dynamic>> Function()? loadInventory;

  const IdsScreen({
    super.key,
    this.documents = false,
    this.initialFilter,
    this.loadIds,
    this.loadDetail,
    this.loadRecordDetail,
    this.loadInventory,
  });

  @override
  State<IdsScreen> createState() => _IdsScreenState();
}

class _IdsScreenState extends State<IdsScreen> {
  late Future<List<GovernmentIdDetails>> _catalog;
  late final AuthService _auth;
  RequirementReadiness? _inventory;
  bool _inventoryLoading = false;
  int _inventoryRequest = 0;
  final _detailRequests = <(String, int), Future<GovernmentIdDetails>>{};
  final _candidateDetails = <(String, int), GovernmentIdDetails>{};
  int _revision = -1;
  String? _token;
  String _search = '';
  String _filter = 'All';
  static const _blue = AppTheme.primaryBlue;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? (widget.documents ? 'Documents' : 'All');
    _catalog = _load();
    _auth = AuthService.instance;
    _auth.addListener(_refreshInventory);
    _refreshInventory();
  }

  Future<List<GovernmentIdDetails>> _load() async {
    if (widget.loadIds != null) return widget.loadIds!();
    final catalogs = await Future.wait([
      ApiService.getGovernmentIds(),
      ApiService.getDocuments(),
    ]);
    return catalogs.expand((rows) => rows).toList();
  }

  void _refreshInventory() {
    final unchanged =
        _revision == _auth.inventoryRevision && _token == _auth.token;
    // A failed request is retryable on the next interaction, even without an
    // inventory revision. Successful and in-flight requests are not repeated.
    if (unchanged && (_inventory != null || _inventoryLoading)) return;
    _revision = _auth.inventoryRevision;
    _token = _auth.token;
    unawaited(_loadInventory());
  }

  Future<void> _loadInventory() async {
    final request = ++_inventoryRequest;
    _inventoryLoading = true;
    if (mounted) setState(() => _inventory = null);
    try {
      if (widget.loadInventory == null && _token == null) return;
      final data = await (widget.loadInventory?.call() ?? _auth.getInventory());
      final inventory = RequirementReadiness.fromInventory(data);
      if (mounted && request == _inventoryRequest) {
        setState(() => _inventory = inventory);
        unawaited(_loadCandidateDetails());
      }
    } catch (_) {
      // Missing personal readiness never prevents catalog browsing.
    } finally {
      if (request == _inventoryRequest) _inventoryLoading = false;
    }
  }

  List<GovernmentIdDetails> _candidates(List<GovernmentIdDetails> records) =>
      suggestionCandidates(records, _inventory);

  Future<GovernmentIdDetails> _detailFor(GovernmentIdDetails record) {
    final key = (record.recordType, record.id);
    return _detailRequests.putIfAbsent(key, () => _fetchDetail(record));
  }

  Future<GovernmentIdDetails> _fetchDetail(GovernmentIdDetails record) async {
    final key = (record.recordType, record.id);
    try {
      final detail = await Future.sync(
        () =>
            widget.loadRecordDetail?.call(record.recordType, record.id) ??
            widget.loadDetail?.call(record.id) ??
            (record.recordType == 'document'
                ? ApiService.getDocument(record.id)
                : ApiService.getGovernmentId(record.id)),
      );
      if (detail.id != record.id || detail.recordType != record.recordType) {
        throw const FormatException('Mismatched directory detail');
      }
      return detail;
    } catch (_) {
      _detailRequests.remove(key);
      rethrow;
    }
  }

  Future<void> _loadCandidateDetails() async {
    try {
      final catalogRequest = _catalog;
      final records = await catalogRequest;
      if (!mounted || _inventory == null || catalogRequest != _catalog) return;
      await Future.wait(
        _candidates(records).map((record) async {
          try {
            final detail = await _detailFor(record);
            if (mounted && catalogRequest == _catalog) {
              setState(
                () =>
                    _candidateDetails[(record.recordType, record.id)] = detail,
              );
            }
          } catch (_) {
            // One unavailable guide must not discard other useful suggestions.
          }
        }),
      );
    } catch (_) {
      // The catalog already owns its loading/error UI.
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_refreshInventory);
    super.dispose();
  }

  bool _supported(GovernmentIdDetails record) => isSupportedRecord(record);

  ChecklistReadinessSummary? _readiness(GovernmentIdDetails record) =>
      suggestionReadiness(
        record,
        _candidateDetails[(record.recordType, record.id)],
        _inventory,
      );

  void _open(GovernmentIdDetails record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IdDetailsScreen(
          idName: record.name,
          governmentId: record.id,
          recordType: record.recordType,
          loadDetail: (_) => _detailFor(record),
        ),
      ),
    );
    if (mounted) _refreshInventory();
  }

  IconData _icon(GovernmentIdDetails record) => record.recordType == 'document'
      ? Icons.description_outlined
      : Icons.badge_outlined;

  Widget _heading(String title, [String? subtitle]) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );

  Color _accent(bool documents) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFFA8CCFA) : _blue;
  }

  Widget _iconTile(IconData icon, bool documents) {
    final accent = _accent(documents);
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }

  Widget _surface({
    required Widget child,
    required VoidCallback onTap,
    Color? tint,
  }) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.brightness == Brightness.dark
        ? colors.surfaceContainer
        : Colors.white;
    return Material(
      color: tint == null
          ? base
          : Color.alphaBlend(tint.withValues(alpha: .035), base),
      elevation: colors.brightness == Brightness.dark ? 0 : .4,
      shadowColor: const Color(0x18174B85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: MotionInkWell(onTap: onTap, child: child),
    );
  }

  Widget _row(GovernmentIdDetails record, {bool suggestion = false}) {
    final colors = Theme.of(context).colorScheme;
    final readiness = suggestion ? _readiness(record) : null;
    final status = readiness?.status;
    final ready = readiness?.ready == true;
    final badgeBackground = ready
        ? AppTheme.completedGreen.withValues(alpha: .1)
        : AppTheme.accentGold;
    final badgeForeground = ready
        ? (colors.brightness == Brightness.dark
              ? const Color(0xFF81C784)
              : AppTheme.completedGreen)
        : AppTheme.navy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _surface(
        tint: null,
        onTap: () => _open(record),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              _iconTile(_icon(record), record.recordType == 'document'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (status != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBackground,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: badgeForeground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        readiness!.message,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ] else
                      Text(
                        record.recordType == 'document'
                            ? 'Document • ${record.issuedBy ?? 'Certification'}'
                            : 'Government ID${record.issuedBy == null ? '' : ' • ${record.issuedBy}'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortName(GovernmentIdDetails record) {
    final name = record.name.toLowerCase();
    if (name.contains('national id')) return 'National ID';
    if (name.contains('passport')) return 'Passport';
    if (name.contains('nbi')) return 'NBI Clearance';
    if (name.contains('birth certificate')) return 'Birth Certificate';
    return record.name;
  }

  Widget _commonCard(GovernmentIdDetails record) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: SizedBox(
      width: 82,
      child: Tooltip(
        message: record.name,
        child: _surface(
          tint: _accent(record.recordType == 'document'),
          onTap: () => _open(record),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
            child: Column(
              children: [
                Icon(
                  _icon(record),
                  color: _accent(record.recordType == 'document'),
                  size: 22,
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(11) * 2.5,
                  child: Center(
                    child: Semantics(
                      label: record.name,
                      excludeSemantics: true,
                      child: Text(
                        _shortName(record),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  void _browse(List<GovernmentIdDetails> records, bool documents) {
    final title = documents ? 'Documents & Certifications' : 'Government IDs';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: IdsScreen(
            documents: documents,
            initialFilter: documents ? 'Documents' : 'IDs',
            loadIds: () async => records
                .where(
                  (r) =>
                      r.recordType ==
                      (documents ? 'document' : 'government_id'),
                )
                .toList(),
            loadDetail: widget.loadDetail,
            loadRecordDetail: (type, id) => _detailFor(
              records.firstWhere((r) => r.recordType == type && r.id == id),
            ),
            loadInventory: widget.loadInventory,
          ),
        ),
      ),
    );
  }

  Widget _category(List<GovernmentIdDetails> records, bool documents) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: _surface(
          tint: _accent(documents),
          onTap: () => _browse(records, documents),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                _iconTile(
                  documents ? Icons.folder_outlined : Icons.badge_outlined,
                  documents,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documents
                            ? 'Documents & Certifications'
                            : 'Government IDs',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        documents
                            ? 'Certificates, clearances & civil records'
                            : 'Identity, travel & driving',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<GovernmentIdDetails>>(
    future: _catalog,
    builder: (context, snapshot) {
      final records = snapshot.data ?? [];
      final query = _search.trim().toLowerCase();
      final browsing =
          query.isNotEmpty ||
          _filter != 'All' ||
          widget.initialFilter != null ||
          widget.documents;
      final visible = records.where((record) {
        if (widget.documents && record.recordType != 'document') return false;
        if (_filter == 'IDs' && record.recordType != 'government_id') {
          return false;
        }
        if (_filter == 'Documents' && record.recordType != 'document') {
          return false;
        }
        if (_filter == 'Ready Now' && _readiness(record)?.ready != true) {
          return false;
        }
        return [
          record.name,
          record.issuedBy ?? '',
          record.description ?? '',
        ].any((text) => text.toLowerCase().contains(query));
      }).toList();
      final suggestions = rankedSuggestions(records, _readiness);
      // Small editorial selection, always resolved against currently supported API records.
      final common = <GovernmentIdDetails>[];
      for (final term in [
        'national id',
        'passport',
        'nbi',
        'birth certificate',
      ]) {
        final matches = records.where(
          (r) => _supported(r) && r.name.toLowerCase().contains(term),
        );
        if (matches.isNotEmpty && !common.contains(matches.first)) {
          common.add(matches.first);
        }
      }
      final colors = Theme.of(context).colorScheme;
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            children: [
              Text(
                widget.documents
                    ? 'Documents & Certifications'
                    : 'ID Directory',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  hintText: 'Search IDs, documents, or agencies',
                  hintStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: _accent(false),
                  ),
                  filled: true,
                  fillColor: colors.brightness == Brightness.dark
                      ? colors.surfaceContainer
                      : _accent(false).withValues(alpha: .045),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: .35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _accent(true), width: 1.2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in [
                      'All',
                      'IDs',
                      'Documents',
                      'Ready Now',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: ChoiceChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _filter == filter
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          selected: _filter == filter,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          selectedColor: AppTheme.accentGold,
                          backgroundColor: colors.surface,
                          labelStyle: TextStyle(
                            color: _filter == filter
                                ? AppTheme.navy
                                : colors.onSurfaceVariant,
                          ),
                          side: BorderSide(
                            color: _filter == filter
                                ? _accent(true).withValues(alpha: .25)
                                : colors.outlineVariant.withValues(alpha: .45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) {
                            _refreshInventory();
                            setState(() => _filter = filter);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              if (snapshot.connectionState != ConnectionState.done) ...[
                const SizedBox(height: 24),
                const LinearProgressIndicator(minHeight: 2),
                const Text('Loading directory…'),
              ] else if (snapshot.hasError) ...[
                const SizedBox(height: 24),
                const Text('Could not load the ID directory.'),
                TextButton(
                  onPressed: () {
                    final request = _load();
                    setState(() {
                      _catalog = request;
                    });
                    if (_inventory != null) unawaited(_loadCandidateDetails());
                    _refreshInventory();
                  },
                  child: const Text('Retry'),
                ),
              ] else if (browsing) ...[
                _heading(
                  query.isNotEmpty
                      ? 'Search results'
                      : widget.documents
                      ? 'Documents & Certifications'
                      : _filter,
                ),
                if (_filter == 'Ready Now' && visible.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Based on saved inventory and the structured checklist. Confirm details in the guide.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                if (visible.isEmpty) const Text('No matching entries.'),
                for (final record in visible)
                  _row(record, suggestion: _filter == 'Ready Now'),
              ] else ...[
                if (suggestions.isNotEmpty) ...[
                  _heading(
                    'Suggested for You',
                    'Based on your profile and readiness.',
                  ),
                  for (final record in suggestions.take(3))
                    _row(record, suggestion: true),
                ],
                _heading('Commonly Needed'),
                if (common.isEmpty)
                  const Text(
                    'No commonly needed guides are available yet.',
                    style: TextStyle(fontSize: 12),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final record in common) _commonCard(record),
                    ],
                  ),
                ),
                _heading('Browse by Category'),
                _category(records, false),
                _category(records, true),
              ],
            ],
          ),
        ),
      );
    },
  );
}
