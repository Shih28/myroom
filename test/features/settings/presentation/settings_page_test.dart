import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/settings/data/firebase_settings_repo.dart';
import 'package:myroom/features/settings/domain/app_settings.dart';
import 'package:myroom/features/settings/domain/settings_repo.dart';
import 'package:myroom/features/settings/presentation/settings_page.dart';
import 'package:myroom/shared/auth/domain/app_user.dart';
import 'package:myroom/shared/auth/domain/auth_repo.dart';
import 'package:provider/provider.dart';

import '../../../support/fakes.dart';
import '../../../support/widget_harness.dart';

void main() {
  const uid = 'userA';

  testWidgets('renders the signed-in email and logout affordance', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await pumpPage(
      tester,
      const SettingsPage(),
      providers: [
        Provider<SettingsRepo>(create: (_) => FirebaseSettingsRepo(db, uid)),
        Provider<AuthRepo>(create: (_) => FakeAuthRepo()),
        Provider<AppUser>.value(
          value: const AppUser(uid: uid, email: 'happy@example.com'),
        ),
        Provider<AppSettings?>.value(value: const AppSettings()),
      ],
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('happy@example.com'), findsOneWidget);
    expect(find.text('登出'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
