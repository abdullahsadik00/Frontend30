import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/day_content.dart';
import '../models/progress_state.dart';
import '../utils/phase_colors.dart';
import '../widgets/progress_scope.dart';
import 'verification_screen.dart';


class DayDetailScreen extends StatelessWidget {
  final DayContent day;
  final DayStatus status;

  const DayDetailScreen({
    super.key,
    required this.day,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color    = phaseColor(day.phaseNumber);
    final progress = ProgressScope.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day ${day.dayNumber}: ${day.shortTopic}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Text(
                  day.phaseShort,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              const Tab(
                  icon: Icon(Icons.article_outlined, size: 18),
                  text: 'Content'),
              Tab(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.quiz_outlined, size: 18),
                    if (day.hasPracticeQuestions)
                      Positioned(
                        top: -3,
                        right: -5,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                text: 'Practice',
              ),
              Tab(
                icon: progress.noteFor(day.dayNumber) != null
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.edit_note_rounded, size: 18),
                          Positioned(
                            top: -3,
                            right: -5,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Icon(Icons.edit_note_rounded, size: 18),
                text: 'Notes',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ContentTab(day: day, accentColor: color),
            _PracticeTab(day: day),
            _NotesTab(
              dayNumber: day.dayNumber,
              initialNote: progress.noteFor(day.dayNumber),
            ),
          ],
        ),
        floatingActionButton: _buildFAB(context, color),
      ),
    );
  }

  Widget? _buildFAB(BuildContext context, Color color) {
    if (status == DayStatus.locked) return null;

    if (status == DayStatus.completed) {
      return FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VerificationScreen(day: day, isPracticeMode: true),
          ),
        ),
        backgroundColor: color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.replay_rounded),
        label: const Text('Practice Again'),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationScreen(day: day),
        ),
      ).then((_) {
        final progress = ProgressScope.of(context);
        if (progress.statusFor(day.dayNumber) == DayStatus.completed) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Day ${day.dayNumber} complete! Day ${day.dayNumber + 1} unlocked.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }),
      backgroundColor: color,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.quiz_outlined),
      label: const Text('Take Test'),
    );
  }
}

// ── Content tab ───────────────────────────────────────────────────────────────

class _ContentTab extends StatelessWidget {
  final DayContent day;
  final Color accentColor;
  const _ContentTab({required this.day, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final content = day.markdownContent.isNotEmpty
        ? day.markdownContent
        : '_No content available for this day yet._';

    return Markdown(
      data: content,
      selectable: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      styleSheet: MarkdownStyleSheet(
        h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
        h2: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
        h3: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: accentColor.withValues(alpha: 0.85),
            ),
        p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: cs.surfaceContainerHighest,
          color: cs.onSurface,
        ),
        codeblockDecoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: accentColor, width: 4)),
          color: accentColor.withValues(alpha: 0.06),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
      ),
    );
  }
}

// ── Practice tab ──────────────────────────────────────────────────────────────

class _PracticeTab extends StatelessWidget {
  final DayContent day;
  const _PracticeTab({required this.day});

  @override
  Widget build(BuildContext context) {
    final pq = day.practiceQuestions;

    if (!day.hasPracticeQuestions) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'No practice questions for this day.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (pq.easy.isNotEmpty) ...[
          _DiffHeader(
              label: 'Easy',
              count: pq.easy.length,
              color: const Color(0xFF10B981)),
          const SizedBox(height: 8),
          ...pq.easy.asMap().entries.map((e) => _QuestionCard(
                index: e.key + 1,
                question: e.value,
                color: const Color(0xFF10B981),
              )),
          const SizedBox(height: 16),
        ],
        if (pq.medium.isNotEmpty) ...[
          _DiffHeader(
              label: 'Medium',
              count: pq.medium.length,
              color: const Color(0xFFF59E0B)),
          const SizedBox(height: 8),
          ...pq.medium.asMap().entries.map((e) => _QuestionCard(
                index: e.key + 1,
                question: e.value,
                color: const Color(0xFFF59E0B),
              )),
          const SizedBox(height: 16),
        ],
        if (pq.hard.isNotEmpty) ...[
          _DiffHeader(
              label: 'Hard',
              count: pq.hard.length,
              color: const Color(0xFFEF4444)),
          const SizedBox(height: 8),
          ...pq.hard.asMap().entries.map((e) => _QuestionCard(
                index: e.key + 1,
                question: e.value,
                color: const Color(0xFFEF4444),
              )),
        ],
      ],
    );
  }
}

class _DiffHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _DiffHeader(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count question${count == 1 ? '' : 's'}',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final int index;
  final PracticeQuestion question;
  final Color color;
  const _QuestionCard(
      {required this.index, required this.question, required this.color});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q  = widget.question;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${widget.index}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: widget.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        q.prompt,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: cs.outline,
                      size: 18,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  if (q.code != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(q.code!,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.4)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (q.expectedOutput != null) ...[
                    _SolutionRow(
                      icon: Icons.output,
                      label: 'Expected Output',
                      value: q.expectedOutput!,
                      color: widget.color,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (q.explanation != null)
                    _SolutionRow(
                      icon: Icons.lightbulb_outline,
                      label: 'Explanation',
                      value: q.explanation!,
                      color: widget.color,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SolutionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SolutionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Notes tab ─────────────────────────────────────────────────────────────────

class _NotesTab extends StatefulWidget {
  final int dayNumber;
  final String? initialNote;
  const _NotesTab({required this.dayNumber, this.initialNote});

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  late final TextEditingController _ctrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ProgressScope.of(context).saveNote(widget.dayNumber, _ctrl.text);
    if (mounted) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Note saved'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => setState(() => _dirty = true),
              decoration: InputDecoration(
                hintText: 'Notes for Day ${widget.dayNumber}…\n\n'
                    'Key concepts, code snippets, things to remember.',
                hintMaxLines: 4,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _dirty ? _save : null,
            icon: const Icon(Icons.save_rounded),
            label: Text(_dirty ? 'Save Note' : 'Saved'),
          ),
        ],
      ),
    );
  }
}
