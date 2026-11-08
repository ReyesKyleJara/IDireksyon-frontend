import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/catalog_image.dart';
import '../../models/government_id.dart';
import '../../services/api_service.dart';
import '../../services/directory_suggestions.dart';
import '../../services/requirement_readiness.dart';
import '../ids/id_details_screen.dart';
import '../roadmap/roadmap_widgets.dart';

/// "Recommended for you" cards, chosen from the live catalog by the same rules
/// as the ID Directory's suggestions: records the resident owns are left out,
/// and those closest to ready come first.
class HomeRecommendations extends StatefulWidget {
  const HomeRecommendations({
    super.key,
    this.loadCatalog,
    this.loadDetail,
    this.loadInventory,
  });

  // Injected loaders supply the data in widget tests.
  final Future<List<GovernmentIdDetails>> Function()? loadCatalog;
  final Future<GovernmentIdDetails> Function(GovernmentIdDetails)? loadDetail;
  final Future<Map<String, dynamic>> Function()? loadInventory;

  static const maxCards = 2;

  @override
  State<HomeRecommendations> createState() => _HomeRecommendationsState();
}

class _HomeRecommendationsState extends State<HomeRecommendations>
    with AutomaticKeepAliveClientMixin {
  late final AuthService _auth;
  late int _revision;
  String? _token;
  int _request = 0;
  List<GovernmentIdDetails>? _picks;
  bool _failed = false;

  // Scrolling away must not fetch the catalog again.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _auth = AuthService.instance;
    _revision = _auth.inventoryRevision;
    _token = _auth.token;
    _auth.addListener(_onAuthChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_revision == _auth.inventoryRevision && _token == _auth.token) return;
    _revision = _auth.inventoryRevision;
    _token = _auth.token;
    unawaited(_load());
  }

  Future<List<GovernmentIdDetails>> _catalog() async {
    if (widget.loadCatalog != null) return widget.loadCatalog!();
    final catalogs = await Future.wait([
      ApiService.getGovernmentIds(),
      ApiService.getDocuments(),
    ]);
    return catalogs.expand((rows) => rows).toList();
  }

  /// Null when unknown; recommendations still show without saved documents.
  Future<RequirementReadiness?> _inventory() async {
    try {
      if (widget.loadInventory == null && _auth.token == null) return null;
      final data = await (widget.loadInventory?.call() ?? _auth.getInventory());
      return RequirementReadiness.fromInventory(data);
    } catch (_) {
      return null;
    }
  }

  Future<GovernmentIdDetails?> _detail(GovernmentIdDetails record) async {
    try {
      if (widget.loadDetail != null) return await widget.loadDetail!(record);
      return await (record.recordType == 'document'
          ? ApiService.getDocument(record.id)
          : ApiService.getGovernmentId(record.id));
    } catch (_) {
      return null; // One unavailable guide must not hide the other picks.
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final records = await _catalog();
      final inventory = await _inventory();
      final candidates = suggestionCandidates(records, inventory);
      final details = <GovernmentIdDetails, GovernmentIdDetails?>{};
      if (inventory != null) {
        await Future.wait(
          candidates.map((r) async => details[r] = await _detail(r)),
        );
      }
      final ranked = rankedSuggestions(
        candidates,
        (r) => suggestionReadiness(r, details[r], inventory),
      );
      final picks = [
        ...ranked,
        ...candidates.where((r) => !ranked.contains(r)),
      ].take(HomeRecommendations.maxCards).toList();
      if (mounted && request == _request) {
        setState(() {
          _picks = picks;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() => _failed = false);
    unawaited(_load());
  }

  void _open(GovernmentIdDetails record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IdDetailsScreen(
          idName: record.name,
          governmentId: record.id,
          recordType: record.recordType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final picks = _picks;
    if (picks == null && _failed) return _error();
    if (picks == null) return _placeholders();
    if (picks.isEmpty) {
      return _note(
        'No recommendations right now. Tap View all to browse the ID Directory.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, record) in picks.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          _card(record),
        ],
      ],
    );
  }

  Widget _note(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      height: 1.4,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _error() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _note('Could not load your recommendations.'),
      TextButton(onPressed: _retry, child: const Text('Retry')),
    ],
  );

  /// Still placeholders, the same height as the cards they stand in for.
  Widget _placeholders() {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Loading recommendations',
      child: Column(
        children: [
          for (var i = 0; i < HomeRecommendations.maxCards; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Container(
              height: 104,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(GovernmentIdDetails record) {
    final colors = Theme.of(context).colorScheme;
    final document = record.recordType == 'document';
    final about = record.description ?? record.issuedBy;
    final accent = colors.primary;
    return RoadmapCard(
      child: MotionInkWell(
        onTap: () => _open(record),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CatalogImage(
                url: record.imageUrl,
                size: 76,
                fallback: Container(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    document
                        ? Icons.description_outlined
                        : Icons.badge_outlined,
                    color: accent,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document ? 'DOCUMENT' : 'GOVERNMENT ID',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      record.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (about != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        about,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
