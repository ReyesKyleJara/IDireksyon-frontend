import 'inventory_context_notice.dart';
import '../../models/applicant_context.dart';
import '../roadmap/sequence_controller.dart';
import '../roadmap/sequence_screen.dart';

import 'package:flutter/material.dart';

import '../../models/government_id.dart';
import '../../services/api_service.dart';
import 'detail_widgets.dart';
import 'government_id_content_tabs.dart';
import 'requirements_tab.dart';
import 'applicant_flow_controller.dart';
import 'applicant_context_card.dart';

class IdDetailsScreen extends StatefulWidget {
  final String idName;
  final int? governmentId;
  final Future<GovernmentIdDetails> Function(int)? loadDetail;
  final EvaluateApplicant? evaluateApplicant;
  final BuildSequence? evaluateSequence;
  final ApplicantContext? initialApplicantContext;
  const IdDetailsScreen({
    super.key,
    required this.idName,
    this.governmentId,
    this.loadDetail,
    this.evaluateApplicant,
    this.evaluateSequence,
    this.initialApplicantContext,
  });
  @override
  State<IdDetailsScreen> createState() => _IdDetailsScreenState();
}

class _IdDetailsScreenState extends State<IdDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Future<GovernmentIdDetails>? _detail;
  ApplicantFlowController? _applicantFlow;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _detail = _load();
    _startApplicantFlow();
  }

  void _startApplicantFlow() {
    _applicantFlow?.dispose();
    _applicantFlow = widget.governmentId == null
        ? null
        : ApplicantFlowController(
            widget.governmentId!,
            widget.evaluateApplicant ?? ApiService.evaluateApplicant,
            initialContext: widget.initialApplicantContext,
          );
    _applicantFlow?.refresh();
  }

  Future<GovernmentIdDetails>? _load() => widget.governmentId == null
      ? null
      : (widget.loadDetail?.call(widget.governmentId!) ??
            ApiService.getGovernmentId(widget.governmentId!));
  @override
  void didUpdateWidget(covariant IdDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.governmentId != widget.governmentId) {
      _startApplicantFlow();
      _detail = _load();
    }
  }

  @override
  void dispose() {
    _applicantFlow?.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: detailsBlue,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: detailsHeaderBlue,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    ),
    child: Builder(
      builder: (context) => FutureBuilder<GovernmentIdDetails>(
        future: _detail,
        builder: (context, snapshot) {
          final record =
              snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasError
              ? snapshot.data
              : null;
          final tabHeight =
              48.0 +
              (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(
                0,
                double.infinity,
              );
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: NestedScrollView(
                headerSliverBuilder: (context, scrolled) => [
                  SliverAppBar(
                    primary: false,
                    pinned: true,
                    backgroundColor: detailsHeaderBlue,
                    surfaceTintColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    leading: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    actions: [
                      if (widget.governmentId != null)
                        if (MediaQuery.sizeOf(context).width >= 360 &&
                            MediaQuery.textScalerOf(context).scale(14) <= 18)
                          TextButton(
                            onPressed: () => _openRoadmap(context, record),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Build My Roadmap'),
                          )
                        else
                          IconButton(
                            tooltip: 'Build My Roadmap',
                            icon: const Icon(Icons.route_outlined),
                            onPressed: () => _openRoadmap(context, record),
                          ),
                    ],
                    title: scrolled
                        ? Text(
                            record?.name ?? widget.idName,
                            key: const ValueKey('compact-id-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  SliverToBoxAdapter(child: _header(record)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedIdTabs(
                      height: tabHeight,
                      child: Material(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          height: tabHeight,
                          child: TabBar(
                            controller: _tabs,
                            isScrollable:
                                MediaQuery.sizeOf(context).width < 380 ||
                                MediaQuery.textScalerOf(context).scale(12) > 16,
                            tabAlignment:
                                MediaQuery.sizeOf(context).width < 380 ||
                                    MediaQuery.textScalerOf(context).scale(12) >
                                        16
                                ? TabAlignment.start
                                : TabAlignment.fill,
                            labelColor: detailsBlue,
                            unselectedLabelColor: const Color(0xFF64748B),
                            indicatorColor: detailsBlue,
                            dividerColor: const Color(0xFFE2E8F0),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            tabs: const [
                              Tab(text: 'Requirements'),
                              Tab(text: 'Estimated Cost'),
                              Tab(text: 'Offices'),
                              Tab(text: 'Guide'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                body: Material(color: Colors.white, child: _content(snapshot)),
              ),
            ),
          );
        },
      ),
    ),
  );
  void _openRoadmap(BuildContext context, GovernmentIdDetails? record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SequenceScreen(
          governmentId: widget.governmentId!,
          targetName: record?.name ?? widget.idName,
          applicantContext: _applicantFlow!.context,
          evaluate: widget.evaluateSequence,
          onContextChanged: (facts) {
            final flow = _applicantFlow;
            if (!mounted || flow == null) return;
            flow.context = facts;
            flow.draftAge = facts.age?.toString() ?? '';
            flow.draftApplicationType = facts.applicationType;
            flow.editorRevision++;
            flow.refresh();
          },
        ),
      ),
    );
  }

  Widget _header(GovernmentIdDetails? record) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE7FA),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(
                Icons.badge_outlined,
                size: 46,
                color: detailsBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record?.name ?? widget.idName,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (record?.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      record!.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (record?.validity != null)
                    _headerFact(
                      Icons.calendar_month_outlined,
                      'Validity',
                      record!.validity!,
                    ),
                  if (record?.issuedBy != null)
                    _headerFact(
                      Icons.account_balance_outlined,
                      'Issued by',
                      record!.issuedBy!,
                    ),
                  if (record?.purpose != null)
                    _headerFact(Icons.person_outline, 'Use', record!.purpose!),
                ],
              ),
            ),
          ],
        ),
        if (record != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme
                    .apply(bodyColor: Colors.white, displayColor: Colors.white),
                iconTheme: const IconThemeData(color: Colors.white70),
              ),
              child: ExpansionTile(
                title: const Text(
                  'About this ID',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
                iconColor: Colors.white,
                collapsedIconColor: Colors.white70,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  for (final entry in <String, String?>{
                    'Description': record.description,
                    'Purpose / usage': record.purpose,
                    'Validity': record.validity,
                    'Eligibility': record.eligibility,
                    'Processing time': record.processingTime,
                  }.entries)
                    if (entry.value != null) _about(entry.key, entry.value!),
                  ..._eligibility(record),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _headerFact(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _about(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(height: 1.5)),
      ],
    ),
  );
  List<Widget> _eligibility(GovernmentIdDetails record) {
    final data = record.eligibilityDetails;
    final rows = <Widget>[];
    if (data['eligibility_age_type'] == 'none') {
      rows.add(_about('Age requirement', 'No age requirement'));
    }
    if (data['eligibility_min_age'] != null) {
      rows.add(_about('Minimum age', '${data['eligibility_min_age']}'));
    }
    if (data['eligibility_max_age'] != null) {
      rows.add(_about('Maximum age', '${data['eligibility_max_age']}'));
    }
    for (final entry in {
      'Citizenship': 'eligibility_citizenship',
      'Residency': 'eligibility_residency',
      'Other eligibility conditions': 'eligibility_other_conditions',
    }.entries) {
      final value = data[entry.value];
      if (value is String && value.isNotEmpty) {
        rows.add(
          _about(
            entry.key,
            value == 'custom'
                ? '${data['eligibility_residency_custom'] ?? 'Custom restriction; confirm with the agency.'}'
                : value == 'none'
                ? 'No specific requirement'
                : const {
                        'filipino': 'Filipino citizen required',
                        'philippines': 'Philippine resident required',
                        'santa_maria': 'Santa Maria, Bulacan resident required',
                      }[value] ??
                      value.replaceAll('_', ' '),
          ),
        );
      }
    }
    return rows;
  }

  Widget _content(AsyncSnapshot<GovernmentIdDetails> snapshot) {
    if (widget.governmentId == null) {
      return const DetailMessage(
        'Open this ID from the ID Directory to view its current requirements.',
      );
    }
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError || snapshot.data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load Government ID details.'),
              TextButton(
                onPressed: () => setState(() {
                  _detail = _load();
                }),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final record = snapshot.data!;
    final flow = _applicantFlow!;
    return AnimatedBuilder(
      animation: flow,
      builder: (context, _) => !flow.ownershipReady
          ? Center(
              child: InventoryContextNotice(
                unavailable: flow.ownershipUnavailable,
                retry: flow.retryOwnership,
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                RequirementsTab(
                  governmentId: record,
                  evaluatedProfiles: flow.result?.requirements ?? [],
                  pendingProfiles: flow.result?.pendingRequirements ?? [],
                  applicationCard: ApplicantContextCard(flow: flow),
                ),
                GovernmentCostTab(record: record),
                GovernmentOfficesTab(record: record),
                GovernmentGuideTab(
                  record: record,
                  evaluatedSteps: flow.result?.steps ?? [],
                  pendingSteps: flow.result?.pendingSteps ?? [],
                  evaluatedRequirements: flow.result?.requirements ?? [],
                  pendingRequirements: flow.result?.pendingRequirements ?? [],
                  applicationCard: ApplicantContextCard(flow: flow),
                ),
              ],
            ),
    );
  }
}

class _PinnedIdTabs extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  _PinnedIdTabs({required this.height, required this.child});
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(covariant _PinnedIdTabs oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}
