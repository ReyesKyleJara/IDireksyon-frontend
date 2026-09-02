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
    // Check whether dark mode is currently active.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // Bottom navigation bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,

          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },

          // Keeps all four navigation items visible.
          type: BottomNavigationBarType.fixed,

          backgroundColor: isDark
              ? Theme.of(context).colorScheme.surface
              : Colors.white,

          selectedItemColor: isDark
              ? Colors.blue.shade300
              : primaryBlue,

          unselectedItemColor: Colors.grey.shade400,

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
              label: 'IDs',
            ),

            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}