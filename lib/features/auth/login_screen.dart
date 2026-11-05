import 'forgot_password_screen.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import 'auth_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _identifier = TextEditingController();

  final _password = TextEditingController();

  bool _showPassword = false;
  bool _submitting = false;

  String? _identifierServerError;
  String? _passwordServerError;
  String? _loginError;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();

    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isSystemError(String message) {
    final lower = message.toLowerCase();

    return lower.contains('connect') ||
        lower.contains('server') ||
        lower.contains('timed out') ||
        lower.contains('too many attempts') ||
        lower.contains('unexpected');
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() {
      _identifierServerError = null;
      _passwordServerError = null;
      _loginError = null;
    });

    final valid = _formKey.currentState!.validate();

    if (!valid) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
    });

    try {
      await AuthService.instance.login(_identifier.text, _password.text);

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/loading', (_) => false);
    } on AuthException catch (error) {
      if (!mounted) return;

      final identifierError = error.fieldErrors['identifier'];

      final passwordError = error.fieldErrors['password'];

      if (identifierError != null || passwordError != null) {
        setState(() {
          _identifierServerError = identifierError;

          _passwordServerError = passwordError;
        });

        _formKey.currentState?.validate();

        return;
      }

      if (_isSystemError(error.message)) {
        _showMessage(error.message);
      } else {
        // Keep login failures generic so we don't
        // reveal whether an account exists.
        setState(() {
          _loginError = 'Incorrect email/mobile number or password.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  static const _label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFF20242B),
  );
  static const _input = TextStyle(fontSize: 14, color: Color(0xFF20242B));

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Welcome back!',
      subtitle: 'Continue your ID journey.',
      mascotAsset: 'assets/onboarding pictures/mascot-wave-cutout.png',
      orbitIcons: const [
        Icons.badge_rounded,
        Icons.lock_rounded,
        Icons.route_rounded,
        Icons.place_rounded,
      ],
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Email or Mobile Number', style: _label),
              const SizedBox(height: 8),
              TextFormField(
                controller: _identifier,
                decoration: AuthShell.inputDecoration(
                  'Enter your email or mobile number',
                ),
                style: _input,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                onChanged: (_) {
                  if (_identifierServerError != null || _loginError != null) {
                    setState(() {
                      _identifierServerError = null;

                      _loginError = null;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your email or mobile number';
                  }

                  return _identifierServerError;
                },
              ),
              const SizedBox(height: 16),
              const Text('Password', style: _label),
              const SizedBox(height: 8),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_passwordServerError != null || _loginError != null) {
                    setState(() {
                      _passwordServerError = null;

                      _loginError = null;
                    });
                  }
                },
                style: _input,
                decoration: AuthShell.inputDecoration(
                  'Enter your password',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: const Color(0xFF697386),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your password';
                  }

                  return _passwordServerError;
                },
              ),
              if (_loginError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(
                    _loginError!,
                    style: const TextStyle(
                      color: Color(0xFFB3261E),
                      fontSize: 12,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen(
                        initialEmail:
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(_identifier.text.trim())
                            ? _identifier.text.trim()
                            : '',
                      ),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF526579),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: AuthShell.primaryButton,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Log In'),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(fontSize: 14, color: Color(0xFF526079)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushReplacementNamed('/signup/email');
                    },
                    style: AuthShell.linkButton,
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
