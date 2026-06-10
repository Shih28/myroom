import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/ideas/domain/idea.dart';
import 'package:myroom/features/ideas/domain/pinned_resource.dart';

import '../../../support/firestore_helpers.dart';

void main() {
  group('Idea', () {
    test('toJson exposes only the client-writable text field', () {
      final idea = Idea(
        id: 'i1',
        text: '做一個 App',
        aiSummary: 'should not serialize',
        aiStatus: 'completed',
        links: const [IdeaLink(title: 't', url: 'u')],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(idea.toJson(), {'text': '做一個 App'});
    });

    test('fromFirestore reads fn-written enrichment fields + links', () async {
      final snap = await snapshotOf({
        'text': '靈感',
        'aiSummary': '很棒的點子',
        'aiStatus': 'completed',
        'links': [
          {'title': 'Flutter', 'url': 'https://flutter.dev'},
          {'title': 'Dart', 'url': 'https://dart.dev'},
        ],
        'createdAt': ts2026,
        'updatedAt': ts2026,
      }, id: 'idea3');
      final idea = Idea.fromFirestore(snap);
      expect(idea.id, 'idea3');
      expect(idea.text, '靈感');
      expect(idea.aiSummary, '很棒的點子');
      expect(idea.aiStatus, 'completed');
      expect(idea.links, hasLength(2));
      expect(idea.links.first.title, 'Flutter');
      expect(idea.links.first.url, 'https://flutter.dev');
    });

    test(
      'fromFirestore defaults: aiStatus none, no summary, empty links',
      () async {
        final snap = await snapshotOf({'text': 'x'});
        final idea = Idea.fromFirestore(snap);
        expect(idea.aiStatus, 'none');
        expect(idea.aiSummary, isNull);
        expect(idea.links, isEmpty);
      },
    );
  });

  group('PinnedResource', () {
    test('toJson omits createdAt (repo injects it)', () {
      final r = PinnedResource(
        id: 'p1',
        title: 'Clean Code',
        type: '書籍',
        description: 'd',
        url: 'https://example.com',
        sortOrder: 1.5,
        createdAt: DateTime.utc(2026),
      );
      final json = r.toJson();
      expect(json, {
        'title': 'Clean Code',
        'type': '書籍',
        'description': 'd',
        'url': 'https://example.com',
        'sortOrder': 1.5,
      });
      expect(json.containsKey('createdAt'), isFalse);
    });

    test('fromFirestore coerces sortOrder to double', () async {
      final snap = await snapshotOf({
        'title': 't',
        'type': '文章',
        'description': 'd',
        'url': 'u',
        'sortOrder': 3, // int in Firestore → double in model
        'createdAt': ts2026,
      }, id: 'p9');
      final r = PinnedResource.fromFirestore(snap);
      expect(r.id, 'p9');
      expect(r.sortOrder, 3.0);
      expect(r.sortOrder, isA<double>());
    });
  });
}
