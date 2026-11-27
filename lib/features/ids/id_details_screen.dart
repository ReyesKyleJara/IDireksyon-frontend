import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_config.dart';
import '../../core/auth/auth_service.dart';
import '../../models/government_id.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/catalog_image.dart';
import '../../services/api_service.dart';
import '../office_finder/models/office_model.dart';
import 'requirements_tab.dart';
import 'fees_tab.dart';
import 'guide_steps.dart';
import 'offices_tab.dart';
import 'barangay_offices.dart';
import '../profile/account_details_screen.dart';
import 'agency_verification_card.dart';
import 'catalog_source_card.dart';
import 'review_dates_note.dart';
import 'inventory_readiness_card.dart';

/// General catalog details with optional, read-only request-method information.
class IdDetailsScreen extends StatefulWidget {
  final String idName, recordType;
  final int? governmentId;
  final Future<GovernmentIdDetails> Function(int)? loadDetail;
  final Widget Function(google.GoogleMap)? officesMapBuilder;

  /// Opens the phone's share sheet; replaceable in tests.
  final Future<void> Function(String text, String subject)? shareRecord;
  const IdDetailsScreen({
    super.key,
    required this.idName,
    this.governmentId,
    this.recordType = 'government_id',
    this.loadDetail,
    this.officesMapBuilder,
    this.shareRecord,
  });
  @override
  State<IdDetailsScreen> createState() => _IdDetailsScreenState();
}

class _IdDetailsScreenState extends State<IdDetailsScreen>
    with CatalogDetailContent {
  late Future<GovernmentIdDetails>? _detail;
  int? _pathId;
  Future<GovernmentIdDetails>? _load() {
    final id = widget.governmentId;
    if (id == null) return null;
    return widget.loadDetail?.call(id) ??
        (widget.recordType == 'document'
            ? ApiService.getDocument(id)
            : ApiService.getGovernmentId(id));
  }

  @override
  void initState() {
    super.initState();
    _detail = _load();
  }

  /// Shares a link to the record's public web preview. Only public catalog
  /// information is behind the link; nothing about the resident is sent.
  Future<void> _share(GovernmentIdDetails record) async {
    final link = ApiConfig.shareUrl(
      recordType: record.recordType,
      id: record.id,
    );
    final text =
        '${record.name}: requirements, fees and steps on IDireksyon\n$link';
    final share =
        widget.shareRecord ??
        (String text, String subject) =>
            SharePlus.instance.share(ShareParams(text: text, subject: subject));
    try {
      await share(text, record.name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open sharing on this device.')),
      );
    }
  }

  @override
  void didUpdateWidget(covariant IdDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.governmentId != widget.governmentId ||
        oldWidget.recordType != widget.recordType) {
      _pathId = null;
      _detail = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<GovernmentIdDetails>(
    future: _detail,
    builder: (context, snapshot) {
      if (_detail == null) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.idName)),
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Open this record from the directory to load its saved information.',
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.idName)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.idName)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load this record.'),
                TextButton(
                  onPressed: () {
                    final retry = _load();
                    setState(() {
                      _detail = retry;
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      final record = snapshot.data!;
      final general = record.generalDetails;
      final paths = general.requestPaths;
      final path =
          paths.where((row) => row['id'] == _pathId).firstOrNull ??
          paths.firstOrNull;
      final selected = path == null ? general : general.forPath(path);
      final hidden = List<String>.from(
        record.research['hidden_sections'] as List? ?? [],
      );
      final specialCases = hidden.contains('troubleshooting')
          ? <Map<String, dynamic>>[]
          : _maps(record.raw['special_cases'])
                .where(
                  (item) =>
                      _has(item['title']) || _has(item['assistance_title']),
                )
                .toList();
      final checklist = selected.requirementSets.firstOrNull;
      final hasRequirements = checklist == null
          ? _has(selected.requirements)
          : checklist.groups.any(
              (group) => group.ways.any((way) => way.items.isNotEmpty),
            );
      final canTrackPreparation =
          checklist?.groups.any(
            (group) =>
                group.conditionType == 'always' &&
                group.ways.any(
                  (way) =>
                      way.requiredCount > 0 &&
                      way.items.any((item) => item.id != null),
                ),
          ) ??
          false;
      final sections = <(String, Widget)>[];
      if (!record.isInformational) {
        if (!hidden.contains('requirements') && hasRequirements) {
          sections.add((
            'Requirements',
            RequirementsTab(
              key: ValueKey((record.recordType, record.id, path?['id'])),
              governmentId: selected,
            ),
          ));
        }
        if (!hidden.contains('fees') &&
            (general.fees.any(
                  (fee) => fee.type != 'options' || fee.options.isNotEmpty,
                ) ||
                (general.fees.isEmpty && _has(general.legacyFee)))) {
          sections.add((
            'Cost',
            FeesTab(
              key: ValueKey(('general-fees', record.id)),
              record: general,
            ),
          ));
        }
      }
      final guide = record.isInformational || hidden.contains('guide')
          ? <Map<String, dynamic>>[]
          : _maps(path?['guide'])
                .where(
                  (step) =>
                      _has(step['title']) ||
                      _has(step['short_description']) ||
                      _maps(step['blocks']).any(
                        (block) =>
                            _has(block['section_title']) ||
                            (block['content'] is Map &&
                                (block['content'] as Map).isNotEmpty),
                      ),
                )
                .toList();
      final methods = record.requestMethods
          .where((method) => _has(method['label']))
          .toList();
      final cases = hidden.contains('troubleshooting')
          ? <Map<String, dynamic>>[]
          : _maps(path?['troubleshooting'])
                .where(
                  (item) =>
                      _has(item['title']) ||
                      _has(item['body']) ||
                      _has(item['url']),
                )
                .toList();
      final assistance = specialCases;
      if (guide.isNotEmpty) {
        sections.add((
          'Guide',
          // Numbered accordion steps; linked blocks show this path's real data.
          GuideSteps(
            key: ValueKey(('guide', record.id, path?['id'])),
            steps: guide,
            path: path!,
            tabIndex: (label) =>
                sections.indexWhere((section) => section.$1 == label),
          ),
        ));
      }
      if (methods.isNotEmpty) {
        final methodGroups = <String, List<Map<String, dynamic>>>{
          'Face-to-face': [],
          'Online requests': [],
          'Other ways to request': [],
        };
        for (final method in methods) {
          final channel = '${method['channel'] ?? ''}'.trim().toLowerCase();
          final group = switch (channel) {
            'outlet' ||
            'in_person' ||
            'in-person' ||
            'in person' ||
            'physical' => 'Face-to-face',
            'online' || 'web' || 'website' || 'portal' => 'Online requests',
            _ => 'Other ways to request',
          };
          methodGroups[group]!.add(method);
        }
        sections.add((
          'Ways to Request',
          _list([
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Tap a card for details. Use the website icon to open its portal.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final group in methodGroups.entries)
              if (group.value.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Text(
                    group.key,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                for (final method in group.value)
                  _RequestMethodCard(record: record, method: method),
              ],
          ]),
        ));
      }
      if (assistance.isNotEmpty || cases.isNotEmpty) {
        sections.add((
          'Special Cases',
          _list([
            for (final specialCase in assistance)
              _card(
                '${specialCase['assistance_title'] ?? specialCase['title']}',
                [
                  if (_has(
                    specialCase['assistance_description'] ??
                        specialCase['description'],
                  ))
                    Text(
                      '${specialCase['assistance_description'] ?? specialCase['description']}',
                    ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SpecialCaseGuideScreen(
                          parent: record,
                          guide: specialCase,
                        ),
                      ),
                    ),
                    child: Text('${specialCase['action_label']}'),
                  ),
                ],
              ),
            for (final item in cases)
              _card('${item['title']}', [
                if (_has(item['body'])) Text('${item['body']}'),
                if (_has(item['url']))
                  CatalogOfficialLink(url: '${item['url']}'),
              ]),
          ]),
        ));
      }
      if (!record.isInformational) {
        final offices = record.offices
            .where((office) => _has(office['name']))
            .toList();
        // Barangay-level records always get the tab, so a resident whose
        // barangay office is missing sees why instead of no tab at all.
        final barangayRecord = BarangayOffices.appliesTo(record.level);
        if (!hidden.contains('offices') &&
            (offices.isNotEmpty || barangayRecord)) {
          sections.add((
            'Offices',
            // Rebuilds when the resident saves a barangay in Account Details.
            ListenableBuilder(
              listenable: AuthService.instance,
              builder: (context, _) {
                final user = AuthService.instance.user;
                final residentBarangayId = BarangayOffices.residentBarangayId(
                  user,
                );
                return OfficesTab(
                  key: ValueKey(('offices', record.recordType, record.id)),
                  offices: BarangayOffices.applicable(
                    offices,
                    level: record.level,
                    residentBarangayId: residentBarangayId,
                  ),
                  recordType: record.recordType,
                  mapBuilder: widget.officesMapBuilder,
                  barangayRecord: barangayRecord,
                  residentBarangayId: residentBarangayId,
                  residentBarangayName: user?['barangay_name'] as String?,
                  onSetBarangay: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountDetailsScreen(),
                    ),
                  ),
                );
              },
            ),
          ));
        }
      }
      final overview = <Widget>[
        if (!record.isInformational &&
            !hidden.contains('requirements') &&
            canTrackPreparation)
          ApplicationPreparationCard(
            key: ValueKey((record.recordType, record.id, path?['id'])),
            record: selected,
          ),
        ..._information(record),
      ];
      if (overview.isNotEmpty || sections.isEmpty) {
        sections.insert(0, ('Overview', _list(overview)));
      }
      final showTabs = sections.length > 1 || sections.single.$1 != 'Overview';
      return DefaultTabController(
        key: ValueKey((
          record.recordType,
          record.id,
          path?['id'],
          sections.map((s) => s.$1).join(','),
        )),
        length: sections.length,
        initialIndex: 0,
        child: Scaffold(
          // Only the back arrow lives here; the name is in the hero below.
          // The hero's gradient and texture continue behind the back arrow.
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 48,
            actions: [
              IconButton(
                key: const ValueKey('share-record'),
                tooltip: 'Share',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _share(record),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                key: const ValueKey('detail-brand-header'),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.royalBlue,
                      AppTheme.primaryBlue,
                      AppTheme.navy,
                    ],
                    stops: [0, .55, 1],
                  ),
                ),
                child: Stack(
                  children: [
                    // Soft glows give the hero depth without any image asset.
                    const Positioned.fill(
                      child: ClipRect(
                        child: CustomPaint(painter: _HeroTexture()),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Room for the status bar and the transparent app bar.
                        Builder(
                          builder: (context) => SizedBox(
                            height: MediaQuery.paddingOf(context).top,
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .46,
                          ),
                          child: SingleChildScrollView(
                            key: const ValueKey('detail-overview-scroll'),
                            child: _overview(general, path),
                          ),
                        ),
                        // Rounded top edge of the content sheet over the hero.
                        Container(
                          key: const ValueKey('detail-sheet-edge'),
                          height: 20,
                          decoration: BoxDecoration(
                            color: showTabs
                                ? _sheetColor(context)
                                : Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showTabs)
                Material(
                  color: _sheetColor(context),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      dividerColor: Colors.transparent,
                      // Pill tabs: the selected section is a filled capsule.
                      indicator: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.primary
                            : AppTheme.navy,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      splashBorderRadius: BorderRadius.circular(999),
                      labelColor: Theme.of(context).colorScheme.onPrimary,
                      unselectedLabelColor: Theme.of(context)
                          .colorScheme
                          .onSurface,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                      tabs: sections
                          .map((section) => Tab(height: 34, text: section.$1))
                          .toList(),
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: sections.map((section) {
                    final dates = record.reviewDates;
                    if (dates == null) return section.$2;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ReviewDatesNote(dates: dates, compact: true),
                        Expanded(child: section.$2),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// The whole About text, for descriptions longer than the hero's 3 lines.
  void _showAbout(GovernmentIdDetails record) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'About ${record.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  record.description!.trim(),
                  style: const TextStyle(fontSize: 14, height: 1.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _sheetColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surface
      : Colors.white;

  /// Width and height of the ID picture in the hero. Change this to resize it.
  static const double _heroImageSize = 120;

  /// How much height the picture takes up in the layout (about the height of
  /// the name plus "Issued by"). Keeping it fixed stops a bigger picture from
  /// adding empty space above About.
  static const double _heroImageSlot = 84;

  Widget _overview(GovernmentIdDetails record, Map<String, dynamic>? path) {
    final quiet = TextStyle(
      fontSize: 12,
      height: 1.3,
      color: Colors.white.withValues(alpha: .75),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: record.name,
                      child: Text(
                        record.name,
                        key: const ValueKey('compact-id-title'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_has(record.issuedBy)) ...[
                      const SizedBox(height: 14),
                      Text('Issued by', style: quiet),
                      const SizedBox(height: 3),
                      Text(
                        record.issuedBy!,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // The picture is a square with the card drawn in its middle, so
              // only [_heroImageSlot] of its height takes up room. The rest
              // (usually transparent) spills over without pushing About down.
              // To resize the picture, change [_heroImageSize] only.
              SizedBox(
                width: record.imageUrl == null ? 70 : _heroImageSize,
                height: record.imageUrl == null ? 70 : _heroImageSlot,
                child: OverflowBox(
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: CatalogImage(
                    url: record.imageUrl,
                    size: record.imageUrl == null ? 70 : _heroImageSize,
                    radius: 12,
                    fallback: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        record.recordType == 'document'
                            ? Icons.description_outlined
                            : Icons.badge_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // About: short and quiet under the agency; tap to read all of it.
          if (_has(record.description)) ...[
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'About ${record.name}. Tap to read more.',
              child: InkWell(
                key: const ValueKey('hero-about'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showAbout(record),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About', style: quiet),
                    const SizedBox(height: 3),
                    Text(
                      record.description!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: .92),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!record.isInformational && record.requestPaths.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DropdownButtonFormField<int>(
                initialValue: path?['id'] as int?,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 14, color: AppTheme.navy),
                decoration: InputDecoration(
                  labelText: 'Application type',
                  labelStyle: const TextStyle(color: AppTheme.navy),
                  floatingLabelStyle: const TextStyle(color: AppTheme.navy),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: record.requestPaths
                    .map(
                      (row) => DropdownMenuItem<int>(
                        value: row['id'] as int,
                        child: Text(
                          '${row['label']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _pathId = value),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _information(GovernmentIdDetails record) {
    final general = record.generalDetails;
    final keyFacts = <Widget>[
      if (_has(general.processingTime) || _has(general.processingTimeNote))
        _KeyFact(
          icon: Icons.schedule_outlined,
          label: 'Processing Time',
          value: _has(general.processingTime) ? general.processingTime : null,
          note: _has(general.processingTimeNote)
              ? general.processingTimeNote
              : null,
        ),
      if (_has(record.validity))
        _KeyFact(
          icon: Icons.event_available_outlined,
          label: 'Validity',
          value: record.validity,
        ),
      if (_has(record.research['validity_note']))
        _KeyFact(
          icon: Icons.history_outlined,
          label: 'Validity / recency',
          value: '${record.research['validity_note']}',
        ),
    ];
    final about = <String, dynamic>{
      'Purpose': record.purpose,
      "Who it's for": record.targetGroup,
    }..removeWhere((_, value) => !_has(value));
    final verifiedInfo = record.raw['verified_information'];
    final sources = _maps(
      verifiedInfo is Map
          ? verifiedInfo['sources']
          : record.research['sources'],
    );
    final verification = verifiedInfo is Map
        ? verifiedInfo['verification']
        : null;
    final officialSources = sources.where((source) {
      final title = source['title'];
      final url = source['url'];
      return title is String &&
          title.trim().isNotEmpty &&
          url is String &&
          CatalogOfficialLink.isSafe(url);
    }).toList();

    final hasOfficialLink =
        _has(record.officialLink) &&
        CatalogOfficialLink.isSafe(record.officialLink!);
    return [
      if (record.isInformational)
        _card('Informational Record', [
          const Text(
            'IDireksyon provides reference information for this credential but does not currently provide step-by-step acquisition guidance.',
          ),
        ]),
      if (keyFacts.isNotEmpty)
        _card('', [
          for (var index = 0; index < keyFacts.length; index++) ...[
            if (index > 0) const _SoftDivider(),
            keyFacts[index],
          ],
        ]),
      if (_has(record.raw['eligibility']))
        _card(
          'Eligibility',
          [_EligibilityList(value: '${record.raw['eligibility']}')],
          leading: Builder(
            builder: (context) => Icon(
              Icons.groups_rounded,
              size: 22,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.primary
                  : AppTheme.primaryBlue,
            ),
          ),
        ),
      if (hasOfficialLink)
        _card('Official links', [
          CatalogOfficialLink(
            url: record.officialLink!,
            label: 'Visit official website',
          ),
        ]),
      if (verifiedInfo is Map) ...[
        if (officialSources.isNotEmpty || verification is Map)
          _verifiedInformation(
            officialSources,
            verification is Map ? verification : null,
          ),
      ] else ...[
        for (final source in sources)
          CatalogSourceCard(
            source: source,
            recordName: record.name,
            agencyName: record.issuedBy,
          ),
        for (final confirmation in record.agencyConfirmations)
          AgencyVerificationCard(confirmation: confirmation),
      ],
      // The description is in the hero; other background details stay here.
      if (about.isNotEmpty)
        _card('More details', small: true, [
          for (final (index, entry) in about.entries.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            SelectableText(_label('${entry.value}')),
          ],
        ]),
    ];
  }

  Widget _verifiedInformation(
    List<Map<String, dynamic>> sources,
    Map<dynamic, dynamic>? verification,
  ) {
    final colors = Theme.of(context).colorScheme;
    final date = DateTime.tryParse(verification?['date']?.toString() ?? '');

    Widget heading(IconData icon, String title, {Color? color}) => Row(
      children: [
        Icon(icon, color: color ?? colors.onSurfaceVariant, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    return _card('', [
      heading(
        verification == null ? Icons.language : Icons.verified_user_outlined,
        verification == null ? 'Official References' : 'Verified Information',
        color: verification == null ? null : const Color(0xFF278458),
      ),
      if (date != null) ...[
        const SizedBox(height: 4),
        Text(
          'Last verified: ${MaterialLocalizations.of(context).formatMonthYear(date).replaceFirst(' ', ' ${date.day}, ')}',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
        ),
      ],
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 9),
        child: _SoftDivider(),
      ),
      if (sources.isNotEmpty) ...[
        heading(Icons.language, 'Official Government Source'),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final source in sources)
                CatalogOfficialLink(
                  url: source['url'] as String,
                  label: source['title'] as String,
                ),
            ],
          ),
        ),
      ],
      if (verification != null) ...[
        if (sources.isNotEmpty) const SizedBox(height: 4),
        heading(Icons.location_on_outlined, verification['method'] as String),
        Padding(
          padding: const EdgeInsets.only(left: 25, top: 4),
          child: Text(verification['office'] as String),
        ),
      ],
      const SizedBox(height: 8),
      Text(
        'Information reviewed by the IDireksyon research team. Requirements and procedures may change.',
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
      ),
    ]);
  }
}

/// Soft glows over the hero gradient: depth without hard shapes or assets.
class _HeroTexture extends CustomPainter {
  const _HeroTexture();

  void _glow(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    Color color,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(rect),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // A lighter blue glow from the top right, a deeper one from the bottom left.
    _glow(
      canvas,
      size,
      Offset(size.width * 1.05, -size.height * .1),
      size.width * .95,
      const Color(0xFF4F8DF7).withValues(alpha: .42),
    );
    _glow(
      canvas,
      size,
      Offset(-size.width * .1, size.height * 1.1),
      size.width * .8,
      const Color(0xFF071F45).withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A request method opens inline while its portal link opens the saved website.
class _RequestMethodCard extends StatelessWidget with CatalogDetailContent {
  _RequestMethodCard({required this.record, required this.method});

  final GovernmentIdDetails record;
  final Map<String, dynamic> method;

  final PageStorageBucket _detailsStorage = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = '${method['label']}';
    final channel = '${method['channel'] ?? ''}'.trim().toLowerCase();
    final summary = _has(method['applicability'])
        ? '${method['applicability']}'
        : switch (channel) {
            'outlet' ||
            'in_person' ||
            'in-person' ||
            'in person' ||
            'physical' =>
              'Submit your request in person at this service location.',
            'online' ||
            'web' ||
            'website' ||
            'portal' => 'Submit your request online through this website.',
            _ => 'View the requirements and steps for this request method.',
          };
    final portal = '${method['portal_url'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: colors.brightness == Brightness.dark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: .08),
      color: colors.brightness == Brightness.dark
          ? colors.surfaceContainer
          : Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.primary.withValues(alpha: .28)),
      ),
      child: ExpansionTile(
        key: PageStorageKey((
          'request-method',
          record.recordType,
          record.id,
          method['id'],
          label,
        )),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: colors.primary,
        collapsedIconColor: colors.onSurfaceVariant,
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
            if (CatalogOfficialLink.isSafe(portal))
              IconButton(
                tooltip: 'Open $label website',
                onPressed: () => CatalogOfficialLink.open(context, portal),
                icon: Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ),
          ],
        ),
        subtitle: Text(
          summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: colors.onSurfaceVariant,
          ),
        ),
        children: [
          Divider(color: colors.outlineVariant.withValues(alpha: .5)),
          PageStorage(
            bucket: _detailsStorage,
            child: _RequestMethodDetails(record: record, method: method),
          ),
        ],
      ),
    );
  }
}

/// Optional reference page for other entry points to a request method.
class RequestMethodScreen extends StatelessWidget {
  const RequestMethodScreen({
    super.key,
    required this.record,
    required this.method,
  });

  final GovernmentIdDetails record;
  final Map<String, dynamic> method;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${method['label']}')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: _RequestMethodDetails(record: record, method: method),
    ),
  );
}

class _RequestMethodDetails extends StatelessWidget with CatalogDetailContent {
  const _RequestMethodDetails({required this.record, required this.method});

  final GovernmentIdDetails record;
  final Map<String, dynamic> method;

  @override
  Widget _card(
    String title,
    List<Widget> children, {
    Widget? leading,
    bool small = false,
  }) => Builder(
    builder: (context) => Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : AppTheme.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: .45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    ),
  );

  bool _hasContent(dynamic value) {
    if (value is String) return _has(value);
    if (value is Map) {
      return _has(value['text']) || _hasContent(value['content']);
    }
    if (value is List) return value.any(_hasContent);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final method = {
      ...this.method,
      'offices': _applicableOffices(record, this.method['offices']),
    };
    final hidden = List<String>.from(
      record.research['hidden_sections'] as List? ?? [],
    );
    final scoped = record.forPath(method);
    final guide = _maps(method['guide']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_has(method['provider']))
          _card('Provider', [Text('${method['provider']}')]),
        if (_has(method['applicability']))
          _card('Who this applies to', [Text('${method['applicability']}')]),
        if (_has(method['portal_url']))
          CatalogOfficialLink(
            url: '${method['portal_url']}',
            label: 'Open official request portal',
          ),
        if (!hidden.contains('guide')) ...[
          if (_hasContent(method['preparation']))
            _card('Before you request', [
              CatalogRichText(value: method['preparation']),
            ]),
          if (_hasContent(method['application_guide_text']))
            _card('Instructions', [
              CatalogRichText(value: method['application_guide_text']),
            ]),
          for (var index = 0; index < guide.length; index++)
            _guide(guide[index], index, method),
        ],
        if (!hidden.contains('requirements') &&
            scoped.requirementSets.any((set) => set.groups.isNotEmpty))
          _card('Requirements for this method', [
            AssistanceRequirements(record: scoped),
          ]),
        if (!hidden.contains('fees') && scoped.fees.isNotEmpty)
          _card('Estimated Cost', [FeesTab(record: scoped, embedded: true)]),
        if (_has(method['processing']))
          _card('Processing time', [Text('${method['processing']}')]),
        // Only what is known: "unknown" values are left out, and the card is
        // hidden when nothing is left.
        if (_known(method['channel']) ||
            _known(method['appointment']) ||
            (method['fulfillment'] as List? ?? []).isNotEmpty)
          _card('Request information', [
            if (_known(method['channel']))
              Text('Request via: ${_label('${method['channel']}')}'),
            if (_known(method['appointment']))
              Text('Appointment: ${_label('${method['appointment']}')}'),
            if ((method['fulfillment'] as List? ?? []).isNotEmpty)
              Text(
                'How you receive it: ${(method['fulfillment'] as List).map((value) => _label('$value')).join(', ')}',
              ),
          ]),
        if (!hidden.contains('offices'))
          for (final office in _maps(method['offices'])) _office(office),
        if (!hidden.contains('troubleshooting'))
          for (final note in _maps(method['troubleshooting']))
            _card('${note['title']}', [
              Text('${note['body']}'),
              if (_has(note['url'])) CatalogOfficialLink(url: '${note['url']}'),
            ]),
      ],
    );
  }
}

/// Shared CMS content rendering for normal channels and voluntary assistance.
mixin CatalogDetailContent {
  /// On Barangay-level records, only the resident's own barangay office and
  /// shared offices (see [BarangayOffices]); other records are unchanged.
  List<Map<String, dynamic>> _applicableOffices(
    GovernmentIdDetails record,
    dynamic offices,
  ) => BarangayOffices.applicable(
    _maps(offices),
    level: record.level,
    residentBarangayId: BarangayOffices.residentBarangayId(
      AuthService.instance.user,
    ),
  );

  Widget _office(Map<String, dynamic> office) {
    final location = OfficeModel.usableLocation(
      office['latitude'],
      office['longitude'],
    );
    return _card(
      '${office['name']}',
      [
        if (_has(office['address'])) SelectableText('${office['address']}'),
        if (_has(office['service_notes'])) Text('${office['service_notes']}'),
        // Office services with an unknown status are not shown.
        for (final service
            in (office['services'] is Map
                    ? Map<String, dynamic>.from(office['services'])
                    : <String, dynamic>{})
                .entries
                .where((service) => _known(service.value)))
          Text('${_label(service.key)}: ${_label('${service.value}')}'),
        for (final line in OfficeModel.weeklyLines(
          OfficeModel.scheduleFrom(office['schedules']),
        ))
          Text('$line'),
        if (location != null)
          CatalogOfficialLink(
            url: Uri.https('www.google.com', '/maps/dir/', {
              'api': '1',
              'destination': '${location.latitude},${location.longitude}',
            }).toString(),
            label: 'Get Directions',
          ),
        if (_has(office['source_url']))
          CatalogOfficialLink(url: '${office['source_url']}'),
      ],
      leading: Builder(
        builder: (context) => Icon(
          Icons.location_on_outlined,
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.primary
              : AppTheme.primaryBlue,
          size: 22,
        ),
      ),
    );
  }

  Widget _guide(
    Map<String, dynamic> step,
    int index,
    Map<String, dynamic> path,
  ) => _card(
    '${step['title']}',
    [
      if (_has(step['short_description'])) Text('${step['short_description']}'),
      for (final block in _maps(step['blocks'])) ...[
        const SizedBox(height: 10),
        if (_has(block['section_title']))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${block['section_title']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ..._block(block, path),
      ],
    ],
    leading: Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppTheme.primaryBlue,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  List<Widget> _block(Map<String, dynamic> block, Map<String, dynamic> path) {
    final content = block['content'] is Map
        ? Map<String, dynamic>.from(block['content'])
        : <String, dynamic>{};
    if (block['type'] == 'official_link') {
      return [
        CatalogOfficialLink(
          url: '${content['url']}',
          label: '${content['label'] ?? 'Official link'}',
        ),
        if (_has(content['description'])) Text('${content['description']}'),
      ];
    }
    final output = <Widget>[];
    for (final key in ['intro', 'body']) {
      if (content[key] != null) {
        output.add(CatalogRichText(value: content[key]));
      }
    }
    for (final item in content['items'] as List? ?? []) {
      output.add(
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 4),
          child: CatalogRichText(value: item is Map ? item['body'] : item),
        ),
      );
    }
    // Live blocks refer to the selected path; they never embed a second stale copy.
    if (block['type'] == 'requirements' &&
        _maps(path['requirement_sets']).isNotEmpty) {
      output.add(Text('See Requirements for ${path['label']}.'));
    }
    if (block['type'] == 'fees' && _maps(path['fees']).isNotEmpty) {
      output.add(Text('See Estimated Cost for ${path['label']}.'));
    }
    if (block['type'] == 'offices' && _maps(path['offices']).isNotEmpty) {
      output.add(Text('See applicable offices for ${path['label']}.'));
    }
    if (block['type'] == 'processing_time' && _has(path['processing'])) {
      output.add(Text('${path['processing']}'));
    }
    return output;
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : [];
  bool _has(dynamic value) =>
      value is String &&
      value.trim().isNotEmpty &&
      !{
        'notapplicable',
        'na',
      }.contains(value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  );

  /// False for empty values and the CMS placeholders "unknown" / "not specified".
  bool _known(dynamic value) =>
      value is String &&
      value.trim().isNotEmpty &&
      !const {'unknown', 'not_specified'}.contains(value.trim().toLowerCase());

  String _label(String value) =>
      const {
        'outlet': 'Face-to-face',
        'online': 'Online',
        'partner': 'Service partner',
        'hybrid': 'Online and in person',
        'new_application_status': 'New applications',
        'renewal_status': 'Renewals',
        'replacement_status': 'Replacements',
        'pickup': 'Pickup',
        'delivery': 'Delivery',
        'email': 'Email',
        'national': 'National',
        'general_public': 'General Public',
        'profession_based': 'Profession-Based',
        'employment_based': 'Employment-Based',
        'sector_specific': 'Sector-Specific',
        'special_eligibility': 'Special Eligibility',
        'available': 'Available',
        'not_required': 'Not required',
      }[value] ??
      value.replaceAll('_', ' ');

  /// A content card. An empty [title] draws no heading; [small] is the quieter
  /// style used for secondary text such as About.
  Widget _card(
    String title,
    List<Widget> children, {
    Widget? leading,
    bool small = false,
  }) => Builder(
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return Card(
        color: colors.brightness == Brightness.dark
            ? colors.surfaceContainer
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: .4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: small ? 13 : 14,
              height: 1.5,
              color: small ? colors.onSurfaceVariant : colors.onSurface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        leading,
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: small ? 13 : 16,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: colors.brightness == Brightness.dark
                                ? colors.primary
                                : AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: small ? 6 : 12),
                ],
                ...children,
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _list(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: children,
  );
}

class SpecialCaseGuideScreen extends StatelessWidget with CatalogDetailContent {
  final GovernmentIdDetails parent;
  final Map<String, dynamic> guide;
  const SpecialCaseGuideScreen({
    super.key,
    required this.parent,
    required this.guide,
  });
  @override
  Widget build(BuildContext context) {
    final scoped = parent.forPath(guide);
    final steps = _maps(guide['steps']);
    final offices = _applicableOffices(parent, guide['offices']);
    final sources = _maps(guide['sources']);
    final reference = {...guide, 'label': guide['title'], 'offices': offices};
    return Scaffold(
      appBar: AppBar(title: Text('${guide['title']}')),
      body: _list([
        Text(
          '${guide['description']}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (guide['status'] != 'reviewed')
          _card('Research status', [
            const Text(
              'This assistance guide is not yet reviewed. Confirm current information with the issuing agency.',
            ),
          ]),
        if (_has(guide['introduction']))
          _card('About this guide', [
            SelectableText('${guide['introduction']}'),
          ]),
        if (_has(guide['before_you_begin']))
          _card('Before You Begin', [
            SelectableText('${guide['before_you_begin']}'),
          ]),
        if (scoped.requirementSets.any((set) => set.groups.isNotEmpty))
          _card('Requirements', [AssistanceRequirements(record: scoped)]),
        if (steps.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Step-by-Step Application Guide',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          for (var index = 0; index < steps.length; index++)
            _guide(steps[index], index, reference),
        ],
        if (scoped.fees.isNotEmpty)
          _card('Fees', [FeesTab(record: scoped, embedded: true)]),
        if (offices.isNotEmpty)
          _card('Where to Apply', [
            for (final office in offices) _office(office),
          ]),
        if (_has(guide['notes']))
          _card('Important Notes', [SelectableText('${guide['notes']}')]),
        if (sources.isNotEmpty) ...[
          _sectionTitle('Public references'),
          for (final source in sources)
            CatalogSourceCard(
              source: source,
              recordName: '${guide['title']}',
              agencyName: parent.issuedBy,
            ),
        ],
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: Text('Back to ${parent.name}'),
        ),
      ]),
    );
  }
}

class CatalogOfficialLink extends StatelessWidget {
  const CatalogOfficialLink({
    super.key,
    required this.url,
    this.label,
    this.inline = false,
  });
  final String url;
  final String? label;

  /// Inline links sit inside a sentence, so they stay plain text buttons.
  final bool inline;

  static bool isSafe(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        ['https', 'http'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  /// Opens a safe official link outside the app; unsafe links are ignored.
  static Future<void> open(BuildContext context, String url) async {
    if (!isSafe(url)) return;
    await const CatalogOfficialLink(url: '')._open(context, Uri.parse(url));
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this official link.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this official link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isSafe(url)) return const SizedBox.shrink();
    final uri = Uri.parse(url);
    if (inline) {
      return TextButton(
        onPressed: () => _open(context, uri),
        child: Text(label ?? url),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _open(context, uri),
        iconAlignment: IconAlignment.end,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: Text(label ?? uri.host),
      ),
    );
  }
}

/// One headline fact, such as processing time, with an icon and optional note.
class _KeyFact extends StatelessWidget {
  const _KeyFact({
    required this.icon,
    required this.label,
    this.value,
    this.note,
  });
  final IconData icon;
  final String label;
  final String? value, note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SelectableText(
                    value!,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText(
                    note!,
                    style: TextStyle(
                      fontSize: 13,
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

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 24,
    thickness: 1,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .4),
  );
}

/// Shows saved eligibility text line by line: "Age: 18+" becomes a label and
/// value, and any other line becomes a bullet. The wording is never changed.
class _EligibilityList extends StatelessWidget {
  const _EligibilityList({required this.value});
  final String value;

  static final _labelled = RegExp(r'^([^:]{2,24}):\s+(.+)$');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) return SelectableText(value.trim());
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;
    final labelStyle = TextStyle(
      fontSize: 13,
      height: 1.5,
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
            child: Builder(
              builder: (context) {
                final match = _labelled.firstMatch(lines[index]);
                if (match == null) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 10),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(child: SelectableText(lines[index])),
                    ],
                  );
                }
                final label = Text(match[1]!, style: labelStyle);
                final detail = SelectableText(match[2]!);
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, detail],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 92, child: label),
                    const SizedBox(width: 8),
                    Expanded(child: detail),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Renders stored Tiptap text, lists and safe links without executing HTML.
class CatalogRichText extends StatelessWidget {
  const CatalogRichText({super.key, required this.value});
  final dynamic value;
  @override
  Widget build(BuildContext context) {
    if (value is String) return SelectableText(value as String);
    if (value is! Map) return const SizedBox.shrink();
    final node = value as Map;
    final children = node['content'] as List? ?? [];
    if (node['type'] == 'text') {
      final marks = (node['marks'] as List? ?? []).whereType<Map>();
      final link = marks.where((mark) => mark['type'] == 'link').firstOrNull;
      if (link != null) {
        return CatalogOfficialLink(
          url: '${(link['attrs'] as Map?)?['href']}',
          label: '${node['text'] ?? ''}',
          inline: true,
        );
      }
      return Text(
        '${node['text'] ?? ''}',
        style: TextStyle(
          fontWeight: marks.any((mark) => mark['type'] == 'bold')
              ? FontWeight.bold
              : null,
          fontStyle: marks.any((mark) => mark['type'] == 'italic')
              ? FontStyle.italic
              : null,
        ),
      );
    }
    if (node['type'] == 'hardBreak') return const SizedBox(height: 8);
    final widgets = [
      for (final child in children) CatalogRichText(value: child),
    ];
    if (node['type'] == 'paragraph' || node['type'] == 'heading') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: widgets,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
