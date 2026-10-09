import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';

import '../../models/government_id.dart';
import '../../services/api_service.dart';
import 'requirements_tab.dart';

class IdDetailsScreen extends StatefulWidget {
  final String idName;
  final int? governmentId;
  final Future<GovernmentIdDetails> Function(int)? loadDetail;

  const IdDetailsScreen({super.key, required this.idName, this.governmentId, this.loadDetail});

  @override
  State<IdDetailsScreen> createState() => _IdDetailsScreenState();
}

class _IdDetailsScreenState extends State<IdDetailsScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBlue = Color(0xFFEFF4FB);
  Future<GovernmentIdDetails>? _detail;
  GovernmentIdDetails? _record;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _detail = _load();
  }

  Future<GovernmentIdDetails>? _load() {
    final id = widget.governmentId;
    return id == null ? null : (widget.loadDetail?.call(id) ?? ApiService.getGovernmentId(id));
  }

  @override
  void didUpdateWidget(covariant IdDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.governmentId != widget.governmentId) {
      _record = null;
      _detail = _load();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GovernmentIdDetails>(
      future: _detail,
      builder: (context, snapshot) {
        _record = snapshot.connectionState == ConnectionState.done && !snapshot.hasError ? snapshot.data : null;
        return _buildScreen(context, snapshot);
      },
    );
  }

  Widget _buildScreen(BuildContext context, AsyncSnapshot<GovernmentIdDetails> snapshot) {
    return Scaffold(
      backgroundColor: const Color(0xFF072C76),
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              primary: false,
              pinned: true,
              backgroundColor: const Color(0xFF072C76),
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              elevation: 0,
              scrolledUnderElevation: 0,
              title: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero : const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previousChildren, ?currentChild],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.12), end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: innerBoxIsScrolled
                    ? Text(_record?.name ?? widget.idName,
                        key: const ValueKey('compact-id-title'),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
                    : const SizedBox.shrink(key: ValueKey('expanded-id-title')),
              ),
            ),
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedIdTabs(
                height: 48 + (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0, double.infinity),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: _buildTabBar(),
                ),
              ),
            ),
          ],
          body: _buildContent(context, snapshot),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(width: 88, height: 64,
            decoration: BoxDecoration(color: const Color(0xFFDDE7FA), borderRadius: BorderRadius.circular(5)),
            child: const Icon(Icons.badge_outlined, size: 46, color: Color(0xFF345F9E))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_record?.name ?? widget.idName, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, height: 1.2, fontWeight: FontWeight.w800, color: Colors.white)),
            if (_record?.description != null) ...[
              const SizedBox(height: 4),
              Text(_record!.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, height: 1.4, color: Colors.white70)),
            ],
            if (_record?.validity != null) _headerFact(Icons.calendar_month_outlined, 'Validity', _record!.validity!),
            if (_record?.issuedBy != null) _headerFact(Icons.account_balance_outlined, 'Issued by', _record!.issuedBy!),
            if (_record?.purpose != null) _headerFact(Icons.person_outline_rounded, 'Use', _record!.purpose!),
          ])),
        ]),
      ]),
    );
  }

  Widget _headerFact(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.only(top: 7), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 7),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, height: 1.35, color: Colors.white70)),
        ])),
      ],
    ));
  }

  // ============================================================
  // WHITE CONTENT CONTAINER
  // ============================================================

  Widget _buildContent(BuildContext context, AsyncSnapshot<GovernmentIdDetails> snapshot) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildRequirementsTab(snapshot),
          _buildCostTab(),
          _buildOfficesTab(),
          _buildGuideTab(),
        ],
      ),
    );
  }

  // ============================================================
  // TAB BAR
  // ============================================================

  Widget _buildTabBar() {
    return SizedBox(
      height: 48,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,

        labelColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFA8CCFA) : primaryBlue,
        unselectedLabelColor: const Color(0xFF9299A5),

        indicatorColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFA8CCFA) : primaryBlue,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,

        dividerColor: const Color(0xFFE9ECF1),

        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),

        labelPadding: const EdgeInsets.symmetric(horizontal: 15),

        tabs: const [
          Tab(text: 'Requirements'),
          Tab(text: 'Estimated Cost'),
          Tab(text: 'Offices'),
          Tab(text: 'Guide'),
        ],
      ),
    );
  }

  // ============================================================
  // REQUIREMENTS
  // ============================================================

  Widget _buildRequirementsTab(AsyncSnapshot<GovernmentIdDetails> snapshot) {
    if (widget.governmentId == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Open this ID from the ID Directory to view its current requirements.'),
      );
    }
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError || snapshot.data == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Could not load requirements.'),
        TextButton(onPressed: () {
              final request = _load();
              setState(() {
                _detail = request;
              });
            }, child: const Text('Retry')),
      ]));
    }
    return RequirementsTab(governmentId: snapshot.data!);
  }

  // ============================================================
  // COST
  // ============================================================

  Widget _buildCostTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: softBlue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Estimated Cost',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF687385),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '₱2,350.00',
                      style: TextStyle(
                        fontSize: 24,
                        color: primaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        _buildSectionTitle(
          title: 'Cost Overview',
          subtitle: 'Estimated expenses for your application',
        ),

        const SizedBox(height: 14),

        _buildCostRow(label: 'Application Fee', amount: '₱950.00'),
        _buildCostRow(label: 'Processing Fee', amount: '₱1,400.00'),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: Color(0xFFE7E9ED)),
        ),

        _buildCostRow(
          label: 'Estimated Total',
          amount: '₱2,350.00',
          isTotal: true,
        ),

        const SizedBox(height: 22),

        _buildImportantNotes(
          'Fees shown are estimates and may change. Always verify the current fees with the issuing agency.',
        ),
      ],
    );
  }

  // ============================================================
  // OFFICES
  // ============================================================

  Widget _buildOfficesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildSearchField(hintText: 'Search offices'),

        const SizedBox(height: 16),

        Container(
          height: 170,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.map_outlined,
                  size: 46,
                  color: Color(0xFF8A96A8),
                ),
              ),

              Positioned(top: 45, left: 90, child: _buildMapPin()),

              Positioned(bottom: 45, right: 90, child: _buildMapPin()),

              Positioned(
                bottom: 12,
                right: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 1,
                  child: MotionInkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 15,
                            color: primaryBlue,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'My location',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        _buildSectionTitle(
          title: 'Nearby Offices',
          subtitle: 'Offices where you can process this ID',
        ),

        const SizedBox(height: 12),

        _buildOfficeCard(
          officeName: 'DFA Consular Office',
          address: 'Example address, Bulacan',
          travelTime: '25 min away',
        ),

        const SizedBox(height: 12),

        _buildOfficeCard(
          officeName: 'DFA Consular Office',
          address: 'Example address, Metro Manila',
          travelTime: '45 min away',
        ),
      ],
    );
  }

  // ============================================================
  // GUIDE
  // ============================================================

  Widget _buildGuideTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text(
          'Passport Application Guide',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Follow these steps to complete your application.',
          style: TextStyle(fontSize: 12, color: Color(0xFF778092)),
        ),

        const SizedBox(height: 24),

        _buildGuideStep(
          number: '01',
          title: 'Online Appointment',
          description: 'Schedule an appointment through the official application portal.',
          isLast: false,
        ),

        _buildGuideStep(
          number: '02',
          title: 'Accomplish the Form',
          description: 'Complete the required application information before your appointment.',
          isLast: false,
        ),

        _buildGuideStep(
          number: '03',
          title: 'Personal Appearance',
          description:
              'Visit your selected office and bring all required documents.',
          isLast: true,
        ),

        const SizedBox(height: 20),

        _buildImportantNotes(
          'Use only official government websites and channels when submitting applications or payments.',
        ),
      ],
    );
  }

  // ============================================================
  // SHARED COMPONENTS
  // ============================================================

  Widget _buildSectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF7C8493)),
        ),
      ],
    );
  }

  Widget _buildImportantNotes(String text) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 19,
            color: Color(0xFF7C8493),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IMPORTANT NOTES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFF4E5868),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: Color(0xFF737C8C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow({
    required String label,
    required String amount,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 12 : 11.5,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
                color: const Color(0xFF4D5665),
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 13 : 11.5,
              fontWeight: FontWeight.w800,
              color: isTotal ? primaryBlue : const Color(0xFF293244),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({required String hintText}) {
    return TextField(
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9AA1AC)),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: Color(0xFF858D9A),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E8EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E8EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.3),
        ),
      ),
    );
  }

  Widget _buildMapPin() {
    return const Icon(Icons.location_on_rounded, color: primaryBlue, size: 32);
  }

  Widget _buildOfficeCard({
    required String officeName,
    required String address,
    required String travelTime,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      officeName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF293244),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF7C8493),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      travelTime,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.directions_rounded, size: 16),
              label: const Text(
                'Get Directions',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBlue,
                side: const BorderSide(color: Color(0xFFCCD6E5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({
    required String number,
    required String title,
    required String description,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: const Color(0xFFDCE2EA),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF293244),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: Color(0xFF7C8493),
                    ),
                  ),
                ],
              ),
            ),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _PinnedIdTabs oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}
