import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:url_launcher/url_launcher.dart';

import '../../models/government_id.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import 'requirements_tab.dart';
import 'fees_tab.dart';
import 'offices_tab.dart';
import 'inventory_readiness_card.dart';

/// Shared, typed catalog detail. Request-channel context applies to every section.
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
  bool _preferGuide = false;
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
      final paths = record.requestPaths;
      final path =
          paths.where((row) => row['id'] == _pathId).firstOrNull ??
          paths.firstOrNull;
      final selected = path == null ? record : record.forPath(path);
      final hidden = List<String>.from(
        record.research['hidden_sections'] as List? ?? [],
      );
      final specialCases = hidden.contains('troubleshooting')
          ? <Map<String, dynamic>>[]
          : _maps(record.raw['special_cases']);
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
            (selected.fees.isNotEmpty ||
                (path == null && selected.legacyFee != null))) {
          sections.add((
            'Estimated Cost',
            FeesTab(key: ValueKey(path?['id']), record: selected),
          ));
        }
        final offices = record.offices;
        if (!hidden.contains('offices')) {
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
        final guide = _maps(path?['guide']);
        if (!hidden.contains('guide') &&
            (guide.isNotEmpty || specialCases.isNotEmpty)) {
          sections.add((
            'Guide',
            _list([
              if (specialCases.isNotEmpty) ...[
                const Text(
                  'Application Guide',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'How do I request it?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final option in paths)
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _pathId = option['id'] as int;
                          _preferGuide = true;
                        }),
                        child: Text('${option['label']}'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (specialCases.isEmpty || _pathId != null || paths.length == 1)
                for (var index = 0; index < guide.length; index++)
                  _guide(guide[index], index, path!),
              for (final specialCase in specialCases)
                _card(
                  '${specialCase['assistance_title'] ?? specialCase['title']}',
                  [
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
            ]),
          ));
        }
        final cases = _maps(path?['troubleshooting']);
        if (!hidden.contains('troubleshooting') && cases.isNotEmpty) {
          sections.add((
            'Special cases',
            _list([
              for (final item in cases)
                _card('${item['title']}', [
                  Text('${item['body']}'),
                  if (_has(item['url']))
                    CatalogOfficialLink(url: '${item['url']}'),
                ]),
            ]),
          ));
        }
      }
      final information = _information(record, path);
      sections.insert(0, (
        'Overview',
        _list([
          if (!record.isInformational && !hidden.contains('requirements'))
            ApplicationPreparationCard(
              key: ValueKey((record.recordType, record.id, path?['id'])),
              record: selected,
            ),
          ...information,
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
        initialIndex:
            _preferGuide && sections.any((section) => section.$1 == 'Guide')
            ? sections.indexWhere((section) => section.$1 == 'Guide')
            : 0,
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
                    child: _overview(record, path),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
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
    const accent = AppTheme.accentGold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  record.recordType == 'document'
                      ? Icons.description_outlined
                      : Icons.badge_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (record.issuedBy != null)
                      Text(
                        record.issuedBy!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      _label(record.applicationAvailability),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: .8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (record.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Tooltip(
                message: record.description!,
                child: Text(
                  record.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: .8),
                  ),
                ),
              ),
            ),
          for (final fact in <String, String?>{
            'Validity': record.validity,
            'Typical use': record.purpose,
          }.entries)
            if (fact.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Tooltip(
                  message: fact.value!,
                  child: Text(
                    '${fact.key}: ${fact.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: .8),
                    ),
                  ),
                ),
              ),
          if (!record.isInformational && record.requestPaths.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButtonFormField<int>(
                initialValue: path?['id'] as int?,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 12, color: AppTheme.navy),
                decoration: InputDecoration(
                  labelText: 'Transaction / request method',
                  labelStyle: const TextStyle(color: AppTheme.navy),
                  floatingLabelStyle: const TextStyle(
                    color: AppTheme.accentGold,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
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
          if (record.processingTime != null ||
              record.processingTimeNote != null)
            Container(
              key: const ValueKey('detail-processing-summary'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.schedule_rounded, size: 17, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Processing Time',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        if (record.processingTime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              record.processingTime!,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (record.processingTimeNote != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              record.processingTimeNote!,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: Colors.white.withValues(alpha: .8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _information(
    GovernmentIdDetails record,
    Map<String, dynamic>? path,
  ) {
    final facts = <String, dynamic>{
      'Issuing Agency': record.issuedBy,
      'Government Level': record.level,
      'Category': record.category,
      'About / Description': record.description,
      'Purpose': record.purpose,
      'Application Availability': record.applicationAvailability,
      'Acquisition Type': record.acquisitionType,
      'Target Group / Qualification': record.targetGroup,
      'Eligibility': record.raw['eligibility'],
      'Validity': record.validity,
      'Validity / recency': record.research['validity_note'],
    };
    return [
      if (record.isInformational)
        _card('Informational Record', [
          const Text(
            'IDireksyon provides reference information for this credential but does not currently provide step-by-step acquisition guidance.',
          ),
        ]),
      if (_has(record.raw['resident_notice']))
        _card('Research status', [Text('${record.raw['resident_notice']}')]),
      for (final entry in facts.entries)
        if (_has(entry.value))
          _card(entry.key, [SelectableText(_label('${entry.value}'))]),
      if (!record.isInformational && path != null)
        _card('Request channel', [
          if (_has(path['channel']))
            Text('Channel: ${_label('${path['channel']}')}'),
          if (_has(path['provider'])) Text('Provider: ${path['provider']}'),
          if (_has(path['applicability'])) Text('${path['applicability']}'),
          Text('Appointment: ${_label('${path['appointment'] ?? 'unknown'}')}'),
          if ((path['fulfillment'] as List? ?? []).isNotEmpty)
            Text(
              'Fulfillment: ${(path['fulfillment'] as List).map((value) => _label('$value')).join(', ')}',
            ),
          if (_has(path['processing']))
            Text('Processing / fulfillment: ${path['processing']}'),
          if (_has(path['portal_url']))
            CatalogOfficialLink(
              url: '${path['portal_url']}',
              label: 'Open official request portal',
            ),
        ]),
      if (_has(record.officialLink))
        CatalogOfficialLink(url: record.officialLink!),
      for (final source in _maps(record.research['sources']))
        _card('${source['title']}', [
          CatalogOfficialLink(url: '${source['url']}'),
          Text('Checked: ${source['checked_on'] ?? 'Not recorded'}'),
          if (_has(source['scope'])) Text('Supports: ${source['scope']}'),
          if (_has(source['section']))
            Text('Page / section: ${source['section']}'),
        ]),
    ];
  }
}

/// Shared CMS content rendering for normal channels and voluntary assistance.
mixin CatalogDetailContent {
  Widget _office(Map<String, dynamic> office) {
    final latitude = num.tryParse('${office['latitude']}');
    final longitude = num.tryParse('${office['longitude']}');
    final coordinatesAvailable =
        latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude.abs() <= 90 &&
        longitude.abs() <= 180;
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
        for (final schedule in _maps(office['schedules']))
          Text(_officeHours(schedule)),
        if (coordinatesAvailable)
          CatalogOfficialLink(
            url: Uri.https('www.google.com', '/maps/dir/', {
              'api': '1',
              'destination': '$latitude,$longitude',
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

  String _officeHours(Map<String, dynamic> schedule) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final day = int.tryParse('${schedule['day_of_week']}');
    final label = day != null && day >= 0 && day < days.length
        ? days[day]
        : 'Day ${schedule['day_of_week']}';
    final intervals = _maps(schedule['intervals'])
        .map((interval) => '${interval['opens_at']}–${interval['closes_at']}')
        .join(', ');
    return '$label: ${_label('${schedule['status']}')}${intervals.isEmpty ? '' : ' $intervals'}';
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
        if (_has(block['section_title']))
          Text(
            '${block['section_title']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ..._block(block, path),
      ],
    ],
    leading: Container(
      width: 26,
      height: 26,
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
  bool _has(dynamic value) => value is String && value.trim().isNotEmpty;
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
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: .4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.onSurface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (leading != null) ...[
                          leading,
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: colors.brightness == Brightness.dark
                                  ? colors.primary
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...children,
                  ],
                ),
              ),
            ),
          );
        },
      );
  Widget _list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(16), children: children);
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
  const CatalogOfficialLink({super.key, required this.url, this.label});
  final String url;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: () async {
        try {
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!opened && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open this official link.'),
              ),
            );
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open this official link.'),
              ),
            );
          }
        }
      },
      child: Text(label ?? url),
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
