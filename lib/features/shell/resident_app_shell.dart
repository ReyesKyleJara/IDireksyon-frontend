import 'package:flutter/material.dart';

import '../../core/widgets/app_motion.dart';

import '../home/home_screen.dart';
import '../roadmap/roadmap_screen.dart';
import '../roadmap/active_journey_screen.dart';
import '../roadmap/id_journey.dart';
import '../ids/ids_screen.dart';
import '../profile/profile_screen.dart';

class ResidentAppShell extends StatefulWidget {
  const ResidentAppShell({
    super.key,
    this.initialIndex = 0,
    this.journeyConfirmed = false,
    this.journeys = const [],
  });
  final int initialIndex;
  final bool journeyConfirmed;
  final List<IdJourney> journeys;

  @override
  State<ResidentAppShell> createState() => _ResidentAppShellState();
}

class _ResidentAppShellState extends State<ResidentAppShell> {
  late int _currentIndex = widget.initialIndex;

  static const Color primaryBlue = Color(0xFF1E3A8A);

  late final List<IdJourney> _journeys = widget.journeys.isNotEmpty
      ? List.of(widget.journeys)
      : widget.journeyConfirmed
      ? [IdJourney()]
      : [];

  late final List<Widget> _pages = [
    HomeScreen(
      journeys: _journeys,
      onOpenJourney: (journey) {
        setState(() {
          journey.minimized = false;
          _pages[1] = ActiveJourneyScreen(
            key: ObjectKey(journey),
            journeys: _journeys,
            initialJourney: journey,
          );
          _currentIndex = 1;
        });
      },
    ),
    _journeys.isNotEmpty
        ? ActiveJourneyScreen(journeys: _journeys)
        : RoadmapScreen(
            onOpenDirectory: () => setState(() => _currentIndex = 2),
          ),
    const IdsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (var i = 0; i < _pages.length; i++)
            MotionTab(active: i == _currentIndex, child: _pages[i]),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.brightness == Brightness.dark
                ? colorScheme.surfaceContainer
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,

              onTap: (index) {
                if (index == _currentIndex) return;
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() {
                  _currentIndex = index;
                });
              },

              type: BottomNavigationBarType.fixed,

              backgroundColor: Colors.transparent,
              elevation: 0,
              iconSize: 27,
              selectedFontSize: 11,
              unselectedFontSize: 11,

              selectedItemColor: colorScheme.brightness == Brightness.dark
                  ? Colors.blue.shade200
                  : primaryBlue,

              unselectedItemColor: colorScheme.onSurfaceVariant,

              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.5,
              ),

              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                height: 1.5,
              ),

              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),

                BottomNavigationBarItem(
                  // Route icon represents the user's ID journey.
                  icon: Icon(Icons.alt_route_outlined),
                  activeIcon: Icon(Icons.alt_route),
                  label: 'My ID Journey',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.badge_outlined),
                  activeIcon: Icon(Icons.badge),
                  label: 'ID Directory',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle_outlined),
                  activeIcon: Icon(Icons.account_circle),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
