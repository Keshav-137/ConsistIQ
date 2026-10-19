import 'package:flutter_test/flutter_test.dart';
import 'package:consistiq/data/models/app_settings.dart';
import 'package:consistiq/data/models/task_item.dart';

void main() {
  group('alarm settings persistence', () {
    test('loads defaults for settings saved by older app versions', () {
      final settings = AppSettings.fromJson({
        'notif': true,
        'theme': 0,
        'lock': false,
        'key': '',
        'model': 'gemini-2.5-flash',
        'apps': <String>[],
        'silent': true,
      });

      expect(settings.defaultSnoozeMinutes, 10);
      expect(settings.defaultReminderMinutes, 15);
      expect(settings.defaultAlarmStyle, isFalse);
      expect(settings.alarmVibration, isTrue);
      expect(settings.alarmSoundUri, isEmpty);
      expect(settings.displayName, isEmpty);
      expect(settings.profileSetupComplete, isFalse);
      expect(settings.lockTimeoutSeconds, 20);
    });

    test('round-trips user alarm preferences', () {
      final settings = AppSettings(
        defaultSnoozeMinutes: 30,
        defaultReminderMinutes: 60,
        defaultAlarmStyle: true,
        alarmVibration: false,
        alarmSoundUri: 'content://settings/system/alarm_alert',
        displayName: 'Alex',
        profileSetupComplete: true,
        lockTimeoutSeconds: 300,
      );

      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.defaultSnoozeMinutes, 30);
      expect(restored.defaultReminderMinutes, 60);
      expect(restored.defaultAlarmStyle, isTrue);
      expect(restored.alarmVibration, isFalse);
      expect(restored.alarmSoundUri, settings.alarmSoundUri);
      expect(restored.displayName, 'Alex');
      expect(restored.profileSetupComplete, isTrue);
      expect(restored.lockTimeoutSeconds, 300);
    });

    test('uses the safe default for an invalid saved lock timeout', () {
      final settings = AppSettings.fromJson({
        'lockTimeout': -1,
      });

      expect(settings.lockTimeoutSeconds, 20);
    });

    test('falls back when saved lock timeout has the wrong type', () {
      final settings = AppSettings.fromJson({
        'lockTimeout': '30',
      });

      expect(settings.lockTimeoutSeconds, 20);
    });
  });

  test('round-trips task timing choice', () {
    final start = DateTime(2026, 10, 19);
    final task = TaskItem(
      id: 'task-id',
      title: 'Submit assignment',
      kind: TaskKind.task,
      timing: TaskTiming.completeBy,
      repeat: RepeatMode.once,
      startDate: start,
      times: [TaskTime('Complete by', 18, 30)],
    );

    final restored = TaskItem.fromJson(task.toJson());

    expect(restored.kind, TaskKind.task);
    expect(restored.timing, TaskTiming.completeBy);
    expect(restored.startDate, start);
    expect(restored.times.single.hour, 18);
    expect(restored.times.single.minute, 30);
  });
}
