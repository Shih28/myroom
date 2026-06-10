import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/result.dart';
import 'package:myroom/features/calendar/data/firebase_event_repo.dart';
import 'package:myroom/features/calendar/domain/event.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseEventRepo repo;
  const uid = 'userA';

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirebaseEventRepo(db, uid);
  });

  CollectionReference<Map<String, dynamic>> eventsCol() =>
      db.collection('users').doc(uid).collection('events');

  CalendarEvent evt(String title, DateTime start) => CalendarEvent(
    id: '',
    title: title,
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    color: const Color(0xFF7B9E87),
    createdAt: DateTime.now(),
  );

  test('add writes data fields + a server createdAt', () async {
    final res = await repo.add(evt('會議', DateTime.utc(2026, 6, 10, 9)));
    expect(res, isA<Ok<void>>());
    final docs = await eventsCol().get();
    expect(docs.docs, hasLength(1));
    expect(docs.docs.first.data()['title'], '會議');
    expect(docs.docs.first.data()['createdAt'], isA<Timestamp>());
  });

  test('watchEvents streams all events ordered by startTime', () async {
    await repo.add(evt('B', DateTime.utc(2026, 6, 10, 12)));
    await repo.add(evt('A', DateTime.utc(2026, 6, 10, 8)));
    final events = await repo.watchEvents().first;
    expect(events.map((e) => e.title), ['A', 'B']);
  });

  test('watchEvents(window) returns only events inside the range', () async {
    await repo.add(evt('before', DateTime.utc(2026, 6, 1, 9)));
    await repo.add(evt('inside', DateTime.utc(2026, 6, 10, 9)));
    await repo.add(evt('after', DateTime.utc(2026, 6, 20, 9)));

    final window = DateTimeRange(
      start: DateTime.utc(2026, 6, 8),
      end: DateTime.utc(2026, 6, 12),
    );
    final events = await repo.watchEvents(window: window).first;
    expect(events.map((e) => e.title), ['inside']);
  });

  test('update + delete', () async {
    await repo.add(evt('orig', DateTime.utc(2026, 6, 10, 9)));
    final id = (await eventsCol().get()).docs.first.id;

    await repo.update(
      evt('changed', DateTime.utc(2026, 6, 10, 9)).copyWith(id: id),
    );
    expect((await eventsCol().doc(id).get()).data()!['title'], 'changed');

    await repo.delete(id);
    expect((await eventsCol().doc(id).get()).exists, isFalse);
  });

  test('events are scoped per user', () async {
    await repo.add(evt('mine', DateTime.utc(2026, 6, 10, 9)));
    final otherRepo = FirebaseEventRepo(db, 'userB');
    expect(await otherRepo.watchEvents().first, isEmpty);
  });
}
