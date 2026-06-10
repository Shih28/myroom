import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/result.dart';
import 'package:myroom/features/ideas/data/firebase_idea_repo.dart';
import 'package:myroom/features/ideas/domain/pinned_resource.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseIdeaRepo repo;
  const uid = 'userA';

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirebaseIdeaRepo(db, uid);
  });

  // Subcollections live under the fixed `ideas/data` parent doc.
  CollectionReference<Map<String, dynamic>> ideasCol() => db
      .collection('users')
      .doc(uid)
      .collection('ideas')
      .doc('data')
      .collection('user_ideas');

  CollectionReference<Map<String, dynamic>> pinnedCol() => db
      .collection('users')
      .doc(uid)
      .collection('ideas')
      .doc('data')
      .collection('pinned_resources');

  group('ideas', () {
    test(
      'add writes only {text} + timestamps under ideas/data/user_ideas',
      () async {
        final res = await repo.add('學 Rust');
        expect(res, isA<Ok<String>>());
        final id = (res as Ok<String>).value;
        final doc = await ideasCol().doc(id).get();
        expect(doc.data()!['text'], '學 Rust');
        expect(doc.data()!['createdAt'], isA<Timestamp>());
        // The client must NOT write fn-only enrichment fields.
        expect(doc.data()!.containsKey('aiSummary'), isFalse);
        expect(doc.data()!.containsKey('aiStatus'), isFalse);
      },
    );

    test('updateText changes the text', () async {
      final id = (await repo.add('a') as Ok<String>).value;
      await repo.updateText(id, 'b');
      expect((await ideasCol().doc(id).get()).data()!['text'], 'b');
    });

    test('watchIdeas streams newest-first', () async {
      await ideasCol().doc('old').set({
        'text': 'old',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      await ideasCol().doc('new').set({
        'text': 'new',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 2, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 2, 1)),
      });
      final ideas = await repo.watchIdeas().first;
      expect(ideas.map((i) => i.text), ['new', 'old']);
    });

    test('delete removes the idea', () async {
      final id = (await repo.add('x') as Ok<String>).value;
      await repo.delete(id);
      expect((await ideasCol().doc(id).get()).exists, isFalse);
    });
  });

  group('pinned resources', () {
    PinnedResource res(String url) => PinnedResource(
      id: '',
      title: 't',
      type: '文章',
      description: 'd',
      url: url,
      createdAt: DateTime.now(),
    );

    test('pin uses sha1(url) as the doc id (dedupe on re-pin)', () async {
      const url = 'https://example.com/a';
      final expectedId = sha1.convert(utf8.encode(url)).toString();

      await repo.pin(res(url));
      await repo.pin(res(url)); // same url → same doc, no duplicate

      final all = await pinnedCol().get();
      expect(all.docs, hasLength(1));
      expect(all.docs.first.id, expectedId);
    });

    test('unpin deletes by url hash', () async {
      const url = 'https://example.com/b';
      await repo.pin(res(url));
      expect(await repo.watchPinnedResources().first, hasLength(1));
      await repo.unpin(url);
      expect(await repo.watchPinnedResources().first, isEmpty);
    });
  });

  test('ideas are scoped per user', () async {
    await repo.add('private');
    final otherRepo = FirebaseIdeaRepo(db, 'userB');
    expect(await otherRepo.watchIdeas().first, isEmpty);
  });
}
