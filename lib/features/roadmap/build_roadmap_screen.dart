import 'package:flutter/material.dart';

import 'confirm_documents_screen.dart';

class BuildRoadmapScreen extends StatefulWidget {
  const BuildRoadmapScreen({super.key});

  static const primaryBlue = Color(0xFF12499A);

  @override
  State<BuildRoadmapScreen> createState() => _BuildRoadmapScreenState();
}

class _BuildRoadmapScreenState extends State<BuildRoadmapScreen> {
  final Set<String> _selectedIds = {'Passport ID'};

  final List<_RoadmapId> _ids = const [
    _RoadmapId('PhilSys ID', Icons.badge_outlined),
    _RoadmapId('Passport ID', Icons.menu_book_outlined),
    _RoadmapId('SSS ID', Icons.credit_card_outlined),
    _RoadmapId('PhilHealth ID', Icons.health_and_safety_outlined),
    _RoadmapId('UMID', Icons.credit_card_outlined),
    _RoadmapId('TIN ID', Icons.receipt_long_outlined),
  ];

  void _toggleId(String title) {
    setState(() {
      if (_selectedIds.contains(title)) {
        _selectedIds.remove(title);
      } else {
        _selectedIds.add(title);
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
              'What IDs do you want to\nacquire?',
              style: TextStyle(
                fontSize: 28,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select one or more IDs you want to include in\nthis journey.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BuildRoadmapScreen.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${_selectedIds.length} ID${_selectedIds.length == 1 ? '' : 's'} selected',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BuildRoadmapScreen.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 17),
            Expanded(
              child: ListView.separated(
                itemCount: _ids.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (context, index) {
                  final id = _ids[index];
                  return _IdOptionCard(
                    id: id,
                    selected: _selectedIds.contains(id.title),
                    onTap: () => _toggleId(id.title),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ConfirmDocumentsScreen(),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BuildRoadmapScreen.primaryBlue,
                  disabledBackgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdOptionCard extends StatelessWidget {
  const _IdOptionCard({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final _RoadmapId id;
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
            border: Border.all(
              color: selected
                  ? BuildRoadmapScreen.primaryBlue.withValues(alpha: 0.35)
                  : colors.outlineVariant,
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              Icon(
                id.icon,
                size: 25,
                color: selected
                    ? BuildRoadmapScreen.primaryBlue
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Text(
                  id.title,
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
                      ? BuildRoadmapScreen.primaryBlue
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? BuildRoadmapScreen.primaryBlue
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

class _RoadmapId {
  const _RoadmapId(this.title, this.icon);

  final String title;
  final IconData icon;
}
