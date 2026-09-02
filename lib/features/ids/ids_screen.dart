import 'package:flutter/material.dart';

class IdsScreen extends StatelessWidget {
  const IdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'ID Directory',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}