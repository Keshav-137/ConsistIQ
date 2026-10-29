import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_background.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart'
    hide FadeSlideIn, Pressable, PulsingRings;
import '../../core/widgets/motion.dart';
import '../../data/models/task_item.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';

/// Full-screen alarm. Opens when an alarm notification is tapped (or when the
/// full-screen intent fires over the lock screen), and also by itself when an
/// alarm time arrives while the app is open.
class AlarmRingScreen extends StatefulWidget {
  final ReminderPayload payload;
  const AlarmRingScreen({super.key, required this.payload});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  Timer? _buzz;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _buzz = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    _buzz?.cancel();
    // Stop the ringing notification when this screen goes away.
    unawaited(NotificationService.instance
        .silence(widget.payload)
        .catchError((Object e) => debugPrint('silence failed: $e')));
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('Alarm action failed: $e');
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final p = widget.payload;
    final t = st.taskById(p.taskId);

    if (t == null || p.slot >= t.times.length) {
      return PageShell(
        child: Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('This alarm is no longer available.',
                  style: TextStyle(color: g.text)),
              const SizedBox(height: 16),
              GlassButton(
                  label: 'Close', onTap: () => Navigator.of(context).pop()),
            ]),
          ),
        ),
      );
    }

    final comp = st.comps[occKey(t.id, p.dateKey, p.slot)];
    final tt = t.times[p.slot];
    final med = t.kind == TaskKind.medicine;
    final color = t.kind.color;
    final snoozeOptions = <int>{5, t.snoozeMinutes, 15}.toList()..sort();

    return Scaffold(
      body: GlassBackground(
        child: Stack(children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 1.0,
                    colors: [
                      AppTheme.red.withValues(alpha: 0.28),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.alarm_on_rounded,
                          size: 16, color: AppTheme.red),
                      SizedBox(width: 6),
                      Text('ALARM',
                          style: TextStyle(
                              color: AppTheme.red,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  const _LiveClock(),
                  const SizedBox(height: 6),
                  PulsingRings(
                    color: AppTheme.red,
                    size: 240,
                    child: GlassContainer(
                      width: 116,
                      height: 116,
                      radius: 38,
                      blur: 0,
                      glowColor: color,
                      glowOpacity: 0.5,
                      child: Icon(t.kind.icon, size: 56, color: color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(t.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: g.text)),
                  const SizedBox(height: 6),
                  Text(
                    [
                      'Due ${fmtHm(tt.hour, tt.minute)}',
                      if (tt.label.isNotEmpty && t.times.length > 1) tt.label,
                      if (t.dose.isNotEmpty) t.dose,
                    ].join('  |  '),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: g.subText),
                  ),
                  if (t.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(t.notes,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: g.subText)),
                  ],
                  const SizedBox(height: 26),
                  if (comp != null) ...[
                    Icon(
                        comp.status == 'done'
                            ? Icons.check_circle_rounded
                            : Icons.block_rounded,
                        size: 44,
                        color:
                            comp.status == 'done' ? AppTheme.green : g.subText),
                    const SizedBox(height: 8),
                    Text(
                        comp.status == 'done'
                            ? 'Already done'
                            : 'Already skipped',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: g.text)),
                    const SizedBox(height: 14),
                    GlassButton(
                        label: 'Close',
                        onTap: () => Navigator.of(context).pop()),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        label: med ? 'I took it' : 'Done',
                        icon: Icons.check_rounded,
                        filled: true,
                        color: AppTheme.green,
                        onTap: _busy
                            ? null
                            : () => _run(() => st.complete(t, p.dateKey, p.slot,
                                source: 'notification')),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Snooze for',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: g.text),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final minutes in snoozeOptions)
                          GlassButton(
                            label: '$minutes min',
                            icon: Icons.snooze_rounded,
                            compact: true,
                            onTap: _busy
                                ? null
                                : () => _run(() =>
                                    st.snooze(t, p.dateKey, p.slot, minutes)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        label: 'Snooze until a specific time',
                        icon: Icons.schedule_rounded,
                        onTap: _busy
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final selected = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    now.add(const Duration(minutes: 30)),
                                  ),
                                );
                                if (selected == null || !mounted) return;

                                var until = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  selected.hour,
                                  selected.minute,
                                );
                                if (!until.isAfter(now)) {
                                  until = until.add(const Duration(days: 1));
                                }
                                await _run(() => st.snooze(
                                      t,
                                      p.dateKey,
                                      p.slot,
                                      0,
                                      until: until,
                                    ));
                              },
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final ok = await confirmGlass(
                                context,
                                'Skip this one?',
                                'Skipping counts as missed for your streak.',
                                confirm: 'Skip',
                                danger: true,
                              );
                              if (ok) {
                                await _run(() => st.skip(t, p.dateKey, p.slot));
                              }
                            },
                      child: Text(med ? 'Skip this dose' : 'Skip',
                          style: const TextStyle(
                              color: AppTheme.red,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Live clock that rebuilds only itself once per second.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _t;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Text(
      fmtHm(_now.hour, _now.minute),
      style: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w800,
        color: g.text,
        letterSpacing: 1,
      ),
    );
  }
}
