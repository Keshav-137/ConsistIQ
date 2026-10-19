import 'package:flutter/services.dart';

class AppInfo {
  final String pkg;
  final String label;
  const AppInfo(this.pkg, this.label);
}

/// Bridge to the native Android study-mode blocker (see StudyBlockService.kt).
class StudyModeService {
  static const MethodChannel _ch = MethodChannel('consistiq/study_mode');

  static Future<bool> _b(String method) async =>
      (await _ch.invokeMethod<bool>(method)) ?? false;

  static Future<bool> hasUsageAccess() => _b('hasUsageAccess');
  static Future<bool> hasOverlay() => _b('hasOverlay');
  static Future<bool> hasDnd() => _b('hasDnd');
  static Future<void> openUsageAccess() async {
    await _ch.invokeMethod<bool>('openUsageAccess');
  }

  static Future<void> openOverlay() async {
    await _ch.invokeMethod<bool>('openOverlay');
  }

  static Future<void> openDnd() async {
    await _ch.invokeMethod<bool>('openDnd');
  }

  /// endMillis = 0 means "until I stop it".
  static Future<void> start(
      List<String> allowed, int endMillis, bool silent) async {
    await _ch.invokeMethod(
        'start', {'allowed': allowed, 'end': endMillis, 'silent': silent});
  }

  static Future<void> stop() async {
    await _ch.invokeMethod('stop');
  }

  static Future<({bool active, int end})> status() async {
    final r = await _ch.invokeMapMethod<String, dynamic>('status');
    if (r == null) return (active: false, end: 0);
    return (
      active: (r['active'] ?? false) as bool,
      end: ((r['end'] ?? 0) as num).toInt()
    );
  }

  static Future<List<AppInfo>> installedApps() async {
    final r = await _ch.invokeListMethod<Map>('installedApps');
    return (r ?? [])
        .map((m) => AppInfo(m['pkg'] as String, m['label'] as String))
        .toList();
  }
}
