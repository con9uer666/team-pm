import 'package:flutter/material.dart';

/// Subtle fade + slight upward translate entrance animation.
///
/// Designed to be unobtrusive: 260ms, 8px lift, `Curves.easeOutCubic`. Combine
/// with [delay] to build a stagger effect on a column of cards.
///
/// Respects `MediaQuery.disableAnimations` — when the user has reduced motion
/// enabled at the OS level, the child renders immediately at its final state.
class FadeInUp extends StatefulWidget {
  const FadeInUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.distance = 8.0,
    this.duration = const Duration(milliseconds: 260),
  });

  /// Same as [FadeInUp] but only animates on first build of this widget
  /// identity. Useful inside a [ListView.builder] where cells may be rebuilt
  /// on scroll — we don't want the animation to replay each time a row
  /// re-enters the viewport.
  ///
  /// Caller must pass a stable [key] (e.g. `ValueKey(itemId)`) so Flutter
  /// preserves the State across rebuilds.
  static Widget once({
    Key? key,
    required Widget child,
    Duration delay = Duration.zero,
    double distance = 8.0,
    Duration duration = const Duration(milliseconds: 260),
  }) {
    return _FadeInUpOnce(
      key: key,
      delay: delay,
      distance: distance,
      duration: duration,
      child: child,
    );
  }

  final Widget child;
  final Duration delay;
  final double distance;
  final Duration duration;

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _ctrl.value = 1.0;
      return;
    }
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final t = _opacity.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.distance),
            child: child,
          ),
        );
      },
    );
  }
}

class _FadeInUpOnce extends FadeInUp {
  const _FadeInUpOnce({
    super.key,
    required super.child,
    super.delay,
    super.distance,
    super.duration,
  });

  @override
  State<FadeInUp> createState() => _FadeInUpOnceState();
}

class _FadeInUpOnceState extends _FadeInUpState
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // Required by AutomaticKeepAliveClientMixin so this state survives
    // ListView.builder recycling and the entrance doesn't replay.
    super.build(context);
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final t = _opacity.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.distance),
            child: child,
          ),
        );
      },
    );
  }
}
