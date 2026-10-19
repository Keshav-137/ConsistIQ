import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_background.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart'
    hide FadeSlideIn, Pressable, PulsingRings;
import '../../core/widgets/motion.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../shell/root_shell.dart';

/// Wraps the whole app in a fingerprint / face / PIN lock when enabled in
/// Settings. Locks on every cold start and after the chosen time away.
class LockGate extends StatefulWidget {
  const LockGate({super.key});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _busy = false;
  bool _failed = false;
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
    if (_busy || !mounted) return;
    final settings = context.read<AppState>().settings;
    if (s == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final left = _pausedAt;
      _pausedAt = null; // consume, so a late "resumed" can never re-lock
      if (!settings.appLock) {
        if (_locked) setState(() => _locked = false);
        return;
      }
      if (_locked) {
        _unlock();
        return;
      }
      if (left != null &&
          DateTime.now().difference(left).inSeconds >=
              settings.lockTimeoutSeconds) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    if (mounted) setState(() => _failed = false);
    var ok = false;
    try {
      ok = await AuthService.authenticate('Unlock ConsistIQ');
    } catch (_) {
      ok = false;
    }
    _busy = false;
    if (!mounted) return;
    setState(() {
      if (ok) _locked = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockOn = context.select<AppState, bool>((s) => s.settings.appLock);
    final show = _locked && lockOn;
    return Stack(children: [
      const RootShell(),
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !show,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: show
                ? _LockOverlay(
                    key: const ValueKey('lock'),
                    failed: _failed,
                    onUnlock: _unlock,
                  )
                : const SizedBox.shrink(key: ValueKey('open')),
          ),
        ),
      ),
    ]);
  }
}

class _LockOverlay extends StatelessWidget {
  final bool failed;
  final VoidCallback onUnlock;
  const _LockOverlay({super.key, required this.failed, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Scaffold(
      body: GlassBackground(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            PulsingRings(
              color: AppTheme.blue,
              size: 220,
              child: GlassContainer(
                width: 112,
                height: 112,
                radius: 36,
                blur: 0,
                glowColor: AppTheme.blue,
                glowOpacity: 0.4,
                child: Icon(Icons.fingerprint_rounded, size: 64, color: g.text),
              ),
            ),
            const SizedBox(height: 16),
            Text('ConsistIQ is locked',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: g.text)),
            const SizedBox(height: 8),
            Text(
              failed
                  ? 'That did not work. Try again.'
                  : 'Use your fingerprint, face or phone PIN',
              style: TextStyle(color: failed ? AppTheme.amber : g.subText),
            ),
            const SizedBox(height: 22),
            GlassButton(
              label: 'Unlock',
              icon: Icons.lock_open_rounded,
              filled: true,
              onTap: onUnlock,
            ),
          ]),
        ),
      ),
    );
  }
}
