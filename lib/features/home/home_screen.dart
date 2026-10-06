import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../ids/ids_screen.dart';
import '../ids/id_details_screen.dart';
import '../office_finder/office_finder_screen.dart';
import '../profile/manage_inventory_screen.dart';
import '../roadmap/build_roadmap_screen.dart';
import '../roadmap/id_journey.dart';
import '../roadmap/active_journey_screen.dart';
import 'journey_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.journeys = const [], this.onOpenJourney});
  final List<IdJourney> journeys;
  final ValueChanged<IdJourney>? onOpenJourney;
  static const primaryBlue = Color(0xFF174B85);

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            journeys.isEmpty
                ? _banner(context)
                : JourneyBanner(
                    journeys: journeys,
                    onOpen:
                        onOpenJourney ??
                        (journey) => _open(
                          context,
                          Scaffold(
                            appBar: AppBar(title: const Text('My ID Journey')),
                            body: ActiveJourneyScreen(
                              journeys: journeys,
                              initialJourney: journey,
                            ),
                          ),
                        ),
                  ),
            const SizedBox(height: 28),
            const Text(
              'Quick actions',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _action(
                    context,
                    Icons.folder_copy_rounded,
                    primaryBlue,
                    'Document\nInventory',
                    const ManageInventoryScreen(),
                  ),
                  const SizedBox(width: 10),
                  _action(
                    context,
                    Icons.location_on_rounded,
                    const Color(0xFFC84648),
                    'Office\nFinder',
                    const OfficeFinderScreen(),
                  ),
                  const SizedBox(width: 10),
                  _action(
                    context,
                    Icons.badge_rounded,
                    const Color(0xFFAA7309),
                    'ID\nDirectory',
                    const IdsScreen(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recommended for you',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A good place to start your journey',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _open(context, const IdsScreen()),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _recommendation(context, passport: true),
            const SizedBox(height: 12),
            _recommendation(context, passport: false),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final name = AuthService.instance.user?['name'] as String?;
    final displayName = name?.trim();
    final colors = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning,'
        : hour < 18
        ? 'Good Afternoon,'
        : 'Good Evening,';

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: colors.surfaceContainerHighest,
          child: Icon(
            Icons.person_rounded,
            color: colors.onSurfaceVariant,
            size: 28,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName == null || displayName.isEmpty
                    ? 'User'
                    : displayName,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _banner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF103765), Color(0xFF246AA5)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showArt =
                  constraints.maxWidth >= 320 &&
                  MediaQuery.textScalerOf(context).scale(1) < 1.5;
              return Stack(
                children: [
                  Positioned(
                    right: -55,
                    top: -65,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .08),
                          width: 35,
                        ),
                      ),
                    ),
                  ),
                  if (showArt)
                    const Positioned(
                      right: 8,
                      bottom: 24,
                      child: ExcludeSemantics(child: _JourneyArt()),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      22,
                      24,
                      showArt ? 130 : 22,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFFFD576),
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'YOUR NEXT CHAPTER',
                                style: TextStyle(
                                  color: Color(0xFFD5E7FA),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        const Text(
                          'Your ID journey\nstarts here.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            letterSpacing: -.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'The right IDs. Clear steps.\nLet’s get you started.',
                          style: TextStyle(
                            color: Color(0xFFD5E7FA),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _open(
                            context,
                            BuildRoadmapScreen(existingJourneys: journeys),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Get started',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded, size: 17),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _surface(BuildContext context, {required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.brightness == Brightness.dark
          ? colors.surfaceContainer
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    Color tint,
    String label,
    Widget page,
  ) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final pastel = icon == Icons.folder_copy_rounded
        ? const Color(0xFFF0F5FA)
        : icon == Icons.location_on_rounded
        ? const Color(0xFFFDF0F0)
        : const Color(0xFFFFF7E6);
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: dark ? .05 : .08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: dark
              ? Color.alphaBlend(
                  tint.withValues(alpha: .12),
                  colors.surfaceContainer,
                )
              : pastel,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: MotionInkWell(
            onTap: () => _open(context, page),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 22),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: dark
                          ? colors.surfaceContainerHighest
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: dark ? Color.lerp(tint, Colors.white, .4) : tint,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recommendation(BuildContext context, {required bool passport}) {
    final colors = Theme.of(context).colorScheme;
    return _surface(
      context,
      child: MotionInkWell(
        onTap: () => _open(
          context,
          IdDetailsScreen(idName: passport ? 'Passport ID' : 'PhilSys ID'),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 76,
                  height: 88,
                  decoration: BoxDecoration(
                    color: passport
                        ? const Color(0xFFEAF1FB)
                        : const Color(0xFFFFF1EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: passport ? -.09 : .08,
                      child: passport
                          ? Container(
                              width: 44,
                              height: 62,
                              decoration: BoxDecoration(
                                color: const Color(0xFF234E7A),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.public,
                                    color: Color(0xFFE9CB87),
                                    size: 26,
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'PASSPORT',
                                    style: TextStyle(
                                      color: Color(0xFFE9CB87),
                                      fontSize: 6,
                                      letterSpacing: .8,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const _MiniId(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passport ? 'TRAVEL & EXPLORATION' : 'EVERYDAY ESSENTIAL',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      passport ? 'Philippine Passport' : 'PhilSys ID',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      passport
                          ? 'Your gateway to the world'
                          : 'One ID. More possibilities.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
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

class _MiniId extends StatelessWidget {
  const _MiniId();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 42,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180E335B),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF245FA0),
                  Color(0xFFDA5C5C),
                  Color(0xFFF0C660),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.person_rounded,
                size: 20,
                color: HomeScreen.primaryBlue,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  children: [
                    for (final width in [25.0, 20.0, 23.0])
                      Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        width: width,
                        height: 2,
                        color: const Color(0xFFCBD8E6),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyArt extends StatelessWidget {
  const _JourneyArt();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 174,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
          Transform.rotate(
            angle: .12,
            child: Container(
              width: 83,
              height: 142,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6FC),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFF092A50), width: 5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40092343),
                    blurRadius: 14,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 25,
                    height: 4,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF092A50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.verified_user_rounded,
                    color: HomeScreen.primaryBlue,
                    size: 25,
                  ),
                  const SizedBox(height: 10),
                  const _MiniId(),
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8CEE4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 15,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD576),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 23,
                color: Color(0xFF163F65),
              ),
            ),
          ),
          const Positioned(
            left: 1,
            top: 12,
            child: Icon(Icons.auto_awesome, size: 22, color: Color(0xFFFFD576)),
          ),
        ],
      ),
    );
  }
}
