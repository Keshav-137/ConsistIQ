import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable frosted-glass card. Use this for every card, dialog and sheet.
///
/// Performance: inside a scrolling list the blur is skipped automatically.
/// Behind the glass there is only the soft gradient background, so it looks
/// the same, but scrolling stays at full frame rate.
class GlassContainer extends StatelessWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;
  final double glowOpacity;

  const GlassContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.radius = 28,
    this.blur = 20,
    this.padding,
    this.glowColor,
    this.glowOpacity = 0,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final inScroll = Scrollable.maybeOf(context) != null;
    final sigma = blur.clamp(0.0, 24.0).toDouble();
    final useBlur = sigma > 0 && !inScroll;

    final content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [g.tintTop, g.tintBottom],
        ),
        border: Border.all(color: g.border, width: 1.2),
      ),
      child: child,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glowColor == null
            ? null
            : [
                BoxShadow(
                  color: glowColor!.withValues(alpha: glowOpacity),
                  blurRadius: 60,
                  spreadRadius: 6,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: useBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: content,
              )
            : content,
      ),
    );
  }
}
