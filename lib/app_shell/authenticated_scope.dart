import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_errors.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/data/firebase_settings_repo.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/domain/settings_repo.dart';
import '../shared/auth/domain/app_user.dart';

/// Wraps every authenticated route (the tab shell **and** the pushed-over
/// routes /settings, /add, /chat) in the user-scoped provider tier, built from
/// the guaranteed-present `uid`. On logout the auth stream emits null, this
/// rebuilds to a loader, and the redirect sends the user to /login — which
/// unmounts the whole subtree and cancels every user-scoped stream.
///
/// Phase 1 adds the remaining repos (Todo/Event/Idea/Note/Recap/Achievement/
/// Chat/Storage) + their page-level StreamProviders here.
class AuthenticatedScope extends StatelessWidget {
  const AuthenticatedScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppUser?>();
    if (user == null) {
      // Transient: redirect to /login is in flight.
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark),
          ),
        ),
      );
    }

    final db = context.read<FirebaseFirestore>();

    return MultiProvider(
      // Rebuild the whole user tier if the signed-in uid changes.
      key: ValueKey(user.uid),
      providers: [
        Provider<AppUser>.value(value: user),
        Provider<SettingsRepo>(create: (_) => FirebaseSettingsRepo(db, user.uid)),
        // Nullable: null = first snapshot not yet received. Consumers that just
        // need values fall back to AppSettings.defaults; the tutorial gate and
        // tz patch act only once a real snapshot has arrived.
        StreamProvider<AppSettings?>(
          create: (c) => c.read<SettingsRepo>().watchSettings(),
          initialData: null,
          catchError: (_, e) {
            if (e != null) AppErrors.present(e);
            return AppSettings.defaults;
          },
        ),
        // ── Phase 1 repos go here (TodoRepo, EventRepo, …) ──
      ],
      child: child,
    );
  }
}
