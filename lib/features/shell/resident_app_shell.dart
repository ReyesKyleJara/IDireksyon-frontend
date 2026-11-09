import 'package:flutter/material.dart';

import '../../core/widgets/app_motion.dart';
import '../../core/auth/auth_service.dart';

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

class _ResidentAppShellState extends State<ResidentAppShell>
    with WidgetsBindingObserver {
  late int _currentIndex = widget.initialIndex;

  late final List<IdJourney> _journeys = widget.journeys.isNotEmpty
      ? List.of(widget.journeys)
      : widget.journeyConfirmed
      ? [IdJourney()]
      : [];

  late final AuthService _auth = AuthService.instance;
  String? _session;
  IdJourney? _selectedJourney;
  bool _loading = false;
  String? _loadError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _session = _auth.token;
    _auth.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    if (_journeys.isEmpty && _session != null) _restore();
  }

  @override
  void dispose() {
    _auth.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _sessionChanged() {
    if (_session == _auth.token) return;
    _session = _auth.token;
    _generation++;
    setState(() {
      _journeys.clear();
      _selectedJourney = null;
      _loadError = null;
      _loading = false;
    });
    if (_session != null) _restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _session != null) _restore();
  }

  Future<void> _restore() async {
    if (_auth.token == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final rows = await _auth.getJourneys();
      final saved = <IdJourney>[];
      var unreadable = 0;
      // One unreadable Roadmap must not hide the resident's other Roadmaps.
      for (final row in rows) {
        try {
          saved.add(IdJourney.fromJson(row));
        } on FormatException {
          unreadable++;
        }
      }
      if (!mounted || generation != _generation) return;
      if (unreadable > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A saved Roadmap could not be loaded. Please try again.'),
          ),
        );
      }
      final existing = {
        for (final item in _journeys)
          if (item.id != null) item.id!: item,
      };
      setState(() {
        final legacy = _journeys.where((item) => item.id == null).toList();
        _journeys
          ..clear()
          ..addAll(legacy)
          ..addAll(
            saved.map((item) {
              final previous = existing[item.id];
              if (previous == null) return item;
              previous.applyCompletion(item);
              return previous;
            }),
          );
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _loadError = error is AuthException
            ? error.message
            : 'Unable to load saved journeys. Please try again.';
      });
      if (_journeys.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_loadError!)));
      }
    }
  }

  List<Widget> get _pages => [
    HomeScreen(
      journeys: _journeys,
      onOpenJourney: (journey) => setState(() {
        journey.minimized = false;
        _selectedJourney = journey;
        _currentIndex = 1;
      }),
      onOpenDirectory: () => _changeTab(2),
    ),
    _journeys.isNotEmpty
        ? ActiveJourneyScreen(
            key: ObjectKey(_selectedJourney ?? _session),
            journeys: _journeys,
            initialJourney: _selectedJourney,
            onJourneyChanged: () {
              _generation++; // An older list response must not overwrite a saved completion.
              setState(() => _loading = false);
            },
          )
        : RoadmapScreen(
            onOpenDirectory: () => setState(() => _currentIndex = 2),
          ),
    const IdsScreen(),
    const ProfileScreen(),
  ];

  void _changeTab(int index) {
    if (_currentIndex == index) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _currentIndex = index;
    });
    if (index == 1 && _session != null) _restore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 1 && _loading && _journeys.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _currentIndex == 1 && _loadError != null && _journeys.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!),
                    TextButton(
                      onPressed: _restore,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : IndexedStack(
              key: ValueKey(_session),
              index: _currentIndex,
              children: [
                for (final (i, page) in _pages.indexed)
                  MotionTab(active: i == _currentIndex, child: page),
              ],
            ),
      bottomNavigationBar: _ResidentBottomBar(
        currentIndex: _currentIndex,
        onTap: _changeTab,
      ),
    );
  }
}

class _ResidentBottomBar extends StatelessWidget {
  const _ResidentBottomBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accentGold = Color(0xFF1E3A8A);

  static const List<_NavItemData> items = [
    _NavItemData(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavItemData(
      label: 'Roadmap',
      icon: Icons.alt_route_outlined,
      activeIcon: Icons.alt_route_rounded,
    ),
    _NavItemData(
      label: 'IDirectory',
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge_rounded,
    ),
    _NavItemData(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    final barColor = isDark ? const Color(0xFF111111) : Colors.white;

    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF454545);

    final activeColor = isDark ? const Color(0xFF8EBBFF) : primaryBlue;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const indicatorWidth = 32.0;
              const indicatorHeight = 4.0;

              final tabWidth = constraints.maxWidth / items.length;

              final indicatorLeft =
                  tabWidth * currentIndex + (tabWidth - indicatorWidth) / 2;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Navigation items.
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < items.length; index++)
                          Expanded(
                            child: _BottomBarItem(
                              item: items[index],
                              selected: currentIndex == index,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: () => onTap(index),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // One shared indicator gliding between tabs.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    left: indicatorLeft,
                    top: 0,
                    width: indicatorWidth,
                    height: indicatorHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: accentGold,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentGold.withValues(alpha: 0.18),
                              blurRadius: 5,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
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
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.item,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final _NavItemData item;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Refined icon transition without a click overlay.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final scaleAnimation =
                          Tween<double>(begin: 0.92, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: scaleAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      key: ValueKey(selected),
                      size: selected ? 25 : 24,
                      color: selected ? activeColor : inactiveColor,
                    ),
                  ),

                  const SizedBox(height: 5),

                  // Labels stay visible and transition smoothly.
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? activeColor : inactiveColor,
                    ),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
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
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
