import 'package:fl_chart/fl_chart.dart';
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

        // ── Score row + chart ─────────────────────────────────────────────
        if (progress.totalAttempts > 0) ...[
          _SectionLabel(label: 'Verification Scores'),
          const SizedBox(height: 8),
          _ScoreRow(progress: progress),
          const SizedBox(height: 12),
          _ScoreChart(progress: progress),
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

// ── Score history chart ───────────────────────────────────────────────────────

class _ScoreChart extends StatefulWidget {
  final ProgressState progress;
  const _ScoreChart({required this.progress});

  @override
  State<_ScoreChart> createState() => _ScoreChartState();
}

class _ScoreChartState extends State<_ScoreChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Build avg-score spots for days that have at least one attempt.
    final spots = <FlSpot>[];
    for (int d = 1; d <= 30; d++) {
      final scores = widget.progress.scoresFor(d);
      if (scores.isNotEmpty) {
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        spots.add(FlSpot(d.toDouble(), (avg * 100).roundToDouble()));
      }
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    final minX = spots.first.x;
    final maxX = spots.last.x;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 10),
            child: Row(
              children: [
                Icon(Icons.show_chart_rounded,
                    size: 14, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Score History',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                ),
                const Spacer(),
                Container(
                  width: 20,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 4),
                Text('40% pass',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: 0,
                maxY: 100,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: spots.length <= 5 ? 1 : 5,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'D${value.toInt()}',
                            style: TextStyle(
                                fontSize: 9,
                                color: cs.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: TextStyle(
                            fontSize: 9, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  // Score line
                  LineChartBarData(
                    spots: spots,
                    isCurved: spots.length > 2,
                    curveSmoothness: 0.3,
                    color: cs.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: _touchedIndex == index ? 5 : 3,
                            color: cs.primary,
                            strokeWidth: 2,
                            strokeColor: cs.surface,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.primary.withValues(alpha: 0.18),
                          cs.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                  // Dashed 40% threshold line
                  LineChartBarData(
                    spots: [FlSpot(minX, 40), FlSpot(maxX, 40)],
                    isCurved: false,
                    color: Colors.orange.withValues(alpha: 0.65),
                    barWidth: 1.5,
                    dashArray: [5, 4],
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchCallback: (event, response) {
                    final idx = response?.lineBarSpots?.first.spotIndex;
                    if (idx != _touchedIndex) {
                      setState(() => _touchedIndex = idx);
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => cs.inverseSurface,
                    getTooltipItems: (touchedSpots) =>
                        touchedSpots.map((spot) {
                      if (spot.barIndex != 0) return null;
                      return LineTooltipItem(
                        'Day ${spot.x.toInt()}\n${spot.y.toStringAsFixed(0)}%',
                        TextStyle(
                          color: cs.onInverseSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
