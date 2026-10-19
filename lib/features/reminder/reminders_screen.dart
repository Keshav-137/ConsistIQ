import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/routes.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/task_item.dart';
import '../../state/app_state.dart';
import '../tasks/task_editor_screen.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final g = context.glass;
    final now = DateTime.now();
    final today = dayOnly(now);
    final entries = <Object>[];
    var alarmCount = 0;
    var reminderCount = 0;

    for (var offset = 0; offset < 7; offset++) {
      final day = addDays(today, offset);
      final occurrences = state
          .occurrencesOn(day)
          .where((occurrence) => occurrence.task.notify)
          .toList();
      if (occurrences.isEmpty) continue;
      entries.add(day);
      for (final occurrence in occurrences) {
        entries.add(occurrence);
        if (occurrence.c == null) {
          if (occurrence.task.alarmStyle) {
            alarmCount++;
          } else {
            reminderCount++;
          }
        }
      }
    }

    final snoozed = <(Occ, DateTime)>[];
    for (final entry in state.snoozes.entries) {
      if (entry.value <= now.millisecondsSinceEpoch) continue;
      final parts = entry.key.split('|');
      if (parts.length != 3) continue;
      final task = state.taskById(parts[0]);
      final slot = int.tryParse(parts[2]);
      if (task == null ||
          task.archived ||
          slot == null ||
          slot < 0 ||
          slot >= task.times.length ||
          state.comps.containsKey(entry.key)) {
        continue;
      }
      try {
        final day = parseKey(parts[1]);
        if (!task.isScheduledOn(day)) continue;
        snoozed.add((
          Occ(task, parts[1], slot, null),
          DateTime.fromMillisecondsSinceEpoch(entry.value),
        ));
      } on FormatException {
        continue;
      }
    }
    snoozed.sort((a, b) => a.$2.compareTo(b.$2));

    Widget stat(String value, String label, IconData icon, Color color) =>
        Expanded(
          child: GlassContainer(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: g.text,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11.5, color: g.subText),
              ),
            ]),
          ),
        );

    final header = <Widget>[
      const SubHeader(title: 'Reminders & alarms'),
      Row(children: [
        stat('$alarmCount', 'alarms', Icons.alarm_rounded, AppTheme.red),
        const SizedBox(width: 10),
        stat(
          '$reminderCount',
          'reminders',
          Icons.notifications_active_rounded,
          AppTheme.blue,
        ),
        const SizedBox(width: 10),
        stat(
          '${snoozed.length}',
          'snoozed',
          Icons.snooze_rounded,
          AppTheme.amber,
        ),
      ]),
      const SizedBox(height: 14),
      GlassButton(
        label: 'Add alarm or reminder',
        icon: Icons.add_alarm_rounded,
        filled: true,
        onTap: () => Navigator.of(context).push(
          fadeRoute(const TaskEditorScreen(kind: TaskKind.task)),
        ),
      ),
      const SizedBox(height: 18),
    ];

    final listEntries = <Object>[];
    if (snoozed.isNotEmpty) {
      listEntries.add(const SectionLabel('Snoozed'));
      listEntries.addAll(snoozed);
      listEntries.add(const SizedBox(height: 8));
    }
    if (entries.isEmpty) {
      listEntries.add(
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nothing is scheduled to notify you in the next 7 days.',
            style: TextStyle(color: g.subText),
          ),
        ),
      );
    } else {
      listEntries.addAll(entries);
    }

    return PageShell(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: header.length + listEntries.length,
        itemBuilder: (context, index) {
          if (index < header.length) return header[index];
          final entry = listEntries[index - header.length];
          if (entry is Occ) {
            return FadeSlideIn(
              key: ValueKey(occKey(entry.task.id, entry.dateKey, entry.slot)),
              index: index - header.length,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReminderRow(occurrence: entry),
              ),
            );
          }
          if (entry is (Occ, DateTime)) {
            return _SnoozedRow(occurrence: entry.$1, snoozedUntil: entry.$2);
          }
          if (entry is DateTime) {
            final daysFromToday = entry.difference(today).inDays;
            final label = switch (daysFromToday) {
              0 => 'Today',
              1 => 'Tomorrow',
              _ => fmtDate(entry),
            };
            return SectionLabel(label);
          }
          return entry as Widget;
        },
      ),
    );
  }
}

class _SnoozedRow extends StatelessWidget {
  final Occ occurrence;
  final DateTime snoozedUntil;

  const _SnoozedRow({
    required this.occurrence,
    required this.snoozedUntil,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final g = context.glass;
    return Padding(
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
                Text(
                  occurrence.task.title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: g.text),
                ),
                Text(
                  'Rings again at ${fmtHm(snoozedUntil.hour, snoozedUntil.minute)}',
                  style: TextStyle(fontSize: 12.5, color: g.subText),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await state.cancelSnooze(
                  occurrence.task,
                  occurrence.dateKey,
                  occurrence.slot,
                );
              } catch (error) {
                if (context.mounted) {
                  toast(context, 'Could not cancel snooze: $error');
                }
              }
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.red),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final Occ occurrence;
  const _ReminderRow({required this.occurrence});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final g = context.glass;
    final task = occurrence.task;
    final sub = <String>[task.kind.label];
    if (task.times.length > 1 && occurrence.time.label.isNotEmpty) {
      sub.add(occurrence.time.label);
    }
    if (occurrence.done) sub.add('done');
    if (occurrence.skipped) sub.add('skipped');

    return Pressable(
      onTap: () => Navigator.of(context).push(
        fadeRoute(TaskEditorScreen(task: task)),
      ),
      child: Opacity(
        opacity: occurrence.c == null ? 1 : 0.55,
        child: GlassContainer(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            SizedBox(
              width: 64,
              child: Text(
                fmtHm(occurrence.time.hour, occurrence.time.minute),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: g.text,
                ),
              ),
            ),
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: task.kind.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: g.text,
                    ),
                  ),
                  Text(
                    sub.join('  |  '),
                    style: TextStyle(fontSize: 12, color: g.subText),
                  ),
                ],
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                task.alarmStyle
                    ? Icons.alarm_on_rounded
                    : Icons.notifications_rounded,
                size: 18,
                color: task.alarmStyle ? AppTheme.red : g.subText,
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: task.alarmStyle,
                  onChanged: (value) {
                    task.alarmStyle = value;
                    state.saveTask(task);
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
