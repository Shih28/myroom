# Phasing, Milestones & Definition of Done

Stand up the skeleton + backend security first, then port features one at a time, then harden. Targets: Android, iOS,
Windows, Web. Greenfield — no data migration.

## Phase 0 — Project skeleton & infra
- Create the feature-first folder structure (`initial_production_plan.md` tree).
- Single Firebase project + `flutterfire configure` + Emulator Suite (`DevOps.md`).
- `go_router` shell + `AppScaffold` + empty pages, `provider`/`MultiProvider` root (`StateManagement.md`).
- Auth end-to-end: login/signup/logout + guard + `provisionUser` (root doc + `settings/app` + default todo/note
  categories) + first-run tutorial + account deletion (`deleteUserData`) (`Auth.md`).
- Per-collection Firestore/Storage rules + App Check (`Security.md`).
- **Verify web early:** confirm `record_web` + `pdfrx` (pdfium-wasm) work in Chrome (`DevOps.md`).
- **Exit:** a user can sign in and see empty, scoped pages on all four targets.

## Phase 1 — Core repos & feature port
- Implement `core/result.dart`, `failures.dart` (`Repositories.md`).
- Port per feature (repo + `provider` + page rebind to streams): calendar → todo (incl. `todo_categories`) → ideas →
  notes (incl. `note_categories`) → recap (streams `recaps` + `achievements`) → chat → settings. Preserve the required
  behaviors in `Repositories.md`.
- Delete `MyRoomShell`, callbacks, `_KeepAlive`, the `NotePage` bypass, and the SQLite layer.
- Storage repo + attachments (post-classification upload flow) + cascade-cleanup Cloud Function (`Storage.md`).
- **Exit:** all five tabs + settings run fully on Firestore.

## Phase 2 — AI proxy & functions
- Stand up `functions/` TS project (`AI_proxy.md`): **7 callables** (chat, classifyMultiInput, fetchRecommendations,
  generateEraInsight, transcribe, exportRecap, exportAchievement) on the **Responses API** + **7 triggers** (enrichIdea,
  classifyNote, findNotesForCategory, categoryFanout, storageCascade, provisionUser, deleteUserData).
- `chat` runs **server-side tool execution** (Admin SDK writes), incl. real `list_*` tools; idea enrichment, note
  classification, and note-category retro-assignment are triggers, not client calls.
- Client `CloudFunctionAiService` (via `provider`) for the callables; delete `lib/config.dart`.
- Server-side timeout/retry, bounded context, per-user rate limit, typed `HttpsError`→`AiFailure`, surfaced as the top
  error popup.
- Inject the real date into the chat prompt, define real `list_*` tools, read categories once before the loop.
- App Check on callables; `exportRecap`/`exportAchievement` persist PDFs/graphics to Storage; `storageCascade` covers
  notes/recaps/achievements.
- **Exit:** Smart Add, AI chat, idea enrichment, recap/achievement summaries and exports all run through Functions; no
  client key.

## Phase 3 — Hardening & polish
- `categoryFanout` fan-out verified across both category types (`DataModel.md`).
- Indexes finalized from real queries (`Security.md`).
- Tests to the bar in `Test.md`; CI green (`DevOps.md`).
- Strict lints (`flutter_lints`; `avoid_print`, `unawaited_futures`, `prefer_const_constructors`).
- Loading skeletons (Ideas enrichment, Recap), chat pagination.
- **Exit:** definition of done below is met.

## Definition of "semi-production done"

Auth + per-user isolation enforced by per-collection rules & verified by tests; all features on Firestore; no
client-side API key; AI errors surfaced (top popup); cascade deletes clean up Storage; App Check on (Android/iOS/Web;
Windows debug provider); CI green at the agreed coverage; builds produced for Android, iOS, Windows, Web.
