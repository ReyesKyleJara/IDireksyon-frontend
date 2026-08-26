import 'package:flutter/material.dart';

import '../models/bottom_nav_item.dart';
import '../widgets/placeholder_tab_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static final List<BottomNavItem> _tabs = <BottomNavItem>[
    const BottomNavItem(
      label: 'Requirement Checker',
      icon: Icons.checklist,
      content: PlaceholderTabContent(title: 'Requirement Checker'),
    ),
    const BottomNavItem(
      label: 'ID Sequencing',
      icon: Icons.badge,
      content: PlaceholderTabContent(title: 'ID Sequencing'),
    ),
    const BottomNavItem(
      label: 'Document Readiness',
      icon: Icons.description,
      content: PlaceholderTabContent(title: 'Document Readiness'),
    ),
    const BottomNavItem(
      label: 'Office Map',
      icon: Icons.map,
      content: PlaceholderTabContent(title: 'Office Map'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IDireksyon'),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs.map((BottomNavItem tab) => tab.content).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (int index) => setState(() => _currentIndex = index),
        items: _tabs
            .map(
              (BottomNavItem tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
