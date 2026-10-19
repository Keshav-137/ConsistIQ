import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_background.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../shell/root_shell.dart';

/// Wraps the app in a fingerprint / face / PIN lock when enabled in Settings.
class LockGate extends StatefulWidget {
  const LockGate({super.key});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _busy = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = context.read<AppState>().settings.appLock;
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (_busy) return;
    if (s == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final lockOn = context.read<AppState>().settings.appLock;
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      if (lockOn && !_locked && away.inSeconds > 20) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    final ok = await AuthService.authenticate('Unlock ConsistIQ');
    _busy = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Stack(children: [
      const RootShell(),
      if (_locked)
        Positioned.fill(
          child: Scaffold(
            body: GlassBackground(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  GlassContainer(
                    width: 110,
                    height: 110,
                    radius: 34,
                    glowColor: AppTheme.blue,
                    glowOpacity: 0.4,
                    child: Icon(Icons.fingerprint_rounded, size: 60, color: g.text),
                  ),
                  const SizedBox(height: 24),
                  Text('ConsistIQ is locked',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: g.text)),
                  const SizedBox(height: 20),
                  GlassButton(label: 'Unlock', icon: Icons.lock_open_rounded, filled: true, onTap: _unlock),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}
