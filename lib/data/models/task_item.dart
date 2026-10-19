import 'package:flutter/material.dart';
import '../../core/utils/time_utils.dart';

enum TaskKind { habit, medicine, deadline, meeting, study }

enum RepeatMode { once, daily, weekdays, interval }

extension TaskKindX on TaskKind {
  String get label => switch (this) {
        TaskKind.habit => 'Routine',
        TaskKind.medicine => 'Medicine',
        TaskKind.deadline => 'Deadline',
        TaskKind.meeting => 'Meeting',
        TaskKind.study => 'Study',
      };

  IconData get icon => switch (this) {
        TaskKind.habit => Icons.repeat_rounded,
        TaskKind.medicine => Icons.medication_rounded,
        TaskKind.deadline => Icons.assignment_late_rounded,
        TaskKind.meeting => Icons.groups_rounded,
        TaskKind.study => Icons.school_rounded,
      };

  Color get color => switch (this) {
        TaskKind.habit => const Color(0xFF3B82F6),
        TaskKind.medicine => const Color(0xFFEC4899),
        TaskKind.deadline => const Color(0xFFF59E0B),
        TaskKind.meeting => const Color(0xFF8B5CF6),
        TaskKind.study => const Color(0xFF06B6D4),
      };
}

class TaskTime {
  String label;
  int hour;
  int minute;
  TaskTime(this.label, this.hour, this.minute);

  Map<String, dynamic> toJson() => {'l': label, 'h': hour, 'm': minute};
  factory TaskTime.fromJson(Map<String, dynamic> j) =>
      TaskTime((j['l'] ?? '') as String, (j['h'] ?? 0) as int, (j['m'] ?? 0) as int);
}

class TaskItem {
  String id;
  String title;
  String notes;
  String dose;
  TaskKind kind;
  RepeatMode repeat;
  List<int> weekdays; // 1 = Monday ... 7 = Sunday
  int intervalDays;
  DateTime startDate;
  DateTime? endDate;
  List<TaskTime> times;
  List<int> remindBefore; // minutes before due time
  int followUpMinutes; // "did you do it?" repeat gap after due time
  int nagCount; // how many follow-up reminders after due time
  int snoozeMinutes;
  bool alarmStyle; // loud full-screen alarm
  bool notify;
  bool archived;
  String? planId;
  int createdAt;

  TaskItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.dose = '',
    required this.kind,
    this.repeat = RepeatMode.daily,
    List<int>? weekdays,
    this.intervalDays = 1,
    required this.startDate,
    this.endDate,
    required this.times,
    List<int>? remindBefore,
    this.followUpMinutes = 15,
    this.nagCount = 0,
    this.snoozeMinutes = 10,
    this.alarmStyle = false,
    this.notify = true,
    this.archived = false,
    this.planId,
    int? createdAt,
  })  : weekdays = weekdays ?? [1, 2, 3, 4, 5, 6, 7],
        remindBefore = remindBefore ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  bool get hasStreak => repeat != RepeatMode.once;

  bool isScheduledOn(DateTime d) {
    final day = dayOnly(d);
    final s = dayOnly(startDate);
    if (day.isBefore(s)) return false;
    if (endDate != null && day.isAfter(dayOnly(endDate!))) return false;
    return switch (repeat) {
      RepeatMode.once => day == s,
      RepeatMode.daily => true,
      RepeatMode.weekdays => weekdays.contains(day.weekday),
      RepeatMode.interval =>
        ((day.difference(s).inHours / 24).round() % (intervalDays < 1 ? 1 : intervalDays)) == 0,
    };
  }

  String get summary {
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final when = times.map((t) => fmtHm(t.hour, t.minute)).join(', ');
    final r = switch (repeat) {
      RepeatMode.once => 'Once, ${fmtDate(startDate)}',
      RepeatMode.daily => 'Daily',
      RepeatMode.weekdays =>
        weekdays.length == 7 ? 'Daily' : weekdays.map((d) => names[d]).join(' '),
      RepeatMode.interval => 'Every $intervalDays days',
    };
    final e = (endDate != null && repeat != RepeatMode.once) ? ', until ${fmtDate(endDate!)}' : '';
    return '$r  |  $when$e';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'dose': dose,
        'kind': kind.index,
        'repeat': repeat.index,
        'weekdays': weekdays,
        'interval': intervalDays,
        'start': dateKey(startDate),
        'end': endDate == null ? null : dateKey(endDate!),
        'times': times.map((t) => t.toJson()).toList(),
        'remind': remindBefore,
        'follow': followUpMinutes,
        'nag': nagCount,
        'snooze': snoozeMinutes,
        'alarm': alarmStyle,
        'notify': notify,
        'archived': archived,
        'plan': planId,
        'created': createdAt,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        title: j['title'] as String,
        notes: (j['notes'] ?? '') as String,
        dose: (j['dose'] ?? '') as String,
        kind: TaskKind.values[(j['kind'] ?? 0) as int],
        repeat: RepeatMode.values[(j['repeat'] ?? 1) as int],
        weekdays: List<int>.from((j['weekdays'] ?? [1, 2, 3, 4, 5, 6, 7]) as List),
        intervalDays: (j['interval'] ?? 1) as int,
        startDate: parseKey(j['start'] as String),
        endDate: j['end'] == null ? null : parseKey(j['end'] as String),
        times: ((j['times'] ?? []) as List)
            .map((e) => TaskTime.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        remindBefore: List<int>.from((j['remind'] ?? []) as List),
        followUpMinutes: (j['follow'] ?? 15) as int,
        nagCount: (j['nag'] ?? 0) as int,
        snoozeMinutes: (j['snooze'] ?? 10) as int,
        alarmStyle: (j['alarm'] ?? false) as bool,
        notify: (j['notify'] ?? true) as bool,
        archived: (j['archived'] ?? false) as bool,
        planId: j['plan'] as String?,
        createdAt: (j['created'] ?? 0) as int,
      );
}

/// One recorded result for one occurrence of a task.
class Completion {
  final String taskId;
  final String dateKey;
  final int slot;
  final String status; // 'done' | 'skipped'
  final int ts;
  final String source; // tap | notification | manual

  Completion({
    required this.taskId,
    required this.dateKey,
    required this.slot,
    required this.status,
    required this.ts,
    required this.source,
  });

  String get key => occKey(taskId, dateKey, slot);

  Map<String, dynamic> toJson() =>
      {'t': taskId, 'd': dateKey, 's': slot, 'st': status, 'ts': ts, 'src': source};

  factory Completion.fromJson(Map<String, dynamic> j) => Completion(
        taskId: j['t'] as String,
        dateKey: j['d'] as String,
        slot: j['s'] as int,
        status: j['st'] as String,
        ts: j['ts'] as int,
        source: (j['src'] ?? 'tap') as String,
      );
}
