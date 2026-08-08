import 'package:flutter/material.dart';

import '../theme/brand_colors.dart';

/// The Lumina Chat brand mark — two rounded bars forming an L, capped with a
/// glowing dot (approved brand pitch, "L-Mark" direction: 2026-08-09).
/// Vector-drawn so it stays crisp at any size, from a 20px notification-bar
/// glyph up to a full splash-screen hero, and adapts [markColor] to
/// whatever it's placed on while [glowColor] stays the constant brand
/// amber. Same geometry drives the Android adaptive launcher icon and
/// notification icon (see android/app/src/main/res/drawable/ic_launcher_foreground.xml
/// and ic_notification.xml) — keep those in sync if this ever changes.
class LuminaMark extends StatelessWidget {
  const LuminaMark({this.size = 40, this.markColor, this.glowColor, super.key});

  final double size;
  final Color? markColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final resolvedMarkColor = markColor ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LuminaMarkPainter(
          markColor: resolvedMarkColor,
          glowColor: glowColor ?? luminaGlow,
        ),
      ),
    );
  }
}

class _LuminaMarkPainter extends CustomPainter {
  const _LuminaMarkPainter({required this.markColor, required this.glowColor});

  final Color markColor;
  final Color glowColor;

  // Same 100x100 grid as the approved brand pitch's SVG, so every rendering
  // of this mark (Flutter, Android XML) shares identical geometry.
  static const _gridSize = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _gridSize;
    canvas.save();
    canvas.scale(scale);

    final markPaint = Paint()..color = markColor;
    final glowPaint = Paint()..color = glowColor;

    final verticalBar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(32, 16, 18, 54),
      const Radius.circular(9),
    );
    final horizontalBar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(32, 52, 42, 18),
      const Radius.circular(9),
    );
    canvas.drawRRect(verticalBar, markPaint);
    canvas.drawRRect(horizontalBar, markPaint);
    canvas.drawCircle(const Offset(41, 15), 11, glowPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LuminaMarkPainter oldDelegate) {
    return oldDelegate.markColor != markColor || oldDelegate.glowColor != glowColor;
  }
}
