# MyRoom Refactor Plan — Overview / Index

Target: migrate MyRoom from Flutter + SQLite to Flutter + Firebase. One file per topic; each is self-contained.

| File | Topic |
| --- | --- |
| `StateManagement.md` | go_router shell + fused state + Provider DI |
| `Repositories.md` | Repo contracts, Result types, optimistic updates |
| `DataModel.md` | Firestore collections + denormalization fan-out |
| `Auth.md` | Auth flows, userId scoping, guard, provisioning |
| `AI_proxy.md` | Cloud Functions, Responses API, contracts |
| `Storage.md` | Firebase Storage + attachments |
| `Security.md` | Firestore/Storage rules, indexes, App Check |
| `DevOps.md` | Firebase env, flutterfire, emulators, CI/CD |
| `Test.md` | Testing strategy |
| `Phasing.md` | Phase ordering, milestones, definition of done |
| `SystemDiagram.md` | Component/data-flow diagram (mermaid) |

`firebase_port_extraction.md` holds the verbatim audit of the current code (schema, prompts, tool JSON, contracts).

## Architecture

- **State** — go_router `StatefulShellRoute` owns nav state; fused state (ephemeral UI state in widgets, shared state
  via Firestore streams); DI via the `provider` package; no business-logic controllers.
- **Persistence** — Firestore only; local cache is the optimistic source of truth (the Firestore SDK cache — not a
  hand-rolled in-memory store; it reflects writes optimistically and serves offline, so the UI never maintains a
  separate optimistic list).
- **AI / functions** — Cloud Functions on the OpenAI Responses API; no client key. **Callables** (chat,
  classifyMultiInput, fetchRecommendations, generateEraInsight, transcribe, exportRecap, exportAchievement) and
  **triggers** (enrichIdea, classifyNote, findNotesForCategory, categoryFanout, storageCascade, provisionUser,
  deleteUserData); `chat` executes tools server-side.
- **Greenfield** — no data migration; new users start empty.
- **Platforms** — Android, iOS, Windows, Web (Chrome focus).
- **i18n** — out of scope; UI stays `zh-TW`.
- **Categories per type** — separate `todo_categories` and `note_categories`, each with a `無分類` sentinel;
  denormalized copies refreshed by `categoryFanout`.
- **Recap page** — streams two collections: `recaps` (titled reviews) and `achievements` (past/current/future
  summaries), each CRUD via its repo (`RecapRepo` / `AchievementRepo`); content is text, with optional PDF/graphic
  exports via `exportRecap` / `exportAchievement`. The page renders (1) the `achievements` era sections — three
  editable text blocks (`pastContent`/`currentContent`/`futureContent`), each with `generateEraInsight` + export — and
  (2) the `recaps` list (CRUD, each with content + export). **No** per-era milestone-item list and **no** inline
  images: the demo's `recap_items` model and `generateEraImage`/DALL-E are dropped.
- **User preferences** — singleton `users/{uid}/settings/app` doc.
- **Attachments** — Firebase Storage, content-addressed filenames, authenticated downloads, cascade via `onDelete`.
- **Security** — per-collection owner-only Firestore rules that block clients from forging fn-owned data; App Check on
  all platforms.
