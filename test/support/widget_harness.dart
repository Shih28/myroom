import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myroom/core/app_errors.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Pumps [page] under [providers] inside a MaterialApp + Scaffold, then lets the
/// (fake) Firestore streams emit. Never use `pumpAndSettle` afterwards on views
/// with a shimmer/spinner — those animate forever; pump fixed durations instead.
Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  required List<SingleChildWidget> providers,
}) async {
  // Keep widget tests offline & deterministic (no Google Fonts HTTP fetch).
  GoogleFonts.config.allowRuntimeFetching = false;

  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: Scaffold(body: page),
      ),
    ),
  );
  // Two pumps: first builds, second lets the initial stream snapshot arrive.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
