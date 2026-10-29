import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/routes.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart'
    hide FadeSlideIn, Pressable, PulsingRings;
import '../../core/widgets/motion.dart';
import '../../data/models/task_item.dart';
import '../../state/app_state.dart';
import '../planner/plan_detail_screen.dart';
import '../planner/planner_screen.dart';
import '../reminders/reminders_screen.dart';
import '../settings/calendar_import_screen.dart';
import 'task_editor_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  TaskKind? _filter;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final list = st.tasks
        .where((t) => !t.archived && (_filter == null || t.kind == _filter))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    Widget feature(
            IconData icon, String title, String sub, Color c, Widget page) =>
        Expanded(
          child: Pressable(
            onTap: () => Navigator.of(context).push(fadeRoute(page)),
            child: GlassContainer(
              radius: 22,
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: c, size: 28),
                    const SizedBox(height: 10),
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: g.text)),
                    const SizedBox(height: 2),
                    Text(sub, style: TextStyle(fontSize: 12, color: g.subText)),
                  ]),
            ),
          ),
        );

    final header = <Widget>[
      const ScreenHeader(title: 'Routines', subtitle: 'Everything you track'),
      Row(children: [
        feature(
            Icons.school_rounded,
            'Study planner',
            'Paste syllabus, get daily tasks',
            AppTheme.cyan,
            const PlannerScreen()),
        const SizedBox(width: 12),
        feature(
            Icons.event_rounded,
            'Calendar import',
            'Bring events as reminders',
            AppTheme.purple,
            const CalendarImportScreen()),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        feature(Icons.alarm_rounded, 'Reminders & alarms',
            'See and switch what rings', AppTheme.red, const RemindersScreen()),
        const SizedBox(width: 12),
        feature(
            Icons.add_alarm_rounded,
            'Add alarm',
            'One-time alarm or reminder',
            AppTheme.amber,
            const TaskEditorScreen(kind: TaskKind.task)),
      ]),
      const SizedBox(height: 18),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          GlassChip(
              label: 'All',
              selected: _filter == null,
              onTap: () => setState(() => _filter = null)),
          for (final k in TaskKind.values) ...[
            const SizedBox(width: 8),
            GlassChip(
              label: k.label,
              selected: _filter == k,
              color: k.color,
              onTap: () => setState(() => _filter = k),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 16),
    ];

    return SafeArea(
      child: ListView.builder(
        scrollCacheExtent: ScrollCacheExtent.pixels(500),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
        itemCount: header.length + (list.isEmpty ? 1 : list.length),
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          if (list.isEmpty) {
            return GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No items yet. Use + on the Today tab.',
                    style: TextStyle(color: g.subText)),
              ),
            );
          }
          final t = list[i - header.length];
          return FadeSlideIn(
            key: ValueKey(t.id),
            index: i - header.length,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskCard(task: t),
            ),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskItem task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final g = context.glass;
    final t = task;
    final info = t.hasStreak ? st.streakFor(t) : null;
    return Pressable(
      onTap: () {
        if (t.planId != null) {
          Navigator.of(context)
              .push(fadeRoute(PlanDetailScreen(planId: t.planId!)));
        } else {
          Navigator.of(context).push(fadeRoute(TaskEditorScreen(task: t)));
        }
      },
      child: GlassContainer(
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: t.kind.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(t.kind.icon, color: t.kind.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: g.text)),
                ),
                if (t.alarmStyle && t.notify)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.alarm_on_rounded,
                        size: 16, color: AppTheme.red),
                  ),
              ]),
              const SizedBox(height: 3),
              Text(t.summary, style: TextStyle(fontSize: 12, color: g.subText)),
              if (info != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    StreakChip(info.current),
                    if (info.current > 0) const SizedBox(width: 8),
                    Text('best ${info.best}',
                        style: TextStyle(fontSize: 12, color: g.subText)),
                  ]),
                ),
            ]),
          ),
          if (t.planId == null)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: g.subText),
              onPressed: () async {
                final ok = await confirmGlass(context, 'Delete "${t.title}"?',
                    'Its streak and history will be removed.',
                    confirm: 'Delete', danger: true);
                if (ok) await st.deleteTask(t);
              },
            ),
        ]),
      ),
    );
  }
}
