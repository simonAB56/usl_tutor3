import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme/app_theme.dart';
import '../services/progress_service.dart';
import 'detection_screen.dart';
import 'tutor_screen.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    ProgressService.updateStreak();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressService.overallProgress;
    final streak = ProgressService.currentStreak;
    final learned = ProgressService.getLearned().length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'USL Tutor',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                      ),
                      Text(
                        'Ugandan Sign Language',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                  _StreakBadge(streak: streak),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ── Progress card ─────────────────────────────────────────
              _ProgressCard(
                progress: progress,
                learned: learned,
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              Text(
                'What would you like to do?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 16),

              // ── Menu cards ────────────────────────────────────────────
              _MenuCard(
                icon: Icons.camera_alt_rounded,
                title: 'Live Detection',
                subtitle: 'Point camera at a hand sign',
                color: AppTheme.primary,
                delay: 300,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DetectionScreen()),
                ),
              ),

              const SizedBox(height: 12),

              _MenuCard(
                icon: Icons.school_rounded,
                title: 'Learn Signs',
                subtitle: 'Browse and learn all 37 USL signs',
                color: AppTheme.secondary,
                delay: 400,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TutorScreen()),
                ),
              ),

              const SizedBox(height: 12),

              _MenuCard(
                icon: Icons.quiz_rounded,
                title: 'Practice Quiz',
                subtitle: 'Test your knowledge in real time',
                color: AppTheme.accent,
                delay: 500,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuizScreen()),
                ),
              ),

              const SizedBox(height: 24),

              // ── Stats row ─────────────────────────────────────────────
              _StatsRow(learned: learned).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final double progress;
  final int learned;
  const _ProgressCard({required this.progress, required this.learned});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF0F6E56)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '$learned / 37 signs learned',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          LinearPercentIndicator(
            lineHeight: 10,
            percent: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white24,
            progressColor: Colors.white,
            barRadius: const Radius.circular(8),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% complete',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final int delay;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: const Duration(milliseconds: 0))
        .slideX(begin: 0.05);
  }
}

class _StatsRow extends StatelessWidget {
  final int learned;
  const _StatsRow({required this.learned});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _StatBox(label: 'Letters', value: '26', icon: Icons.abc_rounded),
        const SizedBox(width: 12),
        const _StatBox(
            label: 'Numbers', value: '11', icon: Icons.numbers_rounded),
        const SizedBox(width: 12),
        _StatBox(
          label: 'Learned',
          value: '$learned',
          icon: Icons.check_circle_rounded,
          highlight: true,
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? AppTheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: highlight ? AppTheme.primary : AppTheme.textMuted,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: highlight ? AppTheme.primary : AppTheme.textDark,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
