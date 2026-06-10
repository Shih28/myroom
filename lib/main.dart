import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/constants.dart';
import 'firebase_options.dart';

/// Set true to point debug builds at the local Firebase Emulator Suite.
const bool _useEmulators = kDebugMode;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useEmulators) {
    await _connectEmulators();
  }

  await _activateAppCheck();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyRoomApp());
}

/// Android emulators reach the host machine via 10.0.2.2; everything else uses
/// localhost.
String get _emulatorHost =>
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
    ? '10.0.2.2'
    : 'localhost';

Future<void> _connectEmulators() async {
  final host = _emulatorHost;
  try {
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    FirebaseFunctions.instanceFor(
      region: kFunctionsRegion,
    ).useFunctionsEmulator(host, 5001);
  } catch (e) {
    debugPrint('Emulator wiring skipped: $e');
  }
}

Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      // Debug providers for local/dev (incl. Windows, which has no official
      // provider). Swap to real providers via release config before shipping.
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      webProvider: kDebugMode
          ? ReCaptchaEnterpriseProvider('app-check-debug-token-placeholder')
          : ReCaptchaEnterpriseProvider('RECAPTCHA_ENTERPRISE_SITE_KEY'),
    );
  } catch (e) {
    debugPrint('App Check activation skipped: $e');
  }
}
