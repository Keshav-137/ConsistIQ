import 'package:flutter/services.dart';

class AppInfo {
  final String pkg;
  final String label;
  const AppInfo(this.pkg, this.label);
}

/// Bridge to the native Android study-mode blocker (see StudyBlockService.kt).
class StudyModeService {
  static const MethodChannel _ch = MethodChannel('consistiq/study_mode');

  static Future<bool> _b(String m) async {
    try {
      return (await _ch.invokeMethod<bool>(m)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasUsageAccess() => _b('hasUsageAccess');
  static Future<bool> hasOverlay() => _b('hasOverlay');
  static Future<bool> hasDnd() => _b('hasDnd');
  static Future<void> openUsageAccess() => _b('openUsageAccess');
  static Future<void> openOverlay() => _b('openOverlay');
  static Future<void> openDnd() => _b('openDnd');

  /// endMillis = 0 means "until I stop it".
  static Future<void> start(List<String> allowed, int endMillis, bool silent) async {
    await _ch.invokeMethod('start', {'allowed': allowed, 'end': endMillis, 'silent': silent});
  }

  static Future<void> stop() async {
    await _ch.invokeMethod('stop');
  }

  static Future<({bool active, int end})> status() async {
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('status');
      if (r == null) return (active: false, end: 0);
      return (active: (r['active'] ?? false) as bool, end: ((r['end'] ?? 0) as num).toInt());
    } catch (_) {
      return (active: false, end: 0);
    }
  }

  static Future<List<AppInfo>> installedApps() async {
    try {
      final r = await _ch.invokeListMethod<Map>('installedApps');
      return (r ?? [])
          .map((m) => AppInfo(m['pkg'] as String, m['label'] as String))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
