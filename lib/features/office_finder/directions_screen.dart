import 'package:flutter/material.dart';

import 'models/office_model.dart';
import 'office_finder_screen.dart';

/// Keeps existing app routes pointing at the embedded office map.
class DirectionsScreen extends StatelessWidget {
  const DirectionsScreen({super.key, required this.office});
  final OfficeModel office;

  @override
  Widget build(BuildContext context) =>
      OfficeFinderScreen(initialOffice: office);
}
