import 'package:flutter/material.dart';

/// Wraps a message bubble with WhatsApp/Telegram-style swipe-right-to-reply:
/// dragging right translates the bubble and reveals a reply icon, crossing
/// [_threshold] triggers [onReply] on release, and the bubble always snaps
/// back to its resting position. [onLongPress] is wired through the same
/// [GestureDetector] (rather than a separate one) so the gesture arena
/// resolves horizontal movement vs. stillness naturally instead of the two
/// recognizers fighting each other.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    required this.onReply,
    required this.child,
    this.onLongPress,
    super.key,
  });

  final VoidCallback onReply;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _maxDrag = 70;
  static const double _threshold = 50;

  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;
  double _dragExtent = 0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          final animation = _snapAnimation;
          if (animation != null) setState(() => _dragExtent = animation.value);
        });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx).clamp(0.0, _maxDrag);
      _triggered = _dragExtent >= _threshold;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_triggered) widget.onReply();
    _triggered = false;
    _snapAnimation = Tween<double>(
      begin: _dragExtent,
      end: 0,
    ).animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOut));
    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          if (_dragExtent > 0)
            Positioned(
              left: 8,
              child: Opacity(
                opacity: (_dragExtent / _threshold).clamp(0.0, 1.0),
                child: Icon(
                  Icons.reply,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
