import '../../core/widgets/app_motion.dart';
import '../../core/widgets/frosted.dart';

import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/profile/profile_avatar.dart';
import '../../core/theme/app_theme.dart';
import '../ids/ids_screen.dart';
import '../ids/id_details_screen.dart';
import '../office_finder/office_finder_screen.dart';
import '../profile/manage_inventory_screen.dart';
import '../roadmap/build_roadmap_screen.dart';
import '../roadmap/id_journey.dart';
import '../roadmap/active_journey_screen.dart';
import 'journey_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.journeys = const [],
    this.onOpenJourney,
    this.onOpenDirectory,
  });

  final List<IdJourney> journeys;
  final ValueChanged<IdJourney>? onOpenJourney;

  /// Switches to the IDirectory tab. Without it (Home shown on its own), the
  /// directory opens as its own page.
  final VoidCallback? onOpenDirectory;

  void _openDirectory(
    BuildContext context,
  ) {
    if (onOpenDirectory != null) {
      onOpenDirectory!();
      return;
    }
    _open(
      context,
      Scaffold(
        body: const IdsScreen(showBack: true),
      ),
    );
  }

  static const primaryBlue =
      Color(0xFF174B85);

  void _open(
    BuildContext context,
    Widget page,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return SafeArea(
      child: ColoredBox(
        color: Theme.of(context)
            .scaffoldBackgroundColor,
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            28,
            20,
            24,
          ),
          children: [
            AnimatedBuilder(
              animation: AuthService.instance,
              builder: (context, _) => _buildHeader(context),
            ),

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
                            appBar: AppBar(
                              title:
                                  const Text(
                                'My ID Journey',
                              ),
                            ),
                            body:
                                ActiveJourneyScreen(
                              journeys:
                                  journeys,
                              initialJourney:
                                  journey,
                            ),
                          ),
                        ),
                  ),

            const SizedBox(height: 28),

            const Text(
              'Quick actions',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 14),

            _quickActions(context),

            const SizedBox(height: 28),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Recommended for you',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        'A good place to start your journey',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _openDirectory(
                    context,
                  ),
                  child:
                      const Text('View all'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _recommendation(
              context,
              passport: true,
            ),

            const SizedBox(height: 12),

            _recommendation(
              context,
              passport: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
  ) {
    final name =
        AuthService.instance.user?['name']
            as String?;

    final displayName = name?.trim();

    final colors =
        Theme.of(context).colorScheme;

    final hour = DateTime.now().hour;

    final greeting = hour < 12
        ? 'Good Morning,'
        : hour < 18
        ? 'Good Afternoon,'
        : 'Good Evening,';

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        const ProfileAvatar(
          size: 50,
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight:
                      FontWeight.w400,
                  color: colors
                      .onSurfaceVariant,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                displayName == null ||
                        displayName.isEmpty
                    ? 'User'
                    : displayName,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      colors.onSurface,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _banner(
    BuildContext context,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryBlue
                .withValues(alpha: .18),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(26),
        child: DecoratedBox(
          decoration:
              const BoxDecoration(
            gradient: LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Color(0xFF103765),
                Color(0xFF246AA5),
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final showArt =
                  constraints.maxWidth >=
                          320 &&
                      MediaQuery
                              .textScalerOf(
                                context,
                              )
                          .scale(1) <
                          1.5;

              return Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: frostedBannerEdge,
                    ),
                  ),
                  Positioned(
                    right: -55,
                    top: -65,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        border:
                            Border.all(
                          color: Colors
                              .white
                              .withValues(
                            alpha: .08,
                          ),
                          width: 35,
                        ),
                      ),
                    ),
                  ),

                  if (showArt)
                    const Positioned(
                      right: 8,
                      bottom: 24,
                      child:
                          ExcludeSemantics(
                        child:
                            _JourneyArt(),
                      ),
                    ),

                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(
                      22,
                      24,
                      showArt
                          ? 130
                          : 22,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons
                                  .auto_awesome_rounded,
                              color: Color(
                                0xFFFFD576,
                              ),
                              size: 14,
                            ),
                            SizedBox(
                              width: 6,
                            ),
                            Flexible(
                              child: Text(
                                'YOUR NEXT CHAPTER',
                                style:
                                    TextStyle(
                                  color:
                                      Color(
                                    0xFFD5E7FA,
                                  ),
                                  fontSize:
                                      9,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                  letterSpacing:
                                      1.2,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 13,
                        ),

                        const Text(
                          'Your ID journey\nstarts here.',
                          style: TextStyle(
                            color:
                                Colors.white,
                            fontSize: 25,
                            fontWeight:
                                FontWeight
                                    .w800,
                            height: 1.12,
                            letterSpacing:
                                -.6,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        const Text(
                          'The right IDs. Clear steps.\nLet’s get you started.',
                          style: TextStyle(
                            color: Color(
                              0xFFD5E7FA,
                            ),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        FilledButton(
                          style:
                              FilledButton
                                  .styleFrom(
                            backgroundColor:
                                Colors.white,
                            foregroundColor:
                                primaryBlue,
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  16,
                              vertical:
                                  12,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                            ),
                          ),
                          onPressed: () =>
                              _open(
                            context,
                            BuildRoadmapScreen(
                              existingJourneys:
                                  journeys,
                            ),
                          ),
                          child:
                              const Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              // Flexible lets the label wrap instead of
                              // overflowing on narrow screens.
                              Flexible(
                                child: Text(
                                  'Get started',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Icon(
                                Icons
                                    .arrow_forward_rounded,
                                size: 17,
                              ),
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

  Widget _surface(
    BuildContext context, {
    required Widget child,
  }) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color:
          colors.brightness ==
                  Brightness.dark
              ? colors.surfaceContainer
              : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
        side: BorderSide(
          color: colors.outlineVariant
              .withValues(alpha: .45),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: child,
    );
  }

  Widget _quickActions(
    BuildContext context,
  ) {
    // With large text, three columns would squeeze the labels, so the
    // tiles stack as full-width rows instead.
    final largeText = MediaQuery
            .textScalerOf(context)
            .scale(1) >=
        1.4;

    final actions = [
      _QuickAction(
        icon: Icons.folder_copy_rounded,
        tint: primaryBlue,
        label: 'Document\nInventory',
        horizontal: largeText,
        onTap: () => _open(
          context,
          const ManageInventoryScreen(),
        ),
      ),
      _QuickAction(
        icon: Icons.location_on_rounded,
        tint: const Color(0xFFC84648),
        label: 'Office\nFinder',
        horizontal: largeText,
        onTap: () => _open(
          context,
          const OfficeFinderScreen(),
        ),
      ),
      _QuickAction(
        icon: Icons.badge_rounded,
        tint: const Color(0xFFAA7309),
        label: 'ID\nDirectory',
        horizontal: largeText,
        onTap: () =>
            _openDirectory(context),
      ),
    ];

    if (largeText) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          for (final (i, tile)
              in actions.indexed) ...[
            if (i > 0)
              const SizedBox(height: 10),
            tile,
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          for (final (i, tile)
              in actions.indexed) ...[
            if (i > 0)
              const SizedBox(width: 12),
            Expanded(child: tile),
          ],
        ],
      ),
    );
  }

  Widget _recommendation(
    BuildContext context, {
    required bool passport,
  }) {
    final colors =
        Theme.of(context).colorScheme;

    return _surface(
      context,
      child: MotionInkWell(
        onTap: () => _open(
          context,
          IdDetailsScreen(
            idName: passport
                ? 'Passport ID'
                : 'PhilSys ID',
          ),
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 76,
                  height: 88,
                  decoration:
                      BoxDecoration(
                    color: passport
                        ? const Color(
                            0xFFEAF1FB,
                          )
                        : const Color(
                            0xFFFFF1EB,
                          ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      14,
                    ),
                  ),
                  child: Center(
                    child:
                        Transform.rotate(
                      angle: passport
                          ? -.09
                          : .08,
                      child: passport
                          ? Container(
                              width: 44,
                              height: 62,
                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                  0xFF234E7A,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  5,
                                ),
                              ),
                              child:
                                  const Column(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(
                                    Icons.public,
                                    color: Color(
                                      0xFFE9CB87,
                                    ),
                                    size: 26,
                                  ),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  Text(
                                    'PASSPORT',
                                    style:
                                        TextStyle(
                                      color:
                                          Color(
                                        0xFFE9CB87,
                                      ),
                                      fontSize:
                                          6,
                                      letterSpacing:
                                          .8,
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
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      passport
                          ? 'TRAVEL & EXPLORATION'
                          : 'EVERYDAY ESSENTIAL',
                      style: TextStyle(
                        color: colors
                            .onSurfaceVariant,
                        fontSize: 9,
                        fontWeight:
                            FontWeight
                                .w700,
                        letterSpacing:
                            .7,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      passport
                          ? 'Philippine Passport'
                          : 'PhilSys ID',
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      passport
                          ? 'Your gateway to the world'
                          : 'One ID. More possibilities.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors
                            .onSurfaceVariant,
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
                color:
                    colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick action tile: white card, colored icon block, centered content.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final VoidCallback onTap;

  /// Row layout for large text.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final shape = BorderRadius.circular(22);

    final badge = ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(tint, Colors.white, .18)!, tint],
          ),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: dark ? .2 : .28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: SizedBox.square(
          dimension: 50,
          child: Icon(icon, color: Colors.white, size: 25),
        ),
      ),
    );

    final text = Text(
      label,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: dark ? colors.onSurface : AppTheme.navy,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: tint.withValues(alpha: .07),
                  blurRadius: 26,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Material(
        color: dark ? colors.surfaceContainer : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(
            color: dark
                ? colors.outlineVariant.withValues(alpha: .35)
                : const Color(0xFFE3ECF7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: MotionInkWell(
          onTap: onTap,
          child: Padding(
            padding: horizontal
                ? const EdgeInsets.all(14)
                : const EdgeInsets.fromLTRB(8, 18, 8, 16),
            child: horizontal
                ? Row(
                    children: [
                      badge,
                      const SizedBox(width: 14),
                      Expanded(child: text),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [badge, const SizedBox(height: 12), text],
                  ),
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
      padding:
          const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(
              0x180E335B,
            ),
            blurRadius: 8,
            offset:
                Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 3,
            decoration:
                const BoxDecoration(
              gradient:
                  LinearGradient(
                colors: [
                  Color(
                    0xFF245FA0,
                  ),
                  Color(
                    0xFFDA5C5C,
                  ),
                  Color(
                    0xFFF0C660,
                  ),
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
                color:
                    HomeScreen.primaryBlue,
              ),

              const SizedBox(width: 4),

              Expanded(
                child: Column(
                  children: [
                    for (final width in [
                      25.0,
                      20.0,
                      23.0,
                    ])
                      Container(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 3,
                        ),
                        width: width,
                        height: 2,
                        color:
                            const Color(
                          0xFFCBD8E6,
                        ),
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

class _JourneyArt
    extends StatelessWidget {
  const _JourneyArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 174,
      child: Stack(
        alignment:
            Alignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color: Colors.white
                  .withValues(
                alpha: .08,
              ),
            ),
          ),

          Transform.rotate(
            angle: .12,
            child: Container(
              width: 83,
              height: 142,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF1F6FC,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  17,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFF092A50,
                  ),
                  width: 5,
                ),
                boxShadow:
                    const [
                  BoxShadow(
                    color:
                        Color(
                      0x40092343,
                    ),
                    blurRadius:
                        14,
                    offset:
                        Offset(
                      0,
                      10,
                    ),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 25,
                    height: 4,
                    margin:
                        const EdgeInsets
                            .only(
                      top: 5,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFF092A50,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        4,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  const Icon(
                    Icons
                        .verified_user_rounded,
                    color:
                        HomeScreen
                            .primaryBlue,
                    size: 25,
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  const _MiniId(),

                  const SizedBox(
                    height: 10,
                  ),

                  Container(
                    width: 36,
                    height: 4,
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFB8CEE4,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        4,
                      ),
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
              padding:
                  const EdgeInsets
                      .all(
                9,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFFFD576,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  13,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .check_rounded,
                size: 23,
                color:
                    Color(
                  0xFF163F65,
                ),
              ),
            ),
          ),

          const Positioned(
            left: 1,
            top: 12,
            child: Icon(
              Icons.auto_awesome,
              size: 22,
              color:
                  Color(
                0xFFFFD576,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
