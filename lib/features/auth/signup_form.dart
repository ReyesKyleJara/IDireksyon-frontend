import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/auth_service.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key, required this.usePhone});
  final bool usePhone;

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  static const _blue = Color(0xFF0B4295);
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _confirmation = TextEditingController();
  bool _submitting = false;
  bool _accepted = false;
  bool _showAgreementError = false;

  @override
  void dispose() {
    _password.dispose();
    _name.dispose();
    _contact.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final valid = _formKey.currentState!.validate();
    setState(() => _showAgreementError = !_accepted);
    if (valid && _accepted) {
      FocusScope.of(context).unfocus();
      setState(() => _submitting = true);
      try {
        await AuthService.instance.register(
          name: _name.text,
          contact: _contact.text,
          usePhone: widget.usePhone,
          password: _password.text,
          confirmation: _confirmation.text,
          accepted: _accepted,
        );
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/profile/setup', (_) => false);
      } on AuthException catch (error) {
        if (mounted) _message(error.message);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }
  }

  Widget _field(
    String label,
    String hint, {
    bool secret = false,
    String? helper,
    TextEditingController? controller,
    TextInputType? keyboard,
    Iterable<String>? autofill,
    required FormFieldValidator<String> validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black),
          ),
          const SizedBox(height: 3),
          TextFormField(
            controller: controller,
            obscureText: secret,
            autocorrect: false,
            enableSuggestions: !secret,
            keyboardType: keyboard,
            autofillHints: autofill,
            textInputAction: label == 'Confirm Password'
                ? TextInputAction.done
                : TextInputAction.next,
            onFieldSubmitted: label == 'Confirm Password'
                ? (_) => _submit()
                : null,
            validator: validator,
            style: const TextStyle(fontSize: 13, color: Colors.black),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF98A2B3),
              ),
              helperText: helper,
              helperStyle: const TextStyle(
                fontSize: 11,
                color: Color(0xFF98A2B3),
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDFE3EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _method(String label, bool phone) {
    final selected = widget.usePhone == phone;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          onPressed: selected
              ? () {}
              : () => Navigator.of(context).pushReplacementNamed(
                  phone ? '/signup/phone' : '/signup/email',
                ),
          style: TextButton.styleFrom(
            backgroundColor: selected ? _blue : const Color(0xFFD9D9D9),
            foregroundColor: selected ? Colors.white : _blue,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const RoundedRectangleBorder(),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text(label),
        ),
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
                minHeight: (constraints.maxHeight - 48).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 54),
                              Center(
                                child: SvgPicture.asset(
                                  'assets/onboarding pictures/Group 105.svg',
                                  width: 80,
                                  height: 54,
                                  excludeFromSemantics: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'IDireksyon',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Bricolage Grotesque',
                                  fontSize: 32,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A426E),
                                ),
                              ),
                              const SizedBox(height: 26),
                              const Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Bricolage Grotesque',
                                  fontSize: 24,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Let’s set up your ID journey',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _field(
                                'Name',
                                'e.g. Juan',
                                controller: _name,
                                autofill: const [AutofillHints.name],
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter your name'
                                    : null,
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Row(
                                  children: [
                                    _method('Email', false),
                                    _method('Phone Number', true),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _field(
                                widget.usePhone ? 'Phone Number' : 'Email',
                                widget.usePhone
                                    ? 'e.g. 09091234567'
                                    : 'e.g. juandelacruz@email.com',
                                controller: _contact,
                                keyboard: widget.usePhone
                                    ? TextInputType.phone
                                    : TextInputType.emailAddress,
                                autofill: [
                                  widget.usePhone
                                      ? AutofillHints.telephoneNumber
                                      : AutofillHints.email,
                                ],
                                validator: (value) {
                                  final contact = (value ?? '').trim();
                                  if (widget.usePhone) {
                                    return RegExp(r'^(09\d{9}|\+639\d{9})$')
                                            .hasMatch(
                                              contact.replaceAll(
                                                RegExp(r'[\s()-]'),
                                                '',
                                              ),
                                            )
                                        ? null
                                        : 'Enter a valid mobile number (09… or +639…)';
                                  }
                                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                          .hasMatch(contact)
                                      ? null
                                      : 'Enter a valid email address';
                                },
                              ),
                              _field(
                                'Password',
                                'Create a strong password',
                                secret: true,
                                controller: _password,
                                autofill: const [AutofillHints.newPassword],
                                helper: 'Must be at least 8 characters',
                                validator: (value) => (value ?? '').length < 8
                                    ? 'Use at least 8 characters'
                                    : null,
                              ),
                              _field(
                                'Confirm Password',
                                'Re-enter password',
                                controller: _confirmation,
                                secret: true,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Confirm your password'
                                    : value != _password.text
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _accepted,
                                      activeColor: _blue,
                                      semanticLabel:
                                          'Agree to Terms and Privacy Policy',
                                      onChanged: (value) => setState(() {
                                        _accepted = value ?? false;
                                        _showAgreementError = !_accepted;
                                      }),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.15,
                                          color: Colors.black,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'By creating an account, you agree to our ',
                                          ),
                                          WidgetSpan(
                                            child: MotionInkWell(
                                              onTap: () => _message(
                                                'Terms and Privacy Policy are not available yet.',
                                              ),
                                              child: const Text(
                                                'Terms and Privacy Policy',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: _blue,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const TextSpan(
                                            text: '. Your information is used solely to generate personalized ID recommendations and improve your experience.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_showAgreementError)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Please accept the Terms and Privacy Policy.',
                                    style: TextStyle(
                                      color: Color(0xFFB3261E),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
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
                                  _submitting ? 'Creating account…' : 'Sign Up',
                                ),
                              ),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF526079),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context)
                                            .pushReplacementNamed('/login'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFFFAB00),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    ),
                                    child: const Text('Log In'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
