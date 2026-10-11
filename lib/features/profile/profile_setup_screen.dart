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

  final List<_ProfileSetupOption> _ids = [];
  final List<_ProfileSetupOption> _documents = [];

  final Set<int> _selectedIds = {};
  final Set<int> _selectedDocuments = {};

  bool _documentsStep = false;
  bool _saving = false;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _loading = true;
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

      if (!mounted) return;

      setState(() {
        _ids
          ..clear()
          ..addAll(ids);

        _documents
          ..clear()
          ..addAll(documents);

        _selectedIds
          ..clear()
          ..addAll(
            ids.where((item) => item.owned).map((item) => item.id),
          );

        _selectedDocuments
          ..clear()
          ..addAll(
            documents.where((item) => item.owned).map((item) => item.id),
          );

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
        _errorMessage = 'Unable to load available IDs and documents.';
      });
    }
  }

  Future<void> _advance({bool skip = false}) async {
    if (_saving || _loading) return;

    if (!_documentsStep) {
      setState(() {
        if (skip) {
          _selectedIds.clear();
        }

        _documentsStep = true;
      });

      return;
    }

    setState(() => _saving = true);

    try {
      await AuthService.instance.saveProfileSetup(
        governmentIdIds: _selectedIds.toList()..sort(),
        documentIds: skip
            ? <int>[]
            : (_selectedDocuments.toList()..sort()),
      );

      if (!mounted) return;

      Navigator.of(context)
          .pushNamedAndRemoveUntil('/profile/loading', (_) => false);
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
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _documentsStep ? _documents : _ids;

    final selected = _documentsStep
        ? _selectedDocuments
        : _selectedIds;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _documentsStep && !_saving) {
          setState(() => _documentsStep = false);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  children: [
                    SizedBox(
                      height: 62,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: _documentsStep
                                ? IconButton(
                                    tooltip: 'Back to IDs',
                                    onPressed: _saving
                                        ? null
                                        : () => setState(
                                            () => _documentsStep = false,
                                          ),
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      color: Color(0xFF00476A),
                                    ),
                                  )
                                : null,
                          ),
                          const Expanded(
                            child: Text(
                              'Set Up Profile',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: TextButton(
                              onPressed: _saving || _loading
                                  ? null
                                  : () => _advance(skip: true),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF002A3C),
                              ),
                              child: const Text(
                                'Skip',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _documentsStep
                                ? const Color(0xFFD9D9D9)
                                : _blue,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _documentsStep
                                ? _blue
                                : const Color(0xFFD9D9D9),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: _buildContent(options, selected),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving || _loading
                            ? null
                            : () => _advance(),
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _saving
                              ? 'Saving…'
                              : _documentsStep
                                  ? 'Let’s start your ID Journey'
                                  : 'Next',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<_ProfileSetupOption> options,
    Set<int> selected,
  ) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: Color(0xFF666666),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
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

    return SingleChildScrollView(
      key: ValueKey(_documentsStep),
      padding: const EdgeInsets.only(top: 22, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _documentsStep
                ? 'Which documents do you\ncurrently have?'
                : 'Which government IDs do you\nalready have?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Bricolage Grotesque',
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Select all that apply, if none, you can skip this step',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No options are available yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                selected: selected.contains(option.id),
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          if (!selected.add(option.id)) {
                            selected.remove(option.id);
                          }
                        }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: selected.contains(option.id)
                        ? _blue
                        : Colors.black,
                    backgroundColor: selected.contains(option.id)
                        ? const Color(0xFFE7EFFB)
                        : const Color(0xFFF5F5F5),
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    side: BorderSide(
                      color: selected.contains(option.id)
                          ? _blue
                          : const Color(0xFFD6D6D6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    textStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: selected.contains(option.id)
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selected.contains(option.id)) ...[
                        const Icon(Icons.check, size: 16),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          option.name,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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