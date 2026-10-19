import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await NotificationService.instance.init();
  final state = AppState();
  await state.load();
  unawaited(state.reschedule());
  runApp(ChangeNotifierProvider.value(value: state, child: const ConsistIQApp()));
}

class ConsistIQApp extends StatefulWidget {
  const ConsistIQApp({super.key});

  @override
  State<ConsistIQApp> createState() => _ConsistIQAppState();
}

class _ConsistIQAppState extends State<ConsistIQApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final s = context.read<AppState>();
      s.refreshFromDisk().then((_) => s.reschedule());
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, int>((s) => s.settings.themeMode);
    return MaterialApp(
      title: AppConfig.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.values[mode.clamp(0, 2)],
      home: const SplashScreen(),
    );
  }
}
