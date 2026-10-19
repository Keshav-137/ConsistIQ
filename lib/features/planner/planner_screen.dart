import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/routes.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../state/app_state.dart';
import 'create_plan_screen.dart';
import 'plan_detail_screen.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    return PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const SubHeader(title: 'Study planner'),
          GlassButton(
            label: 'New plan from syllabus',
            icon: Icons.auto_awesome_rounded,
            filled: true,
            color: AppTheme.cyan,
            onTap: () =>
                Navigator.of(context).push(fadeRoute(const CreatePlanScreen())),
          ),
          const SizedBox(height: 18),
          if (st.plans.isEmpty)
            GlassContainer(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Paste any syllabus (DSA, Java, GATE...). It is split into daily tasks. '
                'Each day you press "Mark completed" yourself, and that builds your study streak.',
                style: TextStyle(color: g.subText),
              ),
            ),
          for (final p in st.plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(fadeRoute(PlanDetailScreen(planId: p.id))),
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(p.title,
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: g.text)),
                          ),
                          Builder(builder: (_) {
                            final t = st.taskById(p.taskId);
                            return t == null
                                ? const SizedBox.shrink()
                                : StreakChip(st.streakFor(t).current);
                          }),
                        ]),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: p.progress,
                            minHeight: 8,
                            color: AppTheme.cyan,
                            backgroundColor: g.text.withValues(alpha: 0.1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            '${p.doneDays}/${p.days.length} days  |  ${(p.progress * 100).round()}% of syllabus',
                            style: TextStyle(fontSize: 12.5, color: g.subText)),
                        if (p.nextDay != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Next: ${p.nextDay!.title}',
                                style:
                                    TextStyle(color: g.text, fontSize: 13.5)),
                          ),
                      ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
