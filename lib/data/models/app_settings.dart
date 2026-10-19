class AppSettings {
  bool notificationsOn;
  int themeMode; // 0 system, 1 light, 2 dark  (matches ThemeMode.values)
  bool appLock;
  String geminiKey;
  String geminiModel;
  List<String> studyApps; // extra allowed package names in study mode
  bool studySilent;
  int defaultSnoozeMinutes;
  int defaultReminderMinutes;
  bool defaultAlarmStyle;
  bool alarmVibration;
  String alarmSoundUri;
  String displayName;
  bool profileSetupComplete;

  AppSettings({
    this.notificationsOn = true,
    this.themeMode = 0,
    this.appLock = false,
    this.geminiKey = '',
    this.geminiModel = 'gemini-2.5-flash',
    List<String>? studyApps,
    this.studySilent = true,
    this.defaultSnoozeMinutes = 10,
    this.defaultReminderMinutes = 15,
    this.defaultAlarmStyle = false,
    this.alarmVibration = true,
    this.alarmSoundUri = '',
    this.displayName = '',
    this.profileSetupComplete = false,
  }) : studyApps = studyApps ?? [];

  Map<String, dynamic> toJson() => {
        'notif': notificationsOn,
        'theme': themeMode,
        'lock': appLock,
        'key': geminiKey,
        'model': geminiModel,
        'apps': studyApps,
        'silent': studySilent,
        'snoozeDefault': defaultSnoozeMinutes,
        'reminderDefault': defaultReminderMinutes,
        'alarmDefault': defaultAlarmStyle,
        'alarmVibration': alarmVibration,
        'alarmSoundUri': alarmSoundUri,
        'displayName': displayName,
        'profileSetupComplete': profileSetupComplete,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        notificationsOn: (j['notif'] ?? true) as bool,
        themeMode: (j['theme'] ?? 0) as int,
        appLock: (j['lock'] ?? false) as bool,
        geminiKey: (j['key'] ?? '') as String,
        geminiModel: (j['model'] ?? 'gemini-2.5-flash') as String,
        studyApps: List<String>.from((j['apps'] ?? []) as List),
        studySilent: (j['silent'] ?? true) as bool,
        defaultSnoozeMinutes: (j['snoozeDefault'] ?? 10) as int,
        defaultReminderMinutes: (j['reminderDefault'] ?? 15) as int,
        defaultAlarmStyle: (j['alarmDefault'] ?? false) as bool,
        alarmVibration: (j['alarmVibration'] ?? true) as bool,
        alarmSoundUri: (j['alarmSoundUri'] ?? '') as String,
        displayName: (j['displayName'] ?? '') as String,
        profileSetupComplete: (j['profileSetupComplete'] ?? false) as bool,
      );
}
