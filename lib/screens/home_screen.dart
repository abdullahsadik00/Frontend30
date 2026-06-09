import 'package:flutter/material.dart';
import '../models/day_content.dart';
import '../models/progress_state.dart';
import '../services/curriculum_service.dart';
import '../widgets/progress_scope.dart';
import 'day_detail_screen.dart';

// ── Phase metadata ────────────────────────────────────────────────────────────

const _phaseColors = {
  1: Color(0xFFF59E0B), // amber  — JS
  2: Color(0xFF3B82F6), // blue   — TS
  3: Color(0xFF10B981), // emerald — React
  4: Color(0xFF8B5CF6), // violet — Next.js
  5: Color(0xFFEF4444), // red    — System Design
  6: Color(0xFFEC4899), // pink   — Interview
};

const _phaseNames = {
  1: 'JavaScript',
  2: 'TypeScript',
  3: 'React',
  4: 'Next.js',
  5: 'Sys Design',
  6: 'Interview',
};

Color phaseColor(int n) => _phaseColors[n] ?? const Color(0xFF6366F1);

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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return _Body(days: snapshot.data!);
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
    final cs = Theme.of(context).colorScheme;

    final columns = MediaQuery.of(context).size.width > 600 ? 5 : 3;

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
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: 'Reset progress',
              onPressed: () => _confirmReset(context, progress),
            ),
          ],
        ),

        // ── Progress header ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _ProgressHeader(progress: progress),
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
                final day = days[i];
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

  Future<void> _confirmReset(BuildContext context, ProgressState progress) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text('This will unlock only Day 1 and clear all completions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) await progress.reset();
  }
}

// ── Progress header ───────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final ProgressState progress;
  const _ProgressHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;
    final count   = progress.completedCount;
    final ratio   = progress.completionRatio;
    final phaseDone = ((count / 5).floor()).clamp(0, 6);

    return Container(
      color: cs.primary,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          // Animated circular indicator
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: cs.onPrimary.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(cs.onPrimary),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$count',
                        style: tt.titleLarge?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        '/ 30',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0
                      ? '30-Day Challenge'
                      : count == 30
                          ? 'Challenge Complete! 🎉'
                          : 'Keep Going!',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Start with Day 1'
                      : '$count day${count == 1 ? '' : 's'} completed · ${(ratio * 100).round()}%',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
                if (phaseDone > 0 && phaseDone <= 6) ...[
                  const SizedBox(height: 8),
                  Text(
                    'On Phase $phaseDone: ${_phaseNames[phaseDone] ?? ''}',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.7),
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
        children: _phaseNames.entries.map((e) {
          final color = phaseColor(e.key);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    final cs      = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;
    final color   = phaseColor(day.phaseNumber);
    final locked  = status == DayStatus.locked;
    final done    = status == DayStatus.completed;

    final bgColor = locked
        ? cs.surfaceContainerLow
        : color.withValues(alpha: 0.10);

    final borderColor = locked
        ? cs.outlineVariant
        : done
            ? color
            : color.withValues(alpha: 0.5);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: locked
            ? () => _showLockedSnack(context)
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DayDetailScreen(day: day, status: status),
                  ),
                ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: day number + status icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${day.dayNumber}',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: locked ? cs.onSurfaceVariant : color,
                      height: 1,
                    ),
                  ),
                  if (locked)
                    Icon(Icons.lock_outline, size: 14, color: cs.outlineVariant)
                  else if (done)
                    Icon(Icons.check_circle, size: 14, color: color),
                ],
              ),
              const Spacer(),
              // Topic
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
              // Phase color stripe
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

  void _showLockedSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Complete Day ${day.dayNumber - 1} first to unlock this day.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
