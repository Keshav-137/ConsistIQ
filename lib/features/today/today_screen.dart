import 'dart:math' as math;
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
import '../planner/plan_detail_screen.dart';
import '../reminders/reminders_screen.dart';
import '../tasks/task_editor_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final now = DateTime.now();
    final occs = st.occurrencesOn(now);
    final done = occs.where((o) => o.done).length;
    var best = 0;
    for (final t in st.tasks) {
      if (t.archived || !t.hasStreak) continue;
      best = math.max(best, st.streakFor(t).current);
    }
    final h = now.hour;
    final greet =
        h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
    final name = st.settings.displayName.trim();
    final greeting = name.isEmpty ? greet : '$greet, $name';
    final headline = occs.isEmpty
        ? 'Nothing scheduled'
        : (done == occs.length
            ? 'All done for today!'
            : '${occs.length - done} left today');

    return Stack(children: [
      SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
          itemCount: (occs.isEmpty ? 4 : 3 + occs.length),
          itemBuilder: (context, index) {
            if (index == 0) {
              return ScreenHeader(
                title: greeting,
                subtitle: fmtDate(now),
                trailing: GlassIconButton(
                  icon: Icons.alarm_rounded,
                  onTap: () => Navigator.of(context)
                      .push(fadeRoute(const RemindersScreen())),
                ),
              );
            }
            if (index == 1) {
              return FadeSlideIn(
                child: GlassContainer(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    ProgressRing(
                      value: occs.isEmpty ? 0 : done / occs.length,
                      size: 84,
                      label: '$done/${occs.length}',
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(headline,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: g.text)),
                            const SizedBox(height: 10),
                            Row(children: [
                              const Icon(Icons.local_fire_department_rounded,
                                  size: 18, color: AppTheme.amber),
                              const SizedBox(width: 6),
                              Text('$best-day best active streak',
                                  style: TextStyle(
                                      color: g.subText, fontSize: 13)),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.ac_unit_rounded,
                                  size: 18, color: AppTheme.cyan),
                              const SizedBox(width: 6),
                              Text(
                                  '${st.freezes} streak freeze${st.freezes == 1 ? '' : 's'} ready',
                                  style: TextStyle(
                                      color: g.subText, fontSize: 13)),
                            ]),
                          ]),
                    ),
                  ]),
                ),
              );
            }
            if (index == 2) return const SizedBox(height: 20);
            if (occs.isEmpty) {
              return FadeSlideIn(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Icon(Icons.add_task_rounded, size: 44, color: g.subText),
                    const SizedBox(height: 12),
                    Text(
                        'Tap + to add a task, routine, medicine, deadline or meeting.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: g.subText)),
                  ]),
                ),
              );
            }
            final o = occs[index - 3];
            return FadeSlideIn(
              key: ValueKey(occKey(o.task.id, o.dateKey, o.slot)),
              index: index - 3,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OccurrenceTile(occ: o),
              ),
            );
          },
        ),
      ),
      const Positioned(right: 20, bottom: 112, child: _AddFab()),
    ]);
  }
}

class _AddFab extends StatelessWidget {
  const _AddFab();

  Future<void> _openAddSheet(BuildContext context) async {
    final kind = await showGlassSheet<TaskKind>(
      context,
      builder: (ctx) {
        final g = ctx.glass;
        Widget opt(TaskKind k, String sub) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () => Navigator.pop(ctx, k),
                child: GlassContainer(
                  radius: 20,
                  blur: 0,
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(k.icon, color: k.color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(k.label,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: g.text)),
                            Text(sub,
                                style: TextStyle(
                                    fontSize: 12.5, color: g.subText)),
                          ]),
                    ),
                  ]),
                ),
              ),
            );
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add new',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: g.text)),
              const SizedBox(height: 14),
              opt(TaskKind.habit, 'Daily or custom routine with a streak'),
              opt(TaskKind.medicine,
                  'Doses per day for 15 / 30 days, taken-or-snooze prompts'),
              opt(TaskKind.deadline,
                  'One-time task that must be done by a time'),
              opt(TaskKind.task,
                  'One-time task: reminder time, complete-by, or alarm'),
              opt(TaskKind.meeting, 'Reminds repeatedly until you press Done'),
            ]);
      },
    );
    if (kind == null || !context.mounted) return;
    Navigator.of(context).push(fadeRoute(TaskEditorScreen(kind: kind)));
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.92,
      onTap: () => _openAddSheet(context),
      child: GlassContainer(
        radius: 22,
        blur: 18,
        glowColor: AppTheme.blue,
        glowOpacity: 0.35,
        padding: const EdgeInsets.all(18),
        child: const Icon(Icons.add_rounded, size: 28, color: AppTheme.blue),
      ),
    );
  }
}

class OccurrenceTile extends StatelessWidget {
  final Occ occ;
  const OccurrenceTile({super.key, required this.occ});

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final g = context.glass;
    final t = occ.task;
    final color = t.kind.color;
    final timeText = t.kind == TaskKind.task
        ? (t.timing == TaskTiming.completeBy ? 'By ' : 'At ')
        : '';
    final sub = <String>['$timeText${fmtHm(occ.time.hour, occ.time.minute)}'];
    if (t.times.length > 1 && occ.time.label.isNotEmpty)
      sub.add(occ.time.label);
    if (t.dose.isNotEmpty) sub.add(t.dose);
    final plan = st.planById(t.planId);
    if (plan?.nextDay != null) sub.add(plan!.nextDay!.title);
    final streak = t.hasStreak ? st.streakFor(t).current : 0;
    final med = t.kind == TaskKind.medicine;

    Widget trailing;
    if (occ.done) {
      trailing = const Icon(Icons.check_circle_rounded,
          color: AppTheme.green, size: 32);
    } else if (occ.skipped) {
      trailing = Icon(Icons.block_rounded, color: g.subText, size: 30);
    } else {
      trailing = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => st.complete(t, occ.dateKey, occ.slot),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
            ),
          ),
        ),
      );
    }

    return Pressable(
      onTap: () {
        if (t.planId != null) {
          Navigator.of(context)
              .push(fadeRoute(PlanDetailScreen(planId: t.planId!)));
        } else {
          showOccOptions(context, occ);
        }
      },
      onLongPress: () => showOccOptions(context, occ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: occ.done ? 0.6 : 1,
        child: GlassContainer(
          radius: 22,
          blur: 0,
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(t.kind.icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: occ.done ? g.subText : g.text,
                                decoration: occ.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              )),
                        ),
                        if (t.alarmStyle && t.notify)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.alarm_on_rounded,
                                size: 15, color: AppTheme.red),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Text(sub.join('  |  '),
                          style: TextStyle(fontSize: 12.5, color: g.subText)),
                    ]),
              ),
              if (streak > 0)
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: StreakChip(streak)),
              trailing,
            ]),
            if (occ.c == null && occ.overdue)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med ? 'Have you taken it?' : 'Have you done it?',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.amber,
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: GlassButton(
                            label: med ? 'Taken' : 'Done',
                            compact: true,
                            filled: true,
                            color: AppTheme.green,
                            onTap: () => st.complete(t, occ.dateKey, occ.slot),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlassButton(
                            label: 'Snooze',
                            compact: true,
                            onTap: () {
                              st.snooze(
                                  t, occ.dateKey, occ.slot, t.snoozeMinutes);
                              toast(context,
                                  'Reminding you in ${t.snoozeMinutes} min');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlassButton(
                            label: 'Skip',
                            compact: true,
                            color: AppTheme.red,
                            onTap: () => st.skip(t, occ.dateKey, occ.slot),
                          ),
                        ),
                      ]),
                    ]),
              ),
          ]),
        ),
      ),
    );
  }
}

Future<void> showOccOptions(BuildContext context, Occ o) {
  final st = context.read<AppState>();
  return showGlassSheet(context, builder: (ctx) {
    final g = ctx.glass;
    Widget opt(IconData i, String label, VoidCallback action, {Color? color}) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(i, color: color ?? g.text),
          title: Text(label,
              style: TextStyle(color: g.text, fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.pop(ctx);
            action();
          },
        );
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(o.task.title,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: g.text)),
          const SizedBox(height: 8),
          if (o.c != null)
            opt(Icons.undo_rounded, 'Undo (mark pending again)',
                () => st.undo(o.task, o.dateKey, o.slot)),
          if (o.c == null)
            opt(Icons.check_circle_outline_rounded, 'Mark done',
                () => st.complete(o.task, o.dateKey, o.slot),
                color: AppTheme.green),
          if (o.c == null)
            opt(
                Icons.snooze_rounded,
                'Snooze ${o.task.snoozeMinutes} min',
                () =>
                    st.snooze(o.task, o.dateKey, o.slot, o.task.snoozeMinutes)),
          if (o.c == null)
            opt(Icons.block_rounded, 'Skip this time',
                () => st.skip(o.task, o.dateKey, o.slot),
                color: AppTheme.red),
          opt(
              Icons.edit_rounded,
              'Edit task',
              () => Navigator.of(context)
                  .push(fadeRoute(TaskEditorScreen(task: o.task)))),
        ]);
  });
}
