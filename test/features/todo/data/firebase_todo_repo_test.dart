import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/constants.dart';
import 'package:myroom/core/result.dart';
import 'package:myroom/features/todo/data/firebase_todo_repo.dart';
import 'package:myroom/features/todo/domain/todo.dart';
import 'package:myroom/features/todo/domain/todo_category.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseTodoRepo repo;
  const uid = 'userA';

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirebaseTodoRepo(db, uid);
  });

  CollectionReference<Map<String, dynamic>> todosCol() =>
      db.collection('users').doc(uid).collection('todos');

  group('CRUD', () {
    test('add returns the new id and writes server timestamps', () async {
      final res = await repo.add(Todo(id: '', title: '寫測試'));
      expect(res, isA<Ok<String>>());
      final id = (res as Ok<String>).value;

      final doc = await todosCol().doc(id).get();
      expect(doc.data()!['title'], '寫測試');
      expect(doc.data()!['createdAt'], isA<Timestamp>());
      expect(doc.data()!['updatedAt'], isA<Timestamp>());
    });

    test('update mutates fields', () async {
      final id = (await repo.add(Todo(id: '', title: 'a')) as Ok<String>).value;
      await repo.update(Todo(id: id, title: 'b', isCompleted: true));
      final doc = await todosCol().doc(id).get();
      expect(doc.data()!['title'], 'b');
      expect(doc.data()!['isCompleted'], true);
    });

    test('delete removes the doc', () async {
      final id = (await repo.add(Todo(id: '', title: 'x')) as Ok<String>).value;
      await repo.delete(id);
      expect((await todosCol().doc(id).get()).exists, isFalse);
    });
  });

  group('watchTodos', () {
    test('streams todos ordered by sortOrder', () async {
      await todosCol().doc('t1').set({
        ...Todo(id: 't1', title: 'second', sortOrder: 1).toJson(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      await todosCol().doc('t2').set({
        ...Todo(id: 't2', title: 'first', sortOrder: 0).toJson(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      final todos = await repo.watchTodos().first;
      expect(todos.map((t) => t.title), ['first', 'second']);
    });
  });

  group('reorder', () {
    test('assigns dense 0..N-1 sortOrder in the given order', () async {
      final a = (await repo.add(Todo(id: '', title: 'A')) as Ok<String>).value;
      final b = (await repo.add(Todo(id: '', title: 'B')) as Ok<String>).value;
      final c = (await repo.add(Todo(id: '', title: 'C')) as Ok<String>).value;

      // New order: C, A, B
      final res = await repo.reorder([c, a, b]);
      expect(res, isA<Ok<void>>());

      expect((await todosCol().doc(c).get()).data()!['sortOrder'], 0);
      expect((await todosCol().doc(a).get()).data()!['sortOrder'], 1);
      expect((await todosCol().doc(b).get()).data()!['sortOrder'], 2);

      final ordered = await repo.watchTodos().first;
      expect(ordered.map((t) => t.title), ['C', 'A', 'B']);
    });
  });

  group('todo categories', () {
    test('the undefined sentinel is written with its fixed id', () async {
      await repo.addTodoCategory(
        const TodoCategory(
          id: kUndefinedCategoryId,
          label: '無分類',
          color: Color(0xFF9A8A7E),
        ),
      );
      final cats = db
          .collection('users')
          .doc(uid)
          .collection('todo_categories');
      expect((await cats.doc(kUndefinedCategoryId).get()).exists, isTrue);
    });

    test('a normal category gets an auto-id', () async {
      await repo.addTodoCategory(
        const TodoCategory(id: '', label: '工作', color: Color(0xFF7B9E87)),
      );
      final cats = await repo.watchTodoCategories().first;
      expect(cats, hasLength(1));
      expect(cats.first.label, '工作');
      expect(cats.first.id, isNot(kUndefinedCategoryId));
    });

    test('deleteTodoCategory removes only the category doc', () async {
      await repo.addTodoCategory(
        const TodoCategory(id: 'c1', label: 'x', color: Color(0xFF000000)),
      );
      // addTodoCategory auto-ids non-sentinels, so fetch the real id.
      final cat = (await repo.watchTodoCategories().first).first;
      await repo.deleteTodoCategory(cat.id);
      expect(await repo.watchTodoCategories().first, isEmpty);
    });
  });

  group('userId scoping', () {
    test('a repo for another uid cannot see this user\'s todos', () async {
      await repo.add(Todo(id: '', title: 'private'));
      final otherRepo = FirebaseTodoRepo(db, 'userB');
      expect(await otherRepo.watchTodos().first, isEmpty);
      expect(await repo.watchTodos().first, hasLength(1));
    });
  });
}
