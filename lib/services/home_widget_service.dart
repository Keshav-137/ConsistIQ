import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../core/utils/time_utils.dart';
import '../data/models/task_item.dart';

class HomeWidgetService {
  static const _quickAdd = 'com.example.app.widgets.QuickAddWidgetProvider';
  static const _today = 'com.example.app.widgets.TodayWidgetProvider';
  static const _progress = 'com.example.app.widgets.ProgressWidgetProvider';

  static Future<void> sync(
      List<TaskItem> tasks, Map<String, Completion> completions) async {
    if (!Platform.isAndroid) return;

    final today = dayOnly(DateTime.now());
    final dayKey = dateKey(today);
    final occurrences = <({TaskItem task, int slot, bool done})>[];
    for (final task in tasks) {
      if (task.archived || !task.isScheduledOn(today)) continue;
      for (var slot = 0; slot < task.times.length; slot++) {
        occurrences.add((
          task: task,
          slot: slot,
          done: completions[occKey(task.id, dayKey, slot)]?.status == 'done',
        ));
      }
    }

    final done = occurrences.where((item) => item.done).length;
    final remaining = occurrences
        .where((item) => !item.done)
        .take(4)
        .map((item) => '${item.task.kind.label}: ${item.task.title}')
        .toList();

    await _save('today_tasks', jsonEncode(remaining));
    await _save('today_done', '$done');
    await _save('today_total', '${occurrences.length}');

    for (final provider in [_quickAdd, _today, _progress]) {
      await HomeWidget.updateWidget(androidName: provider);
    }
  }

  static Future<void> _save(String key, String value) async {
    final saved = await HomeWidget.saveWidgetData<String>(key, value);
    if (saved != true) {
      throw StateError('Could not save $key for Android home-screen widgets.');
    }
  }
}
