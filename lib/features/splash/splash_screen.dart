import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_background.dart';
import '../../core/widgets/glass_container.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 3200), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Scaffold(
      body: GlassBackground(
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _pulse]),
                builder: (_, _) {
                  final logoT = Curves.elasticOut.transform(
                    const Interval(0.0, 0.6).transform(_intro.value),
                  );
                  final textT = Curves.easeOut.transform(
                    const Interval(0.5, 0.85).transform(_intro.value),
                  );
                  final glow = 0.25 + _pulse.value * 0.35;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: logoT.clamp(0.0, 1.2),
                        child: GlassContainer(
                          width: 150,
                          height: 150,
                          radius: 44,
                          blur: 22,
                          glowColor: AppTheme.blue,
                          glowOpacity: glow,
                          child: Center(
                            child: ShaderMask(
                              shaderCallback: (r) => const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF60A5FA), AppTheme.purple],
                              ).createShader(r),
                              child: const Icon(
                                Icons.local_fire_department_rounded,
                                size: 86,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Opacity(
                        opacity: textT,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - textT)),
                          child: Column(
                            children: [
                              Text(
                                AppConfig.name,
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: g.text,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppConfig.tagline,
                                style: TextStyle(
                                  fontSize: 15,
                                  letterSpacing: 1.2,
                                  color: g.subText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              left: 64,
              right: 64,
              bottom: 70,
              child: AnimatedBuilder(
                animation: _intro,
                builder: (_, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 6,
                    color: g.text.withValues(alpha: 0.10),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _intro.value,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.blue, AppTheme.purple],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
