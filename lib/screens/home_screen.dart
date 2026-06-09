import 'package:flutter/material.dart';
import '../models/day_content.dart';
import '../models/progress_state.dart';
import '../models/struggle_record.dart';
import '../services/curriculum_service.dart';
import '../utils/phase_colors.dart';
import '../widgets/day_search_delegate.dart';
import '../widgets/progress_scope.dart';
import 'day_detail_screen.dart';
import 'stats_screen.dart';
import 'verification_screen.dart';

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<DayContent>> _future;

  @override
  void initState() {
    super.initState();
    _future = CurriculumService.instance.loadDays();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<DayContent>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          return _Body(days: snap.data!);
        },
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final List<DayContent> days;
  const _Body({required this.days});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final cs       = Theme.of(context).colorScheme;
    final columns  = MediaQuery.of(context).size.width > 600 ? 5 : 3;

    return CustomScrollView(
      slivers: [
        // ── App bar ──────────────────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          expandedHeight: 0,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          title: const Text(
            'Frontend 30',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search',
              onPressed: () => showSearch(
                context: context,
                delegate: DaySearchDelegate(days),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: 'Stats',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: 'Reset progress',
              onPressed: () => _confirmReset(context, progress),
            ),
          ],
        ),

        // ── Progress + streak header ─────────────────────────────────────────
        SliverToBoxAdapter(child: _ProgressHeader(progress: progress)),

        // ── Streak-at-risk banner ────────────────────────────────────────────
        if (progress.isStreakAtRisk)
          SliverToBoxAdapter(
            child: _StreakBanner(
              streak: progress.currentStreak,
              hours:  progress.hoursSinceLastActivity,
            ),
          ),

        // ── Review section ────────────────────────────────────────────────────
        if (progress.struggles.isNotEmpty)
          SliverToBoxAdapter(
            child: _ReviewSection(struggles: progress.struggles),
          ),

        // ── Phase legend ─────────────────────────────────────────────────────
        const SliverToBoxAdapter(child: _PhaseLegend()),

        // ── Day grid ─────────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final day    = days[i];
                final status = progress.statusFor(day.dayNumber);
                return _DayCard(day: day, status: status);
              },
              childCount: days.length,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(
      BuildContext context, ProgressState progress) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text(
            'This will clear all completions, your streak, scores, and review history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await progress.reset();
  }
}

// ── Progress header ───────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final ProgressState progress;
  const _ProgressHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final count  = progress.completedCount;
    final ratio  = progress.completionRatio;
    final streak = progress.currentStreak;

    return Container(
      color: cs.primary,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: v,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: cs.onPrimary.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(cs.onPrimary),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$count',
                          style: tt.titleLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1)),
                      Text('/ 30',
                          style: tt.labelSmall?.copyWith(
                              color:
                                  cs.onPrimary.withValues(alpha: 0.75))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0
                      ? '30-Day Challenge'
                      : count == 30
                          ? 'Challenge Complete!'
                          : 'Keep Going!',
                  style: tt.titleMedium?.copyWith(
                      color: cs.onPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  count == 0
                      ? 'Start with Day 1'
                      : '$count day${count == 1 ? '' : 's'} · ${(ratio * 100).round()}%',
                  style: tt.bodySmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.85)),
                ),
                if (streak > 0) ...[
                  const SizedBox(height: 8),
                  _StreakPill(streak: streak),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  final int streak;
  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            '$streak-day streak',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Streak-at-risk banner ─────────────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  final int streak;
  final int hours;
  const _StreakBanner({required this.streak, required this.hours});

  @override
  Widget build(BuildContext context) {
    final hoursLeft = 24 - hours;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFB923C).withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Streak at Risk!',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFFC2410C),
                  ),
                ),
                Text(
                  'Your $streak-day streak expires in ~$hoursLeft h. '
                  "Complete today's test to keep it.",
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9A3412)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review section ────────────────────────────────────────────────────────────

class _ReviewSection extends StatelessWidget {
  final List<StruggleRecord> struggles;
  const _ReviewSection({required this.struggles});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.history_edu_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text('Review',
                  style:
                      tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${struggles.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onErrorContainer),
                ),
              ),
              const Spacer(),
              Text('Most struggled first',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        SizedBox(
          height: 112,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: struggles.length,
            itemBuilder: (_, i) => _StruggleCard(record: struggles[i]),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _StruggleCard extends StatelessWidget {
  final StruggleRecord record;
  const _StruggleCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => _showReviewSheet(context),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: cs.error.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Day ${record.dayNumber}',
                    style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700, color: cs.error)),
                _FailBadge(count: record.failedAttempts),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              record.dayTopic,
              style: tt.labelSmall
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                record.prompt,
                style: tt.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReviewSheet(record: record),
    );
  }
}

class _FailBadge extends StatelessWidget {
  final int count;
  const _FailBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: cs.error, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '×$count',
        style: TextStyle(
            color: cs.onError, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Review bottom sheet ───────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final StruggleRecord record;
  const _ReviewSheet({required this.record});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  bool _loadingRetry = false;

  Future<void> _retry() async {
    setState(() => _loadingRetry = true);

    final day =
        await CurriculumService.instance.getDayByNumber(widget.record.dayNumber);

    if (!mounted) return;

    if (day == null) {
      setState(() => _loadingRetry = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not load this day\'s content.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Try to find the exact question (preserves `code` field).
    PracticeQuestion? question;
    try {
      question = day.practiceQuestions.all
          .firstWhere((q) => q.prompt == widget.record.prompt);
    } catch (_) {}

    // Fall back to reconstructing from the StruggleRecord (no code).
    question ??= PracticeQuestion(
      prompt:         widget.record.prompt,
      expectedOutput: widget.record.expectedOutput,
      explanation:    widget.record.explanation,
    );

    final nav = Navigator.of(context);
    nav.pop(); // close the sheet first
    nav.push(MaterialPageRoute(
      builder: (_) => VerificationScreen(
        day:            day,
        isPracticeMode: true,
        forcedQuestion: question,
        retryForPrompt: widget.record.prompt,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Chip(
                label: Text('Day ${widget.record.dayNumber}'),
                backgroundColor: cs.errorContainer,
                labelStyle: TextStyle(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w600),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              _FailBadge(count: widget.record.failedAttempts),
              const Spacer(),
              Text(widget.record.dayTopic,
                  style:
                      tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Question',
              style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: cs.error)),
          const SizedBox(height: 6),
          Text(widget.record.prompt,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (widget.record.expectedOutput != null) ...[
            _SheetSection(
              icon: Icons.output,
              label: 'Expected Output',
              value: widget.record.expectedOutput!,
              mono: true,
              color: cs.primary,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.record.explanation != null) ...[
            _SheetSection(
              icon: Icons.lightbulb_outline,
              label: 'Explanation',
              value: widget.record.explanation!,
              mono: false,
              color: cs.primary,
            ),
            const SizedBox(height: 12),
          ],
          if (widget.record.expectedOutput == null &&
              widget.record.explanation == null)
            Text('No solution recorded.',
                style: tt.bodySmall?.copyWith(color: cs.outline)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: BorderSide(color: cs.primary),
              foregroundColor: cs.primary,
            ),
            onPressed: _loadingRetry ? null : _retry,
            icon: _loadingRetry
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.primary),
                  )
                : const Icon(Icons.replay_rounded),
            label:
                Text(_loadingRetry ? 'Loading…' : 'Retry This Question'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  final Color color;
  const _SheetSection({
    required this.icon,
    required this.label,
    required this.value,
    required this.mono,
    required this.color,
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
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 5),
        mono
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(value,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4)),
              )
            : Text(value,
                style: const TextStyle(fontSize: 13, height: 1.55)),
      ],
    );
  }
}

// ── Phase legend ──────────────────────────────────────────────────────────────

class _PhaseLegend extends StatelessWidget {
  const _PhaseLegend();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: phaseNameMap.entries.map((e) {
          final color = phaseColor(e.key);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                e.value,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Day card ──────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final DayContent day;
  final DayStatus status;
  const _DayCard({required this.day, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final color  = phaseColor(day.phaseNumber);
    final locked = status == DayStatus.locked;
    final done   = status == DayStatus.completed;

    return Material(
      color: locked
          ? cs.surfaceContainerLow
          : color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: locked
            ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text('Complete Day ${day.dayNumber - 1} first.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ))
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DayDetailScreen(day: day, status: status),
                  ),
                ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: locked
                  ? cs.outlineVariant
                  : done
                      ? color
                      : color.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${day.dayNumber}',
                      style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color:
                              locked ? cs.onSurfaceVariant : color,
                          height: 1)),
                  if (locked)
                    Icon(Icons.lock_outline,
                        size: 14, color: cs.outlineVariant)
                  else if (done)
                    Icon(Icons.check_circle, size: 14, color: color),
                ],
              ),
              const Spacer(),
              Text(
                day.shortTopic,
                style: tt.labelSmall?.copyWith(
                  color: locked
                      ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                      : cs.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: done ? 1.0 : 0.0,
                  minHeight: 3,
                  backgroundColor: locked
                      ? cs.outlineVariant.withValues(alpha: 0.3)
                      : color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
