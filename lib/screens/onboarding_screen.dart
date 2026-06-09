import 'package:flutter/material.dart';
import '../widgets/progress_scope.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _PageData(
      gradient: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      icon: Icons.rocket_launch_rounded,
      title: '30 Days to\nInterview Ready',
      body: 'A structured curriculum that takes you from JavaScript fundamentals to system design and interview mastery — one day at a time.',
    ),
    _PageData(
      gradient: [Color(0xFF10B981), Color(0xFF3B82F6)],
      icon: Icons.psychology_rounded,
      title: 'Learn, Test\n& Verify',
      body: "Read each day's content, then take a reasoning test. You only move forward when you can explain the concept in your own words — not just recognise it.",
    ),
    _PageData(
      gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      icon: Icons.local_fire_department_rounded,
      title: 'Build the\nDaily Habit',
      body: 'Complete one test per day to keep your streak alive. Days are locked until the previous one is mastered. Review questions you struggled with from the home screen.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ProgressScope.of(context).completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _PageView(data: _pages[i]),
          ),
          // Dots + button overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    // Action button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _pages[_page].gradient.first,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _next,
                      child: Text(
                        _page == _pages.length - 1
                            ? "Let's Go"
                            : 'Next',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_page < _pages.length - 1) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: _finish,
                        child: const Text('Skip'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single page ───────────────────────────────────────────────────────────────

class _PageData {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String body;
  const _PageData({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _PageView extends StatelessWidget {
  final _PageData data;
  const _PageView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon bubble
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(data.icon, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 36),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data.body,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
