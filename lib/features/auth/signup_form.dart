import 'auth_mascot_peek.dart';
import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/password_policy.dart';
import '../profile/privacy_policy_screen.dart';
import '../profile/terms_of_service_screen.dart';
import 'email_verification_screen.dart';
import '../../core/theme/app_theme.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({
    super.key,
    required this.usePhone,
  });

  final bool usePhone;

  @override
  State<SignupForm> createState() =>
      _SignupFormState();
}

class _SignupFormState
    extends State<SignupForm> {
  static const _blue =
      Color(0xFF0B4295);

  final _formKey =
      GlobalKey<FormState>();

  final _contact =
      TextEditingController();
  final _password =
      TextEditingController();
  final _confirmation =
      TextEditingController();

  late bool _usePhone;

  bool _submitting = false;
  bool _accepted = false;
  bool _showAgreementError = false;

  bool _showPassword = false;
  bool _showConfirmation = false;

  String? _contactServerError;
  String? _passwordServerError;
  String? _confirmationServerError;

  @override
  void initState() {
    super.initState();

    _usePhone = widget.usePhone;
  }

  @override
  void dispose() {
    _contact.dispose();
    _password.dispose();
    _confirmation.dispose();

    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  void _openLegalPage(Widget page) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _switchMethod(bool phone) {
    if (_usePhone == phone) return;

    setState(() {
      _usePhone = phone;

      _contact.clear();
      _contactServerError = null;
    });
  }

  String _friendlyContactError(
    String serverMessage,
  ) {
    final lower =
        serverMessage.toLowerCase();

    if (lower.contains('taken') ||
        lower.contains('already')) {
      return _usePhone
      ? 'This phone number can’t be used. Try another or log in.'
      : 'This email can’t be used. Try another or log in.';
    }

    return serverMessage;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() {
      _contactServerError = null;
      _passwordServerError = null;
      _confirmationServerError =
          null;
    });

    final valid =
        _formKey.currentState!.validate();

    setState(() {
      _showAgreementError =
          !_accepted;
    });

    if (!valid || !_accepted) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
    });

    try {
      if (!_usePhone) {
        final email = _contact.text.trim();
        final password = _password.text;
        final confirmation = _confirmation.text;
        final accepted = _accepted;
        final challengeId = await AuthService.instance.sendSignupEmailCode(email);
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => EmailVerificationScreen(
            email: email,
            challengeId: challengeId,
            onVerified: (proof) => AuthService.instance.register(
              contact: email, usePhone: false, password: password,
              confirmation: confirmation, accepted: accepted,
              emailVerificationToken: proof,
            ),
          ),
        ));
        return;
      }
      await AuthService.instance.register(
        contact: _contact.text,
        usePhone: _usePhone,
        password: _password.text,
        confirmation:
            _confirmation.text,
        accepted: _accepted,
      );

      if (!mounted) return;

      Navigator.of(context)
          .pushNamedAndRemoveUntil(
        '/profile/setup',
        (_) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      final contactKey =
          _usePhone
              ? 'phone'
              : 'email';

      final contactError =
          error.fieldErrors[
              contactKey];

      final passwordError =
          error.fieldErrors[
              'password'];

      final termsError =
          error.fieldErrors[
              'terms_accepted'];

      final hasFieldError =
          contactError != null ||
              passwordError != null ||
              termsError != null;

      if (hasFieldError) {
        setState(() {
          if (contactError != null) {
            _contactServerError =
                _friendlyContactError(
              contactError,
            );
          }

          if (passwordError != null) {
            if (passwordError
                .toLowerCase()
                .contains(
                  'confirmation',
                )) {
              _confirmationServerError =
                  passwordError;
            } else {
              _passwordServerError =
                  passwordError;
            }
          }

          if (termsError != null) {
            _showAgreementError =
                true;
          }
        });

        _formKey.currentState
            ?.validate();
      } else {
        _message(error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _field(
    String label,
    String hint, {
    bool secret = false,
    bool showSecret = false,
    VoidCallback? onToggleSecret,
    ValueChanged<String>? onChanged,
    String? helper,
    TextEditingController? controller,
    TextInputType? keyboard,
    Iterable<String>? autofill,
    required FormFieldValidator<String>
        validator,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w500,
              color:
                  Color(0xFF20242B),
            ),
          ),

          const SizedBox(height: 6),

          TextFormField(
            controller: controller,
            obscureText:
                secret && !showSecret,
            autocorrect: false,
            enableSuggestions: !secret,
            keyboardType: keyboard,
            autofillHints: autofill,
            onChanged: onChanged,
            textInputAction:
                label ==
                        'Confirm Password'
                    ? TextInputAction.done
                    : TextInputAction.next,
            onFieldSubmitted:
                label ==
                        'Confirm Password'
                    ? (_) => _submit()
                    : null,
            validator: validator,
            style:
                const TextStyle(
              fontSize: 14,
              color:
                  Color(0xFF20242B),
            ),
            decoration:
                InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(
                fontSize: 14,
                color:
                    Color(0xFF98A2B3),
              ),
              helperText: helper,
              helperMaxLines: 3,
              helperStyle:
                  const TextStyle(
                fontSize: 11,
                color:
                    Color(0xFF8E96A3),
              ),

              // Allow validation messages to wrap.
              errorMaxLines: 2,

              suffixIcon: secret
                  ? IconButton(
                      tooltip:
                          showSecret
                              ? 'Hide password'
                              : 'Show password',
                      onPressed:
                          onToggleSecret,
                      icon: Icon(
                        showSecret
                            ? Icons
                                .visibility_off_outlined
                            : Icons
                                .visibility_outlined,
                        size: 20,
                        color:
                            const Color(
                          0xFF697386,
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 15,
                vertical: 14,
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(12),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(12),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFDDE1E6),
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(12),
                borderSide:
                    const BorderSide(
                  color: _blue,
                  width: 1.5,
                ),
              ),
              errorBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(12),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFB3261E),
                ),
              ),
              focusedErrorBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(12),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFB3261E),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _method(
    String label,
    bool phone,
  ) {
    final selected =
        _usePhone == phone;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () =>
              _switchMethod(phone),
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          child:
              AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 150,
            ),
            height: 38,
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              color: selected
                  ? _blue
                  : Colors.transparent,
              borderRadius:
                  BorderRadius
                      .circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
                color: selected
                    ? Colors.white
                    : const Color(
                        0xFF667085,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor:
            AppTheme.pageBackground,
        body: SafeArea(
          child: AuthMascotPeek(
          child: LayoutBuilder(
            builder:
                (
              context,
              constraints,
            ) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  20,
                  18,
                  20,
                  24,
                ),
                child:
                    ConstrainedBox(
                  constraints:
                      BoxConstraints(
                    minHeight:
                        (constraints
                                    .maxHeight -
                                42)
                            .clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Center(
                        child:
                            ConstrainedBox(
                          constraints:
                              const BoxConstraints(
                            maxWidth:
                                420,
                          ),
                          child:
                              AutofillGroup(
                            child: Form(
                              key:
                                  _formKey,
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .stretch,
                                children: [
                                  SizedBox(
                                    // Keep a clear stage for the mascot and tip.
                                    // Release it while typing or using large text.
                                    height: MediaQuery.viewInsetsOf(context).bottom == 0 &&
                                        !MediaQuery.disableAnimationsOf(context) &&
                                        MediaQuery.textScalerOf(context).scale(16) <= 22.4
                                        ? 176 : 32,
                                  ),

                                  Center(
                                    child:
                                        SvgPicture
                                            .asset(
                                      'assets/onboarding pictures/Group 105.svg',
                                      width:
                                          76,
                                      height:
                                          52,
                                      excludeFromSemantics:
                                          true,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 8,
                                  ),

                                  const Text(
                                    'IDireksyon',
                                    textAlign:
                                        TextAlign
                                            .center,
                                    style:
                                        TextStyle(
                                      fontFamily:
                                          'Bricolage Grotesque',
                                      fontSize:
                                          31,
                                      height:
                                          1.2,
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                      color:
                                          Color(
                                        0xFF0A426E,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        22,
                                  ),

                                  const Text(
                                    'Create Account',
                                    textAlign:
                                        TextAlign
                                            .center,
                                    style:
                                        TextStyle(
                                      fontFamily:
                                          'Bricolage Grotesque',
                                      fontSize:
                                          24,
                                      height:
                                          1.25,
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                      color:
                                          Colors
                                              .black,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 5,
                                  ),

                                  const Text(
                                    'Create your account to get started.',
                                    textAlign:
                                        TextAlign
                                            .center,
                                    style:
                                        TextStyle(
                                      fontSize:
                                          13,
                                      color:
                                          Color(
                                        0xFF667085,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        22,
                                  ),

                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .all(
                                      3,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          const Color(
                                        0xFFEDEFF3,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        12,
                                      ),
                                    ),
                                    child:
                                        Row(
                                      children: [
                                        _method(
                                          'Email',
                                          false,
                                        ),
                                        _method(
                                          'Phone Number',
                                          true,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(
                                    height:
                                        14,
                                  ),

                                  _field(
                                    _usePhone
                                        ? 'Phone Number'
                                        : 'Email',
                                    _usePhone
                                        ? 'e.g. 09123456789 or +639123456789'
                                        : 'e.g. juandelacruz@email.com',
                                    controller:
                                        _contact,
                                    keyboard:
                                        _usePhone
                                            ? TextInputType
                                                .phone
                                            : TextInputType
                                                .emailAddress,
                                    autofill: [
                                      _usePhone
                                          ? AutofillHints
                                              .telephoneNumber
                                          : AutofillHints
                                              .email,
                                    ],
                                    onChanged:
                                        (_) {
                                      if (_contactServerError !=
                                          null) {
                                        setState(
                                          () {
                                            _contactServerError =
                                                null;
                                          },
                                        );
                                      }
                                    },
                                    validator:
                                        (value) {
                                      final contact =
                                          (value ??
                                                  '')
                                              .trim();

                                      if (_usePhone) {
                                        final normalized =
                                            contact
                                                .replaceAll(
                                          RegExp(
                                            r'[\s()-]',
                                          ),
                                          '',
                                        );

                                        if (!RegExp(
                                          r'^(09\d{9}|\+639\d{9})$',
                                        ).hasMatch(
                                          normalized,
                                        )) {
                                          return 'Enter a valid mobile number (09… or +639…)';
                                        }
                                      } else {
                                        if (!RegExp(
                                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                        ).hasMatch(
                                          contact,
                                        )) {
                                          return 'Enter a valid email address';
                                        }
                                      }

                                      return _contactServerError;
                                    },
                                  ),

                                  _field(
                                    'Password',
                                    'Create a strong password',
                                    secret:
                                        true,
                                    showSecret:
                                        _showPassword,
                                    onToggleSecret:
                                        () {
                                      setState(
                                        () {
                                          _showPassword =
                                              !_showPassword;
                                        },
                                      );
                                    },
                                    onChanged:
                                        (_) {
                                      if (_passwordServerError !=
                                          null) {
                                        setState(
                                          () {
                                            _passwordServerError =
                                                null;
                                          },
                                        );
                                      }
                                    },
                                    controller:
                                        _password,
                                    autofill:
                                        const [
                                      AutofillHints
                                          .newPassword,
                                    ],
                                    helper:
                                        PasswordPolicy.requirements,
                                    validator:
                                        (value) {
                                      return PasswordPolicy.validate(value) ??
                                          _passwordServerError;
                                    },
                                  ),

                                  _field(
                                    'Confirm Password',
                                    'Re-enter password',
                                    secret:
                                        true,
                                    showSecret:
                                        _showConfirmation,
                                    onToggleSecret:
                                        () {
                                      setState(
                                        () {
                                          _showConfirmation =
                                              !_showConfirmation;
                                        },
                                      );
                                    },
                                    onChanged:
                                        (_) {
                                      if (_confirmationServerError !=
                                          null) {
                                        setState(
                                          () {
                                            _confirmationServerError =
                                                null;
                                          },
                                        );
                                      }
                                    },
                                    controller:
                                        _confirmation,
                                    autofill:
                                        const [
                                      AutofillHints
                                          .newPassword,
                                    ],
                                    validator: (value) {
  // Don't validate confirmation yet
  // if the main password itself is invalid.
  if (PasswordPolicy.validate(_password.text) != null) {
    return null;
  }

  if (value == null || value.isEmpty) {
    return 'Confirm your password';
  }

  if (value != _password.text) {
    return 'Passwords do not match';
  }

  return _confirmationServerError;
},
                                  ),

                                  const SizedBox(
                                    height: 2,
                                  ),

                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      SizedBox(
                                        width:
                                            24,
                                        height:
                                            24,
                                        child:
                                            Checkbox(
                                          value:
                                              _accepted,
                                          activeColor:
                                              _blue,
                                          semanticLabel:
                                              'Agree to Terms and Privacy Policy',
                                          onChanged:
                                              (value) {
                                            setState(
                                              () {
                                                _accepted =
                                                    value ??
                                                        false;

                                                _showAgreementError =
                                                    !_accepted;
                                              },
                                            );
                                          },
                                        ),
                                      ),

                                      const SizedBox(
                                        width: 5,
                                      ),

                                      Expanded(
                                        child:
                                            Text.rich(
                                          TextSpan(
                                            style:
                                                const TextStyle(
                                              fontSize:
                                                  12.5,
                                              height:
                                                  1.35,
                                              color:
                                                  Color(
                                                0xFF4F5663,
                                              ),
                                            ),
                                            children: [
                                              const TextSpan(
                                                text:
                                                    'By creating an account, you agree to our ',
                                              ),

                                              WidgetSpan(
                                                child:
                                                    MotionInkWell(
                                                  onTap:
                                                      () =>
                                                          _openLegalPage(
                                                    const TermsOfServiceScreen(),
                                                  ),
                                                  child:
                                                      const Text(
                                                    'Terms of Service',
                                                    style:
                                                        TextStyle(
                                                      fontSize:
                                                          12.5,
                                                      color:
                                                          _blue,
                                                      decoration:
                                                          TextDecoration.underline,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              const TextSpan(text: ' and '),
                                              WidgetSpan(
                                                child: MotionInkWell(
                                                  onTap: () => _openLegalPage(
                                                    const PrivacyPolicyScreen(),
                                                  ),
                                                  child: const Text(
                                                    'Privacy Policy',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      color: _blue,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const TextSpan(
                                                text:
                                                    '. Your information is used to personalize ID guidance and improve your experience.',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (_showAgreementError)
                                    const Padding(
                                      padding:
                                          EdgeInsets
                                              .only(
                                        top: 6,
                                        bottom:
                                            6,
                                        left:
                                            29,
                                      ),
                                      child:
                                          Text(
                                        'Please accept the Terms and Privacy Policy.',
                                        style:
                                            TextStyle(
                                          color:
                                              Color(
                                            0xFFB3261E,
                                          ),
                                          fontSize:
                                              12,
                                        ),
                                      ),
                                    ),

                                  const SizedBox(
                                    height:
                                        18,
                                  ),

                                  FilledButton(
                                    onPressed:
                                        _submitting
                                            ? null
                                            : _submit,
                                    style:
                                        FilledButton
                                            .styleFrom(
                                      backgroundColor:
                                          _blue,
                                      foregroundColor:
                                          Colors
                                              .white,
                                      disabledBackgroundColor:
                                          _blue
                                              .withValues(
                                        alpha:
                                            0.55,
                                      ),
                                      minimumSize:
                                          const Size
                                              .fromHeight(
                                        50,
                                      ),
                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),
                                      ),
                                    ),
                                    child:
                                        _submitting
                                            ? const SizedBox(
                                                width:
                                                    20,
                                                height:
                                                    20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth:
                                                      2,
                                                  color:
                                                      Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Create Account',
                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      14,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                              ),
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Wrap(
                                    alignment:
                                        WrapAlignment
                                            .center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment
                                            .center,
                                    children: [
                                      const Text(
                                        'Already have an account?',
                                        style:
                                            TextStyle(
                                          fontSize:
                                              14,
                                          color:
                                              Color(
                                            0xFF526079,
                                          ),
                                        ),
                                      ),

                                      TextButton(
                                        onPressed:
                                            () {
                                          Navigator.of(
                                            context,
                                          ).pushReplacementNamed(
                                            '/login',
                                          );
                                        },
                                        style:
                                            TextButton
                                                .styleFrom(
                                          foregroundColor:
                                              const Color(
                                            0xFFFFAB00,
                                          ),
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal:
                                                4,
                                          ),
                                        ),
                                        child:
                                            const Text(
                                          'Log In',
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

                    ],
                  ),
                ),
              );
            },
          ),
          ),
        ),
      ),
    );
  }
}
