import 'package:flutter/material.dart';

class ManageInventoryScreen extends StatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  State<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  static const Color primaryBlue = Color(0xFF1E3A8A);

  final Set<String> _selectedItems = {
    'PhilSys ID',
    'Passport ID',
    'PhilHealth ID',
    'School ID',
    'Birth Certificate',
  };

  final List<_InventoryOption> _ids = [
    _InventoryOption(
      title: 'PhilSys ID',
      icon: Icons.badge_rounded,
    ),
    _InventoryOption(
      title: 'Passport ID',
      icon: Icons.menu_book_rounded,
    ),
    _InventoryOption(
      title: 'SSS ID',
      icon: Icons.credit_card_rounded,
    ),
    _InventoryOption(
      title: 'PhilHealth ID',
      icon: Icons.health_and_safety_rounded,
    ),
    _InventoryOption(
      title: 'UMID',
      icon: Icons.credit_card_rounded,
    ),
  ];

  final List<_InventoryOption> _documents = [
    _InventoryOption(
      title: 'School ID',
      icon: Icons.school_rounded,
    ),
    _InventoryOption(
      title: 'Birth Certificate',
      icon: Icons.description_rounded,
    ),
    _InventoryOption(
      title: 'Certificate of Residency',
      icon: Icons.home_work_rounded,
    ),
  ];

  void _toggleItem(String title) {
    setState(() {
      if (_selectedItems.contains(title)) {
        _selectedItems.remove(title);
      } else {
        _selectedItems.add(title);
      }
    });
  }

  int get _selectedIdCount {
    return _ids
        .where((item) => _selectedItems.contains(item.title))
        .length;
  }

  int get _selectedDocumentCount {
    return _documents
        .where((item) => _selectedItems.contains(item.title))
        .length;
  }

  void _saveInventory() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Inventory',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveInventory,
            child: const Text(
              'Save',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            'Tell us what you already have',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Select the IDs and documents you currently have. IDireksyon will use these when building your personalized roadmap.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          _buildStatusBanner(colorScheme),

          const SizedBox(height: 28),

          _buildSectionTitle('Government IDs', colorScheme),

          const SizedBox(height: 12),

          ..._ids.map(
            (item) => _buildChecklistItem(
              item,
              colorScheme,
            ),
          ),

          const SizedBox(height: 20),

          _buildSectionTitle('Documents', colorScheme),

          const SizedBox(height: 12),

          ..._documents.map(
            (item) => _buildChecklistItem(
              item,
              colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryBlue.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: primaryBlue,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_selectedIdCount IDs · $_selectedDocumentCount documents',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Your selections will help determine what you can do next.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    ColorScheme colorScheme,
  ) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildChecklistItem(
    _InventoryOption item,
    ColorScheme colorScheme,
  ) {
    final isSelected = _selectedItems.contains(item.title);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _toggleItem(item.title),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? primaryBlue.withValues(alpha: 0.30)
                    : colorScheme.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 21,
                  color: isSelected
                      ? primaryBlue
                      : colorScheme.onSurfaceVariant,
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? primaryBlue
                          : colorScheme.onSurface,
                    ),
                  ),
                ),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryBlue
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? primaryBlue
                          : colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryOption {
  final String title;
  final IconData icon;

  const _InventoryOption({
    required this.title,
    required this.icon,
  });
}
