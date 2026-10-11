import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _blue = Color(0xFF10469B);

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

    await AuthService.instance.logout();

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

  @override
  Widget build(BuildContext context) {
    final options = _documentsStep
        ? _documents
        : _ids;

    final selected = _documentsStep
        ? _selectedDocuments
        : _selectedIds;

    final filteredOptions =
        options.where((option) {
      if (_searchQuery.isEmpty) {
        return true;
      }

      return option.name
          .toLowerCase()
          .contains(_searchQuery);
    }).toList();

    // Profile setup is always light.
    // The main app can still follow ThemeMode.system.
    return Theme(
      data: AppTheme.lightTheme,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (
          didPop,
          result,
        ) {
          if (!didPop) {
            _handleBack();
          }
        },
        child: Scaffold(
          backgroundColor:
              AppTheme.pageBackground,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 500,
                ),
                child: Column(
                  children: [
                    _buildHeader(),

                    Expanded(
                      child: _loading
                          ? const Center(
                              child:
                                  CircularProgressIndicator(),
                            )
                          : _errorMessage !=
                                  null
                              ? _buildErrorState()
                              : _aboutStep
                                  ? _buildAboutContent()
                                  : _buildSelectionContent(
                                      filteredOptions,
                                      selected,
                                    ),
                    ),

                    if (!_loading &&
                        _errorMessage == null) ...[
                      if (!_aboutStep)
                        _buildSelectionFooter(
                          selected,
                        ),

                      _buildBottomButton(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        0,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Align(
                    alignment:
                        Alignment.centerLeft,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(),
                      tooltip: _step == 0
                          ? 'Back'
                          : 'Previous step',
                      onPressed:
                          _saving
                              ? null
                              : _handleBack,
                      icon: const Icon(
                        Icons
                            .arrow_back_ios_new_rounded,
                        size: 20,
                        color: _blue,
                      ),
                    ),
                  ),
                ),

                const Expanded(
                  child: Text(
                    'Set Up Profile',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),

                SizedBox(
                  width: 60,
                  child: Align(
                    alignment:
                        Alignment.centerRight,
                    child: _aboutStep
                        ? const SizedBox()
                        : TextButton(
                            onPressed:
                                _saving
                                    ? null
                                    : () =>
                                        _advance(
                                      skip: true,
                                    ),
                            style:
                                TextButton
                                    .styleFrom(
                              foregroundColor:
                                  _blue,
                              padding:
                                  EdgeInsets.zero,
                            ),
                            child:
                                const Text(
                              'Skip',
                              style:
                                  TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              100,
            ),
            child:
                LinearProgressIndicator(
              minHeight: 4,
              value: (_step + 1) / 3,
              backgroundColor:
                  const Color(
                0xFFE4E6EA,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                _blue,
              ),
            ),
          ),

          const SizedBox(height: 9),

          Text(
            'Step ${_step + 1} of 3',
            style: const TextStyle(
              color: Color(0xFF777D89),
              fontSize: 13,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutContent() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24,
      ),
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior
              .onDrag,
      child: Form(
        key: _aboutFormKey,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'A little about you',
              style: TextStyle(
                fontFamily:
                    'Bricolage Grotesque',
                fontSize: 23,
                height: 1.15,
                fontWeight:
                    FontWeight.w800,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'We’ll use these details to check age-based eligibility and show relevant local offices.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF4F5663),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'What should we call you?',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color: Color(0xFF20242B),
              ),
            ),

            const SizedBox(height: 6),

            TextFormField(
              controller: _nameController,
              textInputAction:
                  TextInputAction.next,
              textCapitalization:
                  TextCapitalization.words,
              style: const TextStyle(
                color: Color(0xFF20242B),
                fontSize: 14,
              ),
              decoration:
                  _inputDecoration(
                hintText: 'e.g. Juan',
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter the name you want us to use.';
                }

                return null;
              },
            ),

            const SizedBox(height: 18),

            const Text(
              'Birthday',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color: Color(0xFF20242B),
              ),
            ),

            const SizedBox(height: 6),

            TextFormField(
              controller:
                  _birthDateController,
              readOnly: true,
              onTap: _pickBirthDate,
              style: const TextStyle(
                color: Color(0xFF20242B),
                fontSize: 14,
              ),
              decoration:
                  _inputDecoration(
                hintText: 'MM/DD/YYYY',
                suffixIcon: const Icon(
                  Icons
                      .calendar_today_outlined,
                  size: 19,
                  color:
                      Color(0xFF697386),
                ),
              ),
              validator: (_) {
                if (_birthDate == null) {
                  return 'Select your birthday.';
                }

                return null;
              },
            ),

            const SizedBox(height: 6),

            const Text(
              'Used to check age-based eligibility.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF777D89),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Barangay of Residence',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color: Color(0xFF20242B),
              ),
            ),

            const SizedBox(height: 6),

            DropdownButtonFormField<int>(
              initialValue:
                  _selectedBarangayId,
              isExpanded: true,
              icon: const Icon(
                Icons
                    .keyboard_arrow_down_rounded,
                color: Color(0xFF697386),
              ),
              decoration:
                  _inputDecoration(
                hintText:
                    'Select your barangay',
              ),
              items: _barangays
                  .map(
                    (barangay) =>
                        DropdownMenuItem<int>(
                      value: barangay.id,
                      child: Text(
                        barangay.name,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 14,
                          color: Color(
                            0xFF20242B,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _selectedBarangayId =
                            value;
                      });
                    },
              validator: (value) {
                if (value == null) {
                  return 'Select your barangay.';
                }

                return null;
              },
            ),

            const SizedBox(height: 6),

            const Text(
              'Used to show relevant barangay offices and local services.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF777D89),
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
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF98A2B3),
        fontSize: 14,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: Color(0xFFDDE1E6),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: _blue,
          width: 1.5,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: Color(0xFFB3261E),
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: Color(0xFFB3261E),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildSelectionContent(
    List<_ProfileSetupOption>
        filteredOptions,
    Set<int> selected,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        0,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Text(
            _documentsStep
                ? 'Which documents do you currently have?'
                : 'Which government IDs do you already have?',
            style: const TextStyle(
              fontFamily:
                  'Bricolage Grotesque',
              fontSize: 23,
              height: 1.15,
              fontWeight:
                  FontWeight.w800,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Select all that apply. If none, you can skip this step.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF4F5663),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller:
                _searchController,
            textInputAction:
                TextInputAction.search,
            style: const TextStyle(
              color: Color(0xFF20242B),
              fontSize: 14,
              fontWeight:
                  FontWeight.w500,
            ),
            cursorColor: _blue,
            decoration:
                InputDecoration(
              hintText: _documentsStep
                  ? 'Search documents...'
                  : 'Search government IDs...',
              hintStyle:
                  const TextStyle(
                color:
                    Color(0xFF8E96A3),
                fontSize: 14,
              ),
              prefixIcon:
                  const Icon(
                Icons.search_rounded,
                color:
                    Color(0xFF8E96A3),
              ),
              suffixIcon:
                  _searchController
                          .text
                          .isNotEmpty
                      ? IconButton(
                          onPressed:
                              _searchController
                                  .clear,
                          icon:
                              const Icon(
                            Icons
                                .close_rounded,
                            size: 19,
                          ),
                        )
                      : null,
              filled: true,
              fillColor:
                  const Color(
                0xFFF7F8FA,
              ),
              contentPadding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(14),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFDDE1E6),
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(14),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFDDE1E6),
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(14),
                borderSide:
                    const BorderSide(
                  color: _blue,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: filteredOptions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .search_off_rounded,
                          size: 36,
                          color: Color(
                            0xFF9CA3AF,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        Text(
                          _searchQuery
                                  .isEmpty
                              ? 'No options are available yet.'
                              : 'No matching results found.',
                          textAlign:
                              TextAlign
                                  .center,
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF777D89,
                            ),
                            fontSize:
                                13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets
                            .only(
                      top: 2,
                      bottom: 16,
                    ),
                    physics:
                        const BouncingScrollPhysics(),
                    itemCount:
                        filteredOptions
                            .length,
                    separatorBuilder:
                        (_, _) =>
                            const SizedBox(
                      height: 8,
                    ),
                    itemBuilder:
                        (context, index) {
                      final option =
                          filteredOptions[
                              index];

                      final isSelected =
                          selected.contains(
                        option.id,
                      );

                      return _buildOptionRow(
                        option: option,
                        isSelected:
                            isSelected,
                        selected:
                            selected,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow({
    required _ProfileSetupOption option,
    required bool isSelected,
    required Set<int> selected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving
            ? null
            : () {
                setState(() {
                  if (!selected
                      .add(option.id)) {
                    selected
                        .remove(option.id);
                  }
                });
              },
        borderRadius:
            BorderRadius.circular(12),
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 150,
          ),
          padding:
              const EdgeInsets.fromLTRB(
            12,
            10,
            14,
            10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? _blue.withValues(
                    alpha: 0.07,
                  )
                : Colors.white,
            borderRadius:
                BorderRadius.circular(
              12,
            ),
            border: Border.all(
              color: isSelected
                  ? _blue.withValues(
                      alpha: 0.28,
                    )
                  : const Color(
                      0xFFDDE1E6,
                    ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Checkbox(
                  value: isSelected,
                  onChanged: _saving
                      ? null
                      : (_) {
                          setState(() {
                            if (!selected
                                .add(
                              option.id,
                            )) {
                              selected
                                  .remove(
                                option.id,
                              );
                            }
                          });
                        },
                  activeColor: _blue,
                  checkColor:
                      Colors.white,
                  side:
                      const BorderSide(
                    color:
                        Color(
                      0xFFAAB2BF,
                    ),
                    width: 1.5,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(4),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  option.name,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight:
                        isSelected
                            ? FontWeight
                                .w600
                            : FontWeight
                                .w500,
                    color:
                        const Color(
                      0xFF20242B,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionFooter(
    Set<int> selected,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            Text(
              '${selected.length} selected',
              style: const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const Spacer(),

            if (selected.isNotEmpty)
              TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          selected.clear();
                        });
                      },
                style:
                    TextButton.styleFrom(
                  foregroundColor: _blue,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        18,
      ),
      decoration: BoxDecoration(
        color: AppTheme.pageBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _saving
              ? null
              : () => _advance(),
          style:
              FilledButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor:
                Colors.white,
            disabledBackgroundColor:
                _blue.withValues(
              alpha: 0.55,
            ),
            minimumSize:
                const Size.fromHeight(
              52,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        Colors.white,
                  ),
                )
              : Text(
                  _documentsStep
                      ? 'Finish Setup'
                      : 'Next',
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color:
                  Color(0xFF777D89),
            ),

            const SizedBox(height: 14),

            Text(
              _errorMessage!,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 13,
                height: 1.4,
                color:
                    Color(0xFF555B66),
              ),
            ),

            const SizedBox(height: 18),

            FilledButton(
              onPressed:
                  _loadSetupData,
              child:
                  const Text(
                'Try Again',
              ),
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