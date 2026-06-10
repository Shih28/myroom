import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/widgets/mr_skeleton.dart';
import 'package:myroom/features/ideas/data/firebase_idea_repo.dart';
import 'package:myroom/features/ideas/domain/idea_repo.dart';
import 'package:myroom/features/ideas/presentation/ideas_page.dart';
import 'package:myroom/shared/ai/domain/ai_service.dart';
import 'package:provider/provider.dart';

import '../../../support/fakes.dart';
import '../../../support/widget_harness.dart';

void main() {
  const uid = 'userA';

  testWidgets('shows the enrichment skeleton while an idea is processing', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db
        .collection('users')
        .doc(uid)
        .collection('ideas')
        .doc('data')
        .collection('user_ideas')
        .doc('i1')
        .set({
          'text': '一個很棒的點子',
          'aiStatus': 'processing', // enrichIdea trigger in flight
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });

    await pumpPage(
      tester,
      const IdeasPage(),
      providers: [
        Provider<IdeaRepo>(create: (_) => FirebaseIdeaRepo(db, uid)),
        Provider<AiService>(create: (_) => FakeAiService()),
      ],
    );
    await tester.pump(const Duration(milliseconds: 50));

    // The idea card renders; tapping it expands the AI panel.
    expect(find.text('一個很棒的點子'), findsOneWidget);
    await tester.tap(find.text('一個很棒的點子'));
    await tester.pump();

    expect(find.text('AI 分析中…'), findsOneWidget);
    expect(find.byType(MrSkeletonLines), findsOneWidget);
    // Bounded pump: the shimmer animates forever.
    await tester.pump(const Duration(milliseconds: 100));
  });
}
