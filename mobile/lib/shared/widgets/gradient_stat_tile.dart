import 'package:flutter/material.dart';

import 'press_scale.dart';

/// Square-ish gradient stat tile used on the home dashboard and admin
/// dashboard. Animates the value from 0 → target with an ease-out cubic curve.
///
/// Wrap pattern: extracted from the original `_StatTile` in
/// `home_screen.dart` so the admin dashboard can reuse the look without
/// duplicating layout.
class GradientStatTile extends StatelessWidget {
  const GradientStatTile({
    super.key,
    required this.gradient,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final LinearGradient gradient;
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    '$v',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: tile,
        ),
      ),
    );
  }
}
