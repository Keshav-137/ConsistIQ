import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable frosted-glass card. Use this for every card, dialog and sheet.
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
        child: blur <= 0
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: content,
              ),
      ),
    );
  }
}
