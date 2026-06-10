import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/constants.dart';
import 'package:myroom/features/notes/domain/note.dart';
import 'package:myroom/features/notes/domain/note_category.dart';

import '../../../support/firestore_helpers.dart';

void main() {
  group('NoteCategoryRef', () {
    test('undefined sentinel carries iconName "tag"', () {
      expect(NoteCategoryRef.undefined.id, kUndefinedCategoryId);
      expect(NoteCategoryRef.undefined.label, '未分類');
      expect(NoteCategoryRef.undefined.iconName, 'tag');
    });

    test('toMap includes iconName (unlike todo category)', () {
      const ref = NoteCategoryRef(
        id: 'n1',
        label: '旅行',
        color: Color(0xFFC57A8A),
        iconName: 'plane',
      );
      expect(ref.toMap(), {
        'id': 'n1',
        'label': '旅行',
        'colorVal': 0xFFC57A8A,
        'iconName': 'plane',
      });
    });
  });

  group('NoteAttachment', () {
    test('toMap/fromMap round-trip', () {
      const a = NoteAttachment(
        type: 'audio',
        filename: 'voice.m4a',
        storagePath: 'users/u/notes/n/abc.m4a',
        attId: 'abc',
      );
      final back = NoteAttachment.fromMap(a.toMap());
      expect(back.type, 'audio');
      expect(back.filename, 'voice.m4a');
      expect(back.storagePath, 'users/u/notes/n/abc.m4a');
      expect(back.attId, 'abc');
    });
  });

  group('Note', () {
    test(
      'toJson serializes dateKey, title, content, category, attachments',
      () {
        final note = Note(
          id: 'n1',
          dateKey: '2026-06-09',
          title: '標題',
          content: '內容',
          category: NoteCategoryRef.undefined,
          attachments: const [
            NoteAttachment(
              type: 'image',
              filename: 'a.png',
              storagePath: 'p',
              attId: 'h',
            ),
          ],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final json = note.toJson();
        expect(json['dateKey'], '2026-06-09');
        expect(json['title'], '標題');
        expect(json['content'], '內容');
        expect((json['attachments'] as List), hasLength(1));
        expect(json.containsKey('createdAt'), isFalse);
      },
    );

    test(
      'fromFirestore defaults title to 無標題 and category to undefined',
      () async {
        final snap = await snapshotOf({
          'dateKey': '2026-06-09',
          'content': 'AI 建立的筆記',
          'createdAt': ts2026,
          'updatedAt': ts2026,
        }, id: 'note5');
        final note = Note.fromFirestore(snap);
        expect(note.id, 'note5');
        expect(note.title, '無標題');
        expect(note.category.id, kUndefinedCategoryId);
        expect(note.attachments, isEmpty);
      },
    );

    test('fromFirestore parses nested attachments', () async {
      final snap = await snapshotOf({
        'dateKey': '2026-06-09',
        'content': 'x',
        'attachments': [
          {
            'type': 'file',
            'filename': 'doc.pdf',
            'storagePath': 'users/u/notes/n/h.pdf',
            'attId': 'h',
          },
        ],
        'createdAt': ts2026,
        'updatedAt': ts2026,
      });
      final note = Note.fromFirestore(snap);
      expect(note.attachments, hasLength(1));
      expect(note.attachments.first.type, 'file');
      expect(note.attachments.first.filename, 'doc.pdf');
    });
  });

  group('NoteCategory', () {
    test('toJson + fromFirestore round-trip (carries iconName)', () async {
      const cat = NoteCategory(
        id: 'n1',
        label: '美食',
        color: Color(0xFFC5956A),
        iconName: 'utensils',
        sortOrder: 4,
      );
      final json = cat.toJson();
      expect(json['iconName'], 'utensils');
      final snap = await snapshotOf(json, id: 'n1');
      final back = NoteCategory.fromFirestore(snap);
      expect(back.label, '美食');
      expect(back.iconName, 'utensils');
      expect(back.sortOrder, 4);
    });
  });
}
