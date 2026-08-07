import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shared avatar rendering used everywhere a user's picture appears (search
/// results, conversation list, chat header, profile). Falls back to the
/// existing colored-circle-with-initial when [photoUrl] is null/empty, still
/// loading, or fails to load — this is also what makes a deleted account
/// (whose photoUrl the account-deletion tombstone already nulls out) show a
/// plain initial everywhere with no deleted-specific handling needed here.
class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.photoUrl, required this.displayName, this.radius = 20, super.key});

  final String? photoUrl;
  final String displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final diameter = radius * 2;

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      child: Text(
        initial,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.8),
      ),
    );

    if (photoUrl == null || photoUrl!.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl!,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        placeholder: (context, url) => fallback,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}
