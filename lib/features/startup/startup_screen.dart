import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key, this.resumeRoute});

  /// Where a restored session continues, instead of Home.
  final String? resumeRoute;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _failed = false);
    try {
      final route = await AuthService.instance.startupRoute();
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final next = route == '/home' ? widget.resumeRoute ?? route : route;
      Navigator.of(context).pushNamedAndRemoveUntil(next, (_) => false);
    } catch (_) {
      // A locked/unavailable secure store is not evidence of a signed-out user.
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _failed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not restore your saved session.'),
                TextButton(onPressed: _start, child: const Text('Retry')),
              ],
            )
          : const CircularProgressIndicator(),
    ),
  );
}
