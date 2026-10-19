import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../state/app_state.dart';

class PlanDetailScreen extends StatelessWidget {
  final String planId;
  const PlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final plan = st.planById(planId);
    if (plan == null) {
      return PageShell(
        child: Center(child: GlassButton(label: 'Plan not found. Go back', onTap: () => Navigator.of(context).pop())),
      );
    }
    final task = st.taskById(plan.taskId);
    final info = task == null ? null : st.streakFor(task);
    final todayKey = dateKey(DateTime.now());
    final doneToday = task != null && st.dayDone(task, todayKey);
    final next = plan.nextDay;

    return PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          SubHeader(
            title: plan.title,
            trailing: GlassIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.red,
              onTap: () async {
                final ok = await confirmGlass(context, 'Delete plan?', 'Progress and streak of this plan will be removed.',
                    confirm: 'Delete', danger: true);
                if (!ok) return;
                await st.deletePlan(plan);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ),
          GlassContainer(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              ProgressRing(value: plan.progress, size: 90, color: AppTheme.cyan, label: '${(plan.progress * 100).round()}%'),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Syllabus progress', style: TextStyle(fontWeight: FontWeight.w800, color: g.text, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${plan.donePoints}/${plan.totalPoints} points  |  ${plan.doneDays}/${plan.days.length} days',
                      style: TextStyle(color: g.subText, fontSize: 12.5)),
                  const SizedBox(height: 10),
                  Row(children: [
                    StreakChip(info?.current ?? 0),
                    if ((info?.current ?? 0) > 0) const SizedBox(width: 8),
                    Text('study streak, best ${info?.best ?? 0}', style: TextStyle(color: g.subText, fontSize: 12.5)),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          if (next != null)
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionLabel("Today's task"),
                Text(next.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: g.text)),
                const SizedBox(height: 6),
                for (final p in next.points)
                  Text('- ${p.text}', style: TextStyle(color: g.subText, fontSize: 13)),
                const SizedBox(height: 14),
                GlassButton(
                  label: doneToday ? 'Completed today' : 'Mark as completed',
                  icon: doneToday ? Icons.check_circle_rounded : Icons.check_rounded,
                  filled: !doneToday,
                  color: AppTheme.green,
                  onTap: doneToday ? null : () => st.completeStudyToday(plan),
                ),
              ]),
            )
          else
            GlassContainer(
              padding: const EdgeInsets.all(18),
              child: Text('Syllabus finished. Great work!', style: TextStyle(color: g.text, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 12),
          GlassButton(
            label: 'Catch-up: re-plan unfinished days from today',
            icon: Icons.update_rounded,
            onTap: () async {
              await st.catchUp(plan);
              if (context.mounted) toast(context, 'Remaining days moved. Completed work is untouched.');
            },
          ),
          const SizedBox(height: 20),
          const SectionLabel('All days'),
          for (var i = 0; i < plan.days.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassContainer(
                radius: 20,
                blur: 12,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: g.subText,
                    collapsedIconColor: g.subText,
                    leading: Icon(
                      plan.days[i].done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: plan.days[i].done ? AppTheme.green : g.subText,
                    ),
                    title: Text('Day ${i + 1}: ${plan.days[i].title}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: g.text, fontSize: 15)),
                    subtitle: Text(
                      '${fmtDate(parseKey(plan.days[i].dateKey))}  |  ${plan.days[i].doneCount}/${plan.days[i].points.length}',
                      style: TextStyle(color: g.subText, fontSize: 12),
                    ),
                    children: [
                      for (final pt in plan.days[i].points)
                        CheckboxListTile(
                          dense: true,
                          value: pt.done,
                          title: Text(pt.text,
                              style: TextStyle(
                                  color: pt.done ? g.subText : g.text,
                                  decoration: pt.done ? TextDecoration.lineThrough : null,
                                  fontSize: 13.5)),
                          onChanged: (_) => st.togglePoint(pt),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
