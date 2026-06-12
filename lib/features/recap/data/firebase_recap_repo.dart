import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/app_errors.dart';
import '../../../core/firebase_failure.dart';
import '../../../core/result.dart';
import '../domain/recap.dart';
import '../domain/recap_repo.dart';

class FirebaseRecapRepo implements RecapRepo {
  FirebaseRecapRepo(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('recaps');

  @override
  Stream<List<Recap>> watchRecaps() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Recap.fromFirestore).toList());

  @override
  Future<Result<String>> add(Recap recap) async {
    try {
      final ref = await _col.add({
        ...recap.toJson(),
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
  Future<Result<void>> update(Recap recap) async {
    try {
      await _col.doc(recap.id).update(recap.toJson());
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
