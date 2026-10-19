import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/routes.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart'
    hide FadeSlideIn, Pressable, PulsingRings;
import '../../core/widgets/motion.dart';
import '../../data/models/task_item.dart';
import '../../state/app_state.dart';
import '../tasks/task_editor_screen.dart';

/// Everything that will ring or notify in the next 7 days, in one place.
/// Flip the switch on a row to turn that reminder into a full-screen alarm.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final now = DateTime.now();
    final today = dayOnly(now);

    final items = <Object>[]; // DateTime = day header, Occ = row
    var alarms = 0, reminders = 0;
    for (var i = 0; i < 7; i++) {
      final day = addDays(today, i);
      final occs = st.occurrencesOn(day).where((o) => o.task.notify).toList();
      if (occs.isEmpty) continue;
      items.add(day);
      for (final o in occs) {
        items.add(o);
        if (o.c == null) {
          if (o.task.alarmStyle) {
            alarms++;
          } else {
            reminders++;
          }
        }
      }
    }

    final snoozed = <(Occ, DateTime)>[];
    for (final e in st.snoozes.entries) {
      final at = DateTime.fromMillisecondsSinceEpoch(e.value);
      if (!at.isAfter(now)) continue;
      final parts = e.key.split('|');
      if (parts.length < 3) continue;
      final t = st.taskById(parts[0]);
      final slot = int.tryParse(parts[2]);
      if (t == null || slot == null || slot >= t.times.length) continue;
      if (st.comps.containsKey(e.key)) continue;
      snoozed.add((Occ(t, parts[1], slot, null), at));
    }
    snoozed.sort((a, b) => a.$2.compareTo(b.$2));

    Widget stat(String v, String l, IconData i, Color c) => Expanded(
          child: GlassContainer(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Icon(i, color: c),
              const SizedBox(height: 6),
              Text(v,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: g.text)),
              Text(l, style: TextStyle(fontSize: 11.5, color: g.subText)),
            ]),
          ),
        );

    final children = <Widget>[
      const SubHeader(title: 'Reminders & alarms'),
      Row(children: [
        stat('$alarms', 'alarms', Icons.alarm_rounded, AppTheme.red),
        const SizedBox(width: 10),
        stat('$reminders', 'reminders', Icons.notifications_active_rounded,
            AppTheme.blue),
        const SizedBox(width: 10),
        stat('${snoozed.length}', 'snoozed', Icons.snooze_rounded,
            AppTheme.amber),
      ]),
      const SizedBox(height: 14),
      GlassButton(
        label: 'Add alarm or reminder',
        icon: Icons.add_alarm_rounded,
        filled: true,
        onTap: () => Navigator.of(context)
            .push(fadeRoute(const TaskEditorScreen(kind: TaskKind.task))),
      ),
      const SizedBox(height: 18),
    ];

    if (snoozed.isNotEmpty) {
      children.add(const SectionLabel('Snoozed'));
      for (final s in snoozed) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassContainer(
            radius: 20,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.snooze_rounded, color: AppTheme.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1.task.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: g.text)),
                      Text('Rings again at ${fmtHm(s.$2.hour, s.$2.minute)}',
                          style: TextStyle(fontSize: 12.5, color: g.subText)),
                    ]),
              ),
              TextButton(
                onPressed: () async {
                  // Remove the snooze, then save (undo of a missing completion is a no-op).
                  st.snoozes
                      .remove(occKey(s.$1.task.id, s.$1.dateKey, s.$1.slot));
                  await st.undo(s.$1.task, s.$1.dateKey, s.$1.slot);
                },
                child:
                    const Text('Cancel', style: TextStyle(color: AppTheme.red)),
              ),
            ]),
          ),
        ));
      }
      children.add(const SizedBox(height: 8));
    }

    if (items.isEmpty) {
      children.add(GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nothing is scheduled to notify you in the next 7 days.',
          style: TextStyle(color: g.subText),
        ),
      ));
    }

    var n = 0;
    for (final it in items) {
      if (it is DateTime) {
        final diff = it.difference(today).inDays;
        children.add(SectionLabel(
            diff == 0 ? 'Today' : (diff == 1 ? 'Tomorrow' : fmtDate(it))));
      } else if (it is Occ) {
        children.add(FadeSlideIn(
          key: ValueKey(occKey(it.task.id, it.dateKey, it.slot)),
          index: n++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReminderRow(occ: it),
          ),
        ));
      }
    }

    return PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: children,
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final Occ occ;
  const _ReminderRow({required this.occ});

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final g = context.glass;
    final t = occ.task;
    final dim = occ.c != null;
    final sub = <String>[t.kind.label];
    if (t.times.length > 1 && occ.time.label.isNotEmpty)
      sub.add(occ.time.label);
    if (occ.done) sub.add('done');
    if (occ.skipped) sub.add('skipped');

    return Pressable(
      onTap: () =>
          Navigator.of(context).push(fadeRoute(TaskEditorScreen(task: t))),
      child: Opacity(
        opacity: dim ? 0.55 : 1,
        child: GlassContainer(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            SizedBox(
              width: 64,
              child: Text(fmtHm(occ.time.hour, occ.time.minute),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: g.text)),
            ),
            Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: t.kind.color,
                  borderRadius: BorderRadius.circular(3),
                )),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: g.text)),
                    Text(sub.join('  |  '),
                        style: TextStyle(fontSize: 12, color: g.subText)),
                  ]),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  t.alarmStyle
                      ? Icons.alarm_on_rounded
                      : Icons.notifications_rounded,
                  size: 18,
                  color: t.alarmStyle ? AppTheme.red : g.subText),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: t.alarmStyle,
                  onChanged: (v) {
                    t.alarmStyle = v;
                    st.saveTask(t);
                  },
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
