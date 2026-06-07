# State Management & Navigation

Fused state via the `provider` package + go_router.

## 1. Layering rules

- **No global mutable app state, no controllers/notifiers holding business logic.**
- **Shared state** is read only from Firestore streams exposed as `StreamProvider`s.
- **Ephemeral UI state** (selected date, calendar view mode, form fields, pending "thinking" bubble) lives in the
  widget `State` (or a page-local `ChangeNotifier` that is disposed with the page).
- **Writes** go through repos (`Repositories.md`) and return `Result`; the UI does not optimistically mutate any
  in-memory list — it lets the Firestore stream re-emit. The Firestore SDK's local cache provides the
  optimistic/offline behavior (it reflects the write immediately and the stream re-emits from cache); we do not
  maintain a separate optimistic copy.

## 2. Provider composition

Two tiers. The root tier holds singletons + auth. User-scoped repos/streams live in a **second `MultiProvider` mounted
inside the authenticated shell**, constructed from the known `uid`. This gives deterministic lifecycle: on logout the
shell unmounts and every user-scoped stream is cancelled automatically. Repos are **never** built with a nullable uid.

```dart
// app.dart — ROOT tier
MultiProvider(
  providers: [
    Provider<FirebaseAuth>(create: (_) => FirebaseAuth.instance),
    Provider<FirebaseFirestore>(create: (_) => FirebaseFirestore.instance),
    Provider<FirebaseStorage>(create: (_) => FirebaseStorage.instance),
    Provider<FirebaseFunctions>(create: (_) => FirebaseFunctions.instanceFor(region: kFunctionsRegion)),
    Provider<AuthRepo>(create: (c) => FirebaseAuthRepo(c.read(), c.read())),
    Provider<AiService>(create: (c) => CloudFunctionAiService(c.read())),
    StreamProvider<AppUser?>(
      create: (c) => c.read<AuthRepo>().authState,
      initialData: null, catchError: (_, __) => null),
  ],
  child: MaterialApp.router(...),
)
```

```dart
// AppScaffold (the StatefulShellRoute builder) — USER tier, built from the guaranteed-present uid
Widget build(BuildContext context) {
  final uid = context.read<AppUser>().uid;       // guard guarantees non-null here
  final db = context.read<FirebaseFirestore>();
  return MultiProvider(
    providers: [
      Provider<TodoRepo>(create: (_) => FirebaseTodoRepo(db, uid)),   // also owns todo_categories
      Provider<EventRepo>(create: (_) => FirebaseEventRepo(db, uid)),
      Provider<IdeaRepo>(create: (_) => FirebaseIdeaRepo(db, uid)),
      Provider<NoteRepo>(create: (_) => FirebaseNoteRepo(db, uid, context.read<FirebaseStorage>())), // also owns note_categories
      Provider<RecapRepo>(create: (_) => FirebaseRecapRepo(db, uid)),
      Provider<ChatRepo>(create: (_) => FirebaseChatRepo(db, uid)),
      Provider<SettingsRepo>(create: (_) => FirebaseSettingsRepo(db, uid)),
      // Page-level StreamProviders may be declared here OR per-page (see §3).
    ],
    child: shell,                                  // bottom-nav + branches
  );
}
```

> **Rule:** a feature's `presentation/providers.dart` declares that feature's `StreamProvider`s; they are placed at the
> page subtree (preferred) or in the user tier above. Never above the auth tier.

## 3. Streams in the UI

Each list view consumes a `StreamProvider` whose `create` calls the repo's `watch*`:

```dart
StreamProvider<List<Todo>>(
  create: (c) => c.read<TodoRepo>().watchTodos(),
  initialData: const [],
  catchError: (c, e) { AppErrors.present(e); return const []; }, // route stream errors to the popup
)
```

Consume with `context.watch<List<Todo>>()` / `Selector` for fine-grained rebuilds. Do not call `setState` to refresh
shared data.

## 4. Global error popup

All repo `Err` results and stream `catchError`s funnel through one mechanism.

```dart
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();   // set on MaterialApp.router

class AppErrors {
  static void present(Object error) {
    final f = error is Failure ? error : mapFirebase(error);        // mapFirebase in Repositories.md
    scaffoldMessengerKey.currentState?.showMaterialBanner(
      MaterialBanner(content: Text(f.userMessage), actions: [/* dismiss */]),
    );
  }
}
```
`MaterialBanner` renders at the top of the screen. `Failure.userMessage` is a zh-TW string defined per failure type in
`Repositories.md`.

## 5. Routing

- `go_router` with one `StatefulShellRoute.indexedStack`; branches = the five tabs. `AppScaffold` owns `currentIndex`.
- **Auth redirect** driven by the `AppUser?` stream:

```dart
GoRouter(
  refreshListenable: GoRouterRefreshStream(context.read<AuthRepo>().authState),
  redirect: (ctx, state) {
    final loggedIn = ctx.read<AuthRepo>().currentUserId != null;
    final atLogin = state.matchedLocation == Routes.login;
    if (!loggedIn) return atLogin ? null : Routes.login;
    if (atLogin)   return Routes.calendar;
    return null;
  },
  routes: [...],
)
```
`GoRouterRefreshStream` = the standard go_router adapter that calls `notifyListeners` on each stream event.

- Web: call `usePathUrlStrategy()` in `main()`.

### Route table

| Path | Screen | Placement |
| --- | --- | --- |
| `/login` | Login | top-level (outside shell) |
| `/calendar` `/todo` `/ideas` `/notes` `/recap` | tabs | shell branches; `/calendar` default |
| `/settings` | Settings | top-level route pushed over shell |
| `/add` | Add overlay | **full route** (`context.push('/add')`) |
| `/chat` | AI Chat overlay | **full route** (`context.push('/chat')`) |

## 6. Theme

Port the existing `theme.dart` tokens into `core/theme/app_theme.dart` unchanged (Cormorant Garamond + DM Sans).
Bundle the two font families as assets (declared in `pubspec.yaml`) rather than fetching at runtime.

## 7. Remove

`MyRoomShell` + all `onX*` callbacks; the custom `_KeepAlive` mixin; the `NotePage`→DB bypass (route notes through
`NoteRepo`).
