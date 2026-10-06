import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../core/auth/auth_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _blue = Color(0xFF10469B);
  static const _ids = [
    'PhilSys ID',
    'Passport ID',
    'SSS ID',
    'PhilHealth ID',
    'UMID',
    'TIN ID',
    'Postal ID',
    'Driver’s License',
  ];
  static const _documents = [
    'School ID',
    'Birth Certificate',
    'Certificate of Residency',
    'Marriage Certificate',
    'Barangay Clearance',
    'Police Clearance',
    'NBI Clearance',
  ];
  final _selectedIds = <String>{};
  final _selectedDocuments = <String>{};
  bool _documentsStep = false;
  bool _saving = false;

  Future<void> _advance({bool skip = false}) async {
    if (_saving) return;
    if (!_documentsStep) {
      setState(() {
        if (skip) _selectedIds.clear();
        _documentsStep = true;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      await AuthService.instance.saveProfileSetup(
        ids: _selectedIds.toList(),
        documents: skip ? [] : _selectedDocuments.toList(),
      );
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/profile/loading', (_) => false);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _documentsStep ? _documents : _ids;
    final selected = _documentsStep ? _selectedDocuments : _selectedIds;
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
                              onPressed: _saving
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
                      child: SingleChildScrollView(
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
                            for (final option in options)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Semantics(
                                  selected: selected.contains(option),
                                  child: OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () => setState(() {
                                            if (!selected.add(option)) {
                                              selected.remove(option);
                                            }
                                          }),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: selected.contains(option)
                                          ? _blue
                                          : Colors.black,
                                      backgroundColor: selected.contains(option)
                                          ? const Color(0xFFE7EFFB)
                                          : const Color(0xFFF5F5F5),
                                      minimumSize: const Size.fromHeight(44),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      side: BorderSide(
                                        color: selected.contains(option)
                                            ? _blue
                                            : const Color(0xFFD6D6D6),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      textStyle: TextStyle(
                                        fontSize: 14,
                                        fontWeight: selected.contains(option)
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (selected.contains(option)) ...[
                                          const Icon(Icons.check, size: 16),
                                          const SizedBox(width: 6),
                                        ],
                                        Flexible(
                                          child: Text(
                                            option,
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
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : () => _advance(),
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
}
