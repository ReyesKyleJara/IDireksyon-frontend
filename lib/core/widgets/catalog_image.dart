import 'package:flutter/material.dart';

/// The square picture of an ID or document. Shows [fallback] while there is no
/// image, while it loads, and if it cannot be loaded.
class CatalogImage extends StatelessWidget {
  const CatalogImage({
    super.key,
    required this.url,
    required this.size,
    required this.fallback,
    this.radius = 14,
  });

  final String? url;
  final double size;
  final double radius;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final address = url;
    return SizedBox.square(
      dimension: size,
      child: address == null
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Image.network(
                address,
                width: size,
                height: size,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}
