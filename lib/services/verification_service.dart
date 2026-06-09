import '../models/day_content.dart';

// ── Result ────────────────────────────────────────────────────────────────────

class VerificationResult {
  final bool verified;
  final double score;
  final List<String> matchedTerms;
  final List<String> missedTerms;
  final String feedback;

  const VerificationResult({
    required this.verified,
    required this.score,
    required this.matchedTerms,
    required this.missedTerms,
    required this.feedback,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class VerificationService {
  static const _stopWords = {
    'the', 'is', 'are', 'was', 'were', 'been', 'being', 'have', 'has', 'had',
    'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'can',
    'shall', 'and', 'or', 'but', 'if', 'then', 'than', 'that', 'this', 'these',
    'those', 'from', 'into', 'during', 'before', 'after', 'which', 'when',
    'where', 'how', 'all', 'each', 'both', 'more', 'most', 'other', 'some',
    'only', 'own', 'same', 'very', 'just', 'because', 'while', 'however',
    'therefore', 'also', 'even', 'still', 'since', 'you', 'your', 'they',
    'their', 'what', 'why', 'any', 'here', 'get', 'set', 'used', 'using',
    'new', 'one', 'two', 'three', 'first', 'last', 'next', 'with', 'for',
    'not', 'its', 'run', 'runs', 'call', 'calls', 'called', 'see', 'look',
    'adds', 'add', 'make', 'makes', 'made', 'show', 'shows', 'note', 'line',
    'mean', 'means', 'returns', 'creates', 'create', 'object', 'value', 'values',
    'code', 'output', 'result', 'answer', 'example', 'below', 'above', 'like',
    'when', 'then', 'well', 'need', 'want', 'able', 'way', 'they', 'them',
  };

  // Minimum reasoning length in words
  static const _minWords = 15;

  // Matching threshold (fraction of key concepts to cover)
  static const _threshold = 0.40;

  // Minimum term length
  static const _minLen = 4;

  // ── Stemmer ───────────────────────────────────────────────────────────────

  // Light suffix stripper so "closures" matches "closure", "hoisting" matches "hoist"
  static String _stem(String word) {
    const suffixes = [
      'tions', 'tion', 'ness', 'ment', 'ally', 'ity', 'ing', 'ied',
      'ies', 'ers', 'er', 'ed', 'es', 's',
    ];
    for (final s in suffixes) {
      if (word.endsWith(s) && word.length - s.length >= 3) {
        return word.substring(0, word.length - s.length);
      }
    }
    return word;
  }

  // ── Term extraction ───────────────────────────────────────────────────────

  static List<String> extractKeyTerms(String text) {
    if (text.isEmpty) return [];
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s'-]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= _minLen && !_stopWords.contains(w))
        .toSet()
        .toList();
  }

  // ── Verify ────────────────────────────────────────────────────────────────

  static VerificationResult verify({
    required String userReasoning,
    required PracticeQuestion question,
  }) {
    final reasoning  = userReasoning.trim();
    final wordCount  = reasoning.isEmpty
        ? 0
        : reasoning.split(RegExp(r'\s+')).length;

    // Reject if too short
    if (wordCount < _minWords) {
      return VerificationResult(
        verified: false,
        score: 0,
        matchedTerms: const [],
        missedTerms: const [],
        feedback: 'Your explanation is too brief ($wordCount words). '
            'Write at least $_minWords words — aim for 2–3 full sentences explaining the concept.',
      );
    }

    // Build solution corpus
    final solutionText = [
      question.expectedOutput ?? '',
      question.explanation   ?? '',
    ].join(' ');

    if (solutionText.trim().isEmpty) {
      final ok = wordCount >= 20;
      return VerificationResult(
        verified: ok,
        score: ok ? 1.0 : 0.0,
        matchedTerms: const [],
        missedTerms: const [],
        feedback: ok
            ? 'No reference solution to compare — accepting your detailed answer.'
            : 'Please add more detail to your reasoning (at least 20 words).',
      );
    }

    final rawSolutionTerms = extractKeyTerms(solutionText);
    if (rawSolutionTerms.isEmpty) {
      return const VerificationResult(
        verified: true,
        score: 1.0,
        matchedTerms: [],
        missedTerms: [],
        feedback: 'Looks good!',
      );
    }

    // Deduplicate solution terms by stem (group "closure"/"closures" as one concept)
    final stemToTerm = <String, String>{};
    for (final term in rawSolutionTerms) {
      stemToTerm.putIfAbsent(_stem(term), () => term);
    }

    // Build normalized set of user's terms for fast lookup
    final userTerms = extractKeyTerms(reasoning).map(_stem).toSet();
    final reasoningLower = reasoning.toLowerCase();

    final matched = <String>[];
    final missed  = <String>[];

    for (final entry in stemToTerm.entries) {
      final stemmed  = entry.key;
      final original = entry.value;
      // Hit if: normalized form matches OR original substring present
      if (userTerms.contains(stemmed) || reasoningLower.contains(original)) {
        matched.add(original);
      } else {
        missed.add(original);
      }
    }

    final score = matched.length / stemToTerm.length;
    final pct   = (score * 100).round();

    final String feedback;
    if (score >= _threshold) {
      final topMatched = matched.take(5).join(', ');
      feedback = 'Solid reasoning — $pct% of key concepts covered. '
          'Terms matched: $topMatched.';
    } else {
      final topMissed = missed.take(3).join(', ');
      feedback = 'You scored $pct% (need ${(_threshold * 100).round()}% to pass). '
          'Try to explain: $topMissed.';
    }

    return VerificationResult(
      verified: score >= _threshold,
      score: score,
      matchedTerms: matched,
      missedTerms:  missed,
      feedback: feedback,
    );
  }
}
