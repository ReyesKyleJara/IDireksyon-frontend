import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:url_launcher/url_launcher.dart';

import '../../models/government_id.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/catalog_image.dart';
import '../../services/api_service.dart';
import '../office_finder/models/office_model.dart';
import 'requirements_tab.dart';
import 'fees_tab.dart';
import 'offices_tab.dart';
import 'inventory_readiness_card.dart';

/// General catalog details with optional, read-only request-method information.
class IdDetailsScreen extends StatefulWidget {
  final String idName, recordType;
  final int? governmentId;
  final Future<GovernmentIdDetails> Function(int)? loadDetail;
  final Widget Function(google.GoogleMap)? officesMapBuilder;
  const IdDetailsScreen({
    super.key,
    required this.idName,
    this.governmentId,
    this.recordType = 'government_id',
    this.loadDetail,
    this.officesMapBuilder,
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
      final sections = <(String, Widget)>[];
      if (!record.isInformational) {
        if (!hidden.contains('requirements') &&
            (selected.requirementSets.any((set) => set.groups.isNotEmpty) ||
                selected.requirements != null)) {
          sections.add((
            'Requirements',
            RequirementsTab(
              key: ValueKey((record.recordType, record.id, path?['id'])),
              governmentId: selected,
            ),
          ));
        }
        if (!hidden.contains('fees') &&
            (general.fees.isNotEmpty || _has(general.legacyFee))) {
          sections.add((
            'Estimated Cost',
            FeesTab(
              key: ValueKey(('general-fees', record.id)),
              record: general,
            ),
          ));
        }
        final offices = record.offices;
        if (!hidden.contains('offices') && offices.isNotEmpty) {
          sections.add((
            'Offices',
            OfficesTab(
              key: ValueKey(('offices', record.recordType, record.id)),
              offices: offices,
              recordType: record.recordType,
              mapBuilder: widget.officesMapBuilder,
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
                      _maps(step['blocks']).isNotEmpty,
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
          _list([
            _sectionTitle('Application Guide'),
            for (var index = 0; index < guide.length; index++)
              _guide(guide[index], index, path!),
          ]),
        ));
      }
      if (methods.isNotEmpty) {
        sections.add((
          'Ways to Request',
          _list([
            _card('Request options', [
              const Text(
                'Explore the available ways to request this item. No selection is required.',
              ),
              for (final method in methods)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${method['label']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RequestMethodScreen(record: record, method: method),
                    ),
                  ),
                ),
            ]),
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
      sections.insert(0, (
        'Overview',
        _list([
          if (!record.isInformational && !hidden.contains('requirements'))
            ApplicationPreparationCard(
              key: ValueKey((record.recordType, record.id, path?['id'])),
              record: selected,
            ),
          ..._information(record),
        ]),
      ));
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
          appBar: AppBar(
            backgroundColor: AppTheme.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 28
                ? 88
                : 60,
            title: Tooltip(
              message: record.name,
              child: Text(
                record.name,
                key: const ValueKey('compact-id-title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                key: const ValueKey('detail-brand-header'),
                color: AppTheme.navy,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .28,
                  ),
                  child: SingleChildScrollView(
                    key: const ValueKey('detail-overview-scroll'),
                    child: _overview(general, path),
                  ),
                ),
              ),
              if (sections.length > 1)
                Material(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surface
                      : Colors.white,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: .45),
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorColor: AppTheme.accentGold,
                    indicatorWeight: 3,
                    tabs: sections
                        .map((section) => Tab(text: section.$1))
                        .toList(),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: sections.map((section) => section.$2).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _overview(GovernmentIdDetails record, Map<String, dynamic>? path) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CatalogImage(
                url: record.imageUrl,
                size: record.imageUrl == null ? 44 : 56,
                fallback: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    record.recordType == 'document'
                        ? Icons.description_outlined
                        : Icons.badge_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_has(record.issuedBy))
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Issued by',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: Colors.white.withValues(alpha: .75),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        record.issuedBy!,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
    final sources = _maps(record.research['sources']);
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
        _card('Key information', [
          for (var index = 0; index < keyFacts.length; index++) ...[
            if (index > 0) const _SoftDivider(),
            keyFacts[index],
          ],
        ]),
      if (_has(record.raw['eligibility']))
        _card('Eligibility', [
          _EligibilityList(value: '${record.raw['eligibility']}'),
        ]),
      if (_has(record.description) || about.isNotEmpty)
        _card('About', [
          if (_has(record.description))
            SelectableText(_label(record.description!)),
          for (final entry in about.entries) ...[
            const SizedBox(height: 12),
            Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            SelectableText(_label('${entry.value}')),
          ],
        ]),
      if (hasOfficialLink || sources.isNotEmpty)
        _card('Official links', [
          if (hasOfficialLink)
            CatalogOfficialLink(
              url: record.officialLink!,
              label: 'Visit official website',
            ),
          if (sources.isNotEmpty)
            Builder(
              builder: (context) {
                final muted = TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                );
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  expandedAlignment: Alignment.centerLeft,
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(
                    'Sources used (${sources.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    for (final source in sources) ...[
                      Text(
                        _has(source['title'])
                            ? '${source['title']}'
                            : 'Official source',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Checked: ${source['checked_on'] ?? 'Not recorded'}',
                        style: muted,
                      ),
                      if (_has(source['scope']))
                        Text('Supports: ${source['scope']}', style: muted),
                      if (_has(source['section']))
                        Text(
                          'Page / section: ${source['section']}',
                          style: muted,
                        ),
                      CatalogOfficialLink(url: '${source['url']}'),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
        ]),
    ];
  }
}

/// Optional reference page. Opening it never selects a method or writes progress.
class RequestMethodScreen extends StatelessWidget with CatalogDetailContent {
  const RequestMethodScreen({
    super.key,
    required this.record,
    required this.method,
  });
  final GovernmentIdDetails record;
  final Map<String, dynamic> method;

  @override
  Widget build(BuildContext context) {
    final hidden = List<String>.from(
      record.research['hidden_sections'] as List? ?? [],
    );
    final scoped = record.forPath(method);
    final guide = _maps(method['guide']);
    return Scaffold(
      appBar: AppBar(title: Text('${method['label']}')),
      body: _list([
        const Text(
          'Information only. You do not need to select or save a request method.',
        ),
        const SizedBox(height: 12),
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
          if (_has(method['preparation']))
            _card('Before you request', [
              CatalogRichText(value: method['preparation']),
            ]),
          if (_has(method['application_guide_text']))
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
        _card('Request information', [
          Text(
            'Appointment: ${_label('${method['appointment'] ?? 'unknown'}')}',
          ),
          if ((method['fulfillment'] as List? ?? []).isNotEmpty)
            Text(
              'Fulfillment: ${(method['fulfillment'] as List).map((value) => _label('$value')).join(', ')}',
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Back to ${record.name}'),
        ),
      ]),
    );
  }
}

/// Shared CMS content rendering for normal channels and voluntary assistance.
mixin CatalogDetailContent {
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
        for (final service
            in (office['services'] is Map
                    ? Map<String, dynamic>.from(office['services'])
                    : <String, dynamic>{})
                .entries)
          Text('${_label(service.key)}: ${service.value}'),
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
  String _label(String value) =>
      const {
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
  Widget _card(String title, List<Widget> children, {Widget? leading}) =>
      Builder(
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
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: .4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.onSurface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              fontSize: 15,
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
                    const SizedBox(height: 12),
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
    final offices = _maps(guide['offices']);
    final sources = _maps(guide['sources']);
    final reference = {...guide, 'label': guide['title']};
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
        if (sources.isNotEmpty)
          _card('Official Sources', [
            for (final source in sources) ...[
              Text(
                '${source['title']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              CatalogOfficialLink(url: '${source['url']}'),
              Text('Checked: ${source['checked_on'] ?? 'Not recorded'}'),
              if (_has(source['scope'])) Text('${source['scope']}'),
              if (_has(source['section']))
                Text('Page / section: ${source['section']}'),
              const SizedBox(height: 8),
            ],
          ]),
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
