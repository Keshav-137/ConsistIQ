import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Animated gradient + drifting glow blobs. Wrap every screen with this
/// so the whole app shares the same glassy, transparent look.
class GlassBackground extends StatefulWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = context.isDark;
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: g.background,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = _c.value * 2 * math.pi;
              return Stack(children: [
                _blob(
                    size.width * 0.15 + math.sin(t) * 30,
                    size.height * 0.12 + math.cos(t) * 30,
                    260,
                    AppTheme.blue,
                    dark),
                _blob(
                    size.width * 0.55 + math.cos(t) * 40,
                    size.height * 0.55 + math.sin(t) * 40,
                    300,
                    AppTheme.purple,
                    dark),
                _blob(
                    size.width * -0.1 + math.sin(t + 2) * 30,
                    size.height * 0.7 + math.cos(t + 2) * 30,
                    220,
                    AppTheme.cyan,
                    dark),
              ]);
            },
          ),
          widget.child,
        ],
      ),
    );
  }

  Widget _blob(double x, double y, double d, Color c, bool dark) {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            c.withValues(alpha: dark ? 0.45 : 0.35),
            c.withValues(alpha: 0.0),
          ]),
        ),
      ),
    );
  }
}
