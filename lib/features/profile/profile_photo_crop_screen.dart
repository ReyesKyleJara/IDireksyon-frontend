import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class ProfilePhotoCropScreen extends StatefulWidget {
  const ProfilePhotoCropScreen({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  State<ProfilePhotoCropScreen> createState() => _ProfilePhotoCropScreenState();
}

class _ProfilePhotoCropScreenState extends State<ProfilePhotoCropScreen> {
  final _controller = CropController();
  bool _ready = false;
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_cropping,
      child: Scaffold(
        appBar: AppBar(title: const Text('Adjust profile photo')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Drag and zoom to position your photo inside the circle.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Crop(
                      image: widget.bytes,
                      controller: _controller,
                      aspectRatio: 1,
                      withCircleUi: true,
                      interactive: true,
                      fixCropRect: true,
                      baseColor: colors.surfaceContainerHighest,
                      maskColor: Colors.black.withValues(alpha: .65),
                      onStatusChanged: (status) {
                        if (mounted) {
                          setState(() => _ready = status == CropStatus.ready);
                        }
                      },
                      onCropped: (result) {
                        if (!mounted) return;
                        switch (result) {
                          case CropSuccess(:final croppedImage):
                            setState(() => _cropping = false);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) Navigator.pop(context, croppedImage);
                            });
                          case CropFailure():
                            setState(() => _cropping = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not crop this photo. Try another image.',
                                ),
                              ),
                            );
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cropping
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: !_ready || _cropping
                                ? null
                                : () {
                                    setState(() => _cropping = true);
                                    _controller.crop();
                                  },
                            icon: _cropping
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(
                              _cropping ? 'Processing…' : 'Use photo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
