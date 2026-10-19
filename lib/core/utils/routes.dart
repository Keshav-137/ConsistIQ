import 'package:flutter/material.dart';

/// Smooth fade + tiny slide. Uses `drive` (no CurvedAnimation per frame),
/// so there is no listener leak and no jank during transitions.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: curved.drive(
              Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero),
            ),
            child: child,
          ),
        );
      },
    );
