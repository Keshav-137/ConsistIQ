import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_background.dart';
import '../../core/widgets/glass_container.dart';

/// Placeholder. Replace with the real dashboard in the next step.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Scaffold(
      body: GlassBackground(
        child: Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Home',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: g.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
