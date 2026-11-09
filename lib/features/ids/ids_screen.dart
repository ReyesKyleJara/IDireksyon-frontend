import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/catalog_image.dart';
import '../../core/widgets/page_header.dart';
import '../../models/government_id.dart';
import '../../services/api_service.dart';
import '../../services/requirement_readiness.dart';
import '../../services/checklist_readiness_summary.dart';
import '../../services/directory_suggestions.dart';
import '../roadmap/roadmap_widgets.dart';
import 'id_details_screen.dart';

class IdsScreen extends StatefulWidget {
  final bool documents;
  final String? initialFilter;
  // Pages opened from another page show a back arrow beside the title.
  final bool showBack;
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
    this.showBack = false,
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
  final _search = TextEditingController();
  String _filter = 'All';

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
    _search.dispose();
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

  /// The title of a single-category page; null on the main directory.
  String? get _categoryTitle => widget.documents
      ? 'Documents & Certifications'
      : widget.initialFilter == 'IDs'
      ? 'Government IDs'
      : null;

  Color get _border {
    final colors = Theme.of(context).colorScheme;
    return colors.brightness == Brightness.dark
        ? colors.outlineVariant.withValues(alpha: .35)
        : const Color(0xFFE3ECF7);
  }

  Color get _fill {
    final colors = Theme.of(context).colorScheme;
    return colors.brightness == Brightness.dark
        ? colors.surfaceContainer
        : Colors.white;
  }

  Widget _heading(String? title, [String? subtitle]) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        if (title != null && subtitle != null) const SizedBox(height: 4),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    ),
  );

  Widget _iconTile(IconData icon, {double size = 44}) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: accent, size: size * .52),
    );
  }

  Widget _picture(GovernmentIdDetails record, double size) => CatalogImage(
    url: record.imageUrl,
    size: size,
    fallback: _iconTile(_icon(record), size: size),
  );

  Widget _card({required Widget child, required VoidCallback onTap}) =>
      RoadmapCard(
        child: MotionInkWell(onTap: onTap, child: child),
      );

  Widget _chevron() => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Icon(
      Icons.chevron_right_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  /// Who issues it and what the guide offers, on one quiet line. The type is
  /// left out when the list only holds one type.
  String _meta(GovernmentIdDetails record) {
    final type = record.recordType == 'document' ? 'Document' : 'Government ID';
    final oneType = _filter == 'IDs' || _filter == 'Documents';
    return [
      if (!oneType || record.issuedBy == null) type,
      ?record.issuedBy,
      if (record.isInformational) 'Information only',
    ].join(' • ');
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
    final description = record.description;
    final secondary = TextStyle(
      fontSize: 13,
      height: 1.35,
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        onTap: () => _open(record),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _picture(record, 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (status != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: badgeForeground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(readiness!.message, style: secondary),
                    ] else ...[
                      if (description != null) ...[
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: secondary,
                        ),
                        const SizedBox(height: 5),
                      ],
                      Text(
                        _meta(record),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _chevron(),
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

  Widget _commonCard(GovernmentIdDetails record) => Tooltip(
    message: record.name,
    child: _card(
      onTap: () => _open(record),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _picture(record, 72),
            const SizedBox(height: 10),
            // Room for two lines keeps every tile the same height.
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(14) * 2.5,
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
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
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
  );

  /// Two per row, so every tile is visible without sideways scrolling.
  Widget _commonGrid(List<GovernmentIdDetails> common) => Column(
    children: [
      for (var i = 0; i < common.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(child: _commonCard(common[i])),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < common.length
                    ? _commonCard(common[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
    ],
  );

  void _browse(List<GovernmentIdDetails> records, bool documents) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: IdsScreen(
            documents: documents,
            initialFilter: documents ? 'Documents' : 'IDs',
            showBack: true,
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

  Widget _category(List<GovernmentIdDetails> records, bool documents) {
    final colors = Theme.of(context).colorScheme;
    final type = documents ? 'document' : 'government_id';
    final count = records.where((r) => r.recordType == type).length;
    final noun = documents ? 'document' : 'ID';
    final about = documents
        ? 'Certificates, clearances & civil records'
        : 'Identity, travel & driving';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        onTap: () => _browse(records, documents),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _iconTile(
                documents ? Icons.folder_outlined : Icons.badge_outlined,
              ),
              const SizedBox(width: 12),
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      about,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$count $noun${count == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _chevron(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(ColorScheme colors) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Search IDs, documents, or agencies',
        hintStyle: const TextStyle(fontSize: 14),
        filled: true,
        fillColor: _fill,
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded, color: colors.primary),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () => setState(_search.clear),
                icon: const Icon(Icons.cancel_rounded, size: 20),
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        enabledBorder: border(_border),
        focusedBorder: border(colors.primary),
        border: border(_border),
      ),
    );
  }

  Widget _filters(ColorScheme colors) => Wrap(
    spacing: 8,
    children: [
      for (final filter in ['All', 'IDs', 'Documents'])
        ChoiceChip(
          label: Text(
            filter,
            style: TextStyle(
              fontSize: 13,
              fontWeight: _filter == filter ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          selected: _filter == filter,
          showCheckmark: false,
          selectedColor: AppTheme.accentGold,
          backgroundColor: _fill,
          labelStyle: TextStyle(
            color: _filter == filter ? AppTheme.navy : colors.onSurfaceVariant,
          ),
          side: BorderSide(
            color: _filter == filter ? AppTheme.accentGold : _border,
          ),
          shape: const StadiumBorder(),
          onSelected: (_) {
            _refreshInventory();
            setState(() => _filter = filter);
          },
        ),
    ],
  );

  /// A loading failure or empty list that says what to do next.
  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    String? action,
    VoidCallback? onAction,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 42, color: colors.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ],
      ),
    );
  }

  void _retry() {
    final request = _load();
    setState(() {
      _catalog = request;
    });
    if (_inventory != null) unawaited(_loadCandidateDetails());
    _refreshInventory();
  }

  Widget _noResults(bool searching) {
    if (searching) {
      return _message(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        body: 'Check the spelling, or try searching by agency.',
        action: 'Clear search',
        onAction: () => setState(_search.clear),
      );
    }
    return _message(
      icon: Icons.folder_off_outlined,
      title: 'Nothing here yet',
      body: 'Please check back soon.',
    );
  }

  String _resultsTitle() => switch (_filter) {
    'IDs' => 'Government IDs',
    'Documents' => 'Documents & Certifications',
    _ => _filter,
  };

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<GovernmentIdDetails>>(
    future: _catalog,
    builder: (context, snapshot) {
      final records = snapshot.data ?? [];
      final query = _search.text.trim().toLowerCase();
      final categoryTitle = _categoryTitle;
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
      final title = categoryTitle ?? 'ID Directory';
      final intro = categoryTitle != null
          ? 'Tap one to see what you need and where to get it.'
          : 'Find an ID or document, then see what you need and where to get it.';
      final resultCount =
          '${visible.length} ${visible.length == 1 ? 'result' : 'results'}';
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showBack) BackPageHeader(title, subtitle: intro),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    widget.showBack ? 14 : 22,
                    20,
                    20,
                  ),
                  children: [
                    if (!widget.showBack) ...[
                      PageHeader(title),
                      const SizedBox(height: 4),
                      Text(
                        intro,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _searchField(colors),
                    // A category page already holds a single type of record.
                    if (categoryTitle == null) ...[
                      const SizedBox(height: 12),
                      _filters(colors),
                    ],
                    if (snapshot.connectionState != ConnectionState.done) ...[
                      const SizedBox(height: 24),
                      const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 10),
                      Text(
                        'Loading directory…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ] else if (snapshot.hasError) ...[
                      _message(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load the ID directory.',
                        body: 'Check your internet connection and try again.',
                        action: 'Retry',
                        onAction: _retry,
                      ),
                    ] else if (browsing) ...[
                      if (visible.isEmpty)
                        _noResults(query.isNotEmpty)
                      else ...[
                        _heading(
                          query.isNotEmpty
                              ? 'Search results'
                              : categoryTitle != null
                              ? null
                              : _resultsTitle(),
                          resultCount,
                        ),
                        for (final record in visible) _row(record),
                      ],
                    ] else ...[
                      if (suggestions.isNotEmpty) ...[
                        _heading(
                          'Suggested for You',
                          'Based on the documents saved in your Inventory.',
                        ),
                        for (final record in suggestions.take(3))
                          _row(record, suggestion: true),
                      ],
                      _heading('Commonly Needed', 'Good places to start.'),
                      if (common.isEmpty)
                        Text(
                          'No commonly needed guides are available yet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      _commonGrid(common),
                      _heading(
                        'Browse by Category',
                        'See everything in the directory.',
                      ),
                      _category(records, false),
                      _category(records, true),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
