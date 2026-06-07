---
title: MyRoom App Database Specifications

---

# MyRoom App Database Specifications

> **Scope of this document.** Authoritative **only** for the repository directory/file layout
> (the `lib/` tree and top-level config files — see the "Project" section near the end). For data
> model, collections, security, storage, Cloud Functions, and the system diagram, the rest of
> `refactor_guide/` is authoritative and **supersedes** the "Database Hierarchy", "Collection
> Definitions", root-doc `aiSettings`, the `recaps` schema, the `functions/` tree, and the embedded
> mermaid diagram below. Sections that are superseded are marked **⚠️ SUPERSEDED** inline.

---

### System diagram

> **⚠️ SUPERSEDED by `SystemDiagram.md`.** The diagram below predates `AchievementRepo`, App Check,
> and the dropped `gpt-4o-mini-search-preview`/DALL-E models. Use `SystemDiagram.md` as canonical.

https://mermaid.ai/app/projects/459c8908-2640-4af6-88af-2668f0bf9c38/diagrams/b98aad40-762c-4981-871d-9cac84625fc6/share/invite/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkb2N1bWVudElEIjoiYjk4YWFkNDAtNzYyYy00OTgxLTg3MWQtOWNhYzg0NjI1ZmM2IiwiYWNjZXNzIjoiQ29tbWVudCIsImlhdCI6MTc4MDM5MDY0NH0.Qr_UF8Wn7Tn4T5fUh5q1JoftTPHim792nrEfrlGcn9U?entryPoint=share-modal

---
```mermaid
flowchart TB
    subgraph Frontend["Frontend — Flutter Presentation Layer"]
        Main["main.dart\n(MaterialApp.router · DI setup)"]
        Router["AppRouter\n(go_router · route table\n· Auth Guard / Redirects)"]
        Scaffold["AppScaffold\n(StatefulShellRoute\n· OWNS nav state: currentIndex\n· BottomNavBar)"]
        subgraph AuthUI["Auth"]
            Login["登入 Login\n/login"]
        end
        subgraph Pages["Pages — each = StreamBuilder + local UI state"]
            Cal["行事曆 Calendar /calendar\n(stream events)"]
            Todo["待辦 To-Do /todo\n(stream todos)"]
            Idea["靈感 Ideas /ideas\n(stream ideas)"]
            Note["筆記 Notes /notes\n(stream notes)"]
            Recap["回顧 Recap /recap\n(stream recap)"]
        end
        subgraph Setting["Setting"]
            Settings["設定 Settings\n/settings\n(Logout)"]
        end
        subgraph Overlays["Overlays — write via repos"]
            Add["Add Overlay /add"]
            AiChat["AI Chat Overlay /chat"]
        end
    end

    subgraph Domain["Domain"]
        direction TB
            IAuthRepo(["AuthRepo\n(Manages Session & UserId)"])
            ITodoRepo(["TodoRepo"])
            IEventRepo(["EventRepo"])
            IIdeaRepo(["IdeaRepo"])
            INoteRepo(["NoteRepo"])
            IRecapRepo(["RecapRepo"])
            IChatRepo(["ChatRepo"])
            IAiService(["AiService"])
            IStorageRepo(["StorageRepo"])
    end

    subgraph Backend["Backend — Firebase Implementations"]
        subgraph Firebase["Firebase"]
            FAuthImpl["FirebaseAuthRepo"]
            FEvent["FirebaseEventRepo\n(Scoped to userId)"]
            FTodo["FirebaseTodoRepo\n(Scoped to userId)"]
            FIdea["FirebaseIdeaRepo\n(Scoped to userId)"]
            FNote["FirebaseNoteRepo\n(Scoped to userId)"]
            FRecap["FirebaseRecapRepo\n(Scoped to userId)"]
            FChat["FirebaseChatRepo\n(Scoped to userId)"]
            FStorage["FirebaseStorageRepo\n(Scoped to userId)"]
        end
        subgraph AiProxy["AiProxy"]
            CF["Firebase Cloud Functions\n(OpenAI API key\n· Verifies Firebase Auth Token)"]
        end
    end

    subgraph FirebasePlatform["Firebase Platform"]
        FAuth["Firebase Authentication\n(Email / OAuth)"]
        FS[("Cloud Firestore\n(Rules: match /users/{userId} )\nlocal cache = optimistic source of truth")]
        FSt["Firebase Storage\n(Rules: match /users/{userId} )"]
    end

    subgraph OpenAI["OpenAI API"]
        GPT["GPT-4o-mini"]
        Search["GPT-4o-mini-search-preview"]
        Whisper["Whisper\naudio transcription"]
    end

    Main --> Router
    Router --> Login & Scaffold & Setting & Add & AiChat
    Scaffold --> Cal & Todo & Idea & Note & Recap

    %% Pages talk to repos directly (state fused into the widgets)
    Login --> IAuthRepo
    Settings --> IAuthRepo
    Cal --> IEventRepo
    Todo --> ITodoRepo
    Idea --> IIdeaRepo & IAiService
    Note --> INoteRepo & IAiService & IStorageRepo
    Recap --> IRecapRepo & IStorageRepo & IAiService
    Add --> IAiService
    AiChat --> IAiService & IChatRepo

    IAuthRepo -. implements .-> FAuthImpl
    ITodoRepo -. implements .-> FTodo
    IEventRepo -. implements .-> FEvent
    IIdeaRepo -. implements .-> FIdea
    INoteRepo -. implements .-> FNote
    IRecapRepo -. implements .-> FRecap
    IChatRepo -. implements .-> FChat
    IStorageRepo -. implements .-> FStorage
    IAiService -. implements .-> CF

    FAuthImpl --> FAuth
    FTodo --> FS
    FEvent --> FS
    FIdea --> FS
    FNote --> FS
    FRecap --> FS
    FChat --> FS
    FStorage --> FSt
    CF --> GPT & Search & Whisper
```

### Database Hierarchy

> **⚠️ SUPERSEDED by `DataModel.md`.** This hierarchy and the "Collection Definitions" below are a
> stale snapshot. Authoritative differences in `DataModel.md`: separate `todo_categories` /
> `note_categories` (no unified `categories`, no `scopes`); root user doc holds only `email` +
> `createdAt` (preferences live in the `settings/app` singleton, not `aiSettings`); `recaps`
> `{title, content, exportStoragePath?, createdAt}` **plus** a separate `achievements` collection;
> `notes.attachments` = `{type, filename, storagePath, attId}` (no `url`); `user_ideas.links` =
> `array<map{title,url}>`; chat history is a single flat `chat_messages` collection (no
> `chat_sessions`). Read `DataModel.md` for the field reference; the tables below are kept for
> historical context only.

Data is strictly isolated per user using nested subcollections.
**Path pattern:** `/users/{userId}/{collectionName}/{documentId}`

| Root Collection | Subcollections (under `/users/{userId}`) | Sub-subcollections |
| --- | --- | --- |
| **users** (Root Doc) | **categories** | |
| | **events** | |
| | **todos** | |
| | **ideas** | **user_ideas** / **pinned_resources** |
| | **notes** | **extracted_texts** |
| | **recaps** | |
| | **chat_sessions** | **messages** |

---

### Collection Definitions

#### `users` (Root User Document)
*Path: `/users/{userId}`*
Managed by `FirebaseAuthRepo`. Holds profile data and configurations that the AI Proxy reads to understand the user context before generating responses.

| Key | Type | Description |
| --- | --- | --- |
| email | `String` | Authenticated user email. |
| createdAt | `Timestamp` | Account creation date. |

> **⚠️ SUPERSEDED.** The root user doc holds **only** `email` + `createdAt`. The `aiSettings` map is
> replaced by the `settings/app` singleton (`selfIntro`, `rules`, `autoEnrich`, `tz`, `tutorialSeen`)
> in `DataModel.md` / `Auth.md`.

#### `categories` Collection (Unified Metadata)
> **⚠️ SUPERSEDED.** Replaced by two independent collections `todo_categories` / `note_categories`
> (no `scopes` array) in `DataModel.md`.
*Path: `/users/{userId}/categories/{categoryId}`*
Centralized repository for UI metadata. Note: This data is denormalized (copied) into individual tasks and notes to prevent N+1 read queries on the frontend.

| Key | Type | Description |
| --- | --- | --- |
| label | `String` | Category name (e.g., "Work", "Fitness"). |
| colorVal | `Integer` | UI color integer for Flutter rendering. |
| iconName | `String` | Identifier for the Flutter icon. |
| scopes | `Array<String>` | e.g., `["note", "todo"]`. Determines UI availability. |
| sortOrder | `Integer` | Determines display order in the UI menu. |

#### `events` Collection
*Path: `/users/{userId}/events/{eventId}`*
Managed by `EventRepo`. Optimized for timeline and calendar queries.

| Key | Type | Description |
| --- | --- | --- |
| title | `String` | Event title. |
| description | `String` | Optional details. |
| location | `String` | Location of the event. |
| startTime | `Timestamp` | Used for indexing and calendar range queries. |
| endTime | `Timestamp` | |
| isAllDay | `Boolean` | |
| color | `Integer` | Flutter UI color code. |
| createdAt | `Timestamp` | |

#### `todos` Collection
*Path: `/users/{userId}/todos/{todoId}`*
Managed by `TodoRepo`.

| Key | Type | Description |
| --- | --- | --- |
| title | `String` | Task name. |
| isCompleted | `Boolean` |
| sortOrder | `Integer` | For custom drag-and-drop lists. |
| category | `Map` | **Denormalized**: `{id, label, colorVal}`. |
| createdAt | `Timestamp` | |
| updatedAt | `Timestamp` | |

#### `ideas` Collection
*Path: `/users/{userId}/ideas/`* Contains two subcollection.

#### `user_ideas` (Subcollection under `ideas`)
*Path: `/users/{userId}/ideas/user_ideas/{ideaId}`*
Managed by `IdeaRepo`.

| Key | Type | Description |
| --- | --- | --- |
| text | `String` | The raw thought, text input. |
| aiSummary | `String` | Nullable. GPT-generated summary. |
| aiStatus | `String` | `'none'`, `'processing'`, `'completed'`, or `'error'`. Drives UI loaders. |
| links | `Array<String>` | Extracted or attached URLs. ⚠️ SUPERSEDED → `array<map{title,url}>` (`DataModel.md`). |
| createdAt | `Timestamp` | |
| updatedAt | `Timestamp` | |

#### `pinned_resources` Collection (Subcollection under `ideas`)
*Path: `/users/{userId}/ideas/pinned_resources/{resourceId}`*
For bookmarks and external links.

| Key | Type | Description |
| --- | --- | --- |
| title | `String` | Resource name. |
| type | `String` | e.g., "article", "video", "tool". |
| description | `String` | Brief context. |
| url | `String` | The hyperlink. |
| sortOrder | `Double` | For custom drag-and-drop lists. |
| createdAt | `Timestamp` | |

#### `notes` Collection
*Path: `/users/{userId}/notes/{noteId}`*
Managed by `NoteRepo`. Handles rich content and lightweight attachment metadata.

| Key | Type | Description |
| --- | --- | --- |
| dateKey | `String` | YYYY-MM-DD for fast grouping on calendar views. |
| title | `String` | Note headline. |
| content | `String` | Note body. |
| category | `Map` | **Denormalized**: `{id, label, colorVal, iconName}`. |
| attachments | `Array<Map>` | Metadata only. ⚠️ SUPERSEDED → `{type, filename, storagePath, attId}` (no `url`; URL resolved on demand; `attId` = sha256(bytes)) per `DataModel.md` / `Storage.md`. |
| createdAt | `Timestamp` | Strict chronological ordering. |
| updatedAt | `Timestamp` | |

#### `extracted_texts` (Subcollection under `Notes`)
*Path: `/users/{userId}/notes/{noteId}/extracted_texts/{attachmentId}`*
Prevents massive blocks of extracted text (from PDFs/audio) from hitting Firestore's 1MB document limit on the main Note document.

| Key | Type | Description |
| --- | --- | --- |
| filename | `String` | Reference to the original file. |
| summary | `String` | A brief summary or extracted text for GPT context/search. |

#### `recaps` Collection
> **⚠️ SUPERSEDED by `DataModel.md`.** `recaps` is `{title, content, exportStoragePath?, createdAt}`
> (no `era`, `completedDate`, `targetDate`, `noteLink`). Per-period past/current/future reflections
> live in a **separate `achievements` collection** (`{past,current,future}Content` +
> `{era}ExportStoragePath?`), managed by `AchievementRepo`. Both stream to the Recap page.
*Path: `/users/{userId}/recaps/{recapId}`*
Managed by `RecapRepo`. Holds periodic reviews and optionally generated export assets.

| Key | Type | Description |
| --- | --- | --- |
| era | `String` | e.g., "2026-Q1" or "April Sprint". |
| title | `String` | Recap headline. |
| content | `String` | Body, AI-generated summary, or user-written review. |
| exportStoragePath| `String` | Nullable. Path to an exported PDF/graphic in Storage. |
| completedDate | `Timestamp` | Nullable. |
| targetDate | `Timestamp` | Nullable. |
| noteLink | `String` | ID reference to an expanded Note. |
| createdAt | `Timestamp` | |

#### `chat_sessions` Collection
> **⚠️ SUPERSEDED by `DataModel.md`.** There are **no** chat sessions. Chat history is a single flat
> collection `users/{uid}/chat_messages/{messageId}` — `{role ∈ {user,assistant,system}, content,
> createdAt}`, written only by the chat Cloud Function. No `title`, no session `updatedAt`, no
> sidebar. Ignore this `chat_sessions`/`messages` definition.
*Path: `/users/{userId}/chat_sessions/{sessionId}`*
Managed by `ChatRepo`. Groups messages into threads for the AI Chat Overlay, allowing pagination and history sidebars without downloading all messages.

| Key | Type | Description |
| --- | --- | --- |
| title | `String` | AI-generated summary of the chat (e.g., "Planning Rome Trip"). |
| createdAt | `Timestamp` | |
| updatedAt | `Timestamp` | Used to sort sessions by "Most recent activity". |

#### `messages` (Subcollection under Chat Sessions)
*Path: `/users/{userId}/chat_sessions/{sessionId}/messages/{messageId}`*

| Key | Type | Description |
| --- | --- | --- |
| role | `String` | "user", "assistant", or "system". |
| content | `String` | Message text content. |
| createdAt | `Timestamp` | Required for ordering the conversation flow. |

### Project 
Here's a feature-first layout that maps directly onto your diagram — each feature carries its own slice of the Domain (interface) and Backend (Firebase impl) layers, instead of one giant domain/ and data/ folder. This scales better than layer-first once you have 6+ features, and it reflects the fused-state decision: no controllers/ folder, with ephemeral state living in the widgets and shared data flowing through Firestore streams.

```
my_app/
├── lib/
│   ├── main.dart                       # init Firebase, runApp
│   ├── app.dart                        # MaterialApp.router + theme
│   │
│   ├── router/
│   │   ├── app_router.dart             # GoRouter: StatefulShellRoute + branches (owns nav state)
│   │   ├── routes.dart                 # path / name constants
│   │   └── auth_guard.dart             # redirect: not logged in → /login
│   │
│   ├── core/                           # cross-cutting, no business logic
│   │   ├── theme/app_theme.dart
│   │   ├── result.dart                 # Result/Either type for repo returns
│   │   ├── failures.dart               # typed errors
│   │   ├── firebase_failure.dart       # mapFirebase() used by every repo + AppErrors (Repositories.md)
│   │   ├── extensions/
│   │   └── widgets/                    # shared dumb widgets (loaders, buttons)
│   │
│   ├── shared/                         # cross-feature services (Domain interfaces shared by many pages)
│   │   ├── auth/
│   │   │   ├── domain/
│   │   │   │   ├── app_user.dart
│   │   │   │   └── auth_repo.dart                # abstract (manages session + userId)
│   │   │   ├── data/firebase_auth_repo.dart     # impl
│   │   │   └── providers.dart                    # authRepoProvider, authStateProvider
│   │   ├── ai/
│   │   │   ├── domain/ai_service.dart            # abstract
│   │   │   ├── data/cloud_function_ai_service.dart   # calls CF, passes Firebase auth token
│   │   │   └── models/                           # request/response DTOs
│   │   └── storage/
│   │       ├── domain/storage_repo.dart          # abstract
│   │       ├── data/firebase_storage_repo.dart
│   │       └── providers.dart
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   └── presentation/
│   │   │       ├── login_page.dart               # uses shared/auth
│   │   │       └── widgets/
│   │   │
│   │   ├── calendar/                             # ← canonical feature shape (others mirror this)
│   │   │   ├── domain/
│   │   │   │   ├── event.dart                    # model (fromFirestore / toJson)
│   │   │   │   └── event_repo.dart               # abstract interface
│   │   │   ├── data/
│   │   │   │   └── firebase_event_repo.dart      # impl (scoped to userId)
│   │   │   └── presentation/
│   │   │       ├── calendar_page.dart            # StreamProvider + LOCAL ui state (selected date, view mode)
│   │   │       ├── providers.dart                # eventRepoProvider, eventsStreamProvider
│   │   │       └── widgets/
│   │   │           ├── month_view.dart
│   │   │           └── event_tile.dart
│   │   │
│   │   ├── todo/                                  # domain/ data/ presentation/  (same shape)
│   │   ├── ideas/                                 # + uses shared/ai
│   │   ├── notes/                                 # + uses shared/ai + shared/storage
│   │   ├── recap/                                 # + uses shared/ai + shared/storage
│   │   ├── chat/
│   │   │   ├── domain/
│   │   │   ├── data/                             # chat_message + chat_repo (history in Firestore)
│   │   │   └── presentation/chat_overlay.dart    # holds pending "thinking" bubble in LOCAL state
│   │   ├── add/
│   │   │   └── presentation/add_overlay.dart     # holds form/parsing state LOCAL; writes via repos
│   │   └── settings/
│   │       └── presentation/settings_page.dart   # logout via shared/auth
│   │
│   └── firebase_options.dart           # generated by `flutterfire configure`
│
├── functions/                          # Cloud Functions (AiProxy) — separate TS project, own deploy
│   │                                   # ⚠️ SUPERSEDED — authoritative layout is AI_proxy.md §1
│   │                                   #    (callable/ + triggers/). NO image.ts (DALL-E/era images
│   │                                   #    dropped), NO search.ts (web_search is a built-in tool on
│   │                                   #    gpt-4o-mini, not a separate model/file).
│   ├── src/
│   │   ├── index.ts                    # exports all callables + triggers
│   │   ├── middleware/auth.ts          # verify Auth token + App Check
│   │   ├── lib/{openai.ts, context.ts}
│   │   ├── callable/{chat,classifyMultiInput,fetchRecommendations,generateEraInsight,transcribe,exportRecap,exportAchievement}.ts
│   │   └── triggers/{enrichIdea,classifyNote,findNotesForCategory,categoryFanout,storageCascade,provisionUser,deleteUserData}.ts
│   ├── package.json
│   └── tsconfig.json
│
├── test/                               # mirrors lib/features/...
│   └── features/calendar/
│       ├── firebase_event_repo_test.dart
│       └── calendar_page_test.dart
│
├── android/  ios/  web/  ...           # Flutter platform folders (boilerplate)
│
├── firebase.json
├── .firebaserc
├── firestore/
│   ├──firestore.rules                     # match /users/{userId}/...
│   └──firestore.indexes.json
├── storage.rules                       # match /users/{userId}/...
├── analysis_options.yaml
└── pubspec.yaml
```

