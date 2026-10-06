import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _blue = Color(0xFF0B4295);
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _submitting = false;
  final _identifier = TextEditingController();
  final _password = TextEditingController();

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

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await AuthService.instance.login(_identifier.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/loading', (_) => false);
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDFE3EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth - 32,
                minHeight: (constraints.maxHeight - 48).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      SvgPicture.asset(
                        'assets/onboarding pictures/Group 105.svg',
                        width: 80,
                        height: 54,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'IDireksyon',
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          height: 1.2,
                          color: Color(0xFF0A426E),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Continue your ID Journey',
                        style: TextStyle(fontSize: 13, color: Colors.black),
                      ),
                      const SizedBox(height: 32),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Email or Mobile Number',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                TextFormField(
                                  controller: _identifier,
                                  decoration: _decoration(
                                    'Enter your email or mobile number',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                  autofillHints: const [AutofillHints.username],
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Enter your email or mobile number'
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscurePassword,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                  decoration: _decoration(
                                    'Enter your password',
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                        color: const Color(0xFF697386),
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? 'Enter your password'
                                      : null,
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () => _showMessage(
                                      'Password recovery is not available yet.',
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF98A2B3),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      textStyle: const TextStyle(fontSize: 13),
                                    ),
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FilledButton(
                                  onPressed: _submitting ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _blue,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    _submitting ? 'Logging in…' : 'Log In',
                                  ),
                                ),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      "Don't have an account?",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF526079),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pushReplacementNamed('/signup/email'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFFFAB00,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                      ),
                                      child: const Text('Sign Up'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 8),
                    child: Text(
                      'Simple. Clear. Step-by-step.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
