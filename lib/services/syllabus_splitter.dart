import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SplitDay {
  String title;
  List<String> points;
  SplitDay(this.title, this.points);
}

class SplitResult {
  final List<SplitDay> days;
  final String source;
  final String? note;
  SplitResult(this.days, this.source, {this.note});
}

class SyllabusSplitter {
  static Future<SplitResult> split({
    required String text,
    int? days,
    required int minutesPerDay,
    required String apiKey,
    required String model,
  }) async {
    String? note;
    if (apiKey.trim().isNotEmpty) {
      try {
        final r = await _gemini(text, days, minutesPerDay, apiKey.trim(), model.trim());
        if (r.isNotEmpty) return SplitResult(r, 'AI (Gemini)');
        note = 'AI returned nothing, used offline splitter.';
      } catch (e) {
        debugPrint('Gemini failed: $e');
        note = 'AI failed ($e). Used offline splitter.';
      }
    } else {
      note = 'No AI key set (Settings). Used offline splitter.';
    }
    return SplitResult(_local(text, days ?? 14), 'Offline splitter', note: note);
  }

  static Future<List<SplitDay>> _gemini(
      String text, int? days, int minutes, String key, String model) async {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final dayRule = days != null
        ? 'Use exactly $days days.'
        : 'Choose a sensible number of days (maximum 60).';
    final prompt = '''You are a study planner. Split the syllabus below into daily study tasks.
Rules: $dayRule Each day is about $minutes minutes of study. Order topics from basics to advanced. Split big topics across several days. Add a revision day now and then. Every day has a short title and 3 to 6 concrete checklist points (concepts to learn, exercises to practice).
Return ONLY JSON in this shape: {"days":[{"title":"...","points":["...","..."]}]}

SYLLABUS:
$text''';
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.3},
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      final b = res.body;
      throw Exception('HTTP ${res.statusCode}: ${b.length > 160 ? b.substring(0, 160) : b}');
    }
    final data = jsonDecode(res.body);
    var out = data['candidates'][0]['content']['parts'][0]['text'] as String;
    out = out.replaceAll(RegExp(r'```json|```'), '').trim();
    final j = jsonDecode(out);
    final list = (j is List ? j : j['days']) as List;
    final result = <SplitDay>[];
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      final pts = ((m['points'] ?? []) as List).map((x) => x.toString()).toList();
      if (pts.isEmpty) continue;
      result.add(SplitDay((m['title'] ?? 'Study').toString(), pts));
    }
    return result;
  }

  /// Offline fallback: split by lines / commas / semicolons, group evenly.
  static List<SplitDay> _local(String text, int days) {
    final items = text
        .split(RegExp(r'[\n;,]+'))
        .map((s) => s.replaceAll(RegExp(r'^\s*([-*•]|\d+[.)])\s*'), '').trim())
        .where((s) => s.length > 1)
        .toList();
    if (items.isEmpty) return [];
    final n = days.clamp(1, items.length);
    final out = <SplitDay>[];
    for (var i = 0; i < n; i++) {
      final from = (items.length * i / n).floor();
      final to = (items.length * (i + 1) / n).floor();
      final chunk = items.sublist(from, to);
      if (chunk.isEmpty) continue;
      out.add(SplitDay(
        chunk.length == 1 ? chunk.first : '${chunk.first} and more',
        [
          ...chunk.map((c) => 'Learn: $c'),
          'Practice questions and write short notes',
        ],
      ));
    }
    return out;
  }
}
