import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/calendar/domain/event.dart';
import 'package:myroom/features/calendar/data/firebase_event_repo.dart';
import 'package:myroom/features/calendar/domain/event_repo.dart';
import 'package:myroom/features/calendar/presentation/calendar_page.dart';
import 'package:provider/provider.dart';

import '../../../support/widget_harness.dart';

void main() {
  const uid = 'userA';

  testWidgets('renders an event from the stream in the month view', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final now = DateTime.now();
    await db.collection('users').doc(uid).collection('events').add({
      ...CalendarEvent(
        id: '',
        title: '測試會議',
        startTime: DateTime(now.year, now.month, now.day, 10),
        endTime: DateTime(now.year, now.month, now.day, 11),
        color: const Color(0xFF7B9E87),
        createdAt: now,
      ).toJson(),
      'createdAt': Timestamp.now(),
    });

    await pumpPage(
      tester,
      const CalendarPage(),
      providers: [
        Provider<EventRepo>(create: (_) => FirebaseEventRepo(db, uid)),
      ],
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('測試會議'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
