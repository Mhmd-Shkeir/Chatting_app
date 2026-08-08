import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';
import 'lumina_mark.dart';

/// Shown while the router is resolving auth/profile state (see
/// router.dart's redirect). Fully theme-aware — unlike the native
/// pre-Flutter-engine splash (android/.../launch_background.xml, a flat
/// brand-color background shown before this widget can even run), this one
/// picks up Light/Dark/System like every other screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.3,
            colors: [colorScheme.surfaceContainerHigh, colorScheme.surface],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 136,
                height: 136,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      luminaGlow.withValues(alpha: 0.24),
                      luminaGlow.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Center(
                  child: LuminaMark(size: 76, markColor: colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome to Lumina Chat',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Chat simply. Connect freely.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 44),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
