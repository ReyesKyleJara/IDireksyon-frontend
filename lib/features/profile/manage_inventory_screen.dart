import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';

class ManageInventoryScreen extends StatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  State<ManageInventoryScreen> createState() =>
      _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  static const Color primaryBlue = Color(0xFF1E3A8A);

  final List<_InventoryOption> _ids = [];
  final List<_InventoryOption> _documents = [];

  final Set<int> _selectedIdIds = {};
  final Set<int> _selectedDocumentIds = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AuthService.instance.getInventory();

      final rawIds = data['government_ids'];
      final rawDocuments = data['documents'];

      if (rawIds is! List || rawDocuments is! List) {
        throw const AuthException(
          'The server returned an unexpected inventory response.',
        );
      }

      final ids = rawIds
          .whereType<Map>()
          .map(
            (item) => _InventoryOption.fromJson(
              Map<String, dynamic>.from(item),
              type: _InventoryType.governmentId,
            ),
          )
          .toList();

      final documents = rawDocuments
          .whereType<Map>()
          .map(
            (item) => _InventoryOption.fromJson(
              Map<String, dynamic>.from(item),
              type: _InventoryType.document,
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _ids
          ..clear()
          ..addAll(ids);

        _documents
          ..clear()
          ..addAll(documents);

        _selectedIdIds
          ..clear()
          ..addAll(
            ids.where((item) => item.owned).map((item) => item.id),
          );

        _selectedDocumentIds
          ..clear()
          ..addAll(
            documents.where((item) => item.owned).map((item) => item.id),
          );

        _isLoading = false;
      });
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load your inventory.';
      });
    }
  }

  void _toggleItem(_InventoryOption item) {
    setState(() {
      final selectedSet = item.type == _InventoryType.governmentId
          ? _selectedIdIds
          : _selectedDocumentIds;

      if (selectedSet.contains(item.id)) {
        selectedSet.remove(item.id);
      } else {
        selectedSet.add(item.id);
      }
    });
  }

  Future<void> _saveInventory() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.saveInventory(
        governmentIdIds: _selectedIdIds.toList()..sort(),
        documentIds: _selectedDocumentIds.toList()..sort(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventory updated successfully.'),
        ),
      );

      Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _errorMessage = 'Unable to save your inventory.';
      });
    }
  }

  int get _selectedIdCount => _selectedIdIds.length;

  int get _selectedDocumentCount => _selectedDocumentIds.length;

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
            onPressed:
                _isLoading || _isSaving ? null : _saveInventory,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null &&
        _ids.isEmpty &&
        _documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadInventory,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
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
          'Select the IDs and documents you currently have. '
          'IDireksyon will use these when building your personalized journey.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: colorScheme.onSurfaceVariant,
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(colorScheme),
        ],

        const SizedBox(height: 24),

        _buildStatusBanner(colorScheme),

        const SizedBox(height: 28),

        _buildSectionTitle('Government IDs', colorScheme),

        const SizedBox(height: 12),

        if (_ids.isEmpty)
          _buildEmptyMessage(
            'No Government IDs are available yet.',
            colorScheme,
          )
        else
          ..._ids.map(
            (item) => _buildChecklistItem(
              item,
              _selectedIdIds.contains(item.id),
              colorScheme,
            ),
          ),

        const SizedBox(height: 20),

        _buildSectionTitle('Documents', colorScheme),

        const SizedBox(height: 12),

        if (_documents.isEmpty)
          _buildEmptyMessage(
            'No documents are available yet.',
            colorScheme,
          )
        else
          ..._documents.map(
            (item) => _buildChecklistItem(
              item,
              _selectedDocumentIds.contains(item.id),
              colorScheme,
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onErrorContainer,
              ),
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
                  '$_selectedIdCount IDs · '
                  '$_selectedDocumentCount documents',
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

  Widget _buildEmptyMessage(
    String message,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildChecklistItem(
    _InventoryOption item,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _toggleItem(item),
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
                  item.type == _InventoryType.governmentId
                      ? Icons.badge_rounded
                      : Icons.description_rounded,
                  size: 21,
                  color: isSelected
                      ? primaryBlue
                      : colorScheme.onSurfaceVariant,
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Text(
                    item.name,
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

enum _InventoryType {
  governmentId,
  document,
}

class _InventoryOption {
  final int id;
  final String name;
  final bool owned;
  final _InventoryType type;

  const _InventoryOption({
    required this.id,
    required this.name,
    required this.owned,
    required this.type,
  });

  factory _InventoryOption.fromJson(
    Map<String, dynamic> json, {
    required _InventoryType type,
  }) {
    final id = json['id'];
    final name = json['name'];

    if (id is! int || name is! String) {
      throw const FormatException(
        'Invalid inventory item.',
      );
    }

    return _InventoryOption(
      id: id,
      name: name,
      owned: json['owned'] == true,
      type: type,
    );
  }
}