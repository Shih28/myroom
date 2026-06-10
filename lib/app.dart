import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/app_errors.dart';
import 'core/constants.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'shared/auth/data/firebase_auth_repo.dart';
import 'shared/auth/domain/app_user.dart';
import 'shared/auth/domain/auth_repo.dart';

/// Root provider tier (singletons + auth). User-scoped repos live in the
/// `AuthenticatedScope` mounted inside the authenticated shell.
class MyRoomApp extends StatelessWidget {
  const MyRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseAuth>(create: (_) => FirebaseAuth.instance),
        Provider<FirebaseFirestore>(create: (_) => FirebaseFirestore.instance),
        Provider<FirebaseStorage>(create: (_) => FirebaseStorage.instance),
        Provider<FirebaseFunctions>(
          create: (_) =>
              FirebaseFunctions.instanceFor(region: kFunctionsRegion),
        ),
        Provider<AuthRepo>(create: (c) => FirebaseAuthRepo(c.read())),
        StreamProvider<AppUser?>(
          create: (c) => c.read<AuthRepo>().authState,
          initialData: null,
          catchError: (_, __) => null,
        ),
      ],
      child: const _RouterHost(),
    );
  }
}

class _RouterHost extends StatefulWidget {
  const _RouterHost();

  @override
  State<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends State<_RouterHost> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(context.read<AuthRepo>());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyRoom',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: _router,
    );
  }
}
