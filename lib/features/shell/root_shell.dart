import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/routes.dart';
import '../../data/models/task_item.dart';
import '../../core/widgets/glass_background.dart';
import '../../core/widgets/glass_container.dart';
import '../../services/home_widget_service.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
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

class _RootShellState extends State<RootShell> {
  int _i = 0;
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
    _sub = NotificationService.instance.taps.listen(_open);
    _widgetSub = HomeWidget.widgetClicked.listen(_handleWidgetClick);
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_handleWidgetClick)
        .catchError((Object error) {
      debugPrint('Could not read initial home widget action: $error');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      unawaited(HomeWidgetService.sync(state.tasks, state.comps).catchError((e) {
        debugPrint('Home widget startup sync failed: $e');
      }));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = NotificationService.instance.pending;
      if (p != null) _open(p);
    });
    // Pick up completions made from notification buttons.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) context.read<AppState>().refreshFromDisk();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _widgetSub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  void _open(ReminderPayload p) {
    if (!mounted) return;
    NotificationService.instance.clearPending();
    Navigator.of(context).push(fadeRoute(ReminderScreen(payload: p)));
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

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Scaffold(
      extendBody: true,
      body: GlassBackground(
        child: IndexedStack(index: _i, children: const [
          TodayScreen(),
          RoutinesScreen(),
          StudyModeScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassContainer(
            radius: 30,
            blur: 28,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var n = 0; n < _tabs.length; n++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _i = n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
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
