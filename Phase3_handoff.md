# Phase 3 (Hardening & Polish) — Handoff / Continuation Guide

> **STATUS: IN PROGRESS.** The Flutter side is done and fully green (108 tests).
> The Cloud Functions side is **blocked** by a Phase 2 gap (the entire
> `functions/src/lib/` is missing). Read §3 (Blocker) and §5 (Remaining) to
> continue. A prompt like *"continue phase 3"* should start at §5.
>
> **Nothing is committed yet** — all Phase 3 work is in the working tree
> (`git status` = many `M` + untracked `test/`, `lib/core/widgets/mr_skeleton.dart`,
> this file). Decide whether to commit the done Flutter work before/while
> continuing (see §7).

Reference: `refactor_guide/Phasing.md` §"Phase 3" + "Definition of done";
`refactor_guide/Test.md`; `refactor_guide/Security.md`; `refactor_guide/DevOps.md`;
`refactor_guide/DataModel.md`. Today's project date: 2026-06-10.

---

## 1. Phase 3 deliverables — status at a glance

| # | Deliverable (Phasing.md) | Status |
|---|---|---|
| 1 | `categoryFanout` fan-out verified across both category types | ⚠️ Code already correct + loop-safe (`functions/src/triggers/categoryFanout.ts`); **test pending** (needs §3 unblock) |
| 2 | Indexes finalized from real queries | ✅ Done — verified `firestore/firestore.indexes.json` is correct (see §2.2) |
| 3 | Tests to the bar in `Test.md` | 🔶 Flutter layers DONE; Functions + security-rules layers PENDING (see §4, §5) |
| 4 | CI green (`DevOps.md`) | ❌ Pending — workflow not written yet (see §5.4); blocked on functions build |
| 5 | Strict lints (`avoid_print`, `unawaited_futures`, `prefer_const_constructors`) | ✅ Done — analyze + `dart format` clean |
| 6 | Loading skeletons (Ideas enrichment, Recap) + chat pagination | ✅ Done (see §2.3) |
| 7 | Definition of "semi-production done" | 🔶 Most met on the client; functions/CI/rules-tests outstanding |

**Quick verify of the current (Flutter) state:**
```bash
cd /Users/ameliashih/ss_demo/myroom
flutter analyze                              # → No issues found!
dart format --output none --set-exit-if-changed lib test   # → exits 0 (clean)
flutter test                                 # → All tests passed! (108)
```

---

## 2. What is DONE (Flutter side) — detail

### 2.1 Strict lints  (`analysis_options.yaml`)
- Enabled `avoid_print`, `unawaited_futures`, `prefer_const_constructors`
  (+ `prefer_const_constructors_in_immutables`, `prefer_const_declarations`).
- Escalated `unawaited_futures` and `avoid_print` to **error** under `analyzer.errors`.
- Ran `dart fix --apply` (fixed 18 const-constructor sites) and `dart format`
  (**reformatted 44 pre-existing files** — that's why `git status` shows many `M`
  files with no logic change; CI step `dart format --set-exit-if-changed` requires this).
- Kept the existing `deprecated_member_use: ignore` (Firebase SDK churn).

### 2.2 Indexes  (`firestore/firestore.indexes.json`) — verified, no change needed
Audited every repo query. **Only `notes` needs composite indexes**, and both are
present (`dateKey ASC, createdAt DESC` and `category.id ASC, createdAt DESC`).
Everything else is a single-field order/range (auto-indexed by Firestore):
`todos.sortOrder`, `events.startTime` (range+order on same field),
`ideas/user_ideas.createdAt`, `pinned_resources.sortOrder`, `chat_messages.createdAt`,
`recaps.createdAt`, `achievements.createdAt`, `note_categories.sortOrder`.
→ The file is **correct and complete**. (Confirm later via emulator "index required"
errors when the functions/emulator come up, but static analysis is authoritative.)

### 2.3 UI polish
- **New widget** `lib/core/widgets/mr_skeleton.dart`: `MrShimmer` (ShaderMask sweep,
  no external `shimmer` package), `MrSkeletonBox`, `MrSkeletonLines`.
- **Ideas enrichment skeleton** (`ideas_page.dart` `_buildAiPanel`): while
  `aiStatus == 'processing'`, renders a card with "AI 分析中…" + `MrSkeletonLines`
  instead of the old plain text.
- **Recap skeleton** (`recap_page.dart`): added `_generating` flag to `_EraBlockState`
  and `_RecapCardState`; while a `generateEraInsight` call is in flight, the text
  body shows `MrSkeletonLines` (export still uses the header spinner only).
- **Chat pagination** (the load-more affordance was missing in the UI):
  - `chat_repo.dart`: added `static const int pageSize = 50`; **changed
    `loadOlder(DocumentSnapshot cursor)` → `loadOlder(ChatMessage cursor)`** because
    the stream yields `ChatMessage` (no snapshots), so the old signature was
    un-wireable from the UI.
  - `firebase_chat_repo.dart`: `loadOlder` now fetches the cursor doc by id and uses
    `startAfterDocument` (collision-proof; matches the guide's original intent), with
    a `startAfter([Timestamp])` fallback if the cursor doc was deleted.
    ⚠️ **Gotcha:** `fake_cloud_firestore`'s `startAfter([Timestamp])` with a
    `descending` order returns empty — `startAfterDocument` is required for tests to pass.
  - `chat_overlay.dart`: local `_older` list + `_hasMore` + `_loadingOlder`; merges
    `_older` with the live tail (dedupe by id, sort by `createdAt`); **guards
    auto-scroll** so prepending history doesn't yank to bottom (tracks `_newestId`);
    `_LoadMoreButton` ("載入更多訊息") shown only when `_hasMore && (tail.length >= pageSize || _older.isNotEmpty)`.

### 2.4 Latent bug fixed  (`lib/core/widgets/mr_card.dart`)
`MrCard(leftBorderColor: …)` used `Row(crossAxisAlignment: stretch)` which throws
"BoxConstraints forces an infinite height" inside an unbounded-height parent
(a `ListView` item) — e.g. every `_RecapCard`. Wrapped the Row in `IntrinsicHeight`.
The recap widget test surfaced this; it would also crash the real Recap page once a
recap card renders.

### 2.5 Tests added (Flutter) — all green, 108 total
Test deps added to `pubspec.yaml` dev_dependencies: `fake_cloud_firestore ^3.1.0`,
`firebase_auth_mocks ^0.14.2`, `mocktail ^1.0.5`, `firebase_storage_mocks ^0.7.0`.

Support helpers:
- `test/support/firestore_helpers.dart` — `snapshotOf(map)` builds a real
  `DocumentSnapshot` from a fake Firestore (for `fromFirestore` tests); `ts2026`.
- `test/support/fakes.dart` — `FakeStorageRepo` (in-memory), `FakeAiService`
  (records calls / canned results), `FakeAuthRepo` (records sign-in).
- `test/support/widget_harness.dart` — `pumpPage()` wraps providers + MaterialApp +
  Scaffold, sets `GoogleFonts.config.allowRuntimeFetching = false` (offline/deterministic),
  pumps twice for the first stream snapshot.

Model serialization (`fromFirestore`/`toJson` round-trips + defaults):
`test/features/{calendar,todo,ideas,notes,recap,settings,chat}/domain/*_test.dart`
and `test/shared/ai/classification_test.dart` (the sealed `ClassificationItem`:
discriminator + 5 item types + null for unknown; `AiResource`, `AiAttachmentRef`).

Repository tests (real repos backed by `fake_cloud_firestore`; CRUD, stream order,
**userId scoping**, todo **reorder** dense 0..N-1, idea **pin sha1 dedupe**, note
**content-addressed upload + extracted_texts** (audio writes it, image does NOT),
upload-failure abort, `watchNoteDateKeys`, nested `category.id` query, settings
partial-merge): `test/features/*/data/*_test.dart` (calendar, todo, ideas, notes,
recap+achievement, settings, chat-pagination).

Widget tests (≥1 happy path per feature):
`test/core/widgets/mr_skeleton_test.dart`,
`test/features/{calendar,todo,ideas,notes,recap,settings}/presentation/*_test.dart`,
`test/features/chat/presentation/chat_overlay_test.dart`,
`test/features/auth/presentation/login_page_test.dart`,
`test/features/add/presentation/add_overlay_test.dart`.
- Ideas test asserts the enrichment **skeleton** shows.
- Chat test asserts empty-state, bubbles, send→`AiService.chat`, and load-more
  visibility (present at 55 msgs, absent at 3).
- Login test asserts `AuthRepo.signIn` is called with the entered creds.

Gotchas baked into the tests (keep when extending):
- `AppErrors.present` no-ops when `scaffoldMessengerKey.currentState == null` → safe
  in repo tests.
- `Timestamp.toDate()` returns **local** time → compare instants
  (`isAtSameMomentAs`), not `DateTime.utc(...)` equality.
- Never `pumpAndSettle` a view with a shimmer/spinner (animates forever) — use
  bounded `pump(Duration)`.
- Ideas live at `users/{uid}/ideas/data/user_ideas/{id}` and
  `…/ideas/data/pinned_resources/{id}` (fixed `data` parent doc, `kIdeasRootDocId`).

---

## 3. ⛔ BLOCKER — Phase 2's Cloud Functions do not compile

`functions/src/{callable,triggers,middleware}` import **12 shared modules from
`functions/src/lib/` that do not exist** and were **never committed** (checked
`refactor`, `origin/main`, `upstream/refactor`, all stashes — absent everywhere).
The Phase 2 session hit its limit during review; the `lib/` it described in
`Phase2_summary.md` ("openai, context, rateLimit, categories, date, prompts,
schemas, tools, render") was lost. Therefore `npm run build` (tsc) cannot succeed,
which blocks: functions unit tests, the functions CI job, and the formal
definition-of-done. (`functions/node_modules` is also not installed — run `npm ci`
once a `package-lock.json`-consistent tree exists.)

### 3.1 Exact modules + required exports to recreate (`functions/src/lib/`)

| Module | Must export (used by) |
|---|---|
| `admin.ts` | `db`, `storage` (Admin SDK handles), `REGION` (string, e.g. `'asia-east1'` = `kFunctionsRegion`). Initializes `firebase-admin`. **Imported by nearly every file.** |
| `config.ts` | `MODELS` (map: chat/classify/search/whisper model ids), `REQ_TIMEOUT` (ms), `UNDEFINED_CAT` (`'undefined'`), `DEFAULT_TZ` (`'Asia/Taipei'`), `USER_LOCATION` (for web-search models), `LOOP_LIMIT_REPLY` (canned zh-TW round-limit reply string), `MAX_CHAT_ROUNDS` (6) |
| `openai.ts` | `createResponse(params)`, `extractJson(resp)`, `transcribeAudio({bytes,filename})`, type `ResponsesParams`. Wrap the **OpenAI Responses API** + Whisper; 3× retry; timeout→`HttpsError`. Key from Secret Manager `OPENAI_API_KEY`. |
| `prompts.ts` | `chatSystemPrompt(...)`, `classifyMultiSystemPrompt(...)`, `ENRICH_IDEA_SYSTEM`, `ERA_INSIGHT_SYSTEM`, `eraInsightUser(...)`, `RECOMMEND_SYSTEM`, `CLASSIFY_NOTE_SYSTEM`, `classifyNoteUser(...)`, `FIND_NOTES_SYSTEM`, `findNotesUser(...)` — **verbatim zh-TW**, source in `firebase_port_extraction.md` (see §3.2) |
| `context.ts` | `buildContext(...)` — bounded chat context (AI_proxy.md) |
| `schemas.ts` | `CLASSIFY_MULTI_SCHEMA`, `CLASSIFY_NOTE_SCHEMA`, `FIND_NOTES_SCHEMA`, `jsonFormat(schema)` (Responses API JSON-schema response_format helper) |
| `date.ts` | `todayKey(tz)` (and tz-aware "now") — injects the real date into prompts |
| `categories.ts` | `loadTodoCats(uid)`, `loadNoteCats(uid)`, `findNoteCat(...)` — read once + `{id,label}` injection/validation |
| `defaultCategories.ts` | `DEFAULT_TODO_CATEGORIES`, `DEFAULT_NOTE_CATEGORIES` (seed arrays for `provisionUser`; each incl. the `undefined` sentinel) |
| `rateLimit.ts` | `enforceRateLimit(uid)` — 60/hr via `users/{uid}/_internal/rateLimit` txn; throws `resource-exhausted` |
| `tools.ts` | `buildChatTools(...)`, `runToolCall(...)`, type `ToolContext` — **9 write tools + 4 real `list_*` tools**; server-side execution via Admin SDK |
| `render.ts` | `renderRecapExport(...)`, `renderAchievementExport(...)` — **SVG** export persisted to Storage (deliberate: SVG renders zh-TW via viewer fonts, no CJK font binary in the image) |

Per-file dependency callgraph (what each function pulls in):
```
callable/chat.ts            -> admin,categories,config,context,date,openai,prompts,rateLimit,tools
callable/classifyMultiInput -> admin,categories,config,date,openai,prompts,rateLimit,schemas
callable/exportAchievement  -> admin,render
callable/exportRecap        -> admin,render
callable/fetchRecommendations -> admin,config,openai,prompts,rateLimit
callable/generateEraInsight -> admin,config,openai,prompts,rateLimit
callable/transcribe         -> admin,config,openai,rateLimit
middleware/auth.ts          -> admin,config          (EXISTS: requireUid(), loadSettings())
triggers/categoryFanout.ts  -> admin,config          (EXISTS, correct, loop-safe)
triggers/classifyNote.ts    -> admin,categories,config,openai,prompts,schemas
triggers/deleteUserData.ts  -> admin
triggers/enrichIdea.ts      -> admin,config,openai,prompts
triggers/findNotesForCategory -> admin,config,openai,prompts,schemas
triggers/provisionUser.ts   -> admin,defaultCategories
triggers/storageCascade.ts  -> admin
index.ts                    -> admin
```

### 3.2 Where the verbatim content lives — `firebase_port_extraction.md` (1339 lines)
- `## 1` SQLite schema (field reference cross-check)
- `## 3`-ish: each AI op's **verbatim system prompt** (search "System prompt (verbatim)"
  — chat, classifyMultiInput, enrichIdea, fetchRecommendations, classifyNote,
  findNotes, eraInsight). Categories are appended at runtime (see "injected categories").
- `## 4` **Chat Tool Definitions (Full JSON) and Loop Logic** — the 9 write tools +
  loop (`finish_reason == 'tool_calls'`, ≤6 rounds, canned round-limit reply).
- The original Dart source of truth is the pre-refactor `lib/services/openai_service.dart`
  on `main`/`upstream` history if more detail is needed.

**Recommendation when rebuilding:** keep prompts/tool JSON byte-for-byte from the
extraction doc; the field names must match `DataModel.md` (e.g. note items carry no
title → default `'無標題'`; todo/note categories are separate; `aiStatus`/`aiSummary`/
`links` are fn-only).

---

## 4. Test bar reference (`refactor_guide/Test.md`) — what's left to satisfy

Done: model serialization (incl. `ClassificationItem`), all repo CRUD+scoping+reorder,
note cascade-create (extracted_texts), ≥1 widget test per feature.

Outstanding (need §3 unblock + §5):
- **Cloud Functions tests** (`functions/`, jest/**vitest** + `firebase-functions-test`):
  callable auth-token + App Check rejection, request/response contract, retry/timeout
  (mock OpenAI), chat context-bounding + server-side tool loop + stop conditions
  (incl. canned round-limit reply), rate-limit `resource-exhausted`,
  `exportRecap`/`exportAchievement` persist to Storage + write the `…ExportStoragePath`.
  Triggers (emulator): `provisionUser` (root doc + `settings/app` + default cats),
  `enrichIdea` (processing→completed/error, respects `autoEnrich`), `classifyNote`
  (only on the `undefined` note-cat), `findNotesForCategory`, `categoryFanout`
  (refresh + reassign-to-`undefined` on delete), `storageCascade`, `deleteUserData`.
- **Security-rules tests** (`@firebase/rules-unit-testing`): owner-vs-non-owner
  allow/deny; `createdAt` immutability; 10 MB Storage cap; per-collection field
  restrictions (client cannot write `chat_messages`; cannot set/modify
  `aiSummary`/`aiStatus`/`links` on ideas, `exportStoragePath` on recaps,
  `*ExportStoragePath` on achievements; cannot touch `_internal`). **Not blocked by
  the functions build** — can be done independently against the Firestore emulator +
  `firestore/firestore.rules`.
- Coverage target: **60%** on `lib/features/**/data` and `functions/src`.

Tooling already present locally: Flutter 3.41.8, Node v26, npm 11, firebase-tools
15.18, Java 26 (emulators OK). `firebase.json` already wires emulators
(auth 9099, firestore 8080, storage 9199, functions 5001).

---

## 5. REMAINING WORK — ordered plan for "continue phase 3"

### 5.1 Rebuild `functions/src/lib/` (unblocks everything backend)  ← do FIRST
Recreate the 12 modules in §3.1 from `firebase_port_extraction.md`. Then:
```bash
cd functions && npm install        # or: npm ci once package-lock is consistent
npm run build                      # tsc must be clean
```
Acceptance: `tsc` clean; emulator `firebase emulators:start` loads all 14 functions.

### 5.2 Functions tests (vitest + firebase-functions-test)
- Add `vitest` + `firebase-functions-test` to `functions/package.json` devDeps;
  set `"test": "vitest run"`.
- **Pure-lib unit tests** (no emulator/OpenAI): `date.todayKey`, `categories` validation/
  injection, `context.buildContext` bounding, `tools` shape (9 write + 4 list),
  `schemas` shape, `config` constants.
- **Callable tests**: `requireUid` throws `unauthenticated` with no `req.auth`; mock the
  `openai` wrapper module for happy-path contracts; rate-limit path.
- **Trigger tests** (Firestore emulator): per §4. Mock the `openai` wrapper so no real key
  is needed and CI stays green.
- Acceptance: `npm test` green; ≥60% on `functions/src`.

### 5.3 Security-rules tests  (independent — can be done even before 5.1)
- New node project (suggest `firestore/test/` or `test_rules/`) with
  `@firebase/rules-unit-testing` + vitest/jest; load `firestore/firestore.rules` and
  `storage.rules`; run against the emulator.
- Cover the owner-isolation / `createdAt`-immutability / fn-field / `_internal` /
  10 MB cap cases in §4.
- Acceptance: green against `firebase emulators:exec`.

### 5.4 CI wiring (`.github/workflows/ci.yml`)  (DevOps.md §CI/CD)
Note: existing `.github/workflows/{claude.yml,claude-code-review.yml}` are the Claude
bot, **not** project CI. Add a new workflow:
1. `flutter analyze` + `dart format --output none --set-exit-if-changed lib test`
2. `flutter test` (note: repo tests use `fake_cloud_firestore`, so **no emulator needed**
   for the Flutter job as currently written)
3. `functions`: `npm ci && npm run build && npm test` (needs 5.1)
4. rules tests: `firebase emulators:exec '<run rules tests>'` (needs 5.3)
5. (deploy-on-tag is optional for semi-prod)
Acceptance: all jobs green.

### 5.5 Definition of done (Phasing.md) — final checklist
Auth + per-user isolation enforced by rules **and tests** (5.3); all features on
Firestore (done); no client API key (done — `CloudFunctionAiService`); AI errors as
top popup (done — `AppErrors`); cascade deletes clean Storage (needs `storageCascade`
build+test); App Check on (verify enforced in functions once they build); CI green
(5.4); builds for Android/iOS/Windows/Web (smoke `flutter build` per target).

---

## 6. Key decisions & gotchas (don't relitigate)
- **`loadOlder(ChatMessage)`** not `loadOlder(DocumentSnapshot)` — see §2.3. Repo test
  asserts the pagination; keep `startAfterDocument`.
- **`MrCard` IntrinsicHeight** — keep; it's a real fix (§2.4).
- **Exports are SVG** (not PDF) by deliberate Phase 2 design — preserve in `render.ts`.
- **`dart format` reformatted 44 files** — that churn is intentional (CI requires it).
- **fake_cloud_firestore** is used for repo + widget tests instead of the live emulator
  (Test.md allows it for fast unit tests; the live emulator can't be reached from a pure
  `flutter test` without `integration_test`). Owner-isolation is therefore proven in the
  **rules** suite (5.3), not the repo suite.
- **google_fonts**: `allowRuntimeFetching = false` in the widget harness; keep it.

---

## 7. Git state & commit guidance
Nothing committed for Phase 3. Working tree:
- **Logic changes**: `analysis_options.yaml`, `pubspec.yaml`/`.lock`,
  `lib/core/widgets/mr_card.dart`, `lib/features/chat/{domain/chat_repo.dart,
  data/firebase_chat_repo.dart, presentation/chat_overlay.dart}`,
  `lib/features/ideas/presentation/ideas_page.dart`,
  `lib/features/recap/presentation/recap_page.dart`.
- **New**: `lib/core/widgets/mr_skeleton.dart`, `test/**` (25 new test files + 3
  support files), this `Phase3_handoff.md`.
- **Formatting-only `M`**: all other `lib/**` files (pure `dart format`).

Suggested: commit the verified Flutter hardening now so it isn't lost
(`flutter analyze` + `flutter test` are green), e.g. branch is already `refactor`:
> `Phase 3 (partial): strict lints, indexes verified, skeletons + chat pagination,
> 108 Flutter tests; MrCard infinite-height fix. Functions/rules tests + CI pending
> on functions/src/lib reconstruction (see Phase3_handoff.md).`
Then continue at §5.1.
