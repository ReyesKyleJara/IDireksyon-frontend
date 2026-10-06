import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lottie/lottie.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, this.nextRoute = '/home', this.onComplete});

  final String nextRoute;
  final void Function(BuildContext context)? onComplete;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        if (widget.onComplete != null) {
          widget.onComplete!(context);
        } else {
          Navigator.of(context).pushReplacementNamed(widget.nextRoute);
        }
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Match the background embedded in the Lottie animation.
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/loading.json.json',
          animate: !MediaQuery.disableAnimationsOf(context),
          repeat: true,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
