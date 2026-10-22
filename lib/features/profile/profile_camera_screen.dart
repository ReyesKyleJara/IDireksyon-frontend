import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Browser camera capture; mobile apps use the device's native camera picker.
class ProfileCameraScreen extends StatefulWidget {
  const ProfileCameraScreen({super.key});

  @override
  State<ProfileCameraScreen> createState() => _ProfileCameraScreenState();
}

class _ProfileCameraScreenState extends State<ProfileCameraScreen> {
  CameraController? _controller;
  String? _error;
  bool _capturing = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) throw StateError('No camera');
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Camera unavailable. Allow camera access in your browser settings, or upload a photo from your gallery.',
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing || !_ready) return;
    setState(() => _capturing = true);
    try {
      final photo = await _controller!.takePicture();
      final bytes = await photo.readAsBytes();
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not take a photo. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Take a photo')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    )
                  : _ready
                  ? CameraPreview(_controller!)
                  : const CircularProgressIndicator(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton.icon(
              onPressed: _ready && !_capturing ? _capture : null,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_capturing ? 'Capturing…' : 'Take photo'),
            ),
          ),
        ],
      ),
    ),
  );
}
