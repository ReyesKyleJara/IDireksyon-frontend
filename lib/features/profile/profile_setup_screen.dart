import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/page_header.dart';
import '../roadmap/roadmap_widgets.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _aboutFormKey = GlobalKey<FormState>();

  final List<_ProfileSetupOption> _ids = [];
  final List<_ProfileSetupOption> _documents = [];
  final List<_BarangayOption> _barangays = [];

  final Set<int> _selectedIds = {};
  final Set<int> _selectedDocuments = {};

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController =
      TextEditingController();
  final TextEditingController _searchController =
      TextEditingController();

  int _step = 0;

  DateTime? _birthDate;
  int? _selectedBarangayId;

  bool _saving = false;
  bool _loading = true;

  String? _errorMessage;
  String _searchQuery = '';

  bool get _aboutStep => _step == 0;
  bool get _governmentIdsStep => _step == 1;
  bool get _documentsStep => _step == 2;

  @override
  void initState() {
    super.initState();

    _loadSetupData();

    _searchController.addListener(() {
      setState(() {
        _searchQuery =
            _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadSetupData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final inventory =
          await AuthService.instance.getInventory();

      final barangayData =
          await AuthService.instance.getBarangays();

      final rawIds = inventory['government_ids'];
      final rawDocuments = inventory['documents'];

      if (rawIds is! List || rawDocuments is! List) {
        throw const AuthException(
          'The server returned an unexpected inventory response.',
        );
      }

      final ids = rawIds
          .whereType<Map>()
          .map(
            (item) => _ProfileSetupOption.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final documents = rawDocuments
          .whereType<Map>()
          .map(
            (item) => _ProfileSetupOption.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final barangays = barangayData
          .map(_BarangayOption.fromJson)
          .toList();

      if (barangays.isEmpty) {
        throw const AuthException(
          'No barangays are available yet.',
        );
      }

      final profile = AuthService.instance.user;

      final existingName = profile?['name'];
      final existingDateOfBirth =
          profile?['date_of_birth'];
      final existingBarangayId =
          profile?['barangay_id'];

      DateTime? birthDate;

      if (existingDateOfBirth is String &&
          existingDateOfBirth.isNotEmpty) {
        birthDate =
            DateTime.tryParse(existingDateOfBirth);
      }

      int? barangayId;

      if (existingBarangayId is int) {
        barangayId = existingBarangayId;
      } else if (existingBarangayId is num) {
        barangayId = existingBarangayId.toInt();
      }

      if (barangayId != null &&
          !barangays.any(
            (barangay) => barangay.id == barangayId,
          )) {
        barangayId = null;
      }

      if (!mounted) return;

      setState(() {
        _ids
          ..clear()
          ..addAll(ids);

        _documents
          ..clear()
          ..addAll(documents);

        _barangays
          ..clear()
          ..addAll(barangays);

        _selectedIds
          ..clear()
          ..addAll(
            ids
                .where((item) => item.owned)
                .map((item) => item.id),
          );

        _selectedDocuments
          ..clear()
          ..addAll(
            documents
                .where((item) => item.owned)
                .map((item) => item.id),
          );

        if (existingName is String &&
            existingName.trim().isNotEmpty) {
          _nameController.text =
              existingName.trim();
        }

        _birthDate = birthDate;

        if (birthDate != null) {
          _birthDateController.text =
              _formatDisplayDate(birthDate);
        }

        _selectedBarangayId = barangayId;

        _loading = false;
      });
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
            'Unable to load profile setup information.';
      });
    }
  }

  String _formatDisplayDate(DateTime date) {
    final month =
        date.month.toString().padLeft(2, '0');
    final day =
        date.day.toString().padLeft(2, '0');

    return '$month/$day/${date.year}';
  }

  String _formatApiDate(DateTime date) {
    final month =
        date.month.toString().padLeft(2, '0');
    final day =
        date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();

    final lastDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(
      const Duration(days: 1),
    );

    final initialDate = _birthDate ??
        DateTime(
          now.year - 18,
          now.month,
          now.day,
        );

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: lastDate,
      helpText: 'Select your birthday',

      // Keep onboarding dialogs light even when
      // the device itself is using dark mode.
      builder: (context, child) {
        return Theme(
          data: AppTheme.lightTheme,
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _birthDate = picked;
      _birthDateController.text =
          _formatDisplayDate(picked);
    });
  }

  void _switchStep(int step) {
    setState(() {
      _step = step;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Future<void> _handleBack() async {
    if (_saving) return;

    if (_step > 0) {
      _switchStep(_step - 1);
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Theme(
          data: AppTheme.lightTheme,
          child: AlertDialog(
            title: const Text(
              'Leave profile setup?',
            ),
            content: const Text(
              'Your account has already been created. '
              'You can sign in again and finish your profile later.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(true),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        );
      },
    );

    if (leave != true) return;

    try {
      await AuthService.instance.logout();
    } on AuthException {
      // Local cleanup runs even when the backend logout request fails.
    }

    if (!mounted) return;

    Navigator.of(context)
        .pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
    );
  }

  Future<void> _advance({
    bool skip = false,
  }) async {
    if (_saving || _loading) return;

    if (_aboutStep) {
      final valid =
          _aboutFormKey.currentState?.validate() ??
              false;

      if (!valid) return;

      _switchStep(1);
      return;
    }

    if (_governmentIdsStep) {
      if (skip) {
        setState(() {
          _selectedIds.clear();
        });
      }

      _switchStep(2);
      return;
    }

    if (_birthDate == null ||
        _selectedBarangayId == null ||
        _nameController.text.trim().isEmpty) {
      _switchStep(0);

      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        _aboutFormKey.currentState?.validate();
      });

      return;
    }

    if (skip) {
      setState(() {
        _selectedDocuments.clear();
      });
    }

    setState(() {
      _saving = true;
    });

    try {
      await AuthService.instance.saveProfileSetup(
        name: _nameController.text.trim(),
        dateOfBirth:
            _formatApiDate(_birthDate!),
        barangayId: _selectedBarangayId!,
        governmentIdIds:
            _selectedIds.toList()..sort(),
        documentIds:
            _selectedDocuments.toList()..sort(),
      );

      if (!mounted) return;

      Navigator.of(context)
          .pushNamedAndRemoveUntil(
        '/profile/loading',
        (_) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.message),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // Profile setup is always light, whatever the device theme is.
  static final _colors = AppTheme.lightTheme.colorScheme;
  static const _border = Color(0xFFE3ECF7);
  static const _error = Color(0xFFB3261E);

  @override
  Widget build(BuildContext context) {
    final options = _documentsStep ? _documents : _ids;
    final selected = _documentsStep ? _selectedDocuments : _selectedIds;
    final filteredOptions = options
        .where(
          (option) =>
              _searchQuery.isEmpty ||
              option.name.toLowerCase().contains(_searchQuery),
        )
        .toList();

    return Theme(
      data: AppTheme.lightTheme,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: AppTheme.pageBackground,
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                          ? _buildErrorState()
                          : _aboutStep
                          ? _buildAboutContent()
                          : _buildSelectionContent(filteredOptions, selected),
                    ),
                    if (!_loading && _errorMessage == null)
                      _buildBottomBar(selected),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: _step == 0 ? 'Back' : 'Previous step',
            onPressed: _saving ? null : _handleBack,
            color: _colors.primary,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          // One line, shrunk only as far as needed, so large text leaves
          // room for the step's own heading and options.
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PageHeader('Set Up Profile'),
            ),
          ),
          if (!_aboutStep)
            TextButton(
              onPressed: _saving ? null : () => _advance(skip: true),
              style: TextButton.styleFrom(
                foregroundColor: _colors.primary,
                minimumSize: const Size(48, 40),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepHeader({
    required String title,
    required String subtitle,
    Widget? below,
  }) {
    return RoadmapStepHeader(
      step: 'STEP ${_step + 1} OF 3',
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: (_step + 1) / 3,
              backgroundColor: Colors.white.withValues(alpha: .22),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.accentGold,
              ),
            ),
          ),
          if (below != null) ...[const SizedBox(height: 14), below],
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: _colors.onSurface,
      ),
    ),
  );

  Widget _fieldHint(String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.35,
        color: _colors.onSurfaceVariant,
      ),
    ),
  );

  Widget _buildAboutContent() {
    final fieldText = TextStyle(color: _colors.onSurface, fontSize: 15);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Form(
        key: _aboutFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepHeader(
              title: 'A little about you',
              subtitle:
                  'We’ll use these details to check age-based eligibility and show relevant local offices.',
            ),
            const SizedBox(height: 16),
            RoadmapCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fieldLabel('What should we call you?'),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      style: fieldText,
                      decoration: _inputDecoration(hintText: 'e.g. Juan'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter the name you want us to use.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _fieldLabel('Birthday'),
                    TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: _pickBirthDate,
                      style: fieldText,
                      decoration: _inputDecoration(
                        hintText: 'MM/DD/YYYY',
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          size: 19,
                          color: _colors.primary,
                        ),
                      ),
                      validator: (_) =>
                          _birthDate == null ? 'Select your birthday.' : null,
                    ),
                    _fieldHint('Used to check age-based eligibility.'),
                    const SizedBox(height: 18),
                    _fieldLabel('Barangay of Residence'),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedBarangayId,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: Colors.white,
                      style: fieldText,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _colors.primary,
                      ),
                      decoration: _inputDecoration(
                        hintText: 'Select your barangay',
                      ),
                      items: _barangays
                          .map(
                            (barangay) => DropdownMenuItem<int>(
                              value: barangay.id,
                              child: Text(
                                barangay.name,
                                overflow: TextOverflow.ellipsis,
                                style: fieldText,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _selectedBarangayId = value),
                      validator: (value) =>
                          value == null ? 'Select your barangay.' : null,
                    ),
                    _fieldHint(
                      'Used to show relevant barangay offices and local services.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: _colors.onSurfaceVariant, fontSize: 14),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.pageBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: outline(_border),
      enabledBorder: outline(_border),
      focusedBorder: outline(_colors.primary, 1.5),
      errorBorder: outline(_error),
      focusedErrorBorder: outline(_error, 1.5),
    );
  }

  Widget _buildSearchField() {
    const navy = AppTheme.navy;
    final noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: navy, fontSize: 15),
      cursorColor: AppTheme.primaryBlue,
      decoration: InputDecoration(
        hintText: _documentsStep
            ? 'Search documents'
            : 'Search government IDs',
        hintStyle: const TextStyle(color: Color(0xFF5B6B7E), fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: navy),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: _searchController.clear,
                icon: const Icon(Icons.close_rounded, color: navy),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: noBorder,
        enabledBorder: noBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accentGold, width: 2),
        ),
      ),
    );
  }

  Widget _buildSelectionContent(
    List<_ProfileSetupOption> filteredOptions,
    Set<int> selected,
  ) {
    // The intro, search and options share one scroll view, so large text
    // can never squeeze the option list off a small screen.
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          sliver: SliverToBoxAdapter(
            child: _buildStepHeader(
              title: _documentsStep
                  ? 'Which documents do you have?'
                  : 'Which government IDs do you have?',
              subtitle:
                  'Select all that apply. If none, you can skip this step.',
              below: _buildSearchField(),
            ),
          ),
        ),
        if (filteredOptions.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: _colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No options are available yet.'
                          : 'No matching results found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverList.separated(
              itemCount: filteredOptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _buildOptionRow(
                option: filteredOptions[index],
                selected: selected,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOptionRow({
    required _ProfileSetupOption option,
    required Set<int> selected,
  }) {
    final isSelected = selected.contains(option.id);
    final shape = BorderRadius.circular(16);
    return Semantics(
      selected: isSelected,
      checked: isSelected,
      child: Material(
        color: isSelected
            ? _colors.primary.withValues(alpha: .07)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(
            width: isSelected ? 1.5 : 1,
            color: isSelected ? _colors.primary : _border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: MotionInkWell(
          onTap: _saving
              ? null
              : () => setState(() {
                  if (!selected.add(option.id)) selected.remove(option.id);
                }),
          borderRadius: shape,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                RoadmapRecordIcon(document: _documentsStep),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: isSelected
                      ? _colors.primary
                      : _colors.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Set<int> selected) {
    return RoadmapBottomBar(
      note: _aboutStep
          ? null
          : Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${selected.length} selected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _colors.onSurface,
                      ),
                    ),
                  ),
                ),
                if (selected.isNotEmpty)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(selected.clear),
                    style: TextButton.styleFrom(
                      foregroundColor: _colors.primary,
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Clear all'),
                  ),
              ],
            ),
      action: Builder(
        builder: (context) => FilledButton(
          onPressed: _saving ? null : () => _advance(),
          style: roadmapPrimaryButtonStyle(context),
          child: _saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _colors.primary,
                  ),
                )
              : Text(_documentsStep ? 'Finish Setup' : 'Next'),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: _colors.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadSetupData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSetupOption {
  final int id;
  final String name;
  final bool owned;

  const _ProfileSetupOption({
    required this.id,
    required this.name,
    required this.owned,
  });

  factory _ProfileSetupOption.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = json['id'];
    final name = json['name'];

    if (id is! int || name is! String) {
      throw const FormatException(
        'Invalid inventory item.',
      );
    }

    return _ProfileSetupOption(
      id: id,
      name: name,
      owned: json['owned'] == true,
    );
  }
}

class _BarangayOption {
  final int id;
  final String name;

  const _BarangayOption({
    required this.id,
    required this.name,
  });

  factory _BarangayOption.fromJson(
    Map<String, dynamic> json,
  ) {
    final id = json['id'];
    final name = json['name'];

    if (id is! int || name is! String) {
      throw const FormatException(
        'Invalid barangay item.',
      );
    }

    return _BarangayOption(
      id: id,
      name: name,
    );
  }
}