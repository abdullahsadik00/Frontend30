import '../models/day_content.dart';

// ── Result ────────────────────────────────────────────────────────────────────

class VerificationResult {
  final bool verified;
  final double score;        // 0.0 – 1.0
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
  // Common words that carry no technical signal
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
  };

  // Minimum word length to consider as a technical term
  static const _minLen = 4;

  // Required fraction of key terms the user must cover
  static const _threshold = 0.30;

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

  static VerificationResult verify({
    required String userReasoning,
    required PracticeQuestion question,
  }) {
    final reasoning = userReasoning.trim();

    // If reasoning is trivially short, reject immediately
    if (reasoning.split(RegExp(r'\s+')).length < 5) {
      return const VerificationResult(
        verified: false,
        score: 0,
        matchedTerms: [],
        missedTerms: [],
        feedback: 'Please write a more detailed explanation (at least a few sentences).',
      );
    }

    // Build solution corpus from expectedOutput + explanation
    final solutionText = [
      question.expectedOutput ?? '',
      question.explanation ?? '',
    ].join(' ');

    if (solutionText.trim().isEmpty) {
      // No reference solution — give benefit of doubt to substantive answers
      final wordCount = reasoning.split(RegExp(r'\s+')).length;
      final ok = wordCount >= 15;
      return VerificationResult(
        verified: ok,
        score: ok ? 1.0 : 0.0,
        matchedTerms: const [],
        missedTerms: const [],
        feedback: ok
            ? 'Good effort! No reference solution to compare — keeping your answer.'
            : 'Please add more detail to your reasoning.',
      );
    }

    final solutionTerms = extractKeyTerms(solutionText);
    if (solutionTerms.isEmpty) {
      return const VerificationResult(
        verified: true,
        score: 1.0,
        matchedTerms: [],
        missedTerms: [],
        feedback: 'Looks good!',
      );
    }

    final reasoningLower = reasoning.toLowerCase();
    final matched = <String>[];
    final missed  = <String>[];

    for (final term in solutionTerms) {
      if (reasoningLower.contains(term)) {
        matched.add(term);
      } else {
        missed.add(term);
      }
    }

    final score = matched.length / solutionTerms.length;
    final pct   = (score * 100).round();

    String feedback;
    if (score >= _threshold) {
      feedback = 'Your reasoning covers the key concepts ($pct% match). '
          'Key terms found: ${matched.take(5).join(', ')}.';
    } else {
      final topMissed = missed.take(4).join(', ');
      feedback = 'Your reasoning scored $pct% — below the passing threshold of '
          '${(_threshold * 100).round()}%. '
          'Try to address: $topMissed.';
    }

    return VerificationResult(
      verified: score >= _threshold,
      score: score,
      matchedTerms: matched,
      missedTerms: missed,
      feedback: feedback,
    );
  }
}
