import 'package:flutter/material.dart';

import 'signup_form.dart';

class EmailSignupScreen extends StatelessWidget {
  const EmailSignupScreen({super.key});

  @override
  Widget build(BuildContext context) => const SignupForm(usePhone: false);
}
