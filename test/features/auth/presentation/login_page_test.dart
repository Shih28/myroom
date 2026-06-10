import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/auth/presentation/login_page.dart';
import 'package:myroom/shared/auth/domain/auth_repo.dart';
import 'package:provider/provider.dart';

import '../../../support/fakes.dart';
import '../../../support/widget_harness.dart';

void main() {
  testWidgets('submitting email + password calls AuthRepo.signIn', (
    tester,
  ) async {
    final auth = FakeAuthRepo();
    await pumpPage(
      tester,
      const LoginPage(),
      providers: [Provider<AuthRepo>.value(value: auth)],
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2)); // email + password
    await tester.enterText(fields.at(0), 'happy@example.com');
    await tester.enterText(fields.at(1), 'secret123');

    await tester.tap(find.text('登入'));
    await tester.pump();

    expect(auth.signInCalls, hasLength(1));
    expect(auth.signInCalls.first.email, 'happy@example.com');
    expect(auth.signInCalls.first.password, 'secret123');
  });
}
