import 'package:flutter/material.dart';
import '../models/day_content.dart';
import '../models/progress_state.dart';
import '../models/struggle_record.dart';
import '../services/curriculum_service.dart';
import '../utils/phase_colors.dart';
import '../widgets/progress_scope.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: const Text(
          'Your Stats',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<List<DayContent>>(
        future: CurriculumService.instance.loadDays(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _StatsBody(days: snap.data!, progress: progress);
        },
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _StatsBody extends StatelessWidget {
  final List<DayContent> days;
  final ProgressState progress;
  const _StatsBody({required this.days, required this.progress});

  @override
  Widget build(BuildContext context) {
    // Group days by phase
    final phaseGroups = <int, List<DayContent>>{};
    for (final day in days) {
      phaseGroups.putIfAbsent(day.phaseNumber, () => []).add(day);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Completion ring ───────────────────────────────────────────────
        _CompletionHeader(progress: progress),
        const SizedBox(height: 20),

        // ── Streak row ────────────────────────────────────────────────────
        _SectionLabel(label: 'Streak'),
        const SizedBox(height: 8),
        _StreakRow(progress: progress),
        const SizedBox(height: 20),

        // ── Score row ─────────────────────────────────────────────────────
        if (progress.totalAttempts > 0) ...[
          _SectionLabel(label: 'Verification Scores'),
          const SizedBox(height: 8),
          _ScoreRow(progress: progress),
          const SizedBox(height: 20),
        ],

        // ── Phase breakdown ───────────────────────────────────────────────
        _SectionLabel(label: 'Phase Breakdown'),
        const SizedBox(height: 8),
        ...phaseGroups.entries.map(
          (e) => _PhaseRow(
            phaseNumber: e.key,
            days: e.value,
            progress: progress,
          ),
        ),
        const SizedBox(height: 20),

        // ── Struggles ─────────────────────────────────────────────────────
        if (progress.struggles.isNotEmpty) ...[
          _SectionLabel(label: 'Review Queue'),
          const SizedBox(height: 8),
          _StrugglesCard(struggles: progress.struggles),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ── Completion header ─────────────────────────────────────────────────────────

class _CompletionHeader extends StatelessWidget {
  final ProgressState progress;
  const _CompletionHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final tt    = Theme.of(context).textTheme;
    final count = progress.completedCount;
    final ratio = progress.completionRatio;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: v,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                  Text(
                    '${(v * 100).round()}%',
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
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
                  '$count / 30 days complete',
                  style: tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Start your journey with Day 1'
                      : count == 30
                          ? 'Full challenge complete!'
                          : '${30 - count} days remaining',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Streak row ────────────────────────────────────────────────────────────────

class _StreakRow extends StatelessWidget {
  final ProgressState progress;
  const _StreakRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFF59E0B),
            label: 'Current Streak',
            value: '${progress.currentStreak}d',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFEC4899),
            label: 'Best Streak',
            value: '${progress.bestStreak}d',
          ),
        ),
      ],
    );
  }
}

// ── Score row ─────────────────────────────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  final ProgressState progress;
  const _ScoreRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    final avg = progress.overallAverageScore;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF3B82F6),
            label: 'Average Score',
            value: '${(avg * 100).round()}%',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.quiz_outlined,
            color: const Color(0xFF6366F1),
            label: 'Total Attempts',
            value: '${progress.totalAttempts}',
          ),
        ),
      ],
    );
  }
}

// ── Phase row ─────────────────────────────────────────────────────────────────

class _PhaseRow extends StatelessWidget {
  final int phaseNumber;
  final List<DayContent> days;
  final ProgressState progress;
  const _PhaseRow({
    required this.phaseNumber,
    required this.days,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final cs         = Theme.of(context).colorScheme;
    final tt         = Theme.of(context).textTheme;
    final color      = phaseColor(phaseNumber);
    final name       = phaseName(phaseNumber);
    final total      = days.length;
    final completed  = days
        .where((d) => progress.statusFor(d.dayNumber) == DayStatus.completed)
        .length;
    final ratio      = total == 0 ? 0.0 : completed / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: tt.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$completed / $total',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Struggles card ────────────────────────────────────────────────────────────

class _StrugglesCard extends StatelessWidget {
  final List<StruggleRecord> struggles;
  const _StrugglesCard({required this.struggles});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu_rounded, size: 16, color: cs.error),
              const SizedBox(width: 6),
              Text(
                '${struggles.length} question${struggles.length == 1 ? '' : 's'} to review',
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onErrorContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...struggles.take(3).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'D${r.dayNumber}',
                        style: TextStyle(
                          color: cs.onError,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.prompt,
                        style: tt.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '×${r.failedAttempts}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.error,
                      ),
                    ),
                  ],
                ),
              )),
          if (struggles.length > 3) ...[
            const SizedBox(height: 4),
            Text(
              '+ ${struggles.length - 3} more — see Home Screen',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared stat card ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              Text(
                label,
                style: tt.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
    );
  }
}
