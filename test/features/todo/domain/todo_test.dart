import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/constants.dart';
import 'package:myroom/features/todo/domain/todo.dart';
import 'package:myroom/features/todo/domain/todo_category.dart';

import '../../../support/firestore_helpers.dart';

void main() {
  group('TodoCategoryRef', () {
    test('undefined sentinel has fixed id/label/color', () {
      expect(TodoCategoryRef.undefined.id, kUndefinedCategoryId);
      expect(TodoCategoryRef.undefined.label, '無分類');
      expect(TodoCategoryRef.undefined.color.toARGB32(), 0xFF9A8A7E);
    });

    test('toMap/fromMap round-trip', () {
      const ref = TodoCategoryRef(
        id: 'c1',
        label: '工作',
        color: Color(0xFF7B9E87),
      );
      final map = ref.toMap();
      expect(map, {'id': 'c1', 'label': '工作', 'colorVal': 0xFF7B9E87});
      final back = TodoCategoryRef.fromMap(map);
      expect(back.id, 'c1');
      expect(back.label, '工作');
      expect(back.color.toARGB32(), 0xFF7B9E87);
    });

    test('fromMap(null) yields the undefined sentinel', () {
      final ref = TodoCategoryRef.fromMap(null);
      expect(ref.id, kUndefinedCategoryId);
      expect(ref.label, '無分類');
    });
  });

  group('Todo', () {
    test('toJson emits only client-writable fields (no timestamps)', () {
      final todo = Todo(
        id: 't1',
        title: '寫程式',
        isCompleted: true,
        sortOrder: 3,
        category: const TodoCategoryRef(
          id: 'c1',
          label: '工作',
          color: Color(0xFF7B9E87),
        ),
      );
      final json = todo.toJson();
      expect(json['title'], '寫程式');
      expect(json['isCompleted'], true);
      expect(json['sortOrder'], 3);
      expect(json['category'], {
        'id': 'c1',
        'label': '工作',
        'colorVal': 0xFF7B9E87,
      });
      expect(json.containsKey('createdAt'), isFalse);
      expect(json.containsKey('updatedAt'), isFalse);
    });

    test(
      'fromFirestore round-trips and defaults category to undefined',
      () async {
        final snap = await snapshotOf({
          'title': '無分類待辦',
          'sortOrder': 5,
          'createdAt': ts2026,
          'updatedAt': ts2026,
        }, id: 'todo7');
        final todo = Todo.fromFirestore(snap);
        expect(todo.id, 'todo7');
        expect(todo.title, '無分類待辦');
        expect(todo.isCompleted, false);
        expect(todo.sortOrder, 5);
        expect(todo.category.id, kUndefinedCategoryId);
        expect(todo.createdAt, ts2026.toDate());
      },
    );
  });

  group('TodoCategory', () {
    test('toJson + fromFirestore round-trip (no iconName)', () async {
      const cat = TodoCategory(
        id: 'c1',
        label: '生活',
        color: Color(0xFFC5956A),
        sortOrder: 2,
      );
      final json = cat.toJson();
      expect(json, {'label': '生活', 'colorVal': 0xFFC5956A, 'sortOrder': 2});
      expect(json.containsKey('iconName'), isFalse);

      final snap = await snapshotOf(json, id: 'c1');
      final back = TodoCategory.fromFirestore(snap);
      expect(back.id, 'c1');
      expect(back.label, '生活');
      expect(back.color.toARGB32(), 0xFFC5956A);
      expect(back.sortOrder, 2);
    });
  });
}
