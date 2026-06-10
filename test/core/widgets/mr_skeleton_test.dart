import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/core/widgets/mr_skeleton.dart';

void main() {
  testWidgets(
    'MrSkeletonLines renders the requested line count inside a shimmer',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 240, child: MrSkeletonLines(lines: 3)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MrShimmer), findsOneWidget);
      expect(find.byType(MrSkeletonBox), findsNWidgets(3));

      // The shimmer animates forever; a bounded pump must not throw.
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('MrSkeletonBox honours an explicit size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MrSkeletonBox(width: 120, height: 10)),
      ),
    );
    await tester.pump();
    final box = tester.widget<MrSkeletonBox>(find.byType(MrSkeletonBox));
    expect(box.width, 120);
    expect(box.height, 10);
  });
}
