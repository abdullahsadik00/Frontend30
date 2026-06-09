import 'dart:convert';
import 'dart:math';

// ── PracticeQuestion ─────────────────────────────────────────────────────────

class PracticeQuestion {
  final String prompt;
  final String? code;
  final String? expectedOutput;
  final String? explanation;

  const PracticeQuestion({
    required this.prompt,
    this.code,
    this.expectedOutput,
    this.explanation,
  });

  bool get hasSolution => (expectedOutput ?? explanation) != null;

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    return PracticeQuestion(
      prompt:         json['prompt']         as String? ?? '',
      code:           json['code']           as String?,
      expectedOutput: json['expectedOutput'] as String?,
      explanation:    json['explanation']    as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'prompt':         prompt,
    'code':           code,
    'expectedOutput': expectedOutput,
    'explanation':    explanation,
  };
}

// ── PracticeQuestions ────────────────────────────────────────────────────────

class PracticeQuestions {
  final List<PracticeQuestion> easy;
  final List<PracticeQuestion> medium;
  final List<PracticeQuestion> hard;

  const PracticeQuestions({
    required this.easy,
    required this.medium,
    required this.hard,
  });

  int get total => easy.length + medium.length + hard.length;
  List<PracticeQuestion> get all => [...easy, ...medium, ...hard];

  // Prefer medium/hard for the reasoning test; fall back to easy
  PracticeQuestion? randomChallenge() {
    final pool = [...medium, ...hard];
    if (pool.isNotEmpty) return pool[Random().nextInt(pool.length)];
    if (easy.isNotEmpty) return easy[Random().nextInt(easy.length)];
    return null;
  }

  factory PracticeQuestions.fromJson(Map<String, dynamic> json) {
    List<PracticeQuestion> _parse(String key) =>
        (json[key] as List? ?? [])
            .map((e) => PracticeQuestion.fromJson(e as Map<String, dynamic>))
            .toList();
    return PracticeQuestions(
      easy:   _parse('easy'),
      medium: _parse('medium'),
      hard:   _parse('hard'),
    );
  }
}

// ── DayContent ───────────────────────────────────────────────────────────────

class DayContent {
  final int dayNumber;
  final String title;
  final String phase;
  final List<String> sections;
  final String markdownContent;
  final PracticeQuestions practiceQuestions;

  const DayContent({
    required this.dayNumber,
    required this.title,
    required this.phase,
    required this.sections,
    required this.markdownContent,
    required this.practiceQuestions,
  });

  bool get hasPracticeQuestions => practiceQuestions.total > 0;

  // e.g. "Phase 3: React Deep Dive"
  String get phaseShort {
    final m = RegExp(r'Phase\s+(\d+)[:\s]+(.+)').firstMatch(phase);
    if (m == null) return phase;
    final words = m.group(2)!.trim().split(' ').take(3).join(' ');
    return 'Phase ${m.group(1)}: $words';
  }

  int get phaseNumber {
    final m = RegExp(r'Phase\s+(\d+)').firstMatch(phase);
    return int.tryParse(m?.group(1) ?? '1') ?? 1;
  }

  // Short topic for the day card (e.g. "Closures", "Event Loop", "Generics")
  String get shortTopic {
    // "📘 MODULE 4: Closures" → "Closures"
    var m = RegExp(r'MODULE\s+\d+[:\s]+(.+)', caseSensitive: false).firstMatch(title);
    if (m != null) return _shorten(m.group(1)!);

    // "Section 4: Data Fetching..." → "Data Fetching"
    m = RegExp(r'Section\s+\d+[:\s]+(.+)', caseSensitive: false).firstMatch(title);
    if (m != null) return _shorten(m.group(1)!);

    // First section that isn't a generic phase description
    for (final s in sections) {
      if (!RegExp(r'mastery|deep dive|overview|complete|fundamentals',
              caseSensitive: false)
          .hasMatch(s)) {
        return _shorten(s);
      }
    }

    // Cleaned title
    String cleaned = title
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '') // drop non-ASCII (emoji etc.)
        .replaceAll(RegExp(r'Phase\s+\d+[:\s]+', caseSensitive: false), '')
        .replaceAll(RegExp(r'COMPLETE MISSING TOPICS', caseSensitive: false), 'Polyfills')
        .trim();
    return _shorten(cleaned);
  }

  static String _shorten(String s) {
    // Split on " & ", " — ", " - " etc. and take first segment
    final parts = s.split(RegExp(r'\s+[&—–-]\s+'));
    final text = parts.first.trim();
    return text.split(RegExp(r'\s+')).take(3).join(' ').trim();
  }

  factory DayContent.fromJson(Map<String, dynamic> json) {
    return DayContent(
      dayNumber:         json['dayNumber']       as int,
      title:             json['title']           as String? ?? '',
      phase:             json['phase']           as String? ?? '',
      sections:          List<String>.from(json['sections'] as List? ?? []),
      markdownContent:   json['markdownContent'] as String? ?? '',
      practiceQuestions: PracticeQuestions.fromJson(
          json['practiceQuestions'] as Map<String, dynamic>? ?? {}),
    );
  }

  static List<DayContent> listFromJson(String jsonString) {
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => DayContent.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
