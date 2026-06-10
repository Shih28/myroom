import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/recap/data/firebase_achievement_repo.dart';
import 'package:myroom/features/recap/data/firebase_recap_repo.dart';
import 'package:myroom/features/recap/domain/achievement_repo.dart';
import 'package:myroom/features/recap/domain/recap_repo.dart';
import 'package:myroom/features/recap/presentation/recap_page.dart';
import 'package:myroom/shared/ai/domain/ai_service.dart';
import 'package:myroom/shared/storage/storage_repo.dart';
import 'package:provider/provider.dart';

import '../../../support/fakes.dart';
import '../../../support/widget_harness.dart';

void main() {
  const uid = 'userA';

  testWidgets('renders both section headers and a streamed recap card', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc(uid).collection('recaps').doc('r1').set({
      'title': '充滿喜悅的六月',
      'content': '這個月很棒',
      'createdAt': Timestamp.now(),
    });

    await pumpPage(
      tester,
      const RecapPage(),
      providers: [
        Provider<AchievementRepo>(
          create: (_) => FirebaseAchievementRepo(db, uid),
        ),
        Provider<RecapRepo>(create: (_) => FirebaseRecapRepo(db, uid)),
        Provider<AiService>(create: (_) => FakeAiService()),
        Provider<StorageRepo>(create: (_) => FakeStorageRepo()),
      ],
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('階段回顧'), findsWidgets);
    expect(find.text('回顧紀錄'), findsOneWidget);
    expect(find.text('充滿喜悅的六月'), findsOneWidget);
  });
}
