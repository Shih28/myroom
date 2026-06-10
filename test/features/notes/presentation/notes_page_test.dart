import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/notes/data/firebase_note_repo.dart';
import 'package:myroom/features/notes/domain/note_repo.dart';
import 'package:myroom/features/notes/presentation/notes_page.dart';
import 'package:myroom/shared/storage/storage_repo.dart';
import 'package:provider/provider.dart';

import '../../../support/fakes.dart';
import '../../../support/widget_harness.dart';

void main() {
  const uid = 'userA';

  testWidgets('builds and streams note dateKeys without error', (tester) async {
    final db = FakeFirebaseFirestore();
    final storage = FakeStorageRepo();
    await db.collection('users').doc(uid).collection('notes').doc('n1').set({
      'dateKey': '2026-06-10',
      'title': '無標題',
      'content': '今天的筆記',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    await pumpPage(
      tester,
      const NotesPage(),
      providers: [
        Provider<StorageRepo>.value(value: storage),
        Provider<NoteRepo>(create: (_) => FirebaseNoteRepo(db, uid, storage)),
      ],
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(NotesPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
