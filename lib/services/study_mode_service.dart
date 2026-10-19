import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppInfo {
  final String pkg;
  final String label;
  const AppInfo(this.pkg, this.label);
}

/// Bridge to the native Android study-mode blocker (see StudyBlockService.kt).
/// Every call is wrapped so a missing permission or native error can never
/// crash the app.
class StudyModeService {
  static const MethodChannel _ch = MethodChannel('consistiq/study_mode');
  static List<AppInfo>? _cache;

  static Future<bool> _b(String method) async {
    try {
      return (await _ch.invokeMethod<bool>(method)) ?? false;
    } catch (e) {
      debugPrint('StudyModeService.$method failed: $e');
      return false;
    }
  }

  static Future<bool> hasUsageAccess() => _b('hasUsageAccess');
  static Future<bool> hasOverlay() => _b('hasOverlay');
  static Future<bool> hasDnd() => _b('hasDnd');
  static Future<void> openUsageAccess() async {
    await _b('openUsageAccess');
  }

  static Future<void> openOverlay() async {
    await _b('openOverlay');
  }

  static Future<void> openDnd() async {
    await _b('openDnd');
  }

  /// endMillis = 0 means "until I stop it". Returns false if it failed.
  static Future<bool> start(
      List<String> allowed, int endMillis, bool silent) async {
    try {
      await _ch.invokeMethod(
          'start', {'allowed': allowed, 'end': endMillis, 'silent': silent});
      return true;
    } catch (e) {
      debugPrint('StudyModeService.start failed: $e');
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      await _ch.invokeMethod('stop');
      return true;
    } catch (e) {
      debugPrint('StudyModeService.stop failed: $e');
      return false;
    }
  }

  static Future<({bool active, int end})> status() async {
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('status');
      if (r == null) return (active: false, end: 0);
      return (
        active: (r['active'] ?? false) as bool,
        end: ((r['end'] ?? 0) as num).toInt()
      );
    } catch (e) {
      debugPrint('StudyModeService.status failed: $e');
      return (active: false, end: 0);
    }
  }

  /// Installed launchable apps. Cached after the first load.
  static Future<List<AppInfo>> installedApps({bool refresh = false}) async {
    if (_cache != null && !refresh) return _cache!;
    try {
      final r = await _ch.invokeListMethod<Map>('installedApps');
      final list = (r ?? [])
          .map((m) => AppInfo(m['pkg'] as String, m['label'] as String))
          .toList();
      _cache = list;
      return list;
    } catch (e) {
      debugPrint('StudyModeService.installedApps failed: $e');
      return _cache ?? const [];
    }
  }

  static List<AppInfo> get cachedApps => _cache ?? const [];

  static String labelFor(String pkg) {
    for (final a in cachedApps) {
      if (a.pkg == pkg) return a.label;
    }
    return pkg;
  }
}
