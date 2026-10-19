class AppSettings {
  bool notificationsOn;
  int themeMode; // 0 system, 1 light, 2 dark  (matches ThemeMode.values)
  bool appLock;
  String geminiKey;
  String geminiModel;
  List<String> studyApps; // extra allowed package names in study mode
  bool studySilent;

  AppSettings({
    this.notificationsOn = true,
    this.themeMode = 0,
    this.appLock = false,
    this.geminiKey = '',
    this.geminiModel = 'gemini-2.5-flash',
    List<String>? studyApps,
    this.studySilent = true,
  }) : studyApps = studyApps ?? [];

  Map<String, dynamic> toJson() => {
        'notif': notificationsOn,
        'theme': themeMode,
        'lock': appLock,
        'key': geminiKey,
        'model': geminiModel,
        'apps': studyApps,
        'silent': studySilent,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        notificationsOn: (j['notif'] ?? true) as bool,
        themeMode: (j['theme'] ?? 0) as int,
        appLock: (j['lock'] ?? false) as bool,
        geminiKey: (j['key'] ?? '') as String,
        geminiModel: (j['model'] ?? 'gemini-2.5-flash') as String,
        studyApps: List<String>.from((j['apps'] ?? []) as List),
        studySilent: (j['silent'] ?? true) as bool,
      );
}
