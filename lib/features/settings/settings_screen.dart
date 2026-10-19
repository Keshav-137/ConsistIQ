import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/routes.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/app_settings.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import 'calendar_import_screen.dart';
import 'gmail_import_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _name = TextEditingController();
  final _key = TextEditingController();
  final _model = TextEditingController();
  bool _init = false;
  bool _testingNotification = false;

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _saveName(AppState state) async {
    final name = _name.text.trim();
    await state.updateSettings((settings) {
      settings.displayName = name;
      settings.profileSetupComplete = true;
    }, resched: false);
    if (mounted) toast(context, 'Name updated');
  }

  Future<void> _testNotification({
    required bool alarm,
    required AppSettings settings,
  }) async {
    if (_testingNotification) return;
    setState(() => _testingNotification = true);
    try {
      await NotificationService.instance.showTest(
        alarm: alarm,
        settings: settings,
      );
      if (mounted) {
        toast(
          context,
          alarm
              ? 'Test alarm sent. Check your notification shade.'
              : 'Test reminder sent. Check your notification shade.',
        );
      }
    } catch (error) {
      debugPrint('Could not send test notification: $error');
      if (mounted) {
        toast(
          context,
          error is StateError
              ? error.message.toString()
              : 'Could not send the test notification: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _testingNotification = false);
    }
  }

  Widget _card(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(title),
            ...children,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final g = context.glass;
    final s = st.settings;
    if (!_init) {
      _name.text = s.displayName;
      _key.text = s.geminiKey;
      _model.text = s.geminiModel;
      _init = true;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
        children: [
          const ScreenHeader(title: 'Settings'),
          _card('Your profile', [
            Text(
              'Your name is saved only on this device and is used for your dashboard greeting.',
              style: TextStyle(fontSize: 12.5, color: g.subText),
            ),
            const SizedBox(height: 12),
            GlassField(
              controller: _name,
              label: 'Your name (optional)',
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 10),
            GlassButton(
              label: 'Save name',
              icon: Icons.person_outline_rounded,
              compact: true,
              onTap: () => _saveName(st),
            ),
          ]),
          _card('Appearance', [
            Wrap(spacing: 8, children: [
              GlassChip(
                  label: 'System',
                  icon: Icons.brightness_auto_rounded,
                  selected: s.themeMode == 0,
                  onTap: () => st.updateSettings((x) => x.themeMode = 0,
                      resched: false)),
              GlassChip(
                  label: 'Light',
                  icon: Icons.light_mode_rounded,
                  selected: s.themeMode == 1,
                  onTap: () => st.updateSettings((x) => x.themeMode = 1,
                      resched: false)),
              GlassChip(
                  label: 'Dark',
                  icon: Icons.dark_mode_rounded,
                  selected: s.themeMode == 2,
                  onTap: () => st.updateSettings((x) => x.themeMode = 2,
                      resched: false)),
            ]),
          ]),
          _card('Notifications and alarms', [
            SwitchRow(
              icon: Icons.notifications_active_rounded,
              title: 'Reminders',
              subtitle: 'Master switch for all reminders',
              value: s.notificationsOn,
              onChanged: (v) => st.updateSettings((x) => x.notificationsOn = v),
            ),
            const SizedBox(height: 12),
            GlassButton(
              label: 'Grant alarm and notification permissions',
              icon: Icons.verified_user_rounded,
              compact: true,
              onTap: () => NotificationService.instance.requestPermissions(),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: GlassButton(
                  label: _testingNotification ? 'Sending...' : 'Test reminder',
                  compact: true,
                  onTap: _testingNotification
                      ? null
                      : () => _testNotification(alarm: false, settings: s),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  label: _testingNotification ? 'Sending...' : 'Test alarm',
                  compact: true,
                  color: AppTheme.red,
                  onTap: _testingNotification
                      ? null
                      : () => _testNotification(alarm: true, settings: s),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              'Tip: on Xiaomi, Oppo, Vivo, Samsung etc. set ConsistIQ battery to "Unrestricted" and allow auto-start, '
              'otherwise the phone may delay alarms.',
              style: TextStyle(fontSize: 12, color: g.subText),
            ),
          ]),
          _card('Alarm settings', [
            SwitchRow(
              icon: Icons.vibration_rounded,
              title: 'Vibrate for alarms',
              subtitle: 'Use vibration with alarm notifications',
              value: s.alarmVibration,
              onChanged: (v) => st.updateSettings((x) => x.alarmVibration = v),
            ),
            const SizedBox(height: 10),
            GlassButton(
              label: s.alarmSoundUri.isEmpty
                  ? 'Choose alarm ringtone'
                  : 'Change alarm ringtone',
              icon: Icons.music_note_rounded,
              compact: true,
              onTap: () async {
                final uri = await NotificationService.instance.pickAlarmSound(
                  currentUri: s.alarmSoundUri,
                );
                if (uri != null && context.mounted) {
                  await st.updateSettings((x) => x.alarmSoundUri = uri);
                }
              },
            ),
            const SizedBox(height: 8),
            GlassButton(
              label: 'Use system default ringtone',
              icon: Icons.restart_alt_rounded,
              compact: true,
              onTap: () => st.updateSettings((x) => x.alarmSoundUri = ''),
            ),
            const SizedBox(height: 14),
            Text('Default reminder before a task',
                style: TextStyle(color: g.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final minutes in [0, 5, 15, 30, 60, 120])
                GlassChip(
                  label: minutes == 0
                      ? 'Off'
                      : minutes >= 60
                          ? '${minutes ~/ 60} hr'
                          : '$minutes min',
                  selected: s.defaultReminderMinutes == minutes,
                  onTap: () => st.updateSettings(
                      (x) => x.defaultReminderMinutes = minutes),
                ),
            ]),
            const SizedBox(height: 14),
            Text('Default snooze duration',
                style: TextStyle(color: g.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final minutes in [5, 10, 15, 30, 60])
                GlassChip(
                  label: '$minutes min',
                  selected: s.defaultSnoozeMinutes == minutes,
                  onTap: () => st
                      .updateSettings((x) => x.defaultSnoozeMinutes = minutes),
                ),
            ]),
            const SizedBox(height: 10),
            SwitchRow(
              icon: Icons.alarm_rounded,
              title: 'Use full-screen alarm by default',
              subtitle:
                  'For new tasks and routines; individual items can override it',
              value: s.defaultAlarmStyle,
              onChanged: (v) =>
                  st.updateSettings((x) => x.defaultAlarmStyle = v),
            ),
            const SizedBox(height: 8),
            GlassButton(
              label: 'Test configured alarm',
              icon: Icons.notifications_active_rounded,
              color: AppTheme.red,
              compact: true,
              onTap: _testingNotification
                  ? null
                  : () => _testNotification(alarm: true, settings: s),
            ),
          ]),
          _card('Security', [
            SwitchRow(
              icon: Icons.fingerprint_rounded,
              title: 'App lock',
              subtitle: 'Fingerprint, face or phone PIN',
              value: s.appLock,
              onChanged: (v) async {
                if (v) {
                  if (!await AuthService.isSupported()) {
                    if (context.mounted) {
                      toast(
                          context, 'Set up a screen lock on your phone first');
                    }
                    return;
                  }
                  final ok = await AuthService.authenticate(
                      'Confirm to turn on app lock');
                  if (!ok) return;
                }
                await st.updateSettings((x) => x.appLock = v, resched: false);
              },
            ),
          ]),
          _card('Syllabus AI (free)', [
            Text(
              'Get a free key from aistudio.google.com (Gemini API) and paste it here. '
              'Without a key the offline splitter is used.',
              style: TextStyle(fontSize: 12.5, color: g.subText),
            ),
            const SizedBox(height: 12),
            GlassField(
              controller: _key,
              label: 'Gemini API key',
              obscure: true,
              onChanged: (v) => st.updateSettings((x) => x.geminiKey = v.trim(),
                  resched: false),
            ),
            const SizedBox(height: 10),
            GlassField(
              controller: _model,
              label: 'Model name',
              onChanged: (v) => st.updateSettings(
                  (x) => x.geminiModel = v.trim(),
                  resched: false),
            ),
            const SizedBox(height: 6),
            Text(
                'If splitting fails with a model error, change the model name to a current free Gemini Flash model.',
                style: TextStyle(fontSize: 11.5, color: g.subText)),
          ]),
          _card('Integrations', [
            GlassButton(
              label: 'Import from phone calendar (Google Calendar)',
              icon: Icons.event_rounded,
              compact: true,
              onTap: () => Navigator.of(context)
                  .push(fadeRoute(const CalendarImportScreen())),
            ),
            const SizedBox(height: 10),
            GlassButton(
              label: 'Google account & create tasks from Gmail',
              icon: Icons.mail_outline_rounded,
              compact: true,
              onTap: () => Navigator.of(context)
                  .push(fadeRoute(const GmailImportScreen())),
            ),
          ]),
          _card('Streak freezes', [
            Row(children: [
              const Icon(Icons.ac_unit_rounded, color: AppTheme.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You have ${st.freezes}. A freeze automatically protects a missed day so your streak survives. '
                  'You earn one every time a streak reaches a multiple of 7 days (max 3).',
                  style: TextStyle(color: g.subText, fontSize: 13),
                ),
              ),
            ]),
          ]),
          Center(
              child: Text('${AppConfig.name}  v1.0.0',
                  style: TextStyle(color: g.subText, fontSize: 12))),
        ],
      ),
    );
  }
}
