import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_providers.dart';

/// A slim, unobtrusive strip shown only while the device has no network
/// connectivity — collapses to zero height the rest of the time, so it
/// never permanently changes a screen's layout. Defaults to "online" while
/// the very first connectivity check is still in flight or has errored,
/// so a transient provider hiccup never falsely flashes the banner.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: isOnline
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 14,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'No internet connection',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
