import 'package:flutter/material.dart';

class PlaceholderTabContent extends StatelessWidget {
  const PlaceholderTabContent({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title (Coming Soon)',
        textAlign: TextAlign.center,
      ),
    );
  }
}
