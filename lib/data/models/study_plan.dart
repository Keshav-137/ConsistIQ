class StudyPoint {
  String text;
  bool done;
  StudyPoint(this.text, {this.done = false});

  Map<String, dynamic> toJson() => {'t': text, 'd': done};
  factory StudyPoint.fromJson(Map<String, dynamic> j) =>
      StudyPoint(j['t'] as String, done: (j['d'] ?? false) as bool);
}

class StudyDay {
  String title;
  String dateKey;
  List<StudyPoint> points;
  StudyDay({required this.title, required this.dateKey, required this.points});

  bool get done => points.isNotEmpty && points.every((p) => p.done);
  int get doneCount => points.where((p) => p.done).length;

  Map<String, dynamic> toJson() =>
      {'title': title, 'date': dateKey, 'points': points.map((p) => p.toJson()).toList()};
  factory StudyDay.fromJson(Map<String, dynamic> j) => StudyDay(
        title: j['title'] as String,
        dateKey: j['date'] as String,
        points: ((j['points'] ?? []) as List)
            .map((e) => StudyPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class StudyPlan {
  String id;
  String title;
  String taskId; // linked daily task that carries the streak + reminders
  String source;
  int createdAt;
  int hour;
  int minute;
  List<StudyDay> days;

  StudyPlan({
    required this.id,
    required this.title,
    required this.taskId,
    required this.source,
    required this.createdAt,
    required this.hour,
    required this.minute,
    required this.days,
  });

  int get totalPoints => days.fold(0, (a, d) => a + d.points.length);
  int get donePoints => days.fold(0, (a, d) => a + d.doneCount);
  int get doneDays => days.where((d) => d.done).length;
  double get progress => totalPoints == 0 ? 0 : donePoints / totalPoints;

  StudyDay? get nextDay {
    for (final d in days) {
      if (!d.done) return d;
    }
    return null;
  }

  void markNextDone() {
    final d = nextDay;
    if (d == null) return;
    for (final p in d.points) {
      p.done = true;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'task': taskId,
        'source': source,
        'created': createdAt,
        'h': hour,
        'm': minute,
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory StudyPlan.fromJson(Map<String, dynamic> j) => StudyPlan(
        id: j['id'] as String,
        title: j['title'] as String,
        taskId: j['task'] as String,
        source: (j['source'] ?? '') as String,
        createdAt: (j['created'] ?? 0) as int,
        hour: (j['h'] ?? 20) as int,
        minute: (j['m'] ?? 0) as int,
        days: ((j['days'] ?? []) as List)
            .map((e) => StudyDay.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
