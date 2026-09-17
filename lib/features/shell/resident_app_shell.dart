import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../roadmap/roadmap_screen.dart';
import '../ids/ids_screen.dart';
import '../profile/profile_screen.dart';

class ResidentAppShell extends StatefulWidget {
  const ResidentAppShell({super.key});

  @override
  State<ResidentAppShell> createState() => _ResidentAppShellState();
}

class _ResidentAppShellState extends State<ResidentAppShell> {
  int _currentIndex = 0;

  static const Color primaryBlue = Color(0xFF1E3A8A);

  final List<Widget> _pages = const [
    HomeScreen(),
    RoadmapScreen(),
    IdsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,

              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },

              type: BottomNavigationBarType.fixed,

              backgroundColor: Colors.transparent,
              elevation: 0,

              selectedItemColor: primaryBlue,

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
                  label: 'Roadmap',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.badge_outlined),
                  activeIcon: Icon(Icons.badge),
                  label: 'Directory',
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
