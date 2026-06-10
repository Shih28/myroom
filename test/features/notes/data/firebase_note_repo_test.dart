import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/result.dart';
import 'package:myroom/features/notes/data/firebase_note_repo.dart';
import 'package:myroom/features/notes/domain/note.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FakeStorageRepo storage;
  late FirebaseNoteRepo repo;
  const uid = 'userA';

  setUp(() {
    db = FakeFirebaseFirestore();
    storage = FakeStorageRepo();
    repo = FirebaseNoteRepo(db, uid, storage);
  });

  CollectionReference<Map<String, dynamic>> notesCol() =>
      db.collection('users').doc(uid).collection('notes');

  Note note(String dateKey, String content) => Note(
    id: '',
    dateKey: dateKey,
    content: content,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('add', () {
    test('plain note (no attachments)', () async {
      final res = await repo.add(note('2026-06-10', '純文字筆記'));
      expect(res, isA<Ok<String>>());
      final id = (res as Ok<String>).value;
      final doc = await notesCol().doc(id).get();
      expect(doc.data()!['content'], '純文字筆記');
      expect(doc.data()!['dateKey'], '2026-06-10');
      expect((doc.data()!['attachments'] as List), isEmpty);
    });

    test(
      'audio attachment → content-addressed upload + extracted_texts doc',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final attId = sha256.convert(bytes).toString();

        final res = await repo.add(
          note('2026-06-10', '語音筆記'),
          attachments: [
            PendingAttachment(
              bytes: bytes,
              type: 'audio',
              filename: 'voice.m4a',
              ext: 'm4a',
              extractedText: '逐字稿內容',
            ),
          ],
        );
        final id = (res as Ok<String>).value;
        final expectedPath = 'users/$uid/notes/$id/$attId.m4a';

        // The note carries the attachment metadata (storagePath only).
        final atts =
            (await notesCol().doc(id).get()).data()!['attachments'] as List;
        expect(atts, hasLength(1));
        expect((atts.first as Map)['attId'], attId);
        expect((atts.first as Map)['storagePath'], expectedPath);
        expect((atts.first as Map)['type'], 'audio');

        // Bytes uploaded under the content-addressed path.
        expect(storage.uploaded[expectedPath], bytes);

        // extracted_texts/{attId} written for audio.
        final ext = await notesCol()
            .doc(id)
            .collection('extracted_texts')
            .doc(attId)
            .get();
        expect(ext.exists, isTrue);
        expect(ext.data()!['filename'], 'voice.m4a');
        expect(ext.data()!['summary'], '逐字稿內容');
      },
    );

    test(
      'image attachment is uploaded but has NO extracted_texts doc',
      () async {
        final bytes = Uint8List.fromList([9, 9, 9]);
        final attId = sha256.convert(bytes).toString();
        final res = await repo.add(
          note('2026-06-10', '照片筆記'),
          attachments: [
            PendingAttachment(
              bytes: bytes,
              type: 'image',
              filename: 'p.png',
              ext: 'png',
              extractedText: 'ignored for images',
            ),
          ],
        );
        final id = (res as Ok<String>).value;
        final ext = await notesCol()
            .doc(id)
            .collection('extracted_texts')
            .doc(attId)
            .get();
        expect(ext.exists, isFalse);
      },
    );

    test('upload failure aborts the add (no note written)', () async {
      storage.failUploads = true;
      final before = (await notesCol().get()).docs.length;
      final res = await repo.add(
        note('2026-06-10', 'x'),
        attachments: [
          PendingAttachment(
            bytes: Uint8List.fromList([5]),
            type: 'file',
            filename: 'd.pdf',
            ext: 'pdf',
            extractedText: 't',
          ),
        ],
      );
      expect(res, isA<Err<String>>());
      expect((await notesCol().get()).docs.length, before);
    });
  });

  group('queries', () {
    test('watchNoteDateKeys returns the distinct non-empty dateKeys', () async {
      await repo.add(note('2026-06-10', 'a'));
      await repo.add(note('2026-06-10', 'b'));
      await repo.add(note('2026-06-11', 'c'));
      final keys = await repo.watchNoteDateKeys().first;
      expect(keys, {'2026-06-10', '2026-06-11'});
    });

    test('watchNotes(dateKey) filters to that day', () async {
      await repo.add(note('2026-06-10', 'today'));
      await repo.add(note('2026-06-11', 'tomorrow'));
      final notes = await repo.watchNotes(dateKey: '2026-06-10').first;
      expect(notes.map((n) => n.content), ['today']);
    });

    test(
      'watchNotesByCategory filters on the denormalized category.id',
      () async {
        final id =
            (await repo.add(note('2026-06-10', 'travel note')) as Ok<String>)
                .value;
        await repo.setCategory(
          id,
          const NoteCategoryRef(
            id: 'travel',
            label: '旅行',
            color: Color(0xFFC57A8A),
          ),
        );
        await repo.add(note('2026-06-10', 'uncategorized')); // stays undefined

        final inTravel = await repo.watchNotesByCategory('travel').first;
        expect(inTravel.map((n) => n.content), ['travel note']);
      },
    );
  });

  group('mutations', () {
    test('setCategory updates the embedded snapshot', () async {
      final id = (await repo.add(note('2026-06-10', 'x')) as Ok<String>).value;
      await repo.setCategory(
        id,
        const NoteCategoryRef(
          id: 'food',
          label: '美食',
          color: Color(0xFFC5956A),
          iconName: 'utensils',
        ),
      );
      final cat =
          (await notesCol().doc(id).get()).data()!['category']
              as Map<String, dynamic>;
      expect(cat['id'], 'food');
      expect(cat['iconName'], 'utensils');
    });

    test(
      'delete removes the note doc (storage cascade is server-side)',
      () async {
        final id =
            (await repo.add(note('2026-06-10', 'x')) as Ok<String>).value;
        await repo.delete(id);
        expect((await notesCol().doc(id).get()).exists, isFalse);
      },
    );
  });

  test('notes are scoped per user', () async {
    await repo.add(note('2026-06-10', 'private'));
    final otherRepo = FirebaseNoteRepo(db, 'userB', storage);
    expect(await otherRepo.watchNoteDateKeys().first, isEmpty);
  });
}
