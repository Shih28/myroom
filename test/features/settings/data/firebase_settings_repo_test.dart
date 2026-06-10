import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/constants.dart';
import 'package:myroom/features/settings/data/firebase_settings_repo.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseSettingsRepo repo;
  const uid = 'userA';

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirebaseSettingsRepo(db, uid);
  });

  test('watchSettings emits defaults when the doc is absent', () async {
    final s = await repo.watchSettings().first;
    expect(s.autoEnrich, true);
    expect(s.tz, kDefaultTimezone);
    expect(s.tutorialSeen, false);
  });

  test('updateSettings merges a partial patch into settings/app', () async {
    await repo.updateSettings(selfIntro: '我是工程師', tutorialSeen: true);
    final s1 = await repo.watchSettings().first;
    expect(s1.selfIntro, '我是工程師');
    expect(s1.tutorialSeen, true);
    expect(s1.autoEnrich, true); // untouched → default preserved

    // A second partial patch must not clobber unrelated fields.
    await repo.updateSettings(autoEnrich: false);
    final s2 = await repo.watchSettings().first;
    expect(s2.autoEnrich, false);
    expect(s2.selfIntro, '我是工程師');
    expect(s2.tutorialSeen, true);
  });

  test('settings doc lives at the fixed `app` id', () async {
    await repo.updateSettings(rules: 'r');
    final doc = await db
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc(kSettingsDocId)
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['rules'], 'r');
  });

  test('settings are scoped per user', () async {
    await repo.updateSettings(selfIntro: 'private');
    final other = await FirebaseSettingsRepo(db, 'userB').watchSettings().first;
    expect(other.selfIntro, ''); // default — cannot read user A
  });
}
