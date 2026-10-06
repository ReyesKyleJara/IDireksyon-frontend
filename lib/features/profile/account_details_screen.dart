import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/widgets/page_header.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});
  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final _accountForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: AuthService.instance.user?['name'] as String? ?? '',
  );
  late final bool _usePhone = AuthService.instance.user?['email'] == null;
  late final _contact = TextEditingController(
    text:
        AuthService.instance.user?[_usePhone ? 'phone' : 'email'] as String? ??
        '',
  );
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _hidden = [true, true, true];
  bool _savingAccount = false;
  bool _savingPassword = false;
  bool get _busy => _savingAccount || _savingPassword;

  @override
  void dispose() {
    for (final c in [_name, _contact, _current, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({required bool password}) async {
    if (_busy ||
        !(password ? _passwordForm : _accountForm).currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      if (password) {
        _savingPassword = true;
      } else {
        _savingAccount = true;
      }
    });
    try {
      if (password) {
        await AuthService.instance.updatePassword(
          current: _current.text,
          password: _password.text,
          confirmation: _confirmation.text,
        );
      } else {
        await AuthService.instance.updateAccount(
          name: _name.text,
          contact: _contact.text,
          usePhone: _usePhone,
        );
      }
      if (!mounted) return;
      if (password) {
        _passwordForm.currentState!.reset();
        _current.clear();
        _password.clear();
        _confirmation.clear();
        _hidden.fillRange(0, 3, true);
      } else {
        _name.text = AuthService.instance.user!['name'] as String;
        _contact.text =
            AuthService.instance.user![_usePhone ? 'phone' : 'email'] as String;
      }
      _message(password ? 'Password updated.' : 'Account details updated.');
    } on AuthException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _savingAccount = false;
          _savingPassword = false;
        });
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Color get _accent => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA8CCFA)
      : const Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeader('Account Details'),
                  const SizedBox(height: 6),
                  Text(
                    'Keep your personal information up to date and manage your password.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _card(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal information',
                    children: [
                      Form(
                        key: _accountForm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field(
                              'Full name',
                              _name,
                              autofill: const [AutofillHints.name],
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter your full name'
                                  : v.trim().length > 255
                                  ? 'Use 255 characters or fewer'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            _field(
                              _usePhone ? 'Mobile number' : 'Email address',
                              _contact,
                              keyboard: _usePhone
                                  ? TextInputType.phone
                                  : TextInputType.emailAddress,
                              autofill: [
                                _usePhone
                                    ? AutofillHints.telephoneNumber
                                    : AutofillHints.email,
                              ],
                              validator: (v) {
                                final value = (v ?? '').trim();
                                final valid = _usePhone
                                    ? RegExp(r'^(09\d{9}|\+639\d{9})$')
                                          .hasMatch(
                                            value.replaceAll(
                                              RegExp(r'[\s()-]'),
                                              '',
                                            ),
                                          )
                                    : RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                          .hasMatch(value);
                                return valid
                                    ? null
                                    : _usePhone
                                    ? 'Enter a valid Philippine mobile number'
                                    : 'Enter a valid email address';
                              },
                            ),
                            const SizedBox(height: 22),
                            _button(
                              'Save account details',
                              _savingAccount,
                              () => _save(password: false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _card(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change password',
                    children: [
                      Text(
                        'Choose a new password with at least 8 characters.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: _passwordForm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _field(
                              'Current password',
                              _current,
                              secret: 0,
                              autofill: const [AutofillHints.password],
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Enter your current password'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            _field(
                              'New password',
                              _password,
                              secret: 1,
                              autofill: const [AutofillHints.newPassword],
                              validator: (v) => v == null || v.length < 8
                                  ? 'Use at least 8 characters'
                                  : v.length > 128
                                  ? 'Use 128 characters or fewer'
                                  : v == _current.text
                                  ? 'Choose a different password'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            _field(
                              'Confirm new password',
                              _confirmation,
                              secret: 2,
                              autofill: const [AutofillHints.newPassword],
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Confirm your new password'
                                  : v != _password.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                            const SizedBox(height: 22),
                            _button(
                              'Update password',
                              _savingPassword,
                              () => _save(password: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? colors.surfaceContainer
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int? secret,
    TextInputType? keyboard,
    Iterable<String>? autofill,
    required FormFieldValidator<String> validator,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: !_busy,
          validator: validator,
          keyboardType: keyboard,
          autofillHints: autofill,
          obscureText: secret != null && _hidden[secret],
          autocorrect: false,
          enableSuggestions: secret == null,
          decoration: InputDecoration(
            errorMaxLines: 3,
            filled: true,
            fillColor: Theme.of(context).scaffoldBackgroundColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _accent, width: 2),
            ),
            suffixIcon: secret == null
                ? null
                : IconButton(
                    tooltip:
                        '${_hidden[secret] ? 'Show' : 'Hide'} ${label.toLowerCase()}',
                    onPressed: _busy
                        ? null
                        : () => setState(
                            () => _hidden[secret] = !_hidden[secret],
                          ),
                    icon: Icon(
                      _hidden[secret]
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _button(String label, bool saving, VoidCallback onPressed) =>
      FilledButton(
        onPressed: _busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          saving ? 'Saving…' : label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
}
