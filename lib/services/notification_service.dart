import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/time_utils.dart';
import '../data/models/app_settings.dart';
import '../data/models/task_item.dart';
import 'home_widget_service.dart';
import '../state/app_state.dart';

class ReminderPayload {
  final String taskId;
  final String dateKey;
  final int slot;
  const ReminderPayload(this.taskId, this.dateKey, this.slot);

  String encode() => jsonEncode({'t': taskId, 'd': dateKey, 's': slot});

  static ReminderPayload? tryParse(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return ReminderPayload(m['t'] as String, m['d'] as String, m['s'] as int);
    } catch (_) {
      return null;
    }
  }
}

/// Runs in a background isolate when a notification action button
/// (Taken / Done / Snooze) is pressed while the app is closed.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  final p = ReminderPayload.tryParse(r.payload);
  final a = r.actionId;
  if (p == null || a == null || a.isEmpty || a == 'later') return;
  await NotificationService.instance.init(background: true);
  final s = AppState(background: true);
  await s.load();
  await s.handleAction(p, a);
  try {
    await HomeWidgetService.sync(s.tasks, s.comps);
  } catch (e) {
    debugPrint('Home widget refresh after notification action failed: $e');
  }
}

class _Planned {
  final int id;
  final DateTime when;
  final TaskItem task;
  final int slot;
  final String phase; // pre | due | nag
  final ReminderPayload payload;
  final int mins;
  _Planned(this.id, this.when, this.task, this.slot, this.phase, this.payload, {this.mins = 0});
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static const MethodChannel _alarmChannel = MethodChannel('consistiq/alarms');

  static const int windowDays = 10;
  static const int maxScheduled = 400;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<ReminderPayload> _taps = StreamController.broadcast();
  Stream<ReminderPayload> get taps => _taps.stream;
  ReminderPayload? pending;
  bool _inited = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init({bool background = false}) async {
    if (_inited) return;
    _inited = true;
    tzdata.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: background ? null : _onResponse,
      onDidReceiveBackgroundNotificationResponse: background ? null : notificationTapBackground,
    );
    if (!background) {
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp == true) {
        final p = ReminderPayload.tryParse(d!.notificationResponse?.payload);
        if (p != null) pending = p;
      }
    }
    final a = _android;
    await a?.createNotificationChannel(const AndroidNotificationChannel(
      'consistiq_reminder',
      'Reminders',
      description: 'Task, medicine and deadline reminders',
      importance: Importance.max,
    ));
  }

  void _onResponse(NotificationResponse r) {
    final p = ReminderPayload.tryParse(r.payload);
    if (p == null) return;
    pending = p;
    _taps.add(p);
  }

  void clearPending() => pending = null;

  Future<void> requestPermissions() async {
    final a = _android;
    await a?.requestNotificationsPermission();
    final exact = (await a?.canScheduleExactNotifications()) ?? true;
    if (!exact) await a?.requestExactAlarmsPermission();
    await a?.requestFullScreenIntentPermission();
    await Permission.ignoreBatteryOptimizations.request();
  }

  int _hash(String s) {
    var h = 0x811C9DC5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h & 0x7FFFFFFF;
  }

  int _nid(String taskId, String dk, int slot, int type) => _hash('$taskId|$dk|$slot|$type');

  /// Stops the ringing/visible notification for an occurrence (keeps later follow-ups).
  Future<void> silence(ReminderPayload p) async {
    for (final type in [0, 1, 2, 3, 4, 10, 30]) {
      await _plugin.cancel(_nid(p.taskId, p.dateKey, p.slot, type));
    }
  }

  Future<void> showTest({bool alarm = false, AppSettings? settings}) async {
    final prefs = settings ?? AppSettings();
    if (alarm) await _ensureAlarmChannel(prefs);
    final body = alarm
        ? 'This is how a full-screen alarm reminder looks.'
        : 'Reminders from ConsistIQ will look like this.';
    await _plugin.show(
      999001,
      alarm ? 'Test alarm' : 'Test reminder',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          alarm ? _alarmChannelId(prefs) : 'consistiq_reminder',
          alarm ? 'Alarms' : 'Reminders',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: alarm,
          category: alarm ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
          audioAttributesUsage: alarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
          sound: alarm && prefs.alarmSoundUri.isNotEmpty
              ? UriAndroidNotificationSound(prefs.alarmSoundUri)
              : null,
          enableVibration: !alarm || prefs.alarmVibration,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<String?> pickAlarmSound({required String currentUri}) async =>
      _alarmChannel.invokeMethod<String>(
        'pickAlarmSound',
        {'currentUri': currentUri},
      );

  /// Rebuilds every upcoming reminder from scratch. Completed occurrences get
  /// no reminders; active snoozes are preserved.
  Future<void> rescheduleAll(
    List<TaskItem> tasks,
    Map<String, Completion> comps,
    Map<String, int> snoozes,
    AppSettings settings,
  ) async {
    await _plugin.cancelAll();
    if (!settings.notificationsOn) return;
    await _ensureAlarmChannel(settings);
    final exact = (await _android?.canScheduleExactNotifications()) ?? false;
    final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

    final now = DateTime.now();
    final today = dayOnly(now);
    final list = <_Planned>[];

    for (final t in tasks) {
      if (t.archived || !t.notify) continue;
      for (var off = -1; off < windowDays; off++) {
        final day = addDays(today, off);
        if (!t.isScheduledOn(day)) continue;
        final dk = dateKey(day);
        for (var i = 0; i < t.times.length; i++) {
          final k = occKey(t.id, dk, i);
          if (comps.containsKey(k)) continue; // done or skipped: no reminders
          final tt = t.times[i];
          final due = DateTime(day.year, day.month, day.day, tt.hour, tt.minute);
          final payload = ReminderPayload(t.id, dk, i);
          final sn = snoozes[k];
          if (sn != null) {
            list.add(_Planned(_nid(t.id, dk, i, 30), DateTime.fromMillisecondsSinceEpoch(sn), t, i, 'due', payload));
          }
          if (off < 0) continue; // yesterday: only keep snoozes
          for (var j = 0; j < t.remindBefore.length && j < 5; j++) {
            final m = t.remindBefore[j];
            list.add(_Planned(_nid(t.id, dk, i, j), due.subtract(Duration(minutes: m)), t, i, 'pre', payload, mins: m));
          }
          list.add(_Planned(_nid(t.id, dk, i, 10), due, t, i, 'due', payload));
          for (var n = 1; n <= t.nagCount && n <= 5; n++) {
            list.add(_Planned(_nid(t.id, dk, i, 20 + n), due.add(Duration(minutes: t.followUpMinutes * n)), t, i, 'nag', payload));
          }
        }
      }
    }

    final limit = now.add(const Duration(seconds: 3));
    list.removeWhere((p) => !p.when.isAfter(limit));
    list.sort((a, b) => a.when.compareTo(b.when));

    for (final p in list.take(maxScheduled)) {
      final text = _text(p);
      try {
        await _plugin.zonedSchedule(
          p.id,
          text.$1,
          text.$2,
          tz.TZDateTime.from(p.when, tz.local),
          _details(p.task, p.phase, text.$2, settings),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: p.payload.encode(),
        );
      } catch (e) {
        debugPrint('schedule failed: $e');
      }
    }
  }

  (String, String) _text(_Planned p) {
    final t = p.task;
    final tt = t.times[p.slot];
    final at = fmtHm(tt.hour, tt.minute);
    final med = t.kind == TaskKind.medicine;
    switch (p.phase) {
      case 'pre':
        final m = p.mins;
        final left = m >= 60 && m % 60 == 0 ? '${m ~/ 60} hr' : '$m min';
        return (
          med ? 'Medicine soon: ${t.title}' : 'Coming up: ${t.title}',
          'Due at $at, $left to go.${t.dose.isNotEmpty ? ' ${t.dose}.' : ''}'
        );
      case 'nag':
        return (
          'Still pending: ${t.title}',
          med
              ? 'Have you taken ${t.title}? Tap Taken, Snooze, or Not yet.'
              : 'Not marked done yet. Your streak is at risk!'
        );
      default:
        final title = switch (t.kind) {
          TaskKind.medicine => 'Time for ${t.title}',
          TaskKind.deadline => 'Deadline now: ${t.title}',
          TaskKind.meeting => 'Meeting: ${t.title}',
          TaskKind.study => 'Study time: ${t.title}',
          TaskKind.task => t.timing == TaskTiming.completeBy
              ? 'Complete by: ${t.title}'
              : 'Task reminder: ${t.title}',
          TaskKind.habit => 'Time for: ${t.title}',
        };
        final lab = tt.label.isNotEmpty && t.times.length > 1 ? '${tt.label}. ' : '';
        final dose = t.dose.isNotEmpty ? '${t.dose}. ' : '';
        return (title, med ? '$dose${lab}Have you taken it?' : 'Tap Done when finished, or snooze.');
    }
  }

  String _alarmChannelId(AppSettings settings) =>
      'consistiq_alarm_${_hash(settings.alarmSoundUri)}_${settings.alarmVibration ? 1 : 0}';

  Future<void> _ensureAlarmChannel(AppSettings settings) async {
    final soundUri = settings.alarmSoundUri;
    await _android?.createNotificationChannel(AndroidNotificationChannel(
      _alarmChannelId(settings),
      'Alarms',
      description: 'Full-screen task alarms',
      importance: Importance.max,
      playSound: true,
      sound: soundUri.isEmpty ? null : UriAndroidNotificationSound(soundUri),
      enableVibration: settings.alarmVibration,
      vibrationPattern: settings.alarmVibration
          ? Int64List.fromList(<int>[0, 350, 250, 350])
          : null,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
  }

  NotificationDetails _details(
      TaskItem t, String phase, String body, AppSettings settings) {
    final alarm = t.alarmStyle && phase != 'pre';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        alarm ? _alarmChannelId(settings) : 'consistiq_reminder',
        alarm ? 'Alarms' : 'Reminders',
        importance: Importance.max,
        priority: Priority.high,
        category: alarm ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        fullScreenIntent: alarm,
        ongoing: alarm,
        autoCancel: !alarm,
        audioAttributesUsage: alarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        sound: alarm && settings.alarmSoundUri.isNotEmpty
            ? UriAndroidNotificationSound(settings.alarmSoundUri)
            : null,
        enableVibration: !alarm || settings.alarmVibration,
        vibrationPattern: alarm && settings.alarmVibration
            ? Int64List.fromList(<int>[0, 350, 250, 350])
            : null,
        additionalFlags: alarm ? Int32List.fromList(<int>[4]) : null, // FLAG_INSISTENT
        styleInformation: BigTextStyleInformation(body),
        icon: '@mipmap/ic_launcher',
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('done', t.kind == TaskKind.medicine ? 'Taken' : 'Done'),
          AndroidNotificationAction('snooze', 'Snooze ${t.snoozeMinutes}m'),
          const AndroidNotificationAction('later', 'Not yet', showsUserInterface: true),
        ],
      ),
    );
  }
}
