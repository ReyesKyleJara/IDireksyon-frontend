import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const detailsHeaderBlue = Color(0xFF072C76);
const detailsBlue = Color(0xFF174B85);

class DetailCard extends StatelessWidget {
  final Widget child;
  const DetailCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );
}

class DetailMessage extends StatelessWidget {
  final String text;
  const DetailMessage(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text(
      text,
      style: const TextStyle(height: 1.5, color: Color(0xFF475569)),
    ),
  );
}

Future<void> openOfficialLink(BuildContext context, String? address) async {
  final uri = Uri.tryParse(address ?? '');
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return;
  }
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    /* Preserve content when a device has no URL handler. */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open this link.')));
  }
}

bool safeOfficialLink(dynamic address) {
  final uri = address is String ? Uri.tryParse(address) : null;
  return uri != null &&
      ['https', 'http'].contains(uri.scheme) &&
      uri.host.isNotEmpty;
}
