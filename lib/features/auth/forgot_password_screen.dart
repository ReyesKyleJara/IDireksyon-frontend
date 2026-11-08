import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'account_form_page.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  String? _message;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _message = null;
      _sent = false;
    });
    try {
      final message = await AuthService.instance.sendPasswordResetEmail(
        _email.text,
      );
      if (mounted) {
        setState(() {
          _message = message;
          _sent = true;
        });
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Unable to send the reset email. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static const _label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFF20242B),
  );
  static const _input = TextStyle(fontSize: 15, color: Color(0xFF20242B));
  static const _errorColor = Color(0xFFB3261E);

  @override
  Widget build(BuildContext context) => AccountFormPage(
    title: 'Reset your password',
    subtitle:
        'Enter the email address linked to your account. We will email you a link to choose a new password. The link expires after 60 minutes.',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Email Address', style: _label),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            enabled: !_sending,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _send(),
            style: _input,
            decoration: AccountFormPage.inputDecoration(
              'Enter your email address',
            ),
            validator: (value) =>
                value == null ||
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(value.trim())
                ? 'Enter a valid email address.'
                : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sending ? null : _send,
            style: AccountFormPage.primaryButton,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send reset link'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: (_sent ? AppTheme.completedGreen : _errorColor)
                      .withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _sent
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        size: 19,
                        color: _sent ? AppTheme.completedGreen : _errorColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _message!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF20242B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
