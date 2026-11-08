import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_header.dart';
import '../ids/id_details_screen.dart';
import '../roadmap/roadmap_widgets.dart';

class ManageInventoryScreen extends StatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  State<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  final List<_InventoryOption> _ids = [];
  final List<_InventoryOption> _documents = [];

  final Set<int> _selectedIdIds = {};
  final Set<int> _selectedDocumentIds = {};

  final _search = TextEditingController();
  _InventoryType _tab = _InventoryType.governmentId;
  bool _onlyOwned = false;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
          ..addAll(ids.where((item) => item.owned).map((item) => item.id));

        _selectedDocumentIds
          ..clear()
          ..addAll(
            documents.where((item) => item.owned).map((item) => item.id),
          );

        // Never open on an empty tab when the other one has items.
        if (ids.isEmpty && documents.isNotEmpty) {
          _tab = _InventoryType.document;
        }

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

  Set<int> _selectedFor(_InventoryType type) =>
      type == _InventoryType.governmentId
      ? _selectedIdIds
      : _selectedDocumentIds;

  void _toggleItem(_InventoryOption item) {
    setState(() {
      final selectedSet = _selectedFor(item.type);

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
        const SnackBar(content: Text('Inventory updated successfully.')),
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

  List<_InventoryOption> get _tabItems =>
      _tab == _InventoryType.governmentId ? _ids : _documents;

  List<_InventoryOption> get _visibleItems {
    final query = _search.text.trim().toLowerCase();
    final selected = _selectedFor(_tab);
    return _tabItems
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) &&
              (!_onlyOwned || selected.contains(item.id)),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  bool get _isFiltering => _search.text.trim().isNotEmpty || _onlyOwned;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color _surface(ColorScheme colors) =>
      _dark ? colors.surfaceContainer : Colors.white;

  Color _border(ColorScheme colors) => _dark
      ? colors.outlineVariant.withValues(alpha: .35)
      : const Color(0xFFE3ECF7);

  void _changeTab(_InventoryType tab) {
    _search.clear();
    FocusScope.of(context).unfocus();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loadFailed =
        _errorMessage != null && _ids.isEmpty && _documents.isEmpty;

    const header = BackPageHeader(
      'Manage Inventory',
      subtitle: 'Mark the IDs and documents you already have.',
    );
    final loaded = !_isLoading && !loadFailed;

    return Scaffold(
      // Lets the list scroll behind the frosted Save bar.
      extendBody: true,
      bottomNavigationBar: loaded ? _saveBar(colors) : null,
      body: SafeArea(
        bottom: false,
        // Short screens scroll the header away with the controls.
        child: loaded && _isShort
            ? _content(colors, header: header)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : loadFailed
                        ? _loadError(colors)
                        : _content(colors),
                  ),
                ],
              ),
      ),
    );
  }

  bool get _isShort => MediaQuery.sizeOf(context).height < 520;

  Widget _loadError(ColorScheme colors) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 42,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
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

  Widget _content(ColorScheme colors, {Widget? header}) {
    final items = _visibleItems;
    final list = _itemList(items, colors);
    const padding = EdgeInsets.symmetric(horizontal: 20);
    final controls = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _controls(items.length, colors),
      ),
    );
    final listPadding = EdgeInsets.fromLTRB(
      20,
      4,
      20,
      MediaQuery.paddingOf(context).bottom + 24,
    );

    // Short screens scroll the controls away to leave room for the list.
    if (_isShort) {
      return ListView(
        key: ValueKey(_tab),
        children: [
          ?header,
          const SizedBox(height: 14),
          controls,
          Padding(padding: listPadding, child: list),
        ],
      );
    }
    return Column(
      children: [
        Padding(padding: const EdgeInsets.only(top: 14), child: controls),
        Expanded(
          child: ListView(
            key: ValueKey(_tab),
            padding: listPadding,
            children: [list],
          ),
        ),
      ],
    );
  }

  List<Widget> _controls(int visibleCount, ColorScheme colors) => [
    if (_errorMessage != null) ...[
      _errorBanner(colors),
      const SizedBox(height: 12),
    ],
    SegmentedButton<_InventoryType>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: _InventoryType.governmentId,
          label: FittedBox(fit: BoxFit.scaleDown, child: Text('IDs')),
        ),
        ButtonSegment(
          value: _InventoryType.document,
          label: FittedBox(fit: BoxFit.scaleDown, child: Text('Documents')),
        ),
      ],
      selected: {_tab},
      onSelectionChanged: (selection) => _changeTab(selection.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: _surface(colors),
        foregroundColor: colors.onSurface,
        selectedBackgroundColor: AppTheme.primaryBlue,
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: _border(colors)),
      ),
    ),
    const SizedBox(height: 10),
    _searchField(colors),
    const SizedBox(height: 4),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            _countLabel(visibleCount),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: FilterChip(
              label: const Text('Owned'),
              selected: _onlyOwned,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              backgroundColor: _surface(colors),
              selectedColor: colors.primaryContainer,
              side: BorderSide(color: _border(colors)),
              shape: const StadiumBorder(),
              onSelected: (value) => setState(() => _onlyOwned = value),
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 6),
  ];

  String _countLabel(int visibleCount) {
    if (_search.text.trim().isNotEmpty) {
      return '$visibleCount ${visibleCount == 1 ? 'result' : 'results'}';
    }
    return '${_selectedFor(_tab).length} of ${_tabItems.length} marked';
  }

  Widget _searchField(ColorScheme colors) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: _tab == _InventoryType.governmentId
            ? 'Search IDs'
            : 'Search documents',
        filled: true,
        fillColor: _surface(colors),
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded, color: colors.primary),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () => setState(_search.clear),
                icon: const Icon(Icons.cancel_rounded, size: 20),
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        enabledBorder: border(_border(colors)),
        focusedBorder: border(colors.primary),
      ),
    );
  }

  Widget _errorBanner(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 20,
          color: colors.onErrorContainer,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _errorMessage!,
            style: TextStyle(fontSize: 12, color: colors.onErrorContainer),
          ),
        ),
      ],
    ),
  );

  Widget _itemList(List<_InventoryOption> items, ColorScheme colors) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          _isFiltering
              ? 'Nothing matches. Try another name or filter.'
              : _tab == _InventoryType.governmentId
              ? 'No Government IDs are available yet.'
              : 'No documents are available yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
      );
    }
    return RoadmapCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 52,
                color: colors.outlineVariant.withValues(alpha: .4),
              ),
            _itemRow(items[i], colors),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(_InventoryOption item, ColorScheme colors) {
    final selected = _selectedFor(item.type).contains(item.id);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            checked: selected,
            child: InkWell(
              onTap: () => _toggleItem(item),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected ? colors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? colors.primary : colors.outline,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: colors.onPrimary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'View information for ${item.name}',
          icon: Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => IdDetailsScreen(
                idName: item.name,
                governmentId: item.id,
                recordType: item.type == _InventoryType.document
                    ? 'document'
                    : 'government_id',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveBar(ColorScheme colors) {
    final ids = _selectedIdIds.length;
    final documents = _selectedDocumentIds.length;
    return RoadmapBottomBar(
      note: Text(
        '$ids ${ids == 1 ? 'ID' : 'IDs'} · '
        '$documents ${documents == 1 ? 'document' : 'documents'} marked',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
      ),
      action: ElevatedButton(
        style: roadmapPrimaryButtonStyle(context),
        onPressed: _isSaving ? null : _saveInventory,
        child: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save'),
      ),
    );
  }
}

enum _InventoryType { governmentId, document }

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
      throw const FormatException('Invalid inventory item.');
    }

    return _InventoryOption(
      id: id,
      name: name,
      owned: json['owned'] == true,
      type: type,
    );
  }
}
