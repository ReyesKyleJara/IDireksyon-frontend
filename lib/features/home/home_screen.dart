import '../../core/widgets/app_motion.dart';
import '../../core/widgets/frosted.dart';

import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/profile/profile_avatar.dart';
import '../../core/theme/app_theme.dart';
import '../ids/ids_screen.dart';
import '../office_finder/office_finder_screen.dart';
import '../profile/manage_inventory_screen.dart';
import '../roadmap/build_roadmap_screen.dart';
import '../roadmap/id_journey.dart';
import '../roadmap/active_journey_screen.dart';
import 'diro_poses.dart';
import 'home_recommendations.dart';
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

    // The same rule as the Roadmap's In Progress tab.
    final ongoing = journeys
        .where((journey) => !journey.isCompleted)
        .toList();

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

            ongoing.isEmpty
                ? _banner(context)
                : JourneyBanner(
                    // A finished journey leaves the list, so the banner must
                    // not stay on a page that no longer exists.
                    key: ValueKey(ongoing.length),
                    journeys: ongoing,
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

            const HomeRecommendations(),
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
                      right: -6,
                      bottom: 8,
                      child: DiroPoses(size: 164),
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
                        const Text(
                          'YOUR NEXT CHAPTER',
                          style: TextStyle(
                            color: Color(0xFFD5E7FA),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
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
