import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:myroom/features/chat/data/firebase_chat_repo.dart';
import 'package:myroom/features/chat/domain/chat_repo.dart';
import 'package:myroom/features/chat/presentation/chat_overlay.dart';
import 'package:myroom/shared/ai/domain/ai_service.dart';
import 'package:provider/provider.dart';

import '../../../support/fakes.dart';
import '../../../support/widget_harness.dart';

void main() {
  const uid = 'userA';

  CollectionReference<Map<String, dynamic>> chatCol(FakeFirebaseFirestore db) =>
      db.collection('users').doc(uid).collection('chat_messages');

  Future<void> seed(FakeFirebaseFirestore db, int n) async {
    final base = DateTime.utc(2026, 1, 1);
    for (var i = 0; i < n; i++) {
      await chatCol(db).doc('m$i').set({
        'role': i.isEven ? 'user' : 'assistant',
        'content': 'msg$i',
        'createdAt': Timestamp.fromDate(base.add(Duration(minutes: i))),
      });
    }
  }

  testWidgets('empty thread shows the greeting empty-state', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpPage(
      tester,
      const ChatOverlay(),
      providers: [
        Provider<ChatRepo>(create: (_) => FirebaseChatRepo(db, uid)),
        Provider<AiService>(create: (_) => FakeAiService()),
      ],
    );
    expect(find.text('你好！我是你的個人助理'), findsOneWidget);
  });

  testWidgets('renders streamed messages as bubbles', (tester) async {
    final db = FakeFirebaseFirestore();
    await seed(db, 2);
    await pumpPage(
      tester,
      const ChatOverlay(),
      providers: [
        Provider<ChatRepo>(create: (_) => FirebaseChatRepo(db, uid)),
        Provider<AiService>(create: (_) => FakeAiService()),
      ],
    );
    expect(find.text('msg0'), findsOneWidget);
    expect(find.text('msg1'), findsOneWidget);
  });

  testWidgets('sending a message routes through AiService.chat', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final ai = FakeAiService();
    await pumpPage(
      tester,
      const ChatOverlay(),
      providers: [
        Provider<ChatRepo>(create: (_) => FirebaseChatRepo(db, uid)),
        Provider<AiService>.value(value: ai),
      ],
    );

    await tester.enterText(find.byType(TextField), '今天的優先事項');
    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pump(); // begin send → typing indicator
    expect(ai.chatCalls, ['今天的優先事項']);
    await tester.pump(const Duration(milliseconds: 50)); // settle the future
  });

  testWidgets('a full first page surfaces the load-more affordance', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seed(db, ChatRepo.pageSize + 5); // 55 → tail is a full page
    await pumpPage(
      tester,
      const ChatOverlay(),
      providers: [
        Provider<ChatRepo>(create: (_) => FirebaseChatRepo(db, uid)),
        Provider<AiService>(create: (_) => FakeAiService()),
      ],
    );
    expect(find.text('載入更多訊息'), findsOneWidget);
  });

  testWidgets('a short thread shows no load-more affordance', (tester) async {
    final db = FakeFirebaseFirestore();
    await seed(db, 3);
    await pumpPage(
      tester,
      const ChatOverlay(),
      providers: [
        Provider<ChatRepo>(create: (_) => FirebaseChatRepo(db, uid)),
        Provider<AiService>(create: (_) => FakeAiService()),
      ],
    );
    expect(find.text('載入更多訊息'), findsNothing);
  });
}
