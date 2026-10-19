import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../services/study_mode_service.dart';
import '../../state/app_state.dart';

class StudyModeScreen extends StatefulWidget {
  const StudyModeScreen({super.key});

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen>
    with WidgetsBindingObserver {
  Timer? _t;
  int _tick = 0;
  bool _active = false;
  int _end = 0;
  bool _usage = false, _overlay = false, _dnd = false;
  int? _minutes = 60; // null = until I stop it

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick++;
      if (_tick % 3 == 0) {
        _refresh();
      } else if (mounted && _active) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await StudyModeService.status();
    final u = await StudyModeService.hasUsageAccess();
    final o = await StudyModeService.hasOverlay();
    final d = await StudyModeService.hasDnd();
    if (!mounted) return;
    setState(() {
      _active = s.active;
      _end = s.end;
      _usage = u;
      _overlay = o;
      _dnd = d;
    });
  }

  Future<void> _start() async {
    final settings = context.read<AppState>().settings;
    final end = _minutes == null
        ? 0
        : DateTime.now()
            .add(Duration(minutes: _minutes!))
            .millisecondsSinceEpoch;
    await StudyModeService.start(settings.studyApps, end, settings.studySilent);
    await _refresh();
    if (mounted) toast(context, 'Study mode is ON. Stay focused!');
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
      await _refresh();
    }
  }

  Future<void> _pickApps() async {
    final st = context.read<AppState>();
    final apps = await StudyModeService.installedApps();
    if (!mounted) return;
    final chosen = st.settings.studyApps.toSet();
    String q = '';
    await showGlassSheet(context, builder: (ctx) {
      final g = ctx.glass;
      return StatefulBuilder(builder: (ctx, setS) {
        final shown = apps
            .where((a) => a.label.toLowerCase().contains(q.toLowerCase()))
            .toList();
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.62,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Allowed study apps',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: g.text)),
            const SizedBox(height: 4),
            Text('Calls, messages, YouTube and WhatsApp are always allowed.',
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
              onTap: () async {
                await st.updateSettings((s) => s.studyApps = chosen.toList(),
                    resched: false);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ]),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final remaining = _end > 0
        ? Duration(milliseconds: _end - DateTime.now().millisecondsSinceEpoch)
        : null;
    final permsOk = _usage && _overlay;

    Widget perm(String title, String sub, bool ok, VoidCallback open) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: ok ? AppTheme.green : AppTheme.amber),
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

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
        children: [
          const ScreenHeader(
              title: 'Study mode',
              subtitle: 'Block distractions until you are done'),
          if (_active)
            GlassContainer(
              padding: const EdgeInsets.all(24),
              glowColor: AppTheme.cyan,
              glowOpacity: 0.25,
              child: Column(children: [
                const Icon(Icons.lock_rounded, size: 54, color: AppTheme.cyan),
                const SizedBox(height: 14),
                Text('Study mode is ON',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: g.text)),
                const SizedBox(height: 8),
                Text(
                    remaining == null
                        ? 'Stays on until you stop it'
                        : fmtDuration(remaining),
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.cyan)),
                const SizedBox(height: 18),
                GlassButton(
                    label: 'Stop study mode',
                    icon: Icons.stop_circle_outlined,
                    color: AppTheme.red,
                    onTap: _stop),
              ]),
            )
          else ...[
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('How long?'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final m in [30, 60, 120, 180])
                        GlassChip(
                          label: m < 60 ? '$m min' : '${m ~/ 60} hr',
                          selected: _minutes == m,
                          onTap: () => setState(() => _minutes = m),
                        ),
                      GlassChip(
                          label: 'Until I stop',
                          selected: _minutes == null,
                          onTap: () => setState(() => _minutes = null)),
                    ]),
                    const SizedBox(height: 16),
                    SwitchRow(
                      icon: Icons.volume_off_rounded,
                      title: 'Auto silent',
                      subtitle: 'Do Not Disturb (calls still ring)',
                      value: st.settings.studySilent,
                      onChanged: (v) => st.updateSettings(
                          (s) => s.studySilent = v,
                          resched: false),
                    ),
                  ]),
            ),
            const SizedBox(height: 14),
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Always allowed'),
                    Wrap(spacing: 8, runSpacing: 8, children: const [
                      _Tag(Icons.call_rounded, 'Calls'),
                      _Tag(Icons.sms_rounded, 'Messages'),
                      _Tag(Icons.play_circle_rounded, 'YouTube'),
                      _Tag(Icons.chat_rounded, 'WhatsApp'),
                      _Tag(Icons.local_fire_department_rounded, 'ConsistIQ'),
                    ]),
                    const SizedBox(height: 14),
                    Text(
                        '${st.settings.studyApps.length} extra study app(s) allowed',
                        style: TextStyle(color: g.subText, fontSize: 13)),
                    const SizedBox(height: 10),
                    GlassButton(
                        label: 'Choose study apps',
                        icon: Icons.apps_rounded,
                        compact: true,
                        onTap: _pickApps),
                  ]),
            ),
            const SizedBox(height: 14),
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Permissions'),
                    perm('Usage access', 'Lets ConsistIQ see which app is open',
                        _usage, StudyModeService.openUsageAccess),
                    perm(
                        'Display over other apps',
                        'Lets ConsistIQ cover blocked apps',
                        _overlay,
                        StudyModeService.openOverlay),
                    perm('Do Not Disturb access', 'Optional, for auto silent',
                        _dnd, StudyModeService.openDnd),
                  ]),
            ),
            const SizedBox(height: 18),
            GlassButton(
              label: permsOk
                  ? 'Start study mode'
                  : 'Allow the 2 permissions first',
              icon: Icons.play_arrow_rounded,
              filled: true,
              color: AppTheme.cyan,
              onTap: permsOk ? _start : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.green.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppTheme.green),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13, color: g.text, fontWeight: FontWeight.w600)),
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
        blur: 30,
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
              Text('"$phrase"',
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
                  child: Text('Keep studying',
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
