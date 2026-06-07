import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/app_errors.dart';
import '../../../core/constants.dart';
import '../../../core/firebase_failure.dart';
import '../../../core/result.dart';
import '../domain/todo.dart';
import '../domain/todo_category.dart';
import '../domain/todo_repo.dart';

class FirebaseTodoRepo implements TodoRepo {
  FirebaseTodoRepo(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('todos');

  CollectionReference<Map<String, dynamic>> get _catCol =>
      _db.collection('users').doc(_uid).collection('todo_categories');

  // ── Todos ────────────────────────────────────────────────────────────────
  @override
  Stream<List<Todo>> watchTodos() => _col
      .orderBy('sortOrder')
      .snapshots()
      .map((s) => s.docs.map(Todo.fromFirestore).toList());

  @override
  Future<Result<String>> add(Todo todo) async {
    try {
      final ref = await _col.add({
        ...todo.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return Ok(ref.id);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }

  @override
  Future<Result<void>> update(Todo todo) async {
    try {
      await _col.doc(todo.id).update({
        ...todo.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  @override
  Future<Result<void>> reorder(List<String> orderedIds) async {
    try {
      final batch = _db.batch();
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(_col.doc(orderedIds[i]), {
          'sortOrder': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      return const Ok(null);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }

  // ── Todo categories ────────────────────────────────────────────────────────
  @override
  Stream<List<TodoCategory>> watchTodoCategories() => _catCol
      .orderBy('sortOrder')
      .snapshots()
      .map((s) => s.docs.map(TodoCategory.fromFirestore).toList());

  @override
  Future<Result<void>> addTodoCategory(TodoCategory category) async {
    try {
      // Auto-id, unless this is the "無分類" sentinel (fixed id).
      if (category.id == kUndefinedCategoryId) {
        await _catCol.doc(kUndefinedCategoryId).set(category.toJson());
      } else {
        await _catCol.add(category.toJson());
      }
      return const Ok(null);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }

  @override
  Future<Result<void>> updateTodoCategory(TodoCategory category) async {
    try {
      await _catCol.doc(category.id).update(category.toJson());
      return const Ok(null);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }

  @override
  Future<Result<void>> deleteTodoCategory(String id) async {
    // Deletes ONLY the category doc; `categoryFanout` reassigns affected todos.
    try {
      await _catCol.doc(id).delete();
      return const Ok(null);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }
}
