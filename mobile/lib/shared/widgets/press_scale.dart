import 'package:flutter/material.dart';

/// Wraps [child] with a tiny scale-down feedback while pressed.
///
/// Designed to layer on top of an existing [InkWell] / [GestureDetector] /
/// `onTap`: this widget only listens to pointer events for scaling — actual
/// tap handling stays where it was.
///
/// Keep the effect subtle (default 0.97 → 1.0 over 120ms). Anything larger
/// starts to look like a button on a poker app.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget child;
  final double scale;
  final Duration duration;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      behavior: HitTestBehavior.translucent,
      child: AnimatedScale(
        scale: _pressed && !reduce ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
