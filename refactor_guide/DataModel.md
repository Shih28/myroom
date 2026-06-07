# Firestore Data Model & Denormalization Upkeep

The **field reference** is authoritative for serialization — every model's `fromFirestore`/`toJson` must match it.

## Shape summary

Per-user isolation: `/users/{userId}/{collection}/{doc}`.

```
users/{uid}
  ├─ (root doc: email, createdAt)
  ├─ settings/app           (singleton doc: selfIntro, rules, autoEnrich, tz, tutorialSeen)
  ├─ _internal/{doc}        (fn-only: rateLimit, …; clients denied)
  ├─ todo_categories/{id}   (label, colorVal, sortOrder)            ← todos' own categories
  ├─ note_categories/{id}   (label, colorVal, iconName, sortOrder)  ← notes' own categories
  ├─ events/{id}            (title, description, location, startTime, endTime, isAllDay, color, createdAt)
  ├─ todos/{id}             (title, isCompleted, sortOrder, category{id,label,colorVal}, createdAt, updatedAt)
  ├─ ideas/
  │    ├─ user_ideas/{id}       (text, aiSummary?, aiStatus, links[], createdAt, updatedAt)
  │    └─ pinned_resources/{id} (title, type, description, url, sortOrder, createdAt)
  ├─ notes/{id}             (dateKey, title, content, category{id,label,colorVal,iconName}, attachments[], createdAt, updatedAt)
  │    └─ extracted_texts/{attId} (filename, summary)
  ├─ recaps/{id}            (title, content, exportStoragePath?, createdAt)
  ├─ achievements/{id}      (pastContent, pastExportStoragePath?, currentContent, currentExportStoragePath?,
  │                          futureContent, futureExportStoragePath?, createdAt)
  └─ chat_messages/{id}     (role, content, createdAt)   ← single flat thread; no sessions
```

`recaps` and `achievements` both stream to the Recap page. A recap is a single titled review (e.g. "June with so
many joy"); an achievement holds the past / current / future summary for a period. Both are managed like ordinary
client collections (CRUD + stream) via `RecapRepo` / `AchievementRepo`.

`settings/app` is a singleton document (fixed doc id `app`) holding the user's preferences. Read by the Settings page
and the AI functions.

## Categories — separate per type

- `todo_categories/{id}` and `note_categories/{id}` are independent collections; todos and notes do not share
  categories.
- Each has a permanent `無分類` sentinel with fixed id `"undefined"` (always present, not deletable). New todos/notes
  default to it; deleting any other category reassigns its items back to it.
- Note categories carry an `iconName`; todo categories do not.

## Denormalization upkeep — fan-out via Cloud Function (`categoryFanout`)

Category metadata is copied (denormalized) into items: `todos.category{id,label,colorVal}` and
`notes.category{id,label,colorVal,iconName}`. A Cloud Function keeps the copies fresh so the client never fans out:

- Trigger on **`onWrite todo_categories/{id}`** → fan out to `todos`; on **`onWrite note_categories/{id}`** → fan out
  to `notes`.
- On **category update**: batch-update every item whose `category.id` matches, refreshing the embedded snapshot
  (chunk batches ≤500 ops).
- On **category delete**: reassign matching items to that type's `"undefined"` sentinel; items are not deleted.

## Pagination

- **chat_messages** — `watchMessages` loads the last 50 (`createdAt desc`) + a load-more cursor
  (`Repositories.md`). Single flat thread; there are no chat sessions.
- **AI chat context** — the proxy builds a bounded context (`AI_proxy.md`).

## Indexes

Composite indexes are in `Security.md` (derived from the repo queries).

## Conventions (apply to every collection)

- **Document ids:** Firestore auto-ids (string), except: user root doc (`= uid`), `settings/app` (`= "app"`), the two
  category sentinels (`= "undefined"`), and pinned resources (`= sha1(url)` for dedupe).
- **Timestamps:** `createdAt`/`updatedAt`/`startTime`/`endTime` are Firestore `Timestamp`. On create,
  `createdAt`/`updatedAt` use `FieldValue.serverTimestamp()`. `createdAt` is immutable (rules).
- **Color:** `int` (`Color.toARGB32()`), read with `Color(int)`.
- **Enums:** lowercase strings from a fixed set (`aiStatus`, attachment `type`, message `role`).
- **Writer column:** `client` (repo), `fn` (Cloud Function/trigger via Admin SDK), or `both`. Clients must not write
  `fn`-only fields.

## Field reference (authoritative)

Legend — R = required on create. Default applies when the writer omits it.

**users/{uid}** — root doc, written by `provisionUser` (`Auth.md`).

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| email | string | ✓ | — | fn |
| createdAt | Timestamp | ✓ | serverTs | fn |

**users/{uid}/settings/app** — singleton preferences doc.

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| selfIntro | string | | `''` | client |
| rules | string | | `''` | client |
| autoEnrich | bool | | `true` | client |
| tz | string (IANA) | | `Asia/Taipei` | fn default; client patches |
| tutorialSeen | bool | | `false` | client |

**users/{uid}/_internal/{doc}** — fn-only internal state (e.g. `rateLimit` `{windowStart, count}`). Clients denied in
`Security.md`. Not modeled on the client.

**todo_categories/{id}**

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| label | string | ✓ | — | client |
| colorVal | int | ✓ | — | client |
| sortOrder | int | ✓ | next | client |

**note_categories/{id}**

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| label | string | ✓ | — | client |
| colorVal | int | ✓ | — | client |
| iconName | string | | `''` | client |
| sortOrder | int | ✓ | next | client |

**events/{id}**

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| title | string | ✓ | — | client |
| description | string? | | null | client |
| location | string? | | null | client |
| startTime / endTime | Timestamp | ✓ | endTime = startTime+1h | client |
| isAllDay | bool | | false | client |
| color | int | ✓ | — | client |
| createdAt | Timestamp | ✓ | serverTs | client |

**todos/{id}**

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| title | string | ✓ | — | client |
| isCompleted | bool | | false | client |
| sortOrder | int | ✓ | next | client (reorder) |
| category | map{id,label,colorVal} | ✓ | `undefined` todo-cat | client; refreshed by `fn` fan-out |
| createdAt / updatedAt | Timestamp | ✓ | serverTs | client |

**ideas/user_ideas/{id}**

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| text | string | ✓ | — | client |
| aiSummary | string? | | null | **fn** |
| aiStatus | string | | `none` | **fn** |
| links | array<map{title,url}> | | `[]` | **fn** |
| createdAt / updatedAt | Timestamp | ✓ | serverTs | client |

**ideas/pinned_resources/{id}**: `title,type,desc,url` (string, R), `sortOrder` (double), `createdAt` — writer client.

**notes/{id}**

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| dateKey | string `YYYY-MM-DD` | ✓ | — | client |
| title | string | | `'無標題'` | client |
| content | string | ✓ | — | client |
| category | map{id,label,colorVal,iconName} | | `undefined` note-cat → set by `classifyNote` | client+**fn** |
| attachments | array<map{type,filename,storagePath,attId}> | | `[]` | client |
| createdAt / updatedAt | Timestamp | ✓ | serverTs | client |

> **`title`** is populated only by the note editor's optional title field; if the user leaves it blank, persist
> `'無標題'`. AI/classification paths (`classifyMultiInput` `note` items, the `add_note` chat tool) carry no title, so
> AI-created notes always get the `'無標題'` default.

> `attachments[]` stores **`storagePath` only** (no `url`); the UI resolves a download URL on demand
> (`Storage.md`). `type ∈ {image,audio,file}`. **`attId` = `sha256(bytes)` hex** — the same content hash embedded in
> `storagePath` (`Storage.md §2`); it is the join key to the matching `extracted_texts/{attId}` doc.

**notes/{noteId}/extracted_texts/{attId}**: `filename` (string), `summary` (string, transcript/pdf text) — writer
client. The **doc id `attId` = the attachment's `attId`** (= `sha256(bytes)`). Written only for `audio` and `file`
(PDF) attachments; `image` attachments have no transcript and no `extracted_texts` doc.

**recaps/{id}**

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| title | string | ✓ | — | client |
| content | string | | `''` (user-written or AI summary via `generateEraInsight`) | client |
| exportStoragePath | string? | | null | **fn** (`exportRecap`) |
| createdAt | Timestamp | ✓ | serverTs | client |

**achievements/{id}**

| field | type | R | default | writer |
| --- | --- | --- | --- | --- |
| pastContent / currentContent / futureContent | string | | `''` (user-written or AI summary via `generateEraInsight`) | client |
| pastExportStoragePath / currentExportStoragePath / futureExportStoragePath | string? | | null | **fn** (`exportAchievement`) |
| createdAt | Timestamp | ✓ | serverTs | client |

**chat_messages/{id}** — single flat thread (no sessions): `role` ∈ {user,assistant,system}, `content` (string),
`createdAt` (Timestamp) — writer **fn** (the chat function appends both the user and assistant messages via Admin
SDK). Clients read only; there is no `title` and no session `updatedAt`.
