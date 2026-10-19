import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart'
    hide FadeSlideIn, Pressable, PulsingRings;
import '../../core/widgets/motion.dart';
import '../../data/models/app_settings.dart';
import '../../services/study_mode_service.dart';
import '../../state/app_state.dart';

class StudyModeScreen extends StatefulWidget {
  /// False while another tab is showing, so the screen stops polling.
  final bool visible;
  const StudyModeScreen({super.key, this.visible = true});

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen>
    with WidgetsBindingObserver {
  static const _presets = [30, 60, 120, 180];

  Timer? _t;
  bool _active = false;
  int _end = 0;
  int _totalMs = 0;
  bool _usage = false, _overlay = false, _dnd = false;
  int? _minutes = 60; // null = until I stop it
  bool _custom = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.visible) _startPolling();
    // Load app names once so the chips can show labels instead of package ids.
    final s = context.read<AppState>().settings;
    if (s.studyApps.isNotEmpty || s.emergencyApps.isNotEmpty) {
      StudyModeService.installedApps().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(StudyModeScreen old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) {
      _startPolling();
    } else if (!widget.visible && old.visible) {
      _t?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && widget.visible) _refresh();
  }

  void _startPolling() {
    _refresh();
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final s = await StudyModeService.status();
    final u = await StudyModeService.hasUsageAccess();
    final o = await StudyModeService.hasOverlay();
    final d = await StudyModeService.hasDnd();
    if (!mounted) return;
    var total = _totalMs;
    if (s.active && s.end > 0) {
      final rem = s.end - DateTime.now().millisecondsSinceEpoch;
      if (total <= 0 || rem > total) total = rem;
    } else {
      total = 0;
    }
    if (s.active == _active &&
        s.end == _end &&
        u == _usage &&
        o == _overlay &&
        d == _dnd &&
        total == _totalMs) {
      return;
    }
    setState(() {
      _active = s.active;
      _end = s.end;
      _usage = u;
      _overlay = o;
      _dnd = d;
      _totalMs = total;
    });
  }

  List<String> _allowed(AppSettings s) =>
      {...s.studyApps, ...s.emergencyApps}.toList();

  Future<void> _start() async {
    if (_starting) return;
    final settings = context.read<AppState>().settings;
    setState(() => _starting = true);
    final total = _minutes == null ? 0 : _minutes! * 60000;
    final end =
        _minutes == null ? 0 : DateTime.now().millisecondsSinceEpoch + total;
    final ok = await StudyModeService.start(
        _allowed(settings), end, settings.studySilent);
    if (!mounted) return;
    setState(() {
      _starting = false;
      if (ok) _totalMs = total;
    });
    HapticFeedback.mediumImpact();
    await _refresh();
    if (!mounted) return;
    toast(
      context,
      ok
          ? 'Study mode is ON. Stay focused!'
          : 'Could not start study mode. Check the permissions below.',
    );
  }

  /// If study mode is running, push the updated app list to the blocker
  /// without changing the end time.
  Future<void> _applyLive() async {
    if (!_active) return;
    final settings = context.read<AppState>().settings;
    await StudyModeService.start(
        _allowed(settings), _end, settings.studySilent);
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const _StopChallenge(),
    );
    if (ok == true) {
      await StudyModeService.stop();
      if (mounted) setState(() => _totalMs = 0);
      await _refresh();
    }
  }

  Future<void> _pickCustom() async {
    final s = await promptText(context, 'Minutes of focus (5 - 720)',
        _minutes == null ? '45' : '$_minutes');
    final m = int.tryParse(s ?? '');
    if (m == null || !mounted) return;
    setState(() {
      _minutes = m.clamp(5, 720);
      _custom = true;
    });
  }

  Future<void> _pickApps({required bool emergency}) async {
    final st = context.read<AppState>();
    final apps = await StudyModeService.installedApps();
    if (!mounted) return;
    if (apps.isEmpty) {
      toast(context, 'Could not load the list of installed apps.');
      return;
    }
    final chosen =
        (emergency ? st.settings.emergencyApps : st.settings.studyApps).toSet();
    var q = '';
    await showGlassSheet<void>(context, builder: (ctx) {
      final g = ctx.glass;
      final accent = emergency ? AppTheme.red : AppTheme.green;
      return StatefulBuilder(builder: (ctx, setS) {
        final shown = apps
            .where((a) => a.label.toLowerCase().contains(q.toLowerCase()))
            .toList();
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.62,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(
                  emergency ? Icons.emergency_rounded : Icons.menu_book_rounded,
                  color: accent),
              const SizedBox(width: 10),
              Text(emergency ? 'Emergency apps' : 'Allowed study apps',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: g.text)),
            ]),
            const SizedBox(height: 4),
            Text(
                emergency
                    ? 'These stay reachable even in study mode (maps, banking, ride or hospital apps).'
                    : 'Calls, messages, YouTube and WhatsApp are always allowed.',
                style: TextStyle(fontSize: 12.5, color: g.subText)),
            const SizedBox(height: 12),
            TextField(
              style: TextStyle(color: g.text),
              decoration: InputDecoration(
                hintText: 'Search apps',
                hintStyle: TextStyle(color: g.subText),
                prefixIcon: Icon(Icons.search_rounded, color: g.subText),
              ),
              onChanged: (v) => setS(() => q = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text('No apps found',
                          style: TextStyle(color: g.subText)))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final a = shown[i];
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: accent,
                          value: chosen.contains(a.pkg),
                          title: Text(a.label, style: TextStyle(color: g.text)),
                          onChanged: (v) => setS(() => v == true
                              ? chosen.add(a.pkg)
                              : chosen.remove(a.pkg)),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            GlassButton(
              label: 'Save',
              filled: true,
              color: accent,
              onTap: () async {
                await st.updateSettings((s) {
                  if (emergency) {
                    s.emergencyApps = chosen.toList();
                  } else {
                    s.studyApps = chosen.toList();
                  }
                }, resched: false);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ]),
        );
      });
    });
    if (!mounted) return;
    setState(() {});
    await _applyLive();
  }

  Widget _appTags(List<String> pkgs, Color color, String empty) {
    final g = context.glass;
    if (pkgs.isEmpty) {
      return Text(empty, style: TextStyle(color: g.subText, fontSize: 13));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final p in pkgs)
        _Tag(Icons.apps_rounded, StudyModeService.labelFor(p), color),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final s = st.settings;
    final ready = (_usage ? 1 : 0) + (_overlay ? 1 : 0);
    final permsOk = _usage && _overlay;

    Widget perm(String title, String sub, bool ok, VoidCallback open) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                ok
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(ok),
                color: ok ? AppTheme.green : AppTheme.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: g.text)),
                    Text(sub, style: TextStyle(fontSize: 12, color: g.subText)),
                  ]),
            ),
            if (!ok) GlassButton(label: 'Allow', compact: true, onTap: open),
          ]),
        );

    final cards = <Widget>[
      const ScreenHeader(
        title: 'Study mode',
        subtitle: 'Block distractions until you are done',
      ),

      // ------------------------------------------------------------- hero
      if (_active)
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          glowColor: AppTheme.cyan,
          glowOpacity: 0.25,
          child: Column(children: [
            _CountdownRing(end: _end, total: _totalMs),
            const SizedBox(height: 14),
            Text('Study mode is ON',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: g.text)),
            const SizedBox(height: 4),
            Text('Distracting apps are blocked. You can do this.',
                textAlign: TextAlign.center,
                style: TextStyle(color: g.subText)),
            const SizedBox(height: 18),
            GlassButton(
              label: 'Stop study mode',
              icon: Icons.stop_circle_outlined,
              color: AppTheme.red,
              onTap: _stop,
            ),
          ]),
        )
      else
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          glowColor: AppTheme.cyan,
          glowOpacity: 0.16,
          child: Column(children: [
            PulsingRings(
              color: AppTheme.cyan,
              size: 190,
              child: GlassContainer(
                width: 92,
                height: 92,
                radius: 30,
                blur: 0,
                child: const Icon(Icons.self_improvement_rounded,
                    size: 46, color: AppTheme.cyan),
              ),
            ),
            const SizedBox(height: 6),
            Text('Ready to focus?',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: g.text)),
            const SizedBox(height: 4),
            Text(
                'Pick how long. Everything except your allowed apps is blocked.',
                textAlign: TextAlign.center,
                style: TextStyle(color: g.subText)),
            const SizedBox(height: 18),
            Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final m in _presets)
                    _DurTile(
                      icon: Icons.timer_rounded,
                      label: m < 60 ? '$m min' : '${m ~/ 60} hr',
                      selected: !_custom && _minutes == m,
                      onTap: () => setState(() {
                        _minutes = m;
                        _custom = false;
                      }),
                    ),
                  _DurTile(
                    icon: Icons.tune_rounded,
                    label: _custom ? '$_minutes min' : 'Custom',
                    selected: _custom,
                    onTap: _pickCustom,
                  ),
                  _DurTile(
                    icon: Icons.all_inclusive_rounded,
                    label: 'Until I stop',
                    selected: _minutes == null,
                    onTap: () => setState(() {
                      _minutes = null;
                      _custom = false;
                    }),
                  ),
                ]),
          ]),
        ),
      const SizedBox(height: 14),

      // ------------------------------------------------------------ rules
      if (!_active)
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: SwitchRow(
            icon: Icons.volume_off_rounded,
            title: 'Auto silent',
            subtitle: 'Do Not Disturb while studying (calls still ring)',
            value: s.studySilent,
            onChanged: (v) =>
                st.updateSettings((x) => x.studySilent = v, resched: false),
          ),
        ),
      if (!_active) const SizedBox(height: 14),

      // ---------------------------------------------------- allowed apps
      GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Always allowed'),
          Wrap(spacing: 8, runSpacing: 8, children: const [
            _Tag(Icons.call_rounded, 'Calls', AppTheme.green),
            _Tag(Icons.sms_rounded, 'Messages', AppTheme.green),
            _Tag(Icons.play_circle_rounded, 'YouTube', AppTheme.green),
            _Tag(Icons.chat_rounded, 'WhatsApp', AppTheme.green),
            _Tag(Icons.local_fire_department_rounded, 'ConsistIQ',
                AppTheme.green),
          ]),
          const SizedBox(height: 14),
          const SectionLabel('Your study apps'),
          _appTags(s.studyApps, AppTheme.cyan, 'None added yet'),
          const SizedBox(height: 12),
          GlassButton(
            label: 'Choose study apps',
            icon: Icons.menu_book_rounded,
            compact: true,
            onTap: () => _pickApps(emergency: false),
          ),
        ]),
      ),
      const SizedBox(height: 14),

      // --------------------------------------------------- emergency apps
      GlassContainer(
        padding: const EdgeInsets.all(16),
        glowColor: AppTheme.red,
        glowOpacity: s.emergencyApps.isEmpty ? 0 : 0.10,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.red.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.emergency_rounded,
                  color: AppTheme.red, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emergency apps',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: g.text)),
                    Text('Always reachable, even in study mode',
                        style: TextStyle(fontSize: 12.5, color: g.subText)),
                  ]),
            ),
          ]),
          const SizedBox(height: 14),
          _appTags(s.emergencyApps, AppTheme.red,
              'Add maps, banking, ride, hospital or family apps you may need urgently.'),
          const SizedBox(height: 12),
          GlassButton(
            label: s.emergencyApps.isEmpty
                ? 'Add emergency apps'
                : 'Edit emergency apps',
            icon: Icons.add_moderator_rounded,
            color: AppTheme.red,
            compact: true,
            onTap: () => _pickApps(emergency: true),
          ),
        ]),
      ),

      // -------------------------------------------------- permissions/start
      if (!_active) ...[
        const SizedBox(height: 14),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ProgressRing(
                value: ready / 2,
                size: 52,
                color: permsOk ? AppTheme.green : AppTheme.amber,
                label: '$ready/2',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  permsOk
                      ? 'All set. You can start.'
                      : 'Two permissions are needed to block apps',
                  style: TextStyle(fontWeight: FontWeight.w700, color: g.text),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            perm('Usage access', 'Lets ConsistIQ see which app is open', _usage,
                StudyModeService.openUsageAccess),
            perm('Display over other apps', 'Lets ConsistIQ cover blocked apps',
                _overlay, StudyModeService.openOverlay),
            perm('Do Not Disturb access', 'Optional, for auto silent', _dnd,
                StudyModeService.openDnd),
          ]),
        ),
        const SizedBox(height: 18),
        GlassButton(
          label: _starting
              ? 'Starting...'
              : (permsOk
                  ? 'Start study mode'
                  : 'Allow the 2 permissions first'),
          icon: Icons.play_arrow_rounded,
          filled: true,
          color: AppTheme.cyan,
          onTap: (permsOk && !_starting) ? _start : null,
        ),
      ],
    ];

    return SafeArea(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
        itemCount: cards.length,
        itemBuilder: (context, i) => FadeSlideIn(
          key: ValueKey('study-$i-${_active ? 'a' : 'i'}'),
          index: i,
          child: cards[i],
        ),
      ),
    );
  }
}

/// Countdown that rebuilds only itself once per second.
class _CountdownRing extends StatefulWidget {
  final int end; // 0 = no end
  final int total;
  const _CountdownRing({required this.end, required this.total});

  @override
  State<_CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<_CountdownRing> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.end == 0) {
      return PulsingRings(
        color: AppTheme.cyan,
        size: 200,
        child: const Icon(Icons.all_inclusive_rounded,
            size: 64, color: AppTheme.cyan),
      );
    }
    final remMs = widget.end - DateTime.now().millisecondsSinceEpoch;
    final value = widget.total > 0 ? remMs / widget.total : 0.0;
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(alignment: Alignment.center, children: [
        const Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(2),
            child: PulsingRings(color: AppTheme.cyan, size: 196),
          ),
        ),
        ProgressRing(
          value: value,
          size: 150,
          color: AppTheme.cyan,
          label: fmtDuration(Duration(milliseconds: remMs)),
        ),
      ]),
    );
  }
}

class _DurTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DurTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color:
              selected ? AppTheme.cyan.withValues(alpha: 0.26) : g.tintBottom,
          border: Border.all(
            color: selected ? AppTheme.cyan : g.border.withValues(alpha: 0.5),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppTheme.cyan.withValues(alpha: 0.25),
                      blurRadius: 18)
                ]
              : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? AppTheme.cyan : g.subText),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? g.text : g.subText,
              )),
        ]),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, color: g.text, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// Stopping early is deliberately slow: wait + type a sentence.
class _StopChallenge extends StatefulWidget {
  const _StopChallenge();

  @override
  State<_StopChallenge> createState() => _StopChallengeState();
}

class _StopChallengeState extends State<_StopChallenge> {
  static const phrase = 'I want to stop studying now';
  int _left = 20;
  Timer? _t;
  final _c = TextEditingController();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 0) {
        t.cancel();
      } else if (mounted) {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final ok =
        _left <= 0 && _c.text.trim().toLowerCase() == phrase.toLowerCase();
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: GlassContainer(
        radius: 28,
        blur: 24,
        padding: const EdgeInsets.all(22),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stop study mode?',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: g.text)),
              const SizedBox(height: 10),
              Text(
                  _left > 0
                      ? 'Think about it. Wait $_left s, then type:'
                      : 'Now type this sentence to confirm:',
                  style: TextStyle(color: g.subText)),
              const SizedBox(height: 8),
              const Text('"$phrase"',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.amber)),
              const SizedBox(height: 12),
              GlassField(
                  controller: _c,
                  label: 'Type here',
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep studying',
                      style: TextStyle(
                          color: AppTheme.green, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                GlassButton(
                  label: 'Stop',
                  compact: true,
                  color: AppTheme.red,
                  filled: true,
                  onTap: ok ? () => Navigator.pop(context, true) : null,
                ),
              ]),
            ]),
      ),
    );
  }
}
