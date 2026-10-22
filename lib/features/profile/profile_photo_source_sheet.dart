import 'package:flutter/material.dart';

enum ProfilePhotoAction { gallery, camera, remove }

class ProfilePhotoSourceSheet extends StatelessWidget {
  const ProfilePhotoSourceSheet({super.key, required this.hasPhoto});
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget option(
      ProfilePhotoAction action,
      IconData icon,
      String title,
      String subtitle,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Icon(icon),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.pop(context, action),
        ),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Profile photo',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              'Choose a photo, then crop it to fit your profile.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            option(
              ProfilePhotoAction.gallery,
              Icons.photo_library_outlined,
              'Upload from gallery',
              'Choose an existing photo',
            ),
            option(
              ProfilePhotoAction.camera,
              Icons.camera_alt_outlined,
              'Take a photo',
              'Use your camera',
            ),
            if (hasPhoto)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colors.error),
                onPressed: () =>
                    Navigator.pop(context, ProfilePhotoAction.remove),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove photo'),
              ),
          ],
        ),
      ),
    );
  }
}
