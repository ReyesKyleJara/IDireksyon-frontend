import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'account_form_page.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.challengeId,
    required this.onVerified,
  });

  final String email;
  final String challengeId;
  final Future<void> Function(String proof) onVerified;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _code = TextEditingController();
  late String _challengeId;
  String? _proof;
  String? _error;
  bool _busy = false;
  int _resendSeconds = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _challengeId = widget.challengeId;
    _resendSeconds = AuthService.instance.signupResendSeconds(widget.email);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = AuthService.instance.signupResendSeconds(widget.email);
      if (mounted && remaining != _resendSeconds) {
        setState(() => _resendSeconds = remaining);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_proof == null && _code.text.length != 6) {
      setState(() => _error = 'Enter the six-digit code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _proof ??= await AuthService.instance.verifySignupEmailCode(
        _challengeId,
        _code.text,
      );
      await widget.onVerified(_proof!);
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/profile/setup', (_) => false);
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          if (error.fieldErrors.containsKey('email_verification_token')) {
            _proof = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _resendSeconds > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await AuthService.instance.sendSignupEmailCode(widget.email);
      if (!mounted) return;
      setState(() {
        _challengeId = id;
        _proof = null;
        _code.clear();
        _resendSeconds = AuthService.instance.signupResendSeconds(widget.email);
      });
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _resendSeconds = AuthService.instance.signupResendSeconds(widget.email);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFF20242B),
  );
  static const _codeText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF20242B),
  );
  static const _note = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: Color(0xFF526079),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AccountFormPage(
      title: 'Verify your email',
      subtitle:
          'Enter the six-digit code sent to ${widget.email}. The code expires in 10 minutes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Verification code', style: _label),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            enabled: !_busy && _proof == null,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verify(),
            style: _codeText,
            decoration: AccountFormPage.inputDecoration(
              'Enter the six-digit code',
            ).copyWith(errorText: _error),
          ),
          const SizedBox(height: 10),
          const Text(
            'Check your spam folder if you do not see the email.',
            style: _note,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _verify,
            style: AccountFormPage.primaryButton,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify and create account'),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _busy || _resendSeconds > 0 ? null : _resend,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                textStyle: const TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(
                _resendSeconds > 0
                    ? 'Resend code in ${_resendSeconds}s'
                    : 'Resend code',
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Wrong email address? Go back to change it.',
            textAlign: TextAlign.center,
            style: _note,
          ),
        ],
      ),
    ),
  );
}
