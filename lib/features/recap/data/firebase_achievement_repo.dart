import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/app_errors.dart';
import '../../../core/firebase_failure.dart';
import '../../../core/result.dart';
import '../domain/achievement.dart';
import '../domain/achievement_repo.dart';

class FirebaseAchievementRepo implements AchievementRepo {
  FirebaseAchievementRepo(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('achievements');

  @override
  Stream<List<Achievement>> watchAchievements() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Achievement.fromFirestore).toList());

  @override
  Future<Result<String>> add(Achievement achievement) async {
    try {
      final ref = await _col.add({
        ...achievement.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Ok(ref.id);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }

  @override
  Future<Result<void>> update(Achievement achievement) async {
    try {
      await _col.doc(achievement.id).update(achievement.toJson());
      return const Ok(null);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _col.doc(id).delete();
      return const Ok(null);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }
}
