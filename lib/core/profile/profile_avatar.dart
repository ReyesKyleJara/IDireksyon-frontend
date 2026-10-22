import 'package:flutter/material.dart';

import 'profile_photo_service.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    this.size = 52,
    this.showCameraButton = false,
    this.onTap,
  });

  final double size;
  final bool showCameraButton;
  final VoidCallback? onTap;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  final ProfilePhotoService _photoService = ProfilePhotoService.instance;

  @override
  void initState() {
    super.initState();

    _photoService.addListener(_refresh);
    _photoService.load();
  }

  @override
  void dispose() {
    _photoService.removeListener(_refresh);

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photo = _photoService.photoBytes;

    final avatar = SizedBox(
      width: widget.size + (widget.showCameraButton ? 6 : 0),
      height: widget.size + (widget.showCameraButton ? 6 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox.square(
            dimension: widget.size,
            child: ClipOval(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: photo != null
                  ? Image.memory(
                      photo,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surfaceContainerHighest,
                        border: Border.all(
                          color: colors.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: widget.size * 0.52,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          if (widget.showCameraButton)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E3A8A),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2.5,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.onTap == null) {
      return avatar;
    }

    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: avatar,
      ),
    );
  }
}
