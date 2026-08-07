import 'package:flutter/material.dart';

enum PhotoSourceAction { camera, gallery, remove }

/// Bottom sheet offering to take a new photo, pick one from the gallery,
/// or (optionally) remove an existing one — shared between the profile
/// picture and chat image flows so the picker UI/behavior stays identical.
class PhotoSourceSheet extends StatelessWidget {
  const PhotoSourceSheet({this.showRemove = false, super.key});

  final bool showRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.of(context).pop(PhotoSourceAction.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(context).pop(PhotoSourceAction.gallery),
          ),
          if (showRemove)
            ListTile(
              leading: Icon(Icons.delete_outline, color: colorScheme.error),
              title: Text('Remove photo', style: TextStyle(color: colorScheme.error)),
              onTap: () => Navigator.of(context).pop(PhotoSourceAction.remove),
            ),
        ],
      ),
    );
  }
}
