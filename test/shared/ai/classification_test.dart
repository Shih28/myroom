import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/shared/ai/domain/ai_resource.dart';
import 'package:myroom/shared/ai/domain/classification.dart';

void main() {
  group('ClassificationItem.fromJson — discriminator + 5 item types', () {
    test('todo', () {
      final item = ClassificationItem.fromJson({
        'type': 'todo',
        'text': '買牛奶',
        'catId': 'cat1',
      });
      expect(item, isA<ClassifiedTodo>());
      final t = item as ClassifiedTodo;
      expect(t.text, '買牛奶');
      expect(t.catId, 'cat1');
    });

    test('todo defaults catId to "undefined" when missing', () {
      final item =
          ClassificationItem.fromJson({'type': 'todo', 'text': 'x'})
              as ClassifiedTodo;
      expect(item.catId, 'undefined');
    });

    test(
      'todo_with_time parses {year,month,day,hour,minute} as local wall-clock',
      () {
        final item =
            ClassificationItem.fromJson({
                  'type': 'todo_with_time',
                  'text': '開會',
                  'catId': 'work',
                  'start': {
                    'year': 2026,
                    'month': 6,
                    'day': 9,
                    'hour': 14,
                    'minute': 30,
                  },
                  'end': {
                    'year': 2026,
                    'month': 6,
                    'day': 9,
                    'hour': 15,
                    'minute': 0,
                  },
                })
                as ClassifiedTodoWithTime;
        expect(item.text, '開會');
        expect(item.catId, 'work');
        expect(item.start, DateTime(2026, 6, 9, 14, 30));
        expect(item.end, DateTime(2026, 6, 9, 15, 0));
      },
    );

    test('idea', () {
      final item =
          ClassificationItem.fromJson({'type': 'idea', 'text': '寫一本書'})
              as ClassifiedIdea;
      expect(item.text, '寫一本書');
    });

    test('note with attachment indices', () {
      final item =
          ClassificationItem.fromJson({
                'type': 'note',
                'dateKey': '2026-06-09',
                'noteCatId': 'travel',
                'content': '旅行筆記',
                'attachmentIndices': [0, 2],
              })
              as ClassifiedNote;
      expect(item.dateKey, '2026-06-09');
      expect(item.noteCatId, 'travel');
      expect(item.content, '旅行筆記');
      expect(item.attachmentIndices, [0, 2]);
    });

    test('note defaults: empty indices + "undefined" category', () {
      final item =
          ClassificationItem.fromJson({'type': 'note', 'content': 'x'})
              as ClassifiedNote;
      expect(item.noteCatId, 'undefined');
      expect(item.attachmentIndices, isEmpty);
    });

    test('recap', () {
      final item =
          ClassificationItem.fromJson({
                'type': 'recap',
                'title': '六月回顧',
                'description': '充實的一個月',
              })
              as ClassifiedRecap;
      expect(item.title, '六月回顧');
      expect(item.description, '充實的一個月');
    });

    test('unknown discriminator returns null', () {
      expect(ClassificationItem.fromJson({'type': 'mystery'}), isNull);
      expect(ClassificationItem.fromJson(const {}), isNull);
    });
  });

  group('AiAttachmentRef', () {
    test('toJson', () {
      const ref = AiAttachmentRef(i: 1, type: 'image', name: 'pic.png');
      expect(ref.toJson(), {'i': 1, 'type': 'image', 'name': 'pic.png'});
    });
  });

  group('AiResource.fromJson', () {
    test('parses fields', () {
      final r = AiResource.fromJson({
        'title': 'Clean Code',
        'type': '書籍',
        'description': 'a book',
        'url': 'https://example.com',
      });
      expect(r.title, 'Clean Code');
      expect(r.type, '書籍');
      expect(r.description, 'a book');
      expect(r.url, 'https://example.com');
    });

    test('defaults to empty strings when missing', () {
      final r = AiResource.fromJson(const {});
      expect(r.title, '');
      expect(r.type, '');
      expect(r.url, '');
    });
  });
}
