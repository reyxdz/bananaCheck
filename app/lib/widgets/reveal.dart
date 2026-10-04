import 'package:flutter/material.dart';

/// Fades and lifts [child] in once, staggered by [order].
///
/// Purely decorative and short (≤ ~0.6s), never delays interaction, and
/// skipped entirely when the user asked the OS to reduce motion.
class Reveal extends StatelessWidget {
  const Reveal({required this.child, this.order = 0, super.key});

  final Widget child;

  /// Position in the stagger sequence (0 = first).
  final int order;

  static const _base = Duration(milliseconds: 280);
  static const _step = Duration(milliseconds: 70);
  static const double _lift = 12;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;

    final total = _base + _step * order;
    final start = (_step * order).inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * _lift),
          child: child,
        ),
      ),
    );
  }
}
