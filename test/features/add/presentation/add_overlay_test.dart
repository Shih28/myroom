import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/add/presentation/add_overlay.dart';
import 'package:myroom/features/calendar/data/firebase_event_repo.dart';
import 'package:myroom/features/calendar/domain/event_repo.dart';
import 'package:myroom/features/ideas/data/firebase_idea_repo.dart';
import 'package:myroom/features/ideas/domain/idea_repo.dart';
import 'package:myroom/features/notes/data/firebase_note_repo.dart';
import 'package:myroom/features/notes/domain/note_repo.dart';
import 'package:myroom/features/recap/data/firebase_recap_repo.dart';
import 'package:myroom/features/recap/domain/recap_repo.dart';
import 'package:myroom/features/todo/data/firebase_todo_repo.dart';
import 'package:myroom/features/todo/domain/todo_repo.dart';
import 'package:myroom/shared/ai/domain/ai_service.dart';
import 'package:myroom/shared/storage/storage_repo.dart';
import 'package:provider/provider.dart';

import '../../../support/fakes.dart';
import '../../../support/widget_harness.dart';

void main() {
  const uid = 'userA';

  testWidgets('renders the Smart Add input prompt', (tester) async {
    final db = FakeFirebaseFirestore();
    final storage = FakeStorageRepo();
    await pumpPage(
      tester,
      const AddOverlay(),
      providers: [
        Provider<AiService>(create: (_) => FakeAiService()),
        Provider<StorageRepo>.value(value: storage),
        Provider<TodoRepo>(create: (_) => FirebaseTodoRepo(db, uid)),
        Provider<EventRepo>(create: (_) => FirebaseEventRepo(db, uid)),
        Provider<IdeaRepo>(create: (_) => FirebaseIdeaRepo(db, uid)),
        Provider<NoteRepo>(create: (_) => FirebaseNoteRepo(db, uid, storage)),
        Provider<RecapRepo>(create: (_) => FirebaseRecapRepo(db, uid)),
      ],
    );

    expect(find.byType(AddOverlay), findsOneWidget);
    expect(find.text('智慧新增'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
