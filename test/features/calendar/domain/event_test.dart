import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/calendar/domain/event.dart';

import '../../../support/firestore_helpers.dart';

void main() {
  group('CalendarEvent', () {
    test(
      'toJson emits client-writable fields (no createdAt) with ARGB color',
      () {
        final e = CalendarEvent(
          id: 'e1',
          title: '會議',
          description: 'desc',
          location: 'room',
          startTime: DateTime.utc(2026, 6, 9, 14),
          endTime: DateTime.utc(2026, 6, 9, 15),
          isAllDay: false,
          color: const Color(0xFF7B9E87),
          createdAt: DateTime.utc(2026, 6, 1),
        );
        final json = e.toJson();
        expect(json['title'], '會議');
        expect(json['description'], 'desc');
        expect(json['location'], 'room');
        expect(
          json['startTime'],
          Timestamp.fromDate(DateTime.utc(2026, 6, 9, 14)),
        );
        expect(json['isAllDay'], false);
        expect(json['color'], 0xFF7B9E87);
        expect(json.containsKey('createdAt'), isFalse);
      },
    );

    test('fromFirestore round-trips through Firestore', () async {
      final snap = await snapshotOf({
        ...CalendarEvent(
          id: '_',
          title: '出遊',
          startTime: DateTime.utc(2026, 6, 9, 9),
          endTime: DateTime.utc(2026, 6, 9, 18),
          isAllDay: true,
          color: const Color(0xFF8B9EC5),
          createdAt: DateTime.utc(2026, 6, 1),
        ).toJson(),
        'createdAt': ts2026,
      }, id: 'evt42');

      final e = CalendarEvent.fromFirestore(snap);
      expect(e.id, 'evt42');
      expect(e.title, '出遊');
      expect(e.isAllDay, true);
      expect(e.color.toARGB32(), 0xFF8B9EC5);
      // Timestamp.toDate() returns local time; compare the instant, not the flag.
      expect(e.startTime.isAtSameMomentAs(DateTime.utc(2026, 6, 9, 9)), isTrue);
      expect(e.createdAt, ts2026.toDate());
    });

    test('fromFirestore applies defaults for missing fields', () async {
      final snap = await snapshotOf({'title': 'bare'});
      final e = CalendarEvent.fromFirestore(snap);
      expect(e.title, 'bare');
      expect(e.description, isNull);
      expect(e.isAllDay, false);
      expect(e.color.toARGB32(), 0xFF7B9E87); // sage default
    });

    test('copyWith overrides selected fields', () {
      final e = CalendarEvent(
        id: 'e1',
        title: 'a',
        startTime: DateTime.utc(2026),
        endTime: DateTime.utc(2026),
        color: const Color(0xFF000000),
        createdAt: DateTime.utc(2026),
      );
      final e2 = e.copyWith(title: 'b', isAllDay: true);
      expect(e2.title, 'b');
      expect(e2.isAllDay, true);
      expect(e2.id, 'e1');
    });
  });
}
