import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/recap/domain/achievement.dart';
import 'package:myroom/features/recap/domain/recap.dart';

import '../../../support/firestore_helpers.dart';

void main() {
  group('Recap', () {
    test('toJson omits fn-only exportStoragePath and createdAt', () {
      final recap = Recap(
        id: 'r1',
        title: '六月',
        content: '充滿喜悅',
        exportStoragePath: 'should/not/serialize.svg',
        createdAt: DateTime.utc(2026),
      );
      expect(recap.toJson(), {'title': '六月', 'content': '充滿喜悅'});
    });

    test('fromFirestore reads fn-written exportStoragePath', () async {
      final snap = await snapshotOf({
        'title': '六月',
        'content': 'c',
        'exportStoragePath': 'users/u/exports/r1.svg',
        'createdAt': ts2026,
      }, id: 'r1');
      final recap = Recap.fromFirestore(snap);
      expect(recap.id, 'r1');
      expect(recap.title, '六月');
      expect(recap.exportStoragePath, 'users/u/exports/r1.svg');
      expect(recap.createdAt, ts2026.toDate());
    });

    test('content defaults to empty string', () async {
      final snap = await snapshotOf({'title': 't', 'createdAt': ts2026});
      expect(Recap.fromFirestore(snap).content, '');
    });
  });

  group('Achievement', () {
    test('toJson emits the three era contents only', () {
      final a = Achievement(
        id: 'a1',
        pastContent: '過去',
        currentContent: '現在',
        futureContent: '未來',
        pastExportStoragePath: 'x',
        createdAt: DateTime.utc(2026),
      );
      expect(a.toJson(), {
        'pastContent': '過去',
        'currentContent': '現在',
        'futureContent': '未來',
      });
    });

    test('fromFirestore reads per-era export paths', () async {
      final snap = await snapshotOf({
        'pastContent': '過去',
        'currentContent': '現在',
        'futureContent': '未來',
        'pastExportStoragePath': 'p.svg',
        'futureExportStoragePath': 'f.svg',
        'createdAt': ts2026,
      }, id: 'a1');
      final a = Achievement.fromFirestore(snap);
      expect(a.pastContent, '過去');
      expect(a.pastExportStoragePath, 'p.svg');
      expect(a.currentExportStoragePath, isNull);
      expect(a.futureExportStoragePath, 'f.svg');
    });

    test('copyWith preserves id, createdAt and export paths', () {
      final a = Achievement(
        id: 'a1',
        pastContent: 'p',
        pastExportStoragePath: 'p.svg',
        createdAt: DateTime.utc(2026),
      );
      final a2 = a.copyWith(currentContent: 'now');
      expect(a2.id, 'a1');
      expect(a2.pastContent, 'p');
      expect(a2.currentContent, 'now');
      expect(a2.pastExportStoragePath, 'p.svg');
      expect(a2.createdAt, DateTime.utc(2026));
    });
  });
}
