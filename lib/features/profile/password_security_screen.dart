
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/password_policy.dart';
import '../../core/profile/profile_photo_service.dart';
import '../auth/forgot_password_screen.dart';

class PasswordSecurityScreen extends StatefulWidget {
  const PasswordSecurityScreen({super.key});

  @override
  State<PasswordSecurityScreen> createState() =>
      _PasswordSecurityScreenState();
}

class _PasswordSecurityScreenState
    extends State<PasswordSecurityScreen> {
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
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
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
        _showMessage(
          'Unable to change your password. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    FocusScope.of(context).unfocus();

    final deletedUser = AuthService.instance.user;
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );

    if (!mounted || deleted != true) return;

    try {
      await ProfilePhotoService.instance.forget(deletedUser);
    } catch (_) {
      // The account is already gone; a leftover local photo is harmless.
    }

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
    );

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Your account has been deleted.'),
      ),
    );
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
                      style: TextStyle(
                        fontSize: 14,
                        color: muted,
                        height: 1.4,
                      ),
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

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(
                                    initialEmail:
                                        AuthService.instance.user?['email'] as String? ?? '',
                                  ),
                                ),
                              ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // NEW PASSWORD
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
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 40),
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: 28),

                    // DELETE ACCOUNT
                    const Text(
                      'Delete account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'Permanently delete your IDireksyon account, profile, and saved IDs and documents. This cannot be undone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: muted,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    OutlinedButton.icon(
                      onPressed: _saving ? null : _confirmDeleteAccount,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text(
                        'Delete account',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 10),

        TextFormField(
          controller: controller,
          enabled: !_saving,
          obscureText: hidden,
          enableSuggestions: false,
          autocorrect: false,
          validator: validator,
          autovalidateMode:
              AutovalidateMode.onUserInteraction,
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
              onPressed:
                  _saving ? null : onVisibilityPressed,
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: colors.onSurfaceVariant,
              ),
              tooltip:
                  hidden ? 'Show password' : 'Hide password',
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: colors.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: _navy,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  bool _hidden = true;
  bool _deleting = false;
  String? _passwordError;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _passwordError = null;
      _error = null;
    });

    if (_deleting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _deleting = true);

    try {
      await AuthService.instance.deleteAccount(
        password: _password.text,
      );

      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
        _passwordError = error.field('password');
        _error = _passwordError == null ? error.message : null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
        _error = 'Unable to delete your account. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        scrollable: true,
        constraints: const BoxConstraints(maxWidth: 420),
        surfaceTintColor: Colors.transparent,
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Text(
          'Delete your account?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your profile and saved IDs and documents will be permanently deleted. This cannot be undone.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _password,
                  enabled: !_deleting,
                  obscureText: _hidden,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofocus: true,
                  onFieldSubmitted: (_) => _delete(),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your password to confirm.'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: _passwordError,
                    errorMaxLines: 3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    suffixIcon: IconButton(
                      onPressed: _deleting
                          ? null
                          : () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      tooltip: _hidden ? 'Show password' : 'Hide password',
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _deleting ? null : () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _deleting ? null : _delete,
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _deleting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: colors.onError,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Delete permanently'),
          ),
        ],
      ),
    );
  }
}
