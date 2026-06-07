# MyRoom — Production Handoff Documentation

> **Audience**: Production engineering team preparing the codebase for a stable public release.
> **Purpose**: Explains what is built, how it is structured, where the technical debt lives, and what must be done before shipping.

---

## 1. What This App Is

MyRoom is a Flutter personal productivity app for students and young professionals. It combines five organisational tools (calendar, to-do list, idea journal, notes, life recap) with an AI layer powered by OpenAI. The distinctive feature is a **Smart Add** overlay that accepts free-form text, photos, audio recordings, and files (PDF/images) and uses GPT-4o-mini to classify the input into the appropriate module in a single action.

Supported platforms: **Android, iOS, Windows desktop**. Web is explicitly excluded.

---

## 2. Repository Layout

```
myroom/
├── lib/
│   ├── main.dart                  # App entry, root shell, global state
│   ├── config.dart                # API keys — GITIGNORED, must be created manually
│   ├── theme.dart                 # Design tokens (colours, fonts, shadows)
│   ├── models/                    # Pure data classes — no logic
│   │   ├── event.dart
│   │   ├── todo_item.dart
│   │   ├── idea.dart
│   │   ├── note_item.dart
│   │   ├── recap_item.dart
│   │   └── ai_resource.dart
│   ├── services/
│   │   ├── database_service.dart  # SQLite singleton — all persistence
│   │   ├── openai_service.dart    # OpenAI REST client — all AI calls
│   │   └── attachment_storage.dart# File I/O for attachments
│   ├── data/
│   │   └── seed_data.dart         # Hardcoded first-run data
│   ├── pages/
│   │   ├── calendar_page.dart
│   │   ├── todo_page.dart
│   │   ├── idea_page.dart
│   │   ├── note_page.dart
│   │   ├── recap_page.dart
│   │   └── setting_page.dart
│   ├── overlays/
│   │   ├── add_overlay.dart       # Smart Add — multi-modal classification
│   │   ├── ai_chat_overlay.dart   # Full-screen AI chat with tool execution
│   │   └── tutorial_overlay.dart  # First-run onboarding
│   └── widgets/
│       ├── bottom_nav_bar.dart
│       ├── mr_card.dart
│       ├── mr_icon_button.dart
│       ├── mr_add_row.dart
│       └── note_modal_sheet.dart
├── android/
├── ios/
├── windows/
├── pubspec.yaml
└── README.md
```

---

## 3. Architecture

### 3.1 State Management — Callback Pattern

There is **no external state-management library** (no Riverpod, Bloc, Provider, etc.). All global state lives in `MyRoomShell` in `main.dart`.

```
MyRoomShell (StatefulWidget)
  ├── _events    : List<CalendarEvent>
  ├── _todos     : List<TodoItem>
  ├── _ideas     : List<Idea>
  ├── _notes     : List<NoteItem>
  ├── _categories: List<TodoCategory>
  └── _recapItems: List<RecapItem>
```

Child pages receive their slice of data plus named callbacks (`onTodoAdded`, `onEventDeleted`, `onIdeaAdded`, `onNotesMutated`, …). When a callback fires:

1. The shell calls the corresponding `DatabaseService` mutator.
2. It optionally triggers an AI enrichment call (ideas, notes).
3. It fetches the updated list from the DB.
4. It calls `setState()`, which re-renders the relevant page.

**Exception**: `NotePage` writes directly to `DatabaseService` and notifies the shell via `onNotesMutated()` for efficiency (notes are edited inline and would cause too many round-trips through the shell).

`_KeepAlive` is a mixin applied to each tab widget so `PageView` does not rebuild them when the user switches tabs.

### 3.2 Persistence — SQLite

`DatabaseService` is a lazy singleton (`DatabaseService.instance`). On first open it creates all tables and seeds initial data. It uses `sqflite` on Android/iOS and `sqflite_common_ffi` on Windows/Linux/macOS.

**14 tables** (schema version 1 — no migration logic yet):

| Table | Purpose |
|---|---|
| `todos` | Task rows |
| `categories` | Todo category labels |
| `events` | Calendar events |
| `ideas` | Idea journal entries |
| `notes` | Date-keyed note bodies |
| `note_categories` | User-created note groupings |
| `note_attachments` | Image/audio/file metadata |
| `recap_items` | Past/Now/Future milestone items |
| `chat_messages` | Persisted AI chat history |
| `pinned_resources` | Bookmarked explore-tab resources |
| `user_profile` | Self-intro + AI instruction text |
| *(3 others)* | Metadata / misc |

Events store year, month, day, hour, minute as separate integer columns (not a Unix timestamp). This simplifies calendar lookup queries but complicates range queries and timezone handling.

### 3.3 AI Integration — Direct HTTP

`OpenAIService` is a lazy singleton that calls the OpenAI REST API directly over `http`. There is no abstraction layer or provider interface between the app and OpenAI.

**Models in use:**

| Constant | Model | Use |
|---|---|---|
| `openAiModel` | `gpt-4o-mini` | Chat, classification, insights |
| `openAiWebSearchModel` | `gpt-4o-mini-search-preview` | Idea enrichment, recommendations |
| `openAiWhisperModel` | `whisper-1` | Audio transcription |
| `openAiImageModel` | `dall-e-2` | Era images (note: constant says dall-e-2, README says DALL-E 3 — verify) |

**8 AI operations:**

| Method | Description |
|---|---|
| `chat()` | Conversational assistant with 9 CRUD tool definitions. Loops up to 6 rounds until `finish_reason != "tool_calls"`. |
| `classifyMultiInput()` | Accepts text + base64 images + audio blobs + extracted file text. Returns a `List<ClassificationResult>` (sealed class hierarchy). |
| `enrichIdea()` | One-sentence insight + 2–3 resource links for a single idea. |
| `fetchRecommendations()` | 4–6 curated resources derived from the top 5 ideas. |
| `classifyNoteToCategory()` | Maps a single note to the best matching user category. |
| `findNotesMatchingCategory()` | Batch: given a new category, returns which existing uncategorised notes belong to it. |
| `generateEraInsight()` | 2–3 sentence reflective paragraph for a Recap era (Past/Now/Future). |
| `generateEraImage()` | DALL-E image for a Recap era. |

**Classification result sealed class hierarchy** (`ClassificationResult`):
- `ClassifiedTodo` — text, priority, category
- `ClassifiedTodoWithTime` — above + start/end datetime
- `ClassifiedIdea` — text
- `ClassifiedNote` — text, optional category, attachment index list
- `ClassifiedRecap` — era, title, description
- `ClassificationError` — raw error string

### 3.4 File Attachments

`AttachmentStorage` writes binary files under `<appDocuments>/note_attachments/` using relative paths stored in the `note_attachments` DB table. There is no content-addressed storage or deduplication. Orphan files are not cleaned up automatically.

---

## 4. Feature Walkthroughs

### 4.1 Calendar (`calendar_page.dart`)

- Three views: month, week, day (enum `CalendarView`)
- Custom time picker using `ListWheelScrollView` for 24h input
- Events displayed with coloured chips
- Add/edit/delete via bottom sheet dialogs
- Events passed in from `MyRoomShell`; mutations fire shell callbacks

### 4.2 To-Do (`todo_page.dart`)

- Filter by category; toggle to show/hide completed items
- Drag-to-reorder with stable session-level display order
- On tab focus, completed items sink to the bottom
- Inline add form with category picker and priority selector
- Categories editable from within the page

### 4.3 Ideas (`idea_page.dart`)

Two sub-tabs:

**Record** — User types an idea → added to DB → `enrichIdea()` runs asynchronously → card expands to show AI summary and resource links.

**Explore** — `fetchRecommendations()` derives 4–6 links from the top 5 ideas → user can pin resources → pins persist in `pinned_resources` table.

### 4.4 Notes (`note_page.dart`)

Two modes accessible via toggle:

**Date mode** — Full-year calendar with dot indicators for days that have notes. Tap a day to open a panel: one primary note editor + list of existing notes. Supports image/audio/file attachments. On panel close, `classifyNoteToCategory()` auto-assigns the note to a category if unclassified.

**Category mode** — Grid of user-created categories. Tap to see all notes in that category. When a category is created, `findNotesMatchingCategory()` runs in the background to retroactively assign matching notes.

### 4.5 Recap (`recap_page.dart`)

Timeline of three eras (Past, Now, Future). Left sidebar with era selector dots; right pane is a `PageView` with vertical scroll per era.

On first tap of each era, `generateEraInsight()` and `generateEraImage()` are called lazily; results are cached in widget state (not persisted to DB — regenerated each session).

### 4.6 Smart Add (`add_overlay.dart`)

Entry point for all content creation without knowing the destination in advance:

1. User types text, attaches photos/files, or records audio.
2. Audio is transcribed with Whisper; PDFs are text-extracted with `pdfrx`; images are base64-encoded.
3. All inputs are bundled into `classifyMultiInput()`.
4. The response is a list of `ClassificationResult` items.
5. Each item is routed to the appropriate shell callback (or note service directly).
6. Attachments are saved via `AttachmentStorage` and linked in `note_attachments`.
7. A summary chip shows what was created ("✓ 新增 1 行程、1 待辦、1 筆記").

### 4.7 AI Chat (`ai_chat_overlay.dart`)

Full-screen conversation panel. On open, loads history from `chat_messages`. The system prompt includes the user's self-introduction, AI instructions (from Settings), and a full dump of current todos, events, ideas, notes, and recap items.

The model is given 9 tool definitions (add/delete for each entity type). The service loops until no more tool calls remain (up to 6 rounds). Tool results are displayed inline in the chat as JSON chips.

---

## 5. Configuration

### 5.1 API Key Setup

`lib/config.dart` is in `.gitignore`. It must be created manually before the first build:

```dart
class AppConfig {
  static const openAiApiKey = 'sk-...';
  static const openAiModel = 'gpt-4o-mini';
  static const openAiWebSearchModel = 'gpt-4o-mini-search-preview';
  static const openAiWhisperModel = 'whisper-1';
  static const openAiImageModel = 'dall-e-2';
}
```

There is no runtime secret injection, no `.env` loading, no platform-level secret store. The key is compiled into the binary.

### 5.2 Build Requirements

- Flutter ≥ 3.41.6 / Dart ≥ 3.11.4
- Android: `minSdk` and `targetSdk` set in `android/app/build.gradle`
- iOS: standard Runner configuration, no custom entitlements observed
- Windows: `sqflite_common_ffi` requires the `sqlite3.dll` to be distributed alongside the exe (see `windows/flutter/generated_plugins.cmake`)

---

## 6. Dependencies (Key)

| Package | Version (from lock) | Purpose |
|---|---|---|
| `sqflite` | stable | SQLite on mobile |
| `sqflite_common_ffi` | stable | SQLite on desktop |
| `http` | stable | OpenAI REST calls |
| `google_fonts` | stable | Cormorant Garamond + DM Sans |
| `lucide_icons_flutter` | stable | Icon set |
| `file_picker` | stable | File attachment |
| `record` | stable | Audio recording |
| `permission_handler` | stable | Microphone permission |
| `pdfrx` | stable | PDF text extraction |
| `path_provider` | stable | Platform file paths |
| `url_launcher` | stable | Open links |

---

## 7. Known Technical Debt and Production Risks

### CRITICAL

**7.1 API key hardcoded in binary**
`lib/config.dart` compiles the OpenAI key directly into the app binary. On mobile, it can be extracted via reverse engineering. Before release, move to a backend proxy so the key never leaves your servers.

**7.2 No database migration strategy**
`DatabaseService` creates tables in `_onCreate` with no `_onUpgrade` handler. If the schema changes between releases, existing users' databases will not be updated, causing crashes or data loss. Add a versioned migration chain before the first public release.

**7.3 No error handling on AI calls**
Most `OpenAIService` methods throw or return null on network failure or non-200 responses without surfacing errors to the user. The `chat()` loop has no timeout guard. AI failures in Smart Add can silently drop user content.

**7.4 OpenAI context window unbounded**
The `chat()` system prompt injects the full contents of all todos, events, ideas, notes, and recap items. A user with many items will exceed the model context limit, causing hard failures. No truncation or summarisation is applied.

### HIGH

**7.5 Callback-based state management does not scale**
`MyRoomShell` already manages ~20 callbacks. Adding features or fixing cross-page reactivity becomes error-prone. The production refactor should adopt a proper state-management solution (Riverpod recommended for this team size and app shape).

**7.6 NotePage bypasses the shell pattern**
`NotePage` writes directly to `DatabaseService` and signals the shell via `onNotesMutated()`. This inconsistency means notes-related state can go stale in the shell without any developer noticing during code review.

**7.7 Seed data runs on every first launch per table**
`seed_data.dart` inserts hardcoded Chinese-language sample data. If any table is empty (e.g., after a selective DB wipe or partial migration), seeds re-insert. Production apps should not ship with demo content; the seed system needs a one-time flag.

**7.8 Era images and insights are not persisted**
`RecapPage` regenerates DALL-E images and AI insights every cold session. This costs money per session and creates a jarring experience as content reloads. Images should be saved to `AttachmentStorage` and insights cached in the DB.

**7.9 Duplicate model name in config comment**
`AppConfig.openAiImageModel = 'dall-e-2'` but README states DALL-E 3 is used for era images. Verify which model is actually called and align the constant name and value.

**7.10 Attachment orphan leak**
When a note is deleted, `note_attachments` rows should trigger deletion of the corresponding files via `AttachmentStorage.delete()`. Currently there is no cascade cleanup, so files accumulate in the documents directory indefinitely.

### MEDIUM

**7.11 Event datetime model is fragmented**
`CalendarEvent` stores year, month, day, hour, minute as six separate integer columns. This makes range queries (e.g., "events in the next 7 days") unnecessarily complex and breaks timezone-aware handling. Migrate to a single `DateTime` stored as an ISO-8601 string or Unix timestamp.

**7.12 All text is hardcoded in Traditional Chinese**
Labels, messages, and seed content are in `zh-TW` with no localisation infrastructure (`flutter_localizations`, `intl`, ARB files). Any future i18n work must retrofit the entire codebase.

**7.13 No loading states on AI-heavy operations**
`IdeaPage` enriches ideas after insert, but there is no skeleton loader or shimmer — the card simply shows nothing until the AI responds. Long latency (web search model) causes apparent blank content.

**7.14 Chat history grows unbounded**
`getChatMessages()` returns the full history. A user with months of chat will send a very large payload on every chat open. Implement a windowed query (last N messages) with a "load more" affordance.

**7.15 Permission handling is best-effort**
The audio recording flow requests `RECORD_AUDIO` permission inline in the overlay. There is no graceful degradation path or explanation UI if the user denies permission.

**7.16 No tests**
`test/` directory exists but contains no test files. There are no unit tests for models, no mock-based service tests, and no widget tests. The minimum viable test surface before production: `DatabaseService` CRUD, `ClassificationResult` JSON parsing, and the `chat()` tool execution loop.

### LOW

**7.17 `_KeepAlive` mixin is not standard `AutomaticKeepAliveClientMixin`**
The custom `_KeepAlive` mixin exists in `main.dart` to keep tab pages alive in the `PageView`. Flutter provides `AutomaticKeepAliveClientMixin` for this exact purpose. The custom implementation may behave incorrectly under memory pressure.

**7.18 `analysis_options.yaml` strictness level unknown**
Review linting rules and enable `flutter_lints` recommended rules at minimum. Enable `prefer_const_constructors`, `avoid_print`, and `unawaited_futures` at a minimum.

---

## 8. Recommended Refactor Sequence

The following is a suggested ordering for a production stabilisation sprint. Each item is independent unless marked with a dependency arrow (→).

### Phase 1 — Security & Data Safety (before any external testing)

1. **Build a backend proxy** for OpenAI calls. The app sends requests to your own server; the server holds the key. Remove `lib/config.dart` entirely.
2. **Add DB migration infrastructure** — implement `_onUpgrade` in `DatabaseService` with a version table. Version the current schema as `v1`. Any schema change in subsequent phases increments the version and adds a migration function.
3. **Remove seed data** from production builds. Gate seed insertion behind a `kDebugMode` check or remove it entirely, presenting an empty state on first launch.

### Phase 2 — State Management Refactor

4. **Adopt Riverpod** (or equivalent). Create providers for each domain (todos, events, ideas, notes, recapItems). Pages read from providers and call provider methods; the shell becomes a thin router.
5. **Eliminate the `NotePage` bypass** — make note mutations flow through the notes provider.
6. **Remove all shell callbacks** once all pages are provider-driven.

### Phase 3 — AI Reliability

7. **Add request timeout + retry** (3 attempts, exponential back-off) to all `http.post` calls in `OpenAIService`.
8. **Truncate the chat context** to the 50 most recent messages and the most recent 20 of each entity type.
9. **Persist era images and insights** — save DALL-E images via `AttachmentStorage`, store insight text in a new `era_cache` table with a TTL column.
10. **Surface AI errors** to the user — show a snackbar or inline error chip when any AI call fails instead of silently no-oping.

### Phase 4 — Data Model Cleanup

11. **Migrate event datetime** — consolidate the six integer columns into a single `startTimestamp` and `endTimestamp` (ISO-8601 string). Write a `v2` migration.
12. **Add cascade delete** for note attachments — in `DatabaseService.deleteNote()`, fetch attachment rows, call `AttachmentStorage.delete()` for each, then delete the rows.
13. **Fix the DALL-E model constant** — align `openAiImageModel` with whichever model is actually in use.

### Phase 5 — Quality & Polish

14. **Write tests** — unit tests for `DatabaseService`, `ClassificationResult` parsing, and the AI tool executor. Widget tests for `AddOverlay` happy path.
15. **Enable strict linting** — fix all `avoid_print` and `unawaited_futures` violations (likely widespread in overlay callbacks).
16. **Replace `_KeepAlive`** with `AutomaticKeepAliveClientMixin`.
17. **Add loading skeletons** to `IdeaPage` (while enrichment runs) and `RecapPage` (while AI content loads).
18. **Cap `chat_messages` query** to a rolling window.

---

## 9. File-by-File Refactor Notes

| File | Notes |
|---|---|
| [lib/main.dart](lib/main.dart) | Dissolves almost entirely in Phase 2. Keep only `MyRoomApp` and the root `Scaffold`/`PageView`/`BottomNavBar` wiring. |
| [lib/services/database_service.dart](lib/services/database_service.dart) | Add `_onUpgrade`, cascade delete, and the `era_cache` table in Phase 3/4. Remove seed calls in Phase 1. |
| [lib/services/openai_service.dart](lib/services/openai_service.dart) | Wrap every `http.post` in timeout + retry in Phase 3. Add context truncation to `chat()`. Remove direct API calls — proxy in Phase 1. |
| [lib/services/attachment_storage.dart](lib/services/attachment_storage.dart) | Already clean. Add a `listOrphans()` helper for a future cleanup job. |
| [lib/pages/note_page.dart](lib/pages/note_page.dart) | Route DB calls through the notes provider in Phase 2. |
| [lib/pages/recap_page.dart](lib/pages/recap_page.dart) | Persist AI content in Phase 3. Add skeleton loaders in Phase 5. |
| [lib/pages/idea_page.dart](lib/pages/idea_page.dart) | Add skeleton/shimmer during enrichment in Phase 5. |
| [lib/overlays/add_overlay.dart](lib/overlays/add_overlay.dart) | Add error surface for classification failures in Phase 3. |
| [lib/overlays/ai_chat_overlay.dart](lib/overlays/ai_chat_overlay.dart) | Apply context truncation and rolling message window in Phase 3/5. |
| [lib/config.dart](lib/config.dart) | Delete in Phase 1 after proxy is live. |
| [lib/data/seed_data.dart](lib/data/seed_data.dart) | Gate behind `kDebugMode` in Phase 1. |

---

## 10. Platform-Specific Notes

### Android
- `RECORD_AUDIO` and `READ_EXTERNAL_STORAGE` permissions are declared; verify they match the current `permission_handler` version requirements for Android 13+.
- `pdfrx` uses native pdfium — verify the `.so` size impact on the APK and consider split APKs for production.

### iOS
- `NSMicrophoneUsageDescription` must be present in `Info.plist` before App Store submission.
- `file_picker` requires `NSDocumentsFolderUsageDescription` for broader file access on iOS 16+.

### Windows
- `sqlite3.dll` must be bundled in the installer. Verify `generated_plugins.cmake` handles this correctly.
- The MSIX packaging step needs `appxmanifest.xml` capabilities for microphone if audio recording is to work.

---

## 11. Glossary

| Term | Meaning in this codebase |
|---|---|
| Shell | `MyRoomShell` — the root `StatefulWidget` holding all global state |
| Callback | A named `void Function(...)` passed from the shell down to a page |
| Era | One of three Recap sections: `past`, `now`, `future` |
| Seed data | Hardcoded demo content in `lib/data/seed_data.dart` |
| Enrichment | The async AI call that adds a summary and links to a newly created Idea |
| Classification | The `classifyMultiInput()` AI call that routes Smart Add input to the correct module |
| dateKey | The `YYYY-MM-DD` string used as the primary key for notes in date mode |
| Pinned resource | A bookmarked explore-tab link stored in `pinned_resources` table |
