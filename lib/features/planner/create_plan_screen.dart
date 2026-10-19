import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/study_plan.dart';
import '../../data/models/task_item.dart';
import '../../services/syllabus_splitter.dart';
import '../../state/app_state.dart';

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  final _days = TextEditingController();
  final _min = TextEditingController(text: '90');
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _loading = false;
  SplitResult? _result;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    _days.dispose();
    _min.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final text = _text.text.trim();
    if (text.length < 3) return toast(context, 'Paste your syllabus first');
    final s = context.read<AppState>().settings;
    setState(() => _loading = true);
    final r = await SyllabusSplitter.split(
      text: text,
      days: int.tryParse(_days.text.trim()),
      minutesPerDay: int.tryParse(_min.text.trim()) ?? 90,
      apiKey: s.geminiKey,
      model: s.geminiModel,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = r;
    });
  }

  Future<void> _create() async {
    final r = _result;
    if (r == null || r.days.isEmpty) return;
    final title = _title.text.trim().isEmpty ? 'Study plan' : _title.text.trim();
    final planId = const Uuid().v4();
    final taskId = const Uuid().v4();
    final start = dayOnly(DateTime.now());
    final plan = StudyPlan(
      id: planId,
      title: title,
      taskId: taskId,
      source: r.source,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      hour: _time.hour,
      minute: _time.minute,
      days: [
        for (var i = 0; i < r.days.length; i++)
          StudyDay(
            title: r.days[i].title,
            dateKey: dateKey(addDays(start, i)),
            points: r.days[i].points.map((p) => StudyPoint(p)).toList(),
          ),
      ],
    );
    final task = TaskItem(
      id: taskId,
      title: title,
      kind: TaskKind.study,
      repeat: RepeatMode.daily,
      startDate: start,
      endDate: addDays(start, r.days.length - 1),
      times: [TaskTime('Study', _time.hour, _time.minute)],
      remindBefore: [30],
      followUpMinutes: 30,
      nagCount: 1,
      snoozeMinutes: 15,
      planId: planId,
    );
    await context.read<AppState>().addPlan(plan, task);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final r = _result;
    return PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const SubHeader(title: 'New study plan'),
          GlassField(controller: _title, label: 'Plan name (e.g. DSA, GATE 2027)'),
          const SizedBox(height: 12),
          GlassField(
            controller: _text,
            label: 'Paste syllabus here',
            hint: 'Arrays, Strings, Linked Lists, Trees, Graphs, DP...',
            maxLines: 10,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GlassField(controller: _days, label: 'Days (optional)', keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: GlassField(controller: _min, label: 'Minutes / day', keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          GlassButton(
            label: 'Daily reminder at ${fmtHm(_time.hour, _time.minute)}',
            icon: Icons.alarm_rounded,
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          ),
          const SizedBox(height: 16),
          GlassButton(
            label: _loading ? 'Splitting...' : 'Split into daily tasks',
            icon: Icons.auto_awesome_rounded,
            filled: true,
            color: AppTheme.cyan,
            onTap: _loading ? null : _generate,
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 18), child: Center(child: CircularProgressIndicator())),
          if (r != null) ...[
            const SizedBox(height: 22),
            Text('${r.days.length} days  |  ${r.source}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: g.text)),
            if (r.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(r.note!, style: TextStyle(fontSize: 12.5, color: AppTheme.amber)),
              ),
            const SizedBox(height: 12),
            for (var i = 0; i < r.days.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassContainer(
                  radius: 18,
                  blur: 12,
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final s = await promptText(context, 'Day title', r.days[i].title);
                          if (s != null) setState(() => r.days[i].title = s);
                        },
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Day ${i + 1}: ${r.days[i].title}',
                              style: TextStyle(fontWeight: FontWeight.w700, color: g.text)),
                          const SizedBox(height: 6),
                          for (final p in r.days[i].points)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('- $p', style: TextStyle(fontSize: 12.5, color: g.subText)),
                            ),
                        ]),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: g.subText),
                      onPressed: () => setState(() => r.days.removeAt(i)),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            GlassButton(
              label: 'Create plan and start streak',
              icon: Icons.check_rounded,
              filled: true,
              onTap: r.days.isEmpty ? null : _create,
            ),
          ],
        ],
      ),
    );
  }
}
