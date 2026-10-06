import 'package:flutter/material.dart';

import 'signup_form.dart';

class PhoneSignupScreen extends StatelessWidget {
  const PhoneSignupScreen({super.key});

  @override
  Widget build(BuildContext context) => const SignupForm(usePhone: true);
}
