import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/time_utils.dart';
import '../data/models/app_settings.dart';
import '../data/models/study_plan.dart';
import '../data/models/task_item.dart';
import '../services/notification_service.dart';
import '../services/streak_engine.dart';
import '../services/home_widget_service.dart';

/// One due item: a task on a given day at a given time slot.
class Occ {
  final TaskItem task;
  final String dateKey;
  final int slot;
  final Completion? c;
  Occ(this.task, this.dateKey, this.slot, this.c);

  TaskTime get time => task.times[slot];
  DateTime get due {
    final d = parseKey(dateKey);
    return DateTime(d.year, d.month, d.day, time.hour, time.minute);
  }

  bool get done => c?.status == 'done';
  bool get skipped => c?.status == 'skipped';
  bool get overdue => c == null && due.isBefore(DateTime.now());
}

class AppState extends ChangeNotifier {
  AppState({this.background = false});
  final bool background;

  List<TaskItem> tasks = [];
  Map<String, Completion> comps = {};
  Map<String, Set<String>> frozen = {};
  Map<String, int> snoozes = {};
  List<StudyPlan> plans = [];
  AppSettings settings = AppSettings();
  int freezes = 1;
  String? settledThrough;
  int _rev = 0;

  // ---------------------------------------------------------------- storage
  List<T> _list<T>(String? s, T Function(Map<String, dynamic>) f) {
    if (s == null) return [];
    return (jsonDecode(s) as List)
        .map((e) => f(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    tasks = _list(p.getString('tasks'), TaskItem.fromJson);
    comps = {
      for (final c in _list(p.getString('comps'), Completion.fromJson)) c.key: c
    };
    plans = _list(p.getString('plans'), StudyPlan.fromJson);
    frozen = {};
    final fz = p.getString('frozen');
    if (fz != null) {
      (jsonDecode(fz) as Map<String, dynamic>)
          .forEach((k, v) => frozen[k] = Set<String>.from(v as List));
    }
    snoozes = {};
    final sn = p.getString('snoozes');
    if (sn != null) {
      (jsonDecode(sn) as Map<String, dynamic>)
          .forEach((k, v) => snoozes[k] = v as int);
    }
    final st = p.getString('settings');
    settings = st == null
        ? AppSettings()
        : AppSettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(st) as Map));
    freezes = p.getInt('freezes') ?? 1;
    settledThrough = p.getString('settled');
    _rev = p.getInt('rev') ?? 0;
    if (_settle()) await _save();
    notifyListeners();
  }

  /// Called on app resume / periodically: picks up changes made by
  /// notification buttons (background isolate).
  Future<void> refreshFromDisk() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    if ((p.getInt('rev') ?? 0) != _rev) await load();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    _rev = (p.getInt('rev') ?? 0) + 1;
    await p.setString(
        'tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));
    await p.setString(
        'comps', jsonEncode(comps.values.map((e) => e.toJson()).toList()));
    await p.setString(
        'plans', jsonEncode(plans.map((e) => e.toJson()).toList()));
    await p.setString(
        'frozen', jsonEncode(frozen.map((k, v) => MapEntry(k, v.toList()))));
    await p.setString('snoozes', jsonEncode(snoozes));
    await p.setString('settings', jsonEncode(settings.toJson()));
    await p.setInt('freezes', freezes);
    if (settledThrough != null) await p.setString('settled', settledThrough!);
    await p.setInt('rev', _rev);
  }

  bool _sched = false, _again = false;
  Future<void> reschedule() async {
    if (_sched) {
      _again = true;
      return;
    }
    _sched = true;
    try {
      do {
        _again = false;
        await NotificationService.instance
            .rescheduleAll(tasks, comps, snoozes, settings);
      } while (_again);
    } catch (e) {
      debugPrint('reschedule error: $e');
    } finally {
      _sched = false;
    }
  }

  Future<void> _commit({bool resched = true}) async {
    await _save();
    notifyListeners();
    if (!background) {
      unawaited(HomeWidgetService.sync(tasks, comps).catchError((e) {
        debugPrint('Home widget sync failed: $e');
      }));
    }
    if (resched) {
      if (background) {
        await reschedule();
      } else {
        unawaited(reschedule());
      }
    }
  }

  // --------------------------------------------------------------- lookups
  TaskItem? taskById(String? id) {
    if (id == null) return null;
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  StudyPlan? planById(String? id) {
    if (id == null) return null;
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Occ> occurrencesOn(DateTime day) {
    final dk = dateKey(day);
    final out = <Occ>[];
    for (final t in tasks) {
      if (t.archived || !t.isScheduledOn(day)) continue;
      for (var i = 0; i < t.times.length; i++) {
        out.add(Occ(t, dk, i, comps[occKey(t.id, dk, i)]));
      }
    }
    out.sort((a, b) => a.due.compareTo(b.due));
    return out;
  }

  bool dayDone(TaskItem t, String dk) {
    if (t.times.isEmpty) return false;
    for (var i = 0; i < t.times.length; i++) {
      if (comps[occKey(t.id, dk, i)]?.status != 'done') return false;
    }
    return true;
  }

  StreakInfo streakFor(TaskItem t) =>
      computeStreak(t, comps, frozen[t.id] ?? <String>{}, DateTime.now());

  // ------------------------------------------------------------ streak freeze
  bool _settle() {
    final today = dayOnly(DateTime.now());
    final yKey = dateKey(addDays(today, -1));
    final old = settledThrough;
    if (old == null) {
      settledThrough = yKey;
      return true;
    }
    var changed = false;
    var d = addDays(parseKey(old), 1);
    var guard = 0;
    while (!d.isAfter(addDays(today, -1)) && guard++ < 60) {
      final dk = dateKey(d);
      for (final t in tasks) {
        if (t.archived || !t.hasStreak || !t.isScheduledOn(d)) continue;
        if (dayDone(t, dk) || freezes <= 0) continue;
        final before =
            computeStreak(t, comps, frozen[t.id] ?? <String>{}, d).current;
        if (before > 0) {
          frozen.putIfAbsent(t.id, () => <String>{}).add(dk);
          freezes--;
          changed = true;
        }
      }
      d = addDays(d, 1);
    }
    snoozes.removeWhere(
        (k, v) => v < DateTime.now().millisecondsSinceEpoch - 86400000);
    settledThrough = yKey;
    return changed || old != yKey;
  }

  // ------------------------------------------------------------------ tasks
  Future<void> saveTask(TaskItem t) async {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      tasks[i] = t;
    } else {
      tasks.add(t);
    }
    await _commit();
  }

  void _removeTaskData(String id) {
    tasks.removeWhere((t) => t.id == id);
    comps.removeWhere((k, v) => v.taskId == id);
    frozen.remove(id);
    snoozes.removeWhere((k, v) => k.startsWith('$id|'));
  }

  Future<void> deleteTask(TaskItem t) async {
    _removeTaskData(t.id);
    if (t.planId != null) plans.removeWhere((p) => p.id == t.planId);
    await _commit();
  }

  // ------------------------------------------------------------ completions
  Future<void> complete(TaskItem t, String dk, int slot,
      {String source = 'tap'}) async {
    final wasDone = dayDone(t, dk);
    final k = occKey(t.id, dk, slot);
    comps[k] = Completion(
      taskId: t.id,
      dateKey: dk,
      slot: slot,
      status: 'done',
      ts: DateTime.now().millisecondsSinceEpoch,
      source: source,
    );
    snoozes.remove(k);
    if (!wasDone && dayDone(t, dk) && t.hasStreak) {
      final s = streakFor(t).current;
      if (s > 0 && s % 7 == 0 && freezes < 3)
        freezes++; // earn a freeze every 7 days
    }
    if (t.planId != null) planById(t.planId)?.markNextDone();
    await _commit();
  }

  Future<void> skip(TaskItem t, String dk, int slot) async {
    final k = occKey(t.id, dk, slot);
    comps[k] = Completion(
      taskId: t.id,
      dateKey: dk,
      slot: slot,
      status: 'skipped',
      ts: DateTime.now().millisecondsSinceEpoch,
      source: 'tap',
    );
    snoozes.remove(k);
    await _commit();
  }

  Future<void> undo(TaskItem t, String dk, int slot) async {
    comps.remove(occKey(t.id, dk, slot));
    await _commit();
  }

  /// Manual correction from the history screen (kept in the audit log).
  Future<void> setDayManual(TaskItem t, String dk, bool done) async {
    for (var i = 0; i < t.times.length; i++) {
      final k = occKey(t.id, dk, i);
      if (done) {
        comps[k] = Completion(
          taskId: t.id,
          dateKey: dk,
          slot: i,
          status: 'done',
          ts: DateTime.now().millisecondsSinceEpoch,
          source: 'manual',
        );
      } else {
        comps.remove(k);
      }
    }
    await _commit();
  }

  Future<void> snooze(TaskItem t, String dk, int slot, int minutes,
      {DateTime? until}) async {
    final when = until ?? DateTime.now().add(Duration(minutes: minutes));
    snoozes[occKey(t.id, dk, slot)] = when.millisecondsSinceEpoch;
    await _commit();
  }

  Future<void> cancelSnooze(TaskItem t, String dk, int slot) async {
    if (snoozes.remove(occKey(t.id, dk, slot)) != null) {
      await _commit();
    }
  }

  /// Notification action buttons (works from the background isolate too).
  Future<void> handleAction(ReminderPayload p, String action) async {
    final t = taskById(p.taskId);
    if (t == null) return;
    switch (action) {
      case 'done':
        await complete(t, p.dateKey, p.slot, source: 'notification');
        break;
      case 'snooze':
        await snooze(t, p.dateKey, p.slot, t.snoozeMinutes);
        break;
      case 'skip':
        await skip(t, p.dateKey, p.slot);
        break;
    }
  }

  // ------------------------------------------------------------ study plans
  Future<void> addPlan(StudyPlan plan, TaskItem task) async {
    plans.add(plan);
    tasks.add(task);
    await _commit();
  }

  Future<void> deletePlan(StudyPlan p) async {
    plans.removeWhere((e) => e.id == p.id);
    _removeTaskData(p.taskId);
    await _commit();
  }

  Future<void> togglePoint(StudyPoint pt) async {
    pt.done = !pt.done;
    await _commit(resched: false);
  }

  Future<void> completeStudyToday(StudyPlan p) async {
    final t = taskById(p.taskId);
    if (t == null) return;
    await complete(t, dateKey(DateTime.now()), 0);
  }

  /// Catch-up: re-date every unfinished day starting today. Finished work is untouched.
  Future<void> catchUp(StudyPlan p) async {
    var d = dayOnly(DateTime.now());
    var any = false;
    for (final day in p.days) {
      if (day.done) continue;
      day.dateKey = dateKey(d);
      d = addDays(d, 1);
      any = true;
    }
    final t = taskById(p.taskId);
    if (any && t != null) t.endDate = addDays(d, -1);
    await _commit();
  }

  // --------------------------------------------------------------- settings
  Future<void> updateSettings(void Function(AppSettings s) f,
      {bool resched = true}) async {
    f(settings);
    await _commit(resched: resched);
  }
}
