import 'package:flutter/material.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'My ID Journey',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}