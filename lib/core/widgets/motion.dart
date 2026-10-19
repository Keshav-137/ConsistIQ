import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// Smooth, bouncy scrolling on every list (and drag with mouse/stylus).
class SmoothScrollBehavior extends MaterialScrollBehavior {
  const SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

/// Fades and slides a widget in once when it first appears.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final double dy;
  const FadeSlideIn(
      {super.key, required this.child, this.index = 0, this.dy = 18});

  @override
  Widget build(BuildContext context) {
    final ms = 380 + (index > 8 ? 8 : index) * 45;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child:
            Transform.translate(offset: Offset(0, (1 - v) * dy), child: child),
      ),
    );
  }
}

/// Gentle press-in scale effect for tappable cards.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Expanding ripple rings (alarm, study mode, lock screen).
class PulsingRings extends StatefulWidget {
  final Color color;
  final double size;
  final Widget? child;
  final Duration period;
  const PulsingRings({
    super.key,
    required this.color,
    this.size = 220,
    this.child,
    this.period = const Duration(milliseconds: 2400),
  });

  @override
  State<PulsingRings> createState() => _PulsingRingsState();
}

class _PulsingRingsState extends State<PulsingRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _RingsPainter(_c, widget.color)),
            ),
          ),
          if (widget.child != null) widget.child!,
        ]),
      );
}

class _RingsPainter extends CustomPainter {
  final Animation<double> anim;
  final Color color;
  _RingsPainter(this.anim, this.color) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final p = (anim.value + i / 3) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: (1 - p) * 0.45);
      canvas.drawCircle(c, maxR * (0.4 + p * 0.6), paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color;
}
