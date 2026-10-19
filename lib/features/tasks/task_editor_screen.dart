import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/task_item.dart';
import '../../state/app_state.dart';

class TaskEditorScreen extends StatefulWidget {
  final TaskItem? task;
  final TaskKind? kind;
  final String initialTitle;
  final String initialNotes;
  const TaskEditorScreen({
    super.key,
    this.task,
    this.kind,
    this.initialTitle = '',
    this.initialNotes = '',
  });

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _title = TextEditingController();
  final _dose = TextEditingController();
  final _notes = TextEditingController();

  late TaskKind kind;
  TaskTiming timing = TaskTiming.atTime;
  RepeatMode repeat = RepeatMode.daily;
  Set<int> weekdays = {1, 2, 3, 4, 5, 6, 7};
  int interval = 2;
  late DateTime start;
  DateTime? end;
  List<TaskTime> times = [];
  Set<int> remind = {};
  int follow = 15, nag = 0, snooze = 10;
  bool alarm = false, notify = true;

  bool get editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    start = dayOnly(DateTime.now());
    final t = widget.task;
    if (t != null) {
      kind = t.kind;
      timing = t.timing;
      _title.text = t.title;
      _dose.text = t.dose;
      _notes.text = t.notes;
      repeat = t.repeat;
      weekdays = t.weekdays.toSet();
      interval = t.intervalDays;
      start = dayOnly(t.startDate);
      end = t.endDate;
      times = t.times.map((e) => TaskTime(e.label, e.hour, e.minute)).toList();
      remind = t.remindBefore.toSet();
      follow = t.followUpMinutes;
      nag = t.nagCount;
      snooze = t.snoozeMinutes;
      alarm = t.alarmStyle;
      notify = t.notify;
    } else {
      _defaults(widget.kind ?? TaskKind.habit);
      _applyUserDefaults();
      _title.text = widget.initialTitle;
      _notes.text = widget.initialNotes;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _dose.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _defaults(TaskKind k) {
    kind = k;
    timing = TaskTiming.atTime;
    final today = dayOnly(DateTime.now());
    start = today;
    switch (k) {
      case TaskKind.medicine:
        repeat = RepeatMode.daily;
        times = [
          TaskTime('Morning (after breakfast)', 8, 30),
          TaskTime('Afternoon (after lunch)', 14, 0),
          TaskTime('Night (after dinner)', 21, 0),
        ];
        remind = {};
        nag = 2;
        follow = 15;
        alarm = true;
        end = addDays(today, 14); // 15 days
        break;
      case TaskKind.deadline:
        repeat = RepeatMode.once;
        times = [TaskTime('Deadline', 23, 59)];
        remind = {60};
        nag = 0;
        follow = 15;
        alarm = false;
        end = null;
        break;
      case TaskKind.meeting:
        repeat = RepeatMode.once;
        final n = DateTime.now().add(const Duration(hours: 1));
        times = [TaskTime('Meeting', n.hour, 0)];
        remind = {60, 15};
        nag = 3;
        follow = 10;
        alarm = true;
        end = null;
        break;
      case TaskKind.task:
        repeat = RepeatMode.once;
        final n = DateTime.now().add(const Duration(hours: 1));
        start = dayOnly(n);
        times = [TaskTime('At time', n.hour, n.minute)];
        remind = {15};
        nag = 0;
        follow = 15;
        alarm = false;
        end = null;
        break;
      default:
        repeat = RepeatMode.daily;
        times = [TaskTime('Daily', 20, 0)];
        remind = {30};
        nag = 1;
        follow = 30;
        alarm = false;
        end = null;
    }
  }

  void _applyUserDefaults() {
    final settings = context.read<AppState>().settings;
    snooze = settings.defaultSnoozeMinutes;
    if (kind == TaskKind.task || kind == TaskKind.habit) {
      remind = settings.defaultReminderMinutes == 0
          ? {}
          : {settings.defaultReminderMinutes};
      alarm = settings.defaultAlarmStyle;
    }
  }

  Future<void> _pickTime(TaskTime t) async {
    final tp = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: t.hour, minute: t.minute));
    if (tp != null) {
      setState(() {
        t.hour = tp.hour;
        t.minute = tp.minute;
      });
    }
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: addDays(dayOnly(DateTime.now()), -30),
      lastDate: addDays(dayOnly(DateTime.now()), 730),
    );
    if (d == null) return;
    setState(() {
      if (end != null) {
        final len = end!.difference(start).inDays;
        end = addDays(d, len);
      }
      start = dayOnly(d);
    });
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: end ?? addDays(start, 6),
      firstDate: start,
      lastDate: addDays(start, 1500),
    );
    if (d != null) setState(() => end = dayOnly(d));
  }

  int? get _durationDays =>
      end == null ? null : end!.difference(start).inDays + 1;

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return toast(context, 'Enter a title');
    if (times.isEmpty) return toast(context, 'Add at least one time');
    if (repeat == RepeatMode.weekdays && weekdays.isEmpty) {
      return toast(context, 'Pick at least one weekday');
    }
    final old = widget.task;
    final item = TaskItem(
      id: old?.id ?? const Uuid().v4(),
      title: title,
      notes: _notes.text.trim(),
      dose: _dose.text.trim(),
      kind: kind,
      timing: timing,
      repeat: repeat,
      weekdays: (weekdays.toList()..sort()),
      intervalDays: interval,
      startDate: start,
      endDate: repeat == RepeatMode.once ? null : end,
      times: times,
      remindBefore: (remind.toList()..sort()),
      followUpMinutes: follow,
      nagCount: nag,
      snoozeMinutes: snooze,
      alarmStyle: alarm,
      notify: notify,
      planId: old?.planId,
      createdAt: old?.createdAt,
    );
    await context.read<AppState>().saveTask(item);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(title),
            child,
          ]),
        ),
      );

  Widget _chips<T>(List<T> values, bool Function(T) sel, void Function(T) tap,
      String Function(T) label) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final v in values)
        GlassChip(
            label: label(v),
            selected: sel(v),
            onTap: () => setState(() => tap(v))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final once = repeat == RepeatMode.once;

    return PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          SubHeader(
              title: editing ? 'Edit ${kind.label}' : 'New ${kind.label}'),
          if (!editing && kind != TaskKind.study)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in [
                  TaskKind.habit,
                  TaskKind.medicine,
                  TaskKind.deadline,
                  TaskKind.meeting,
                  TaskKind.task,
                ])
                  GlassChip(
                    label: k.label,
                    icon: k.icon,
                    color: k.color,
                    selected: kind == k,
                    onTap: () => setState(() {
                      _defaults(k);
                      _applyUserDefaults();
                    }),
                  ),
              ]),
            ),
          GlassField(
            controller: _title,
            label: kind == TaskKind.medicine
                ? 'Medicine name'
                : (kind == TaskKind.meeting
                    ? 'Who / what are you meeting?'
                    : 'Title'),
          ),
          const SizedBox(height: 12),
          if (kind == TaskKind.medicine) ...[
            GlassField(controller: _dose, label: 'Dose (e.g. 1 tablet, 5 ml)'),
            const SizedBox(height: 12),
          ],
          GlassField(
              controller: _notes, label: 'Notes (optional)', maxLines: 3),
          const SizedBox(height: 16),
          if (kind == TaskKind.task)
            _section(
              'When do you want to do it?',
              _chips<TaskTiming>(
                TaskTiming.values,
                (v) => timing == v,
                (v) {
                  timing = v;
                  if (times.length == 1) {
                    times.single.label =
                        v == TaskTiming.completeBy ? 'Complete by' : 'At time';
                  }
                },
                (v) => switch (v) {
                  TaskTiming.atTime => 'Remind me at',
                  TaskTiming.completeBy => 'Complete by',
                },
              ),
            ),
          _section(
            kind == TaskKind.task
                ? (timing == TaskTiming.completeBy
                    ? 'Deadline time'
                    : 'Reminder time')
                : 'Time${times.length > 1 ? 's' : ''}',
            Column(children: [
              for (var i = 0; i < times.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final s = await promptText(
                              context, 'Label', times[i].label);
                          if (s != null) setState(() => times[i].label = s);
                        },
                        child: Text(
                            times[i].label.isEmpty
                                ? 'Tap to label'
                                : times[i].label,
                            style: TextStyle(color: g.subText, fontSize: 14)),
                      ),
                    ),
                    GlassButton(
                      label: fmtHm(times[i].hour, times[i].minute),
                      icon: Icons.schedule_rounded,
                      compact: true,
                      onTap: () => _pickTime(times[i]),
                    ),
                    if (times.length > 1)
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: g.subText),
                        onPressed: () => setState(() => times.removeAt(i)),
                      ),
                  ]),
                ),
              if (kind != TaskKind.task)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    GlassButton(
                      label: 'Add time',
                      icon: Icons.add_rounded,
                      compact: true,
                      onTap: () =>
                          setState(() => times.add(TaskTime('Reminder', 9, 0))),
                    ),
                    if (kind == TaskKind.medicine) ...[
                      GlassChip(
                          label: 'Before bed',
                          selected: false,
                          onTap: () => setState(
                              () => times.add(TaskTime('Before bed', 22, 30)))),
                    ],
                  ]),
                ),
            ]),
          ),
          if (kind != TaskKind.task)
            _section(
              'Repeat',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _chips<RepeatMode>(
                  RepeatMode.values,
                  (v) => repeat == v,
                  (v) => repeat = v,
                  (v) => switch (v) {
                    RepeatMode.once => 'Only once',
                    RepeatMode.daily => 'Every day',
                    RepeatMode.weekdays => 'Selected days',
                    RepeatMode.interval => 'Every N days',
                  },
                ),
                if (repeat == RepeatMode.weekdays) ...[
                  const SizedBox(height: 12),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          GestureDetector(
                            onTap: () => setState(() => weekdays.contains(d)
                                ? weekdays.remove(d)
                                : weekdays.add(d)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: weekdays.contains(d)
                                    ? AppTheme.blue.withValues(alpha: 0.35)
                                    : g.tintBottom,
                                border: Border.all(
                                    color: weekdays.contains(d)
                                        ? AppTheme.blue
                                        : g.border.withValues(alpha: 0.5)),
                              ),
                              child: Text(dayNames[d - 1],
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: g.text)),
                            ),
                          ),
                      ]),
                ],
                if (repeat == RepeatMode.interval) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('Every', style: TextStyle(color: g.text)),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline_rounded,
                          color: g.subText),
                      onPressed: () => setState(
                          () => interval = interval > 2 ? interval - 1 : 2),
                    ),
                    Text('$interval',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: g.text)),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline_rounded,
                          color: g.subText),
                      onPressed: () => setState(() => interval++),
                    ),
                    Text('days', style: TextStyle(color: g.text)),
                  ]),
                ],
              ]),
            ),
          _section(
            once ? 'Date' : 'Starts and duration',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (once)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  GlassChip(
                    label: 'Today',
                    selected: start == dayOnly(DateTime.now()),
                    onTap: () =>
                        setState(() => start = dayOnly(DateTime.now())),
                  ),
                  GlassChip(
                    label: 'Tomorrow',
                    selected: start == addDays(dayOnly(DateTime.now()), 1),
                    onTap: () => setState(
                        () => start = addDays(dayOnly(DateTime.now()), 1)),
                  ),
                  GlassButton(
                      label: fmtDate(start),
                      icon: Icons.event_rounded,
                      compact: true,
                      onTap: _pickStart),
                ])
              else ...[
                GlassButton(
                    label: 'Start: ${fmtDate(start)}',
                    icon: Icons.event_rounded,
                    compact: true,
                    onTap: _pickStart),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  GlassChip(
                      label: 'No end',
                      selected: end == null,
                      onTap: () => setState(() => end = null)),
                  for (final n in [2, 7, 15, 30, 60])
                    GlassChip(
                      label: '$n days',
                      selected: _durationDays == n,
                      onTap: () => setState(() => end = addDays(start, n - 1)),
                    ),
                  GlassChip(
                    label: end == null ||
                            [2, 7, 15, 30, 60].contains(_durationDays)
                        ? 'Pick end date'
                        : 'Until ${fmtDate(end!)}',
                    selected: end != null &&
                        ![2, 7, 15, 30, 60].contains(_durationDays),
                    onTap: _pickEnd,
                  ),
                ]),
              ],
            ]),
          ),
          _section(
            'Reminders',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchRow(
                title: 'Notifications',
                subtitle: 'Turn off to track without reminders',
                value: notify,
                onChanged: (v) => setState(() => notify = v),
              ),
              if (notify) ...[
                const SizedBox(height: 14),
                Text('Remind me before',
                    style:
                        TextStyle(color: g.text, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _chips<int>(
                  [5, 15, 30, 60, 120],
                  (v) => remind.contains(v),
                  (v) => remind.contains(v) ? remind.remove(v) : remind.add(v),
                  (v) => v >= 60 ? '${v ~/ 60} hr' : '$v min',
                ),
                const SizedBox(height: 14),
                Text('If still not done, ask again',
                    style:
                        TextStyle(color: g.text, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _chips<int>([0, 1, 2, 3, 5], (v) => nag == v, (v) => nag = v,
                    (v) => v == 0 ? 'Never' : '$v time${v > 1 ? 's' : ''}'),
                if (nag > 0) ...[
                  const SizedBox(height: 10),
                  Text('...every', style: TextStyle(color: g.subText)),
                  const SizedBox(height: 6),
                  _chips<int>([5, 10, 15, 30, 60], (v) => follow == v,
                      (v) => follow = v, (v) => '$v min'),
                ],
                const SizedBox(height: 14),
                Text('Snooze for',
                    style:
                        TextStyle(color: g.text, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _chips<int>([5, 10, 15, 30], (v) => snooze == v,
                    (v) => snooze = v, (v) => '$v min'),
                const SizedBox(height: 14),
                SwitchRow(
                  icon: Icons.alarm_rounded,
                  title: 'Ring like an alarm',
                  subtitle: 'Loud, full-screen, keeps ringing until you act',
                  value: alarm,
                  onChanged: (v) => setState(() => alarm = v),
                ),
              ],
            ]),
          ),
          GlassButton(
              label: editing ? 'Save changes' : 'Create',
              icon: Icons.check_rounded,
              filled: true,
              onTap: _save),
          if (editing) ...[
            const SizedBox(height: 12),
            GlassButton(
              label: 'Delete',
              icon: Icons.delete_outline_rounded,
              color: AppTheme.red,
              onTap: () async {
                final appState = context.read<AppState>();
                final navigator = Navigator.of(context);
                final ok = await confirmGlass(context, 'Delete this?',
                    'Streak and history will be removed.',
                    confirm: 'Delete', danger: true);
                if (!mounted) return;
                if (ok) {
                  await appState.deleteTask(widget.task!);
                  if (!mounted) return;
                  navigator.pop();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
