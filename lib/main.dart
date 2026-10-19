import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/motion.dart';
import 'features/splash/splash_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Never let an unexpected error close the app.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Unhandled error: $error');
      return true;
    };
    if (kReleaseMode) {
      ErrorWidget.builder = (details) => const SizedBox.shrink();
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }

    final state = AppState();
    try {
      await state.load();
    } catch (e) {
      debugPrint('Loading saved data failed: $e');
    }
    unawaited(state.reschedule());

    runApp(ChangeNotifierProvider.value(
      value: state,
      child: const ConsistIQApp(),
    ));
  }, (error, stack) => debugPrint('Zone error: $error'));
}

class ConsistIQApp extends StatefulWidget {
  const ConsistIQApp({super.key});

  @override
  State<ConsistIQApp> createState() => _ConsistIQAppState();
}

class _ConsistIQAppState extends State<ConsistIQApp>
    with WidgetsBindingObserver {
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
      s.refreshFromDisk().then((_) => s.reschedule()).catchError((Object e) {
        debugPrint('Resume refresh failed: $e');
      });
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
      scrollBehavior: const SmoothScrollBehavior(),
      builder: (context, child) {
        // Keeps layouts from overflowing when the phone font size is huge.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
