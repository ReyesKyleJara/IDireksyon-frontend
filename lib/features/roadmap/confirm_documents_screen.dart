import 'package:flutter/material.dart';

import 'suggested_roadmap_screen.dart';

class ConfirmDocumentsScreen extends StatefulWidget {
  const ConfirmDocumentsScreen({super.key});

  static const primaryBlue = Color(0xFF12499A);

  @override
  State<ConfirmDocumentsScreen> createState() => _ConfirmDocumentsScreenState();
}

class _ConfirmDocumentsScreenState extends State<ConfirmDocumentsScreen> {
  final Set<String> _ownedItems = {'Birth Certificate'};

  final List<_DocumentOption> _ownedIds = const [
    _DocumentOption('PhilSys ID', Icons.badge_outlined),
    _DocumentOption('Passport ID', Icons.menu_book_outlined),
    _DocumentOption('TIN ID', Icons.receipt_long_outlined),
  ];

  final List<_DocumentOption> _ownedDocuments = const [
    _DocumentOption('Birth Certificate', Icons.description_outlined),
    _DocumentOption('Barangay Clearance', Icons.verified_user_outlined),
    _DocumentOption('School ID', Icons.school_outlined),
  ];

  void _toggleItem(String title) {
    setState(() {
      if (_ownedItems.contains(title)) {
        _ownedItems.remove(title);
      } else {
        _ownedItems.add(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm your current\ndocuments',
              style: TextStyle(
                fontSize: 28,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review your owned IDs and supporting documents\nbefore we generate your roadmap.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 17),
            _buildSection('Owned IDs', _ownedIds, colors),
            const SizedBox(height: 21),
            _buildSection('Owned Documents', _ownedDocuments, colors),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SuggestedRoadmapScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConfirmDocumentsScreen.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text(
                  'Save & Continue',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<_DocumentOption> options,
    ColorScheme colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _DocumentOptionCard(
              option: option,
              selected: _ownedItems.contains(option.title),
              onTap: () => _toggleItem(option.title),
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentOptionCard extends StatelessWidget {
  const _DocumentOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _DocumentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Icon(
                option.icon,
                size: 25,
                color: selected
                    ? ConfirmDocumentsScreen.primaryBlue
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Text(
                  option.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: selected
                      ? ConfirmDocumentsScreen.primaryBlue
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? ConfirmDocumentsScreen.primaryBlue
                        : colors.onSurfaceVariant,
                    width: selected ? 1 : 1.2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentOption {
  const _DocumentOption(this.title, this.icon);

  final String title;
  final IconData icon;
}
