import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/sign_model.dart';
import '../services/progress_service.dart';
import 'detection_screen.dart';

class TutorScreen extends StatefulWidget {
  const TutorScreen({super.key});
  @override
  State<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends State<TutorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<String> _learned = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _learned = ProgressService.getLearned();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn Signs'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Letters A–Z'),
            Tab(text: 'Numbers 0–10'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _SignGrid(
            signs: SignModel.letters,
            learned: _learned,
            onLearn: _onLearn,
          ),
          _SignGrid(
            signs: SignModel.numbers,
            learned: _learned,
            onLearn: _onLearn,
          ),
        ],
      ),
    );
  }

  void _onLearn(String sign) {
    ProgressService.markLearned(sign);
    setState(() => _learned = ProgressService.getLearned());
  }
}

class _SignGrid extends StatelessWidget {
  final List<SignModel> signs;
  final List<String> learned;
  final void Function(String) onLearn;

  const _SignGrid({
    required this.signs,
    required this.learned,
    required this.onLearn,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: signs.length,
      itemBuilder: (context, i) {
        final sign = signs[i];
        final isLearned = learned.contains(sign.label);
        return _SignTile(
          sign: sign,
          isLearned: isLearned,
          onTap: () => _showSignDetail(context, sign, isLearned),
        );
      },
    );
  }

  void _showSignDetail(BuildContext context, SignModel sign, bool isLearned) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SignDetailSheet(
        sign: sign,
        isLearned: isLearned,
        onLearn: () {
          onLearn(sign.label);
          Navigator.pop(context);
        },
        onPractice: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DetectionScreen()),
          );
        },
      ),
    );
  }
}

class _SignTile extends StatelessWidget {
  final SignModel sign;
  final bool isLearned;
  final VoidCallback onTap;

  const _SignTile({
    required this.sign,
    required this.isLearned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isLearned
              ? AppTheme.primary.withValues(alpha: 0.08)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLearned
                ? AppTheme.primary.withValues(alpha: 0.4)
                : Colors.grey.shade200,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sign.label,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: isLearned ? AppTheme.primary : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sign.isMotion ? 'Motion' : 'Static',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (isLearned)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primary,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignDetailSheet extends StatelessWidget {
  final SignModel sign;
  final bool isLearned;
  final VoidCallback onLearn;
  final VoidCallback onPractice;

  const _SignDetailSheet({
    required this.sign,
    required this.isLearned,
    required this.onLearn,
    required this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Sign display
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                sign.label,
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            sign.description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),

          if (sign.isMotion) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gesture, color: AppTheme.accent, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'This sign involves hand motion',
                    style: TextStyle(color: AppTheme.accent, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPractice,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Practice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLearned ? null : onLearn,
                  icon: Icon(
                    isLearned ? Icons.check_rounded : Icons.school_rounded,
                  ),
                  label: Text(isLearned ? 'Learned' : 'Mark Learned'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
