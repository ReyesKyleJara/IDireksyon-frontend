import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/password_policy.dart';
import '../auth/forgot_password_screen.dart';

class PasswordSecurityScreen extends StatefulWidget {
  const PasswordSecurityScreen({super.key});

  @override
  State<PasswordSecurityScreen> createState() => _PasswordSecurityScreenState();
}

class _PasswordSecurityScreenState extends State<PasswordSecurityScreen> {
  static const _navy = Color(0xFF1E3A8A);

  final _formKey = GlobalKey<FormState>();

  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePassword() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await AuthService.instance.updatePassword(
        current: _currentPassword.text,
        password: _newPassword.text,
        confirmation: _confirmPassword.text,
      );

      if (!mounted) return;

      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();

      _formKey.currentState?.reset();

      _showMessage('Password updated successfully.');
    } on AuthException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to change your password. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // BACK ARROW ONLY
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PAGE HEADING
                    const Text(
                      'Change password',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'Enter your current password. ${PasswordPolicy.requirements}',
                      style: TextStyle(fontSize: 14, color: muted, height: 1.4),
                    ),

                    const SizedBox(height: 36),

                    // CURRENT PASSWORD
                    _passwordField(
                      label: 'Current password',
                      controller: _currentPassword,
                      hidden: _hideCurrent,
                      onVisibilityPressed: () {
                        setState(() {
                          _hideCurrent = !_hideCurrent;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your current password.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 23),

                    // NEW PASSWORD
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(
                                    initialEmail:
                                        AuthService.instance.user?['email']
                                            as String? ??
                                        '',
                                  ),
                                ),
                              ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _passwordField(
                      label: 'New password',
                      controller: _newPassword,
                      hidden: _hideNew,
                      onVisibilityPressed: () {
                        setState(() {
                          _hideNew = !_hideNew;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter a new password.';
                        }

                        final error = PasswordPolicy.validate(value);
                        if (error != null) return error;

                        if (value == _currentPassword.text) {
                          return 'Choose a different password.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 23),

                    // CONFIRM PASSWORD
                    _passwordField(
                      label: 'Confirm new password',
                      controller: _confirmPassword,
                      hidden: _hideConfirm,
                      onVisibilityPressed: () {
                        setState(() {
                          _hideConfirm = !_hideConfirm;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirm your new password.';
                        }

                        if (value != _newPassword.text) {
                          return 'Passwords do not match.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 36),

                    // UPDATE BUTTON
                    FilledButton(
                      onPressed: _saving ? null : _changePassword,
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Update password',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Your current password is required to make this change.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool hidden,
    required VoidCallback onVisibilityPressed,
    required String? Function(String?) validator,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 10),

        TextFormField(
          controller: controller,
          enabled: !_saving,
          obscureText: hidden,
          enableSuggestions: false,
          autocorrect: false,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            errorMaxLines: 3,
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),

            // SHOW / HIDE PASSWORD
            suffixIcon: IconButton(
              onPressed: _saving ? null : onVisibilityPressed,
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: colors.onSurfaceVariant,
              ),
              tooltip: hidden ? 'Show password' : 'Hide password',
            ),

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _navy, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
