// Phase 1 placeholder unit tests over pure helpers (no Firebase needed).
// The comprehensive test suite (repos, models, widgets) lands in Phase 3 per
// refactor_guide/Test.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/date_format.dart';
import 'package:myroom/core/failures.dart';

void main() {
  group('date_format', () {
    test('fmt2 zero-pads to two digits', () {
      expect(fmt2(3), '03');
      expect(fmt2(12), '12');
    });

    test('dateKeyOf formats as YYYY-MM-DD', () {
      expect(dateKeyOf(DateTime(2026, 6, 7)), '2026-06-07');
      expect(dateKeyOf(DateTime(2026, 12, 25)), '2026-12-25');
    });
  });

  group('failures', () {
    test('each failure carries a zh-TW user message', () {
      expect(const NetworkFailure().userMessage, isNotEmpty);
      expect(const PermissionFailure().userMessage, isNotEmpty);
      expect(const NotFoundFailure().userMessage, isNotEmpty);
    });
  });
}
