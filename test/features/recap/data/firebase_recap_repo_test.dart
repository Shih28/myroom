import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/result.dart';
import 'package:myroom/features/recap/data/firebase_achievement_repo.dart';
import 'package:myroom/features/recap/data/firebase_recap_repo.dart';
import 'package:myroom/features/recap/domain/achievement.dart';
import 'package:myroom/features/recap/domain/recap.dart';

void main() {
  late FakeFirebaseFirestore db;
  const uid = 'userA';

  setUp(() => db = FakeFirebaseFirestore());

  group('FirebaseRecapRepo', () {
    late FirebaseRecapRepo repo;
    setUp(() => repo = FirebaseRecapRepo(db, uid));

    CollectionReference<Map<String, dynamic>> col() =>
        db.collection('users').doc(uid).collection('recaps');

    test(
      'add writes title/content + server createdAt (no exportStoragePath)',
      () async {
        final res = await repo.add(
          Recap(id: '', title: '六月', content: 'c', createdAt: DateTime.now()),
        );
        final id = (res as Ok<String>).value;
        final doc = await col().doc(id).get();
        expect(doc.data()!['title'], '六月');
        expect(doc.data()!['createdAt'], isA<Timestamp>());
        expect(doc.data()!.containsKey('exportStoragePath'), isFalse);
      },
    );

    test('watchRecaps streams newest-first', () async {
      await col().doc('a').set({
        'title': 'old',
        'content': '',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      await col().doc('b').set({
        'title': 'new',
        'content': '',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 2, 1)),
      });
      final recaps = await repo.watchRecaps().first;
      expect(recaps.map((r) => r.title), ['new', 'old']);
    });

    test('update + delete', () async {
      final id =
          (await repo.add(Recap(id: '', title: 't', createdAt: DateTime.now()))
                  as Ok<String>)
              .value;
      await repo.update(Recap(id: id, title: 't2', createdAt: DateTime.now()));
      expect((await col().doc(id).get()).data()!['title'], 't2');
      await repo.delete(id);
      expect((await col().doc(id).get()).exists, isFalse);
    });
  });

  group('FirebaseAchievementRepo', () {
    late FirebaseAchievementRepo repo;
    setUp(() => repo = FirebaseAchievementRepo(db, uid));

    CollectionReference<Map<String, dynamic>> col() =>
        db.collection('users').doc(uid).collection('achievements');

    test('add writes the three era contents + server createdAt', () async {
      final res = await repo.add(
        Achievement(
          id: '',
          pastContent: 'p',
          currentContent: 'n',
          futureContent: 'f',
          createdAt: DateTime.now(),
        ),
      );
      final id = (res as Ok<String>).value;
      final doc = await col().doc(id).get();
      expect(doc.data()!['pastContent'], 'p');
      expect(doc.data()!['futureContent'], 'f');
      expect(doc.data()!.containsKey('pastExportStoragePath'), isFalse);
    });

    test('update via copyWith persists changed era only', () async {
      final id =
          (await repo.add(
                    Achievement(
                      id: '',
                      pastContent: 'p',
                      createdAt: DateTime.now(),
                    ),
                  )
                  as Ok<String>)
              .value;
      final current = (await repo.watchAchievements().first).first;
      await repo.update(current.copyWith(currentContent: '現在進行式'));
      final doc = await col().doc(id).get();
      expect(doc.data()!['currentContent'], '現在進行式');
      expect(doc.data()!['pastContent'], 'p');
    });
  });

  test('recaps & achievements are scoped per user', () async {
    await FirebaseRecapRepo(
      db,
      uid,
    ).add(Recap(id: '', title: 'mine', createdAt: DateTime.now()));
    expect(await FirebaseRecapRepo(db, 'userB').watchRecaps().first, isEmpty);
  });
}
