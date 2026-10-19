import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/task_item.dart';
import '../../state/app_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final tasks = st.tasks.where((t) => !t.archived).toList();
    TaskItem? sel = st.taskById(_selected);
    sel ??= tasks.where((t) => t.hasStreak).isNotEmpty
        ? tasks.firstWhere((t) => t.hasStreak)
        : (tasks.isNotEmpty ? tasks.first : null);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
        children: [
          const ScreenHeader(
              title: 'Streaks', subtitle: 'Your consistency, day by day'),
          if (sel == null)
            GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Text('Add a routine to start building a streak.',
                  style: TextStyle(color: g.subText)),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final t in tasks) ...[
                  GlassChip(
                    label: t.title,
                    color: t.kind.color,
                    selected: t.id == sel.id,
                    onTap: () => setState(() => _selected = t.id),
                  ),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            _Detail(task: sel),
          ],
          const SizedBox(height: 20),
          const SectionLabel('Audit log (latest 40)'),
          _Log(taskId: sel?.id),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final TaskItem task;
  const _Detail({required this.task});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final today = dayOnly(DateTime.now());
    final frozen = st.frozen[task.id] ?? <String>{};
    final info = task.hasStreak ? st.streakFor(task) : null;

    var scheduled = 0, done = 0;
    for (var i = 0; i < 30; i++) {
      final d = addDays(today, -i);
      if (!task.isScheduledOn(d)) continue;
      if (i == 0 && !st.dayDone(task, dateKey(d))) continue;
      scheduled++;
      if (st.dayDone(task, dateKey(d))) done++;
    }
    final rate = scheduled == 0 ? 0 : (done * 100 / scheduled).round();

    Widget stat(String v, String l, IconData i, Color c) => Expanded(
          child: GlassContainer(
            radius: 20,
            blur: 12,
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

    Color? cell(DateTime d) {
      if (!task.isScheduledOn(d)) return null;
      final dk = dateKey(d);
      if (st.dayDone(task, dk)) return AppTheme.green;
      if (frozen.contains(dk)) return AppTheme.cyan;
      if (d == today) return AppTheme.blue;
      if (d.isAfter(today)) return g.text.withValues(alpha: 0.12);
      return AppTheme.red;
    }

    return Column(children: [
      Row(children: [
        stat('${info?.current ?? 0}', 'current',
            Icons.local_fire_department_rounded, AppTheme.amber),
        const SizedBox(width: 10),
        stat('${info?.best ?? 0}', 'best', Icons.emoji_events_rounded,
            AppTheme.purple),
        const SizedBox(width: 10),
        stat('$rate%', 'last 30 days', Icons.insights_rounded, AppTheme.cyan),
      ]),
      const SizedBox(height: 14),
      GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionLabel('Last 5 weeks (tap a day to correct it)'),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var i = 34; i >= 0; i--)
                Builder(builder: (_) {
                  final d = addDays(today, -i);
                  final c = cell(d);
                  return GestureDetector(
                    onTap: c == null || d.isAfter(today)
                        ? null
                        : () => _fix(context, st, d),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c?.withValues(alpha: 0.75) ??
                            g.text.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: d == today
                            ? Border.all(color: g.text, width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('${d.day}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: c == null ? g.subText : Colors.white)),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            _legend(AppTheme.green, 'Done', g.subText),
            _legend(AppTheme.red, 'Missed', g.subText),
            _legend(AppTheme.cyan, 'Protected by freeze', g.subText),
            _legend(AppTheme.blue, 'Today', g.subText),
          ]),
        ]),
      ),
    ]);
  }

  Widget _legend(Color c, String t, Color tc) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(fontSize: 11.5, color: tc)),
      ]);

  void _fix(BuildContext context, AppState st, DateTime d) {
    final dk = dateKey(d);
    final done = st.dayDone(task, dk);
    showGlassSheet(context, builder: (ctx) {
      final g = ctx.glass;
      return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${task.title}  |  ${fmtDate(d)}',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: g.text)),
            const SizedBox(height: 6),
            Text('Corrections are saved in the audit log as "manual".',
                style: TextStyle(color: g.subText, fontSize: 12.5)),
            const SizedBox(height: 16),
            GlassButton(
              label: done ? 'Remove completion' : 'Mark as done',
              icon: done ? Icons.undo_rounded : Icons.check_rounded,
              filled: !done,
              color: done ? AppTheme.red : AppTheme.green,
              onTap: () {
                Navigator.pop(ctx);
                st.setDayManual(task, dk, !done);
              },
            ),
          ]);
    });
  }
}

class _Log extends StatelessWidget {
  final String? taskId;
  const _Log({this.taskId});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final items = st.comps.values
        .where((c) => taskId == null || c.taskId == taskId)
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
    if (items.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(18),
        child:
            Text('Nothing recorded yet.', style: TextStyle(color: g.subText)),
      );
    }
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        for (final c in items.take(40))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(
                  c.status == 'done'
                      ? Icons.check_circle_rounded
                      : Icons.block_rounded,
                  size: 20,
                  color: c.status == 'done' ? AppTheme.green : g.subText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${st.taskById(c.taskId)?.title ?? 'Deleted'}  (${c.dateKey})',
                  style: TextStyle(color: g.text, fontSize: 13.5),
                ),
              ),
              Text(
                '${fmtDateTime(DateTime.fromMillisecondsSinceEpoch(c.ts))}  ${c.source}',
                style: TextStyle(color: g.subText, fontSize: 11),
              ),
            ]),
          ),
      ]),
    );
  }
}
