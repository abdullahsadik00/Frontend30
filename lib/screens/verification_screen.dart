import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../models/day_content.dart';
import '../models/progress_state.dart';
import '../services/verification_service.dart';
import '../widgets/progress_scope.dart';

class VerificationScreen extends StatefulWidget {
  final DayContent day;
  const VerificationScreen({super.key, required this.day});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _answerCtrl    = TextEditingController();
  final _reasoningCtrl = TextEditingController();
  final _formKey       = GlobalKey<FormState>();
  late final ConfettiController _confettiCtrl;

  PracticeQuestion? _question;
  VerificationResult? _result;
  bool _showSolution  = false;
  bool _submitting    = false;
  int  _attemptCount  = 0;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
    _pickQuestion();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    _reasoningCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  void _pickQuestion() {
    final pool = [
      ...widget.day.practiceQuestions.medium,
      ...widget.day.practiceQuestions.hard,
    ];
    if (pool.isNotEmpty) {
      _question = pool[Random().nextInt(pool.length)];
    } else {
      final easy = widget.day.practiceQuestions.easy;
      _question = easy.isEmpty ? null : easy[Random().nextInt(easy.length)];
    }
    setState(() {
      _result      = null;
      _showSolution= false;
      _answerCtrl.clear();
      _reasoningCtrl.clear();
      _attemptCount++;
    });
  }

  Color get _accentColor {
    const colors = {
      1: Color(0xFFF59E0B), 2: Color(0xFF3B82F6), 3: Color(0xFF10B981),
      4: Color(0xFF8B5CF6), 5: Color(0xFFEF4444), 6: Color(0xFFEC4899),
    };
    return colors[widget.day.phaseNumber] ?? const Color(0xFF6366F1);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_question == null) return;

    setState(() => _submitting = true);

    // Small delay for visual feedback
    Future.delayed(const Duration(milliseconds: 300), () {
      final result = VerificationService.verify(
        userReasoning: '${_answerCtrl.text} ${_reasoningCtrl.text}',
        question: _question!,
      );
      setState(() {
        _result     = result;
        _submitting = false;
      });

      if (result.verified) {
        ProgressScope.of(context).markPassed(widget.day.dayNumber);
        _confettiCtrl.play();
      } else {
        ProgressScope.of(context).recordStruggle(
          dayNumber: widget.day.dayNumber,
          dayTopic:  widget.day.shortTopic,
          question:  _question!,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            title: Text('Day ${widget.day.dayNumber} — Reasoning Test'),
            actions: [
              if (_question != null)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Try a different question',
                  onPressed: _result == null ? _pickQuestion : null,
                ),
            ],
          ),
          body: _question == null
              ? _NoQuestionsView(dayNumber: widget.day.dayNumber, color: _accentColor)
              : _TestBody(
                  question:    _question!,
                  result:      _result,
                  formKey:     _formKey,
                  answerCtrl:  _answerCtrl,
                  reasonCtrl:  _reasoningCtrl,
                  showSolution:_showSolution,
                  submitting:  _submitting,
                  accentColor: _accentColor,
                  attemptCount:_attemptCount,
                  onSubmit:    _submit,
                  onShowSolution: () => setState(() => _showSolution = true),
                  onTryAnother:   _pickQuestion,
                  onDone: () => Navigator.of(context).pop(),
                ),
        ),
        // Confetti overlay — fires from top-center on verification success
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirection: 3.14 / 2, // straight down
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 30,
            minBlastForce: 10,
            gravity: 0.3,
            colors: [
              _accentColor,
              Colors.green.shade400,
              Colors.yellow.shade600,
              Colors.pink.shade300,
              Colors.blue.shade300,
            ],
          ),
        ),
      ],
    );
  }
}

// ── No questions fallback ─────────────────────────────────────────────────────

class _NoQuestionsView extends StatelessWidget {
  final int dayNumber;
  final Color color;
  const _NoQuestionsView({required this.dayNumber, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 56, color: color),
            const SizedBox(height: 16),
            Text(
              'No practice questions for Day $dayNumber.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Mark this day as complete to continue.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () {
                ProgressScope.of(context).markPassed(dayNumber);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check),
              label: const Text('Mark as Complete'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main test body ────────────────────────────────────────────────────────────

class _TestBody extends StatelessWidget {
  final PracticeQuestion question;
  final VerificationResult? result;
  final GlobalKey<FormState> formKey;
  final TextEditingController answerCtrl;
  final TextEditingController reasonCtrl;
  final bool showSolution;
  final bool submitting;
  final Color accentColor;
  final int attemptCount;
  final VoidCallback onSubmit;
  final VoidCallback onShowSolution;
  final VoidCallback onTryAnother;
  final VoidCallback onDone;

  const _TestBody({
    required this.question,
    required this.result,
    required this.formKey,
    required this.answerCtrl,
    required this.reasonCtrl,
    required this.showSolution,
    required this.submitting,
    required this.accentColor,
    required this.attemptCount,
    required this.onSubmit,
    required this.onShowSolution,
    required this.onTryAnother,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final answered = result != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Question card ───────────────────────────────────────────────
            _QuestionCard(question: question, accentColor: accentColor),
            const SizedBox(height: 20),

            // ── Answer inputs (shown only before submission) ────────────────
            if (!answered) ...[
              TextFormField(
                controller: answerCtrl,
                decoration: InputDecoration(
                  labelText: 'Your Answer',
                  hintText: 'What do you think the output / solution is?',
                  prefixIcon: Icon(Icons.edit_note, color: accentColor),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter your answer' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  labelText: 'Your Reasoning',
                  hintText:
                      'Why is this the correct approach? Explain the concept in your own words…',
                  prefixIcon: Icon(Icons.psychology_outlined, color: accentColor),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please explain your reasoning';
                  final words = v.trim().split(RegExp(r'\s+'));
                  if (words.length < 5) return 'Write at least a few sentences';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: submitting ? null : onSubmit,
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(submitting ? 'Checking…' : 'Submit Reasoning'),
              ),
            ],

            // ── Result ──────────────────────────────────────────────────────
            if (result != null) ...[
              _ResultCard(
                result: result!,
                accentColor: accentColor,
              ),
              const SizedBox(height: 16),

              // Verified → completion banner + done button
              if (result!.verified) ...[
                _SuccessBanner(accentColor: accentColor),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onDone,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Day'),
                ),
              ] else ...[
                // Not verified → show solution / try again
                if (!showSolution)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: BorderSide(color: accentColor),
                      foregroundColor: accentColor,
                    ),
                    onPressed: onShowSolution,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Show Solution'),
                  ),
                if (showSolution) ...[
                  _SolutionReveal(question: question, accentColor: accentColor),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onTryAnother,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try a Different Question'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Question display card ─────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final PracticeQuestion question;
  final Color accentColor;
  const _QuestionCard({required this.question, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline, size: 16, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  'Question',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.prompt,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (question.code != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        question.code!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final VerificationResult result;
  final Color accentColor;
  const _ResultCard({required this.result, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final verified = result.verified;
    final color    = verified ? Colors.green.shade600 : Colors.orange.shade700;
    final cs       = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                verified ? 'Verified ✓' : 'Not Quite Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const Spacer(),
              // Score pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(result.score * 100).round()}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(result.feedback, style: Theme.of(context).textTheme.bodyMedium),
          if (result.matchedTerms.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: result.matchedTerms.take(8).map((term) => _TermChip(
                    term: term,
                    matched: true,
                    color: Colors.green.shade600,
                  )).toList(),
            ),
          ],
          if (!verified && result.missedTerms.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: result.missedTerms.take(6).map((term) => _TermChip(
                    term: term,
                    matched: false,
                    color: Colors.red.shade600,
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TermChip extends StatelessWidget {
  final String term;
  final bool matched;
  final Color color;
  const _TermChip({required this.term, required this.matched, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            matched ? Icons.check : Icons.close,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(term, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

// ── Success banner ────────────────────────────────────────────────────────────

class _SuccessBanner extends StatelessWidget {
  final Color accentColor;
  const _SuccessBanner({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade400.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade400.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day Complete!',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade700,
                      ),
                ),
                Text(
                  'Next day is now unlocked. Keep the momentum!',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Solution reveal ───────────────────────────────────────────────────────────

class _SolutionReveal extends StatelessWidget {
  final PracticeQuestion question;
  final Color accentColor;
  const _SolutionReveal({required this.question, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solution',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accentColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          if (question.expectedOutput != null) ...[
            _RevealRow(
              icon: Icons.output,
              label: 'Expected Output',
              value: question.expectedOutput!,
              color: accentColor,
              mono: true,
            ),
            const SizedBox(height: 8),
          ],
          if (question.explanation != null)
            _RevealRow(
              icon: Icons.lightbulb_outline,
              label: 'Explanation',
              value: question.explanation!,
              color: accentColor,
              mono: false,
            ),
          if (question.expectedOutput == null && question.explanation == null)
            Text(
              'No solution available for this question.',
              style: TextStyle(color: cs.outline, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _RevealRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool mono;
  const _RevealRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 4),
        mono
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(value,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              )
            : Text(value, style: const TextStyle(fontSize: 13, height: 1.5)),
      ],
    );
  }
}
