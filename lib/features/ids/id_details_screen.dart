import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class IdDetailsScreen extends StatefulWidget {
  final String idName;

  const IdDetailsScreen({super.key, required this.idName});

  @override
  State<IdDetailsScreen> createState() => _IdDetailsScreenState();
}

class _IdDetailsScreenState extends State<IdDetailsScreen>
    with SingleTickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBlue = Color(0xFFEFF4FB);
  static const Color gold = Color(0xFFF4C542);

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          _buildTopBar(),
          const SizedBox(height: 20),
          _buildIdOverview(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.idName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      child: MotionInkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildIdOverview() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIdThumbnail(),
        const SizedBox(width: 15),
        Expanded(child: _buildIdInformation()),
        const SizedBox(width: 12),
        _buildReadiness(),
      ],
    );
  }

  Widget _buildIdThumbnail() {
    return Container(
      width: 82,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: const Icon(Icons.badge_rounded, size: 28, color: Colors.white),
    );
  }

  Widget _buildIdInformation() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Issued by',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1),
        Text(
          'Department of Foreign Affairs',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 7),
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 13, color: Colors.white60),
            SizedBox(width: 4),
            Text(
              'Valid for 10 years',
              style: TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ],
        ),
        SizedBox(height: 3),
        Row(
          children: [
            Icon(Icons.public_rounded, size: 13, color: Colors.white60),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'International travel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadiness() {
    return Column(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: 0.5,
                  strokeWidth: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(gold),
                ),
              ),
              const Text(
                '50%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ready',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WHITE CONTENT CONTAINER
  // ============================================================

  Widget _buildContent(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.pageBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequirementsTab(),
                _buildCostTab(),
                _buildOfficesTab(),
                _buildGuideTab(),
              ],
            ),
          ),
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

        labelColor: primaryBlue,
        unselectedLabelColor: const Color(0xFF9299A5),

        indicatorColor: primaryBlue,
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

  Widget _buildRequirementsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildInfoBanner(
          icon: Icons.info_outline_rounded,
          title: 'Before you apply',
          message: 'Make sure you have the required documents ready before proceeding with your application.',
        ),
        const SizedBox(height: 22),

        _buildSectionTitle(
          title: 'Basic Requirements',
          subtitle: 'Documents you should prepare',
        ),
        const SizedBox(height: 12),

        _buildRequirementItem(
          title: 'Birth Certificate',
          subtitle: 'Original or certified copy',
        ),
        _buildRequirementItem(
          title: 'Valid Government ID',
          subtitle: 'Bring an accepted primary ID',
        ),

        const SizedBox(height: 22),

        _buildSectionTitle(
          title: 'Primary ID Requirements',
          subtitle: 'Additional requirements for this application',
        ),
        const SizedBox(height: 12),

        _buildRequirementItem(
          title: 'Personal Appearance',
          subtitle: 'Applicant must appear in person',
        ),
        _buildRequirementItem(
          title: 'Confirmed Appointment',
          subtitle: 'Bring your appointment confirmation',
        ),

        const SizedBox(height: 20),

        _buildImportantNotes(
          'Requirements may vary depending on your application type and current government policies.',
        ),
      ],
    );
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

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6F4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: primaryBlue, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: Color(0xFF566174),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem({
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8EBEF)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC8CDD5), width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF293244),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF858D9A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
