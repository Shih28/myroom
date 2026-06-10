import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/constants.dart';
import 'package:myroom/features/todo/data/firebase_todo_repo.dart';
import 'package:myroom/features/todo/domain/todo.dart';
import 'package:myroom/features/todo/domain/todo_repo.dart';
import 'package:myroom/features/todo/presentation/todo_page.dart';
import 'package:provider/provider.dart';

import '../../../support/widget_harness.dart';

void main() {
  const uid = 'userA';

  testWidgets('renders todos streamed from the repo', (tester) async {
    final db = FakeFirebaseFirestore();
    final todos = db.collection('users').doc(uid).collection('todos');
    await todos.doc('t1').set({
      ...Todo(id: 't1', title: '寫測試', sortOrder: 0).toJson(),
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    // The undefined sentinel category is expected to exist.
    await db
        .collection('users')
        .doc(uid)
        .collection('todo_categories')
        .doc(kUndefinedCategoryId)
        .set({'label': '無分類', 'colorVal': 0xFF9A8A7E, 'sortOrder': 0});

    await pumpPage(
      tester,
      const TodoPage(),
      providers: [Provider<TodoRepo>(create: (_) => FirebaseTodoRepo(db, uid))],
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('寫測試'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
