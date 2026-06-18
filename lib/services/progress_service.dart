import 'package:hive/hive.dart';

class ProgressService {
  static Box get _box => Hive.box('progress');

  // Mark a sign as learned
  static void markLearned(String sign) {
    final learned = getLearned();
    if (!learned.contains(sign)) {
      learned.add(sign);
      _box.put('learned', learned);
    }
  }

  // Get all learned signs
  static List<String> getLearned() {
    return List<String>.from(_box.get('learned', defaultValue: []));
  }

  // Record a quiz result
  static void recordQuizResult(String sign, bool correct) {
    final key = 'quiz_$sign';
    final current = Map<String, int>.from(
      _box.get(key, defaultValue: {'correct': 0, 'wrong': 0}),
    );
    if (correct) {
      current['correct'] = (current['correct'] ?? 0) + 1;
    } else {
      current['wrong'] = (current['wrong'] ?? 0) + 1;
    }
    _box.put(key, current);
  }

  // Get accuracy for a specific sign
  static double getAccuracy(String sign) {
    final data = Map<String, int>.from(
      _box.get('quiz_$sign', defaultValue: {'correct': 0, 'wrong': 0}),
    );
    final total = (data['correct'] ?? 0) + (data['wrong'] ?? 0);
    if (total == 0) return 0.0;
    return (data['correct'] ?? 0) / total;
  }

  // Overall progress percentage
  static double get overallProgress {
    const totalSigns = 37;
    return getLearned().length / totalSigns;
  }

  // Streak tracking
  static int get currentStreak => _box.get('streak', defaultValue: 0);

  static void updateStreak() {
    final last = _box.get('last_practice');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (last == today) return;
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    if (last == yesterday) {
      _box.put('streak', currentStreak + 1);
    } else {
      _box.put('streak', 1);
    }
    _box.put('last_practice', today);
  }
}
