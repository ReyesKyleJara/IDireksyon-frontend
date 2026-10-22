import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_service.dart';

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
  int _resendSeconds = 60;
  late final Timer _timer;
  late DateTime _resendAt;

  @override
  void initState() {
    super.initState();
    _challengeId = widget.challengeId;
    _resendAt = DateTime.now().add(const Duration(seconds: 60));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining =
          (_resendAt.difference(DateTime.now()).inMilliseconds / 1000)
              .ceil()
              .clamp(0, 60);
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
        _resendSeconds = 60;
        _resendAt = DateTime.now().add(const Duration(seconds: 60));
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 56,
                    color: Color(0xFF0B4295),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Enter the six-digit code sent to ${widget.email}. The code expires in 10 minutes.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your spam folder if you do not see the email.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
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
                    decoration: InputDecoration(
                      labelText: 'Verification code',
                      errorText: _error,
                      errorMaxLines: 4,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _verify,
                    child: Text(
                      _busy ? 'Please wait...' : 'Verify and create account',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy || _resendSeconds > 0 ? null : _resend,
                    child: Text(
                      _resendSeconds > 0
                          ? 'Resend code in ${_resendSeconds}s'
                          : 'Resend code',
                    ),
                  ),
                  const Text(
                    'Wrong email address? Go back to change it.',
                    textAlign: TextAlign.center,
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
