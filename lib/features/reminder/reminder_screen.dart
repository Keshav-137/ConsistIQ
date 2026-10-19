import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/task_item.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';

/// Opens when you tap a reminder / alarm notification (also over the lock screen).
class ReminderScreen extends StatefulWidget {
  final ReminderPayload payload;
  const ReminderScreen({super.key, required this.payload});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.silence(widget.payload); // stop the ringing
  }

  void _close() {
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
              Text('This reminder is no longer available.', style: TextStyle(color: g.text)),
              const SizedBox(height: 16),
              GlassButton(label: 'Close', onTap: _close),
            ]),
          ),
        ),
      );
    }

    final comp = st.comps[occKey(t.id, p.dateKey, p.slot)];
    final tt = t.times[p.slot];
    final med = t.kind == TaskKind.medicine;
    final color = t.kind.color;

    return PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: [
          Align(alignment: Alignment.centerRight, child: GlassIconButton(icon: Icons.close_rounded, onTap: _close)),
          const SizedBox(height: 10),
          Center(
            child: GlassContainer(
              width: 130,
              height: 130,
              radius: 42,
              glowColor: color,
              glowOpacity: 0.45,
              child: Icon(t.kind.icon, size: 64, color: color),
            ),
          ),
          const SizedBox(height: 26),
          Text(t.title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: g.text)),
          const SizedBox(height: 8),
          Text(
            [fmtHm(tt.hour, tt.minute), if (tt.label.isNotEmpty && t.times.length > 1) tt.label, if (t.dose.isNotEmpty) t.dose]
                .join('  |  '),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: g.subText),
          ),
          if (t.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t.notes, textAlign: TextAlign.center, style: TextStyle(color: g.subText)),
          ],
          const SizedBox(height: 30),
          if (comp != null)
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Icon(comp.status == 'done' ? Icons.check_circle_rounded : Icons.block_rounded,
                    size: 40, color: comp.status == 'done' ? AppTheme.green : g.subText),
                const SizedBox(height: 10),
                Text(comp.status == 'done' ? 'Already marked as done' : 'Already skipped',
                    style: TextStyle(fontWeight: FontWeight.w700, color: g.text)),
                const SizedBox(height: 14),
                GlassButton(label: 'Close', onTap: _close),
              ]),
            )
          else ...[
            Text(med ? 'Have you taken it?' : 'Have you completed it?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: g.text)),
            const SizedBox(height: 16),
            GlassButton(
              label: med ? 'Yes, taken' : 'Yes, done',
              icon: Icons.check_rounded,
              filled: true,
              color: AppTheme.green,
              onTap: () async {
                await st.complete(t, p.dateKey, p.slot, source: 'notification');
                _close();
              },
            ),
            const SizedBox(height: 22),
            const SectionLabel('Not yet? Remind me again in'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in [5, 10, 15, 30, 60])
                GlassChip(
                  label: m == 60 ? '1 hr' : '$m min',
                  selected: false,
                  onTap: () async {
                    await st.snooze(t, p.dateKey, p.slot, m);
                    if (mounted) toast(context, 'I will remind you in $m min');
                    _close();
                  },
                ),
            ]),
            const SizedBox(height: 14),
            GlassButton(
              label: 'Remind me at a specific time',
              icon: Icons.schedule_rounded,
              onTap: () async {
                final tp = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 30))));
                if (tp == null) return;
                final n = DateTime.now();
                var when = DateTime(n.year, n.month, n.day, tp.hour, tp.minute);
                if (!when.isAfter(n)) when = when.add(const Duration(days: 1));
                await st.snooze(t, p.dateKey, p.slot, 0, until: when);
                if (mounted) toast(context, 'Reminder set for ${fmtHm(tp.hour, tp.minute)}');
                _close();
              },
            ),
            const SizedBox(height: 22),
            GlassButton(
              label: med ? 'Skip this dose' : 'Skip this time',
              icon: Icons.block_rounded,
              color: AppTheme.red,
              onTap: () async {
                final ok = await confirmGlass(context, 'Skip?', 'Skipping counts as missed for your streak.',
                    confirm: 'Skip', danger: true);
                if (!ok) return;
                await st.skip(t, p.dateKey, p.slot);
                _close();
              },
            ),
          ],
        ],
      ),
    );
  }
}
