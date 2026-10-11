import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  static const _blue =
      Color(0xFF0B4295);

  final _formKey =
      GlobalKey<FormState>();

  final _identifier =
      TextEditingController();

  final _password =
      TextEditingController();

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
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
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

    final valid =
        _formKey.currentState!.validate();

    if (!valid) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
    });

    try {
      await AuthService.instance.login(
        _identifier.text,
        _password.text,
      );

      if (!mounted) return;

      Navigator.of(context)
          .pushNamedAndRemoveUntil(
        '/loading',
        (_) => false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      final identifierError =
          error.fieldErrors['identifier'];

      final passwordError =
          error.fieldErrors['password'];

      if (identifierError != null ||
          passwordError != null) {
        setState(() {
          _identifierServerError =
              identifierError;

          _passwordServerError =
              passwordError;
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
          _loginError =
              'Incorrect email/mobile number or password.';
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

  InputDecoration _decoration(
    String hint, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF98A2B3),
        fontSize: 14,
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 14,
      ),
      suffixIcon: suffixIcon,
      errorMaxLines: 2,
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: Color(0xFFDDE1E6),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: _blue,
          width: 1.5,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: Color(0xFFB3261E),
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(12),
        borderSide:
            const BorderSide(
          color: Color(0xFFB3261E),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor:
            AppTheme.pageBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder:
                (context, constraints) {
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
                  child: Center(
                    child:
                        ConstrainedBox(
                      constraints:
                          const BoxConstraints(
                        maxWidth: 420,
                      ),
                      child:
                          AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .stretch,
                            children: [
                              const SizedBox(
                                height: 32,
                              ),

                              Center(
                                child:
                                    SvgPicture
                                        .asset(
                                  'assets/onboarding pictures/Group 105.svg',
                                  width: 76,
                                  height: 52,
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
                                  fontSize: 31,
                                  height: 1.2,
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
                                height: 22,
                              ),

                              const Text(
                                'Welcome Back',
                                textAlign:
                                    TextAlign
                                        .center,
                                style:
                                    TextStyle(
                                  fontFamily:
                                      'Bricolage Grotesque',
                                  fontSize: 24,
                                  height: 1.25,
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
                                'Continue your ID journey.',
                                textAlign:
                                    TextAlign
                                        .center,
                                style:
                                    TextStyle(
                                  fontSize: 13,
                                  color:
                                      Color(
                                    0xFF667085,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 28,
                              ),

                              const Text(
                                'Email or Mobile Number',
                                style:
                                    TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight
                                          .w500,
                                  color:
                                      Color(
                                    0xFF20242B,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 6,
                              ),

                              TextFormField(
                                controller:
                                    _identifier,
                                decoration:
                                    _decoration(
                                  'Enter your email or mobile number',
                                ),
                                style:
                                    const TextStyle(
                                  fontSize: 14,
                                  color:
                                      Color(
                                    0xFF20242B,
                                  ),
                                ),
                                autofillHints:
                                    const [
                                  AutofillHints
                                      .username,
                                ],
                                textInputAction:
                                    TextInputAction
                                        .next,
                                autocorrect:
                                    false,
                                onChanged:
                                    (_) {
                                  if (_identifierServerError !=
                                          null ||
                                      _loginError !=
                                          null) {
                                    setState(
                                      () {
                                        _identifierServerError =
                                            null;

                                        _loginError =
                                            null;
                                      },
                                    );
                                  }
                                },
                                validator:
                                    (value) {
                                  if (value ==
                                          null ||
                                      value
                                          .trim()
                                          .isEmpty) {
                                    return 'Enter your email or mobile number';
                                  }

                                  return _identifierServerError;
                                },
                              ),

                              const SizedBox(
                                height: 14,
                              ),

                              const Text(
                                'Password',
                                style:
                                    TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight
                                          .w500,
                                  color:
                                      Color(
                                    0xFF20242B,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 6,
                              ),

                              TextFormField(
                                controller:
                                    _password,
                                obscureText:
                                    !_showPassword,
                                enableSuggestions:
                                    false,
                                autocorrect:
                                    false,
                                autofillHints:
                                    const [
                                  AutofillHints
                                      .password,
                                ],
                                textInputAction:
                                    TextInputAction
                                        .done,
                                onFieldSubmitted:
                                    (_) =>
                                        _submit(),
                                onChanged:
                                    (_) {
                                  if (_passwordServerError !=
                                          null ||
                                      _loginError !=
                                          null) {
                                    setState(
                                      () {
                                        _passwordServerError =
                                            null;

                                        _loginError =
                                            null;
                                      },
                                    );
                                  }
                                },
                                style:
                                    const TextStyle(
                                  fontSize: 14,
                                  color:
                                      Color(
                                    0xFF20242B,
                                  ),
                                ),
                                decoration:
                                    _decoration(
                                  'Enter your password',
                                  suffixIcon:
                                      IconButton(
                                    tooltip:
                                        _showPassword
                                            ? 'Hide password'
                                            : 'Show password',
                                    onPressed:
                                        () {
                                      setState(
                                        () {
                                          _showPassword =
                                              !_showPassword;
                                        },
                                      );
                                    },
                                    icon: Icon(
                                      _showPassword
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
                                  ),
                                ),
                                validator:
                                    (value) {
                                  if (value ==
                                          null ||
                                      value
                                          .isEmpty) {
                                    return 'Enter your password';
                                  }

                                  return _passwordServerError;
                                },
                              ),

                              if (_loginError !=
                                  null)
                                Padding(
                                  padding:
                                      const EdgeInsets
                                          .only(
                                    top: 6,
                                    left: 2,
                                  ),
                                  child: Text(
                                    _loginError!,
                                    style:
                                        const TextStyle(
                                      color:
                                          Color(
                                        0xFFB3261E,
                                      ),
                                      fontSize:
                                          12,
                                    ),
                                  ),
                                ),

                              Align(
                                alignment:
                                    Alignment
                                        .centerLeft,
                                child:
                                    TextButton(
                                  onPressed:
                                      () =>
                                          _showMessage(
                                    'Password recovery is not available yet.',
                                  ),
                                  style:
                                      TextButton
                                          .styleFrom(
                                    foregroundColor:
                                        const Color(
                                      0xFF98A2B3,
                                    ),
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal:
                                          3,
                                    ),
                                    textStyle:
                                        const TextStyle(
                                      fontSize:
                                          13,
                                    ),
                                  ),
                                  child:
                                      const Text(
                                    'Forgot password?',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height: 6,
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
                                            'Log In',
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
                                    "Don't have an account?",
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
                                        '/signup/email',
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
                                      'Sign Up',
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}