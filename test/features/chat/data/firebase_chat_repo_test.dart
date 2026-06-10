import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/chat/data/firebase_chat_repo.dart';
import 'package:myroom/features/chat/domain/chat_repo.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseChatRepo repo;
  const uid = 'userA';

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirebaseChatRepo(db, uid);
  });

  CollectionReference<Map<String, dynamic>> chatCol() =>
      db.collection('users').doc(uid).collection('chat_messages');

  /// Seeds [n] messages m0..m(n-1) with strictly increasing createdAt.
  Future<void> seed(int n) async {
    final base = DateTime.utc(2026, 1, 1);
    for (var i = 0; i < n; i++) {
      await chatCol().doc('m$i').set({
        'role': i.isEven ? 'user' : 'assistant',
        'content': 'msg$i',
        'createdAt': Timestamp.fromDate(base.add(Duration(minutes: i))),
      });
    }
  }

  test('watchMessages returns the latest 50 in chronological order', () async {
    await seed(60);
    final msgs = await repo.watchMessages().first;
    expect(msgs, hasLength(ChatRepo.pageSize)); // 50
    // Latest 50 = m10..m59, displayed oldest → newest.
    expect(msgs.first.content, 'msg10');
    expect(msgs.last.content, 'msg59');
  });

  test('loadOlder pages the next batch older than the cursor', () async {
    await seed(60);
    final tail = await repo.watchMessages().first; // m10..m59
    final older = await repo.loadOlder(tail.first); // older than m10

    expect(older, hasLength(10)); // m0..m9
    expect(older.first.content, 'msg0');
    expect(older.last.content, 'msg9');
    // < pageSize signals the UI that the thread start has been reached.
    expect(older.length < ChatRepo.pageSize, isTrue);
  });

  test('loadOlder returns empty at the start of the thread', () async {
    await seed(3);
    final tail = await repo.watchMessages().first; // m0..m2
    final older = await repo.loadOlder(tail.first);
    expect(older, isEmpty);
  });

  test('messages are read-only & scoped per user', () async {
    await seed(2);
    final otherRepo = FirebaseChatRepo(db, 'userB');
    expect(await otherRepo.watchMessages().first, isEmpty);

    final mine = await repo.watchMessages().first;
    expect(mine.map((m) => m.isUser), [true, false]); // m0 user, m1 assistant
  });
}
