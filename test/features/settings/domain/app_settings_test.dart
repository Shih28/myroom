import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/constants.dart';
import 'package:myroom/features/settings/domain/app_settings.dart';

import '../../../support/firestore_helpers.dart';

void main() {
  group('AppSettings', () {
    test('defaults match the DataModel field reference', () {
      const s = AppSettings.defaults;
      expect(s.selfIntro, '');
      expect(s.rules, '');
      expect(s.autoEnrich, true);
      expect(s.tz, kDefaultTimezone);
      expect(s.tutorialSeen, false);
    });

    test('fromFirestore reads stored values', () async {
      final snap = await snapshotOf({
        'selfIntro': '我是學生',
        'rules': '請用繁體中文',
        'autoEnrich': false,
        'tz': 'America/New_York',
        'tutorialSeen': true,
      });
      final s = AppSettings.fromFirestore(snap);
      expect(s.selfIntro, '我是學生');
      expect(s.rules, '請用繁體中文');
      expect(s.autoEnrich, false);
      expect(s.tz, 'America/New_York');
      expect(s.tutorialSeen, true);
    });

    test('fromFirestore falls back to defaults for missing fields', () async {
      final snap = await snapshotOf({'selfIntro': 'hi'});
      final s = AppSettings.fromFirestore(snap);
      expect(s.selfIntro, 'hi');
      expect(s.autoEnrich, true); // default
      expect(s.tz, kDefaultTimezone);
    });
  });
}
