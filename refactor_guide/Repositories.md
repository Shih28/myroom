# Repository Layer (Domain Contracts)

Each feature owns an abstract interface (`domain/*_repo.dart`) and a Firebase implementation
(`data/firebase_*_repo.dart`) scoped to the authenticated `userId`, provided through a `Provider`. The canonical types
and patterns below are mandatory so generated code is uniform.

## 1. Cross-cutting types (`lib/core/`)

```dart
// result.dart
sealed class Result<T> { const Result(); }
class Ok<T>  extends Result<T> { final T value;  const Ok(this.value); }
class Err<T> extends Result<T> { final Failure failure; const Err(this.failure); }

// failures.dart
sealed class Failure {
  final String userMessage;   // zh-TW, shown in the top banner
  const Failure(this.userMessage);
}
class NetworkFailure    extends Failure { const NetworkFailure()    : super('網路連線異常，請稍後再試'); }
class PermissionFailure extends Failure { const PermissionFailure() : super('沒有權限執行此操作'); }
class NotFoundFailure   extends Failure { const NotFoundFailure()   : super('找不到資料'); }
class AiFailure         extends Failure { const AiFailure([String? m]) : super('AI 服務暫時無法使用'); }
class UnknownFailure    extends Failure { final Object cause; const UnknownFailure(this.cause) : super('發生未知錯誤'); }
```

```dart
// firebase_failure.dart — the one mapping used by every repo and by AppErrors
Failure mapFirebase(Object e) => switch (e) {
  FirebaseException(:final code) when code == 'permission-denied' => const PermissionFailure(),
  FirebaseException(:final code) when code == 'not-found'         => const NotFoundFailure(),
  FirebaseException(:final code) when code == 'unavailable'
      || code == 'deadline-exceeded'                              => const NetworkFailure(),
  FirebaseFunctionsException()                                    => AiFailure(e.toString()),
  _                                                               => UnknownFailure(e),
};
```

Mutating methods return `Future<Result<T>>`; on error they call `AppErrors.present(failure)` (`StateManagement.md`)
and return `Err`. Read methods return `Stream<...>`; stream errors are mapped and surfaced by the `StreamProvider`'s
`catchError` in the UI.

## 2. Repo construction & scoping

Each Firebase repo takes `(FirebaseFirestore db, String uid[, FirebaseStorage st])` and exposes one private collection
getter. No per-call uid lookup, no nullable uid.

```dart
class FirebaseTodoRepo implements TodoRepo {
  FirebaseTodoRepo(this._db, this._uid);
  CollectionReference<Map<String,dynamic>> get _col => _db.collection('users').doc(_uid).collection('todos');

  @override Stream<List<Todo>> watchTodos() =>
    _col.orderBy('sortOrder').snapshots().map((s) => s.docs.map(Todo.fromFirestore).toList());

  @override Future<Result<void>> add(Todo t) async {
    try { await _col.add(t.toJson()); return const Ok(null); }
    catch (e) { final f = mapFirebase(e); AppErrors.present(f); return Err(f); }
  }
}
```

Build/teardown on auth change is handled by provider scoping (`StateManagement.md`).

## 3. Interfaces

- `AuthRepo` — `Stream<AppUser?> authState`, `String? currentUserId`, `signIn(email,pw)`, `signUp(email,pw)`,
  `signInWithGoogle()`, `signInWithApple()`, `signOut()`, `deleteAccount()`. `deleteAccount` re-authenticates before
  deleting the Auth user (`Auth.md`).
- `EventRepo` — `watchEvents({DateTimeRange? window})`, `add/update/delete`.
- `TodoRepo` — `watchTodos()`, `add`, `update`, `delete`, `reorder(List<String> orderedIds)`; todo categories:
  `watchTodoCategories()`, `addTodoCategory`, `updateTodoCategory`, `deleteTodoCategory(id)`. `reorder` writes
  `sortOrder = index` in one `WriteBatch`. `deleteTodoCategory` deletes only the category doc; `categoryFanout`
  reassigns affected todos to the `無分類` sentinel. Todos have **no `priority`** field (the demo's priority selector
  is an intentional cut); ordering is `sortOrder` only, and the ported inline add form drops the priority selector.
- `IdeaRepo` — `watchIdeas()`, `add(text) → Result<String id>`, `updateText(id,text)`, `delete(id)`;
  `watchPinnedResources()`, `pin(resource)`, `unpin(url)`. No AI calls here; `enrichIdea` (trigger) fills
  `aiSummary/aiStatus/links`.
- `NoteRepo` — `watchNotes({String? dateKey})`, `watchNotesByCategory(catId)`, `watchNoteDateKeys()`,
  `add(note, {attachments})`, `update`, `delete`, `setCategory`; note categories:
  `watchNoteCategories()`, `addNoteCategory`, `updateNoteCategory`, `deleteNoteCategory(id)`. `deleteNoteCategory`
  deletes only the category doc; `categoryFanout` reassigns affected notes to the `無分類` sentinel. There is **no
  "primary note"** concept: every note is an ordinary doc whose `category` defaults to the `undefined` sentinel and is
  then set by `classifyNote`. The date-mode day panel is the list of that day's notes plus an "add note" action —
  new notes are created via `add(note)` with `dateKey` set; it is not "one primary editor + list."
- `RecapRepo` — `watchRecaps()`, `add`, `update`, `delete`.
- `AchievementRepo` — `watchAchievements()`, `add`, `update`, `delete`. Same shape as `RecapRepo`; both stream to the
  Recap page. `exportStoragePath` / `*ExportStoragePath` are fn-written (`exportRecap` / `exportAchievement`) — not set
  by these repos.
- `ChatRepo` — `watchMessages()` + `loadOlder(DocumentSnapshot cursor)`. Single flat `chat_messages` thread: no
  sessions, no `sessionId`. The client does **not** append messages (they are fn-only, written by the chat function);
  there is no `appendMessage`.
- `SettingsRepo` — `watchSettings()`, `updateSettings({selfIntro?, rules?, autoEnrich?, tz?, tutorialSeen?})` (partial)
  against `users/{uid}/settings/app`. The client patches `tz` to the device timezone after first load.
- `StorageRepo` — `Storage.md`. `AiService` — `AI_proxy.md`.

## 4. Chat pagination

- `watchMessages()` streams the latest 50 of `chat_messages` ordered `createdAt desc`, reversed for display.
- `loadOlder(DocumentSnapshot cursor)` does a one-shot `get()` of the next 50 via `startAfterDocument`.
- The page keeps the live tail in a stream and prepends paged-in older messages in local widget state.

## 5. Required behaviors

- `watchNoteDateKeys`: stream only the set of dateKeys with ≥1 note (project the `dateKey` field; never load content).
- `reorder`: dense 0..N-1 `sortOrder` via batched writes.
- `pin`: pinned-resource doc id = `sha1(url)` for dedupe.
- Category delete ⇒ items reassigned to that type's `無分類` sentinel by `categoryFanout`; the repo only deletes.

## 6. Models & serialization

Field/type/required/default and writer per field are defined in `DataModel.md §Field reference`. Every model
implements `fromFirestore(DocumentSnapshot)` + `toJson()` against it. Conventions (Color as `int`, Timestamps,
auto-IDs) are in `DataModel.md §Conventions`.
