import '../../../core/result.dart';
import 'achievement.dart';

abstract class AchievementRepo {
  /// Streams `users/{uid}/achievements`, newest first.
  Stream<List<Achievement>> watchAchievements();

  /// Creates an achievement; returns the new doc id.
  Future<Result<String>> add(Achievement achievement);

  Future<Result<void>> update(Achievement achievement);

  Future<Result<void>> delete(String id);
}
