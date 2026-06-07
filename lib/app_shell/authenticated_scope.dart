import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_errors.dart';
import '../core/theme/app_theme.dart';
import '../features/calendar/data/firebase_event_repo.dart';
import '../features/calendar/domain/event_repo.dart';
import '../features/chat/data/firebase_chat_repo.dart';
import '../features/chat/domain/chat_repo.dart';
import '../features/ideas/data/firebase_idea_repo.dart';
import '../features/ideas/domain/idea_repo.dart';
import '../features/notes/data/firebase_note_repo.dart';
import '../features/notes/domain/note_repo.dart';
import '../features/recap/data/firebase_achievement_repo.dart';
import '../features/recap/data/firebase_recap_repo.dart';
import '../features/recap/domain/achievement_repo.dart';
import '../features/recap/domain/recap_repo.dart';
import '../features/settings/data/firebase_settings_repo.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/domain/settings_repo.dart';
import '../features/todo/data/firebase_todo_repo.dart';
import '../features/todo/domain/todo_repo.dart';
import '../shared/auth/domain/app_user.dart';
import '../shared/storage/firebase_storage_repo.dart';
import '../shared/storage/storage_repo.dart';

/// Wraps every authenticated route (the tab shell **and** the pushed-over
/// routes /settings, /add, /chat) in the user-scoped provider tier, built from
/// the guaranteed-present `uid`. On logout the auth stream emits null, this
/// rebuilds to a loader, and the redirect sends the user to /login — which
/// unmounts the whole subtree and cancels every user-scoped stream.
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
    final uid = user.uid;

    return MultiProvider(
      // Rebuild the whole user tier if the signed-in uid changes.
      key: ValueKey(uid),
      providers: [
        Provider<AppUser>.value(value: user),

        // Storage repo (listed before NoteRepo, which reads it). Also consumed
        // directly by the notes page for on-demand attachment download URLs.
        Provider<StorageRepo>(
          create: (c) => FirebaseStorageRepo(c.read<FirebaseStorage>()),
        ),

        // ── Feature repos (user-scoped) ──
        Provider<EventRepo>(create: (_) => FirebaseEventRepo(db, uid)),
        Provider<TodoRepo>(create: (_) => FirebaseTodoRepo(db, uid)),
        Provider<IdeaRepo>(create: (_) => FirebaseIdeaRepo(db, uid)),
        Provider<NoteRepo>(
          create: (c) => FirebaseNoteRepo(db, uid, c.read<StorageRepo>()),
        ),
        Provider<RecapRepo>(create: (_) => FirebaseRecapRepo(db, uid)),
        Provider<AchievementRepo>(
          create: (_) => FirebaseAchievementRepo(db, uid),
        ),
        Provider<ChatRepo>(create: (_) => FirebaseChatRepo(db, uid)),

        // ── Settings ──
        Provider<SettingsRepo>(create: (_) => FirebaseSettingsRepo(db, uid)),
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
      ],
      child: child,
    );
  }
}
