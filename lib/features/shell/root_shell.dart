import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/routes.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/task_item.dart';
import '../../core/widgets/glass_background.dart';
import '../../core/widgets/glass_container.dart';
import '../../services/home_widget_service.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../alarm/alarm_ring_screen.dart';
import '../history/history_screen.dart';
import '../reminder/reminder_screen.dart';
import '../settings/settings_screen.dart';
import '../study/study_mode_screen.dart';
import '../tasks/routines_screen.dart';
import '../tasks/task_editor_screen.dart';
import '../today/today_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _i = 0;
  final Set<int> _visited = {0}; // tabs are built lazily, on first visit
  final Set<String> _ringShown = {};
  bool _ringOpen = false;
  StreamSubscription<ReminderPayload>? _sub;
  StreamSubscription<Uri?>? _widgetSub;
  Timer? _poll;

  static const _tabs = <(IconData, String)>[
    (Icons.today_rounded, 'Today'),
    (Icons.checklist_rounded, 'Routines'),
    (Icons.school_rounded, 'Study'),
    (Icons.local_fire_department_rounded, 'Streaks'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = NotificationService.instance.taps.listen(_open);
    _widgetSub = HomeWidget.widgetClicked.listen(_handleWidgetClick);
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_handleWidgetClick)
        .catchError((Object error) {
      debugPrint('Could not read initial home widget action: $error');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      unawaited(
          HomeWidgetService.sync(state.tasks, state.comps).catchError((e) {
        debugPrint('Home widget startup sync failed: $e');
      }));
      final p = NotificationService.instance.pending;
      if (p != null) _open(p);
    });
    _startPolling();
  }

  void _startPolling() {
    if (_poll != null ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      context.read<AppState>().refreshFromDisk().catchError((Object e) {
        debugPrint('Refresh failed: $e');
      });
      _checkAlarms();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      context.read<AppState>().refreshFromDisk().then((_) {
        if (mounted) _checkAlarms();
      }).catchError((Object e) {
        debugPrint('Resume refresh failed: $e');
      });
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _widgetSub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _open(ReminderPayload p) async {
    if (!mounted) return;
    NotificationService.instance.clearPending();
    if (_ringOpen) return;
    final t = context.read<AppState>().taskById(p.taskId);
    final alarm = t != null && t.alarmStyle && p.slot < t.times.length;
    _ringOpen = true;
    try {
      await Navigator.of(context).push(fadeRoute<void>(
        alarm ? AlarmRingScreen(payload: p) : ReminderScreen(payload: p),
      ));
    } finally {
      _ringOpen = false;
    }
  }

  /// In-app alarm: when the app is open and an alarm time arrives, show the
  /// full-screen alarm right away (the notification still rings too).
  void _checkAlarms() {
    if (!mounted || _ringOpen) return;
    final st = context.read<AppState>();
    if (!st.settings.notificationsOn) return;
    final now = DateTime.now();
    for (final o in st.occurrencesOn(now)) {
      final t = o.task;
      if (o.c != null || !t.alarmStyle || !t.notify) continue;
      final k = occKey(t.id, o.dateKey, o.slot);
      final snooze = st.snoozes[k];
      final ringAt =
          snooze != null ? DateTime.fromMillisecondsSinceEpoch(snooze) : o.due;
      final tag = snooze != null ? '$k|s$snooze' : k;
      final age = now.difference(ringAt).inSeconds;
      if (age >= 0 && age < 120 && _ringShown.add(tag)) {
        _open(ReminderPayload(t.id, o.dateKey, o.slot));
        return;
      }
    }
  }

  void _handleWidgetClick(Uri? uri) {
    if (!mounted || uri == null || uri.host != 'widget') return;
    if (uri.path == '/add-task') {
      Navigator.of(context).push(fadeRoute(
        const TaskEditorScreen(kind: TaskKind.task),
      ));
    } else if (uri.path == '/today') {
      setState(() => _i = 0);
    }
  }

  Widget _screen(int n) {
    if (!_visited.contains(n)) return const SizedBox.shrink();
    switch (n) {
      case 0:
        return const TodayScreen();
      case 1:
        return const RoutinesScreen();
      case 2:
        return StudyModeScreen(visible: _i == 2);
      case 3:
        return const HistoryScreen();
      default:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Scaffold(
      extendBody: true,
      body: GlassBackground(
        child: IndexedStack(
          index: _i,
          children: [for (var n = 0; n < _tabs.length; n++) _screen(n)],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassContainer(
            radius: 30,
            blur: 20,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var n = 0; n < _tabs.length; n++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_i == n) return;
                        HapticFeedback.selectionClick();
                        setState(() {
                          _i = n;
                          _visited.add(n);
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                            horizontal: _i == n ? 14 : 10, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: _i == n
                              ? AppTheme.blue.withValues(alpha: 0.28)
                              : Colors.transparent,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_tabs[n].$1,
                              size: 24, color: _i == n ? g.text : g.subText),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            child: _i == n
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text(_tabs[n].$2,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: g.text)),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ]),
                      ),
                    ),
                ]),
          ),
        ),
      ),
    );
  }
}
