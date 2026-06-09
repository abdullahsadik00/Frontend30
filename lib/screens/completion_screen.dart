import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../models/progress_state.dart';
import '../widgets/progress_scope.dart';
import 'stats_screen.dart';

class CompletionScreen extends StatefulWidget {
  const CompletionScreen({super.key});

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 6));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.08),
                    cs.surface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Trophy
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Text('🏆', style: TextStyle(fontSize: 56)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Challenge Complete!',
                          style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You finished the 30-day frontend interview\nprep challenge. That's real dedication.',
                          style: tt.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),

                        // Stats grid
                        _StatsGrid(progress: progress),
                        const SizedBox(height: 40),

                        // Buttons
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.of(context)
                              .popUntil((r) => r.isFirst),
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('Back to Dashboard'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StatsScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.bar_chart_rounded),
                          label: const Text('View Full Stats'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Confetti falls from top-center
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: 3.14 / 2,
              emissionFrequency: 0.04,
              numberOfParticles: 25,
              maxBlastForce: 35,
              minBlastForce: 15,
              gravity: 0.25,
              colors: const [
                Color(0xFFF59E0B),
                Color(0xFF10B981),
                Color(0xFF6366F1),
                Color(0xFFEC4899),
                Color(0xFF3B82F6),
                Color(0xFFEF4444),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final ProgressState progress;
  const _StatsGrid({required this.progress});

  @override
  Widget build(BuildContext context) {
    final avgScore = progress.overallAverageScore;
    final items = [
      _StatItem(
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
        label: 'Days Done',
        value: '30 / 30',
      ),
      _StatItem(
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFF59E0B),
        label: 'Best Streak',
        value: '${progress.bestStreak}d',
      ),
      _StatItem(
        icon: Icons.quiz_outlined,
        color: const Color(0xFF6366F1),
        label: 'Attempts',
        value: '${progress.totalAttempts}',
      ),
      _StatItem(
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF3B82F6),
        label: 'Avg Score',
        value: avgScore > 0 ? '${(avgScore * 100).round()}%' : '—',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _StatTile(item: items[i]),
    );
  }
}

class _StatItem {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
}

class _StatTile extends StatelessWidget {
  final _StatItem item;
  const _StatTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.value,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              Text(
                item.label,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
