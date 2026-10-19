import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_background.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../state/app_state.dart';
import '../lock/lock_gate.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish({bool skip = false}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final name = skip ? '' : _nameController.text.trim();
    try {
      await context.read<AppState>().updateSettings((settings) {
        settings.displayName = name;
        settings.profileSetupComplete = true;
      }, resched: false);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, animation, __) => const LockGate(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      toast(context, 'Could not save your profile: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassContainer(
                      width: 108,
                      height: 108,
                      radius: 32,
                      glowColor: AppTheme.blue,
                      glowOpacity: 0.3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/images/icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome to ConsistIQ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: g.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'What should we call you? Add a name for a personal greeting, or skip this step.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: g.subText, height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    GlassField(
                      controller: _nameController,
                      label: 'Your name (optional)',
                      hint: 'e.g. Alex',
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        label: _saving ? 'Saving...' : 'Continue',
                        icon: Icons.arrow_forward_rounded,
                        filled: true,
                        onTap: _saving ? null : () => _finish(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving ? null : () => _finish(skip: true),
                      child: Text(
                        'Skip for now',
                        style: TextStyle(color: g.subText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
