# AI Proxy — Firebase Cloud Functions

OpenAI calls go through Cloud Functions on the **Responses API** (`POST /v1/responses`). Verbatim zh-TW prompts, the
chat tool JSON, and the classification contract are in `firebase_port_extraction.md`.

## 1. Two kinds of functions

- **Callables** (`onCall`, App Check + Auth enforced) — interactive, request/response.
- **Firestore/Auth triggers** (Admin SDK) — reactive; fill fields, fan out, and clean up so the client only reads
  streams. The client never invokes triggers and never writes AI-owned fields.

| Kind | Function | Trigger / signature | Model |
| --- | --- | --- | --- |
| callable | `chat` | client | gpt-4o-mini (+tools) |
| callable | `classifyMultiInput` | client | gpt-4o-mini (multimodal) |
| callable | `fetchRecommendations` | client | gpt-4o-mini + web_search |
| callable | `generateEraInsight` | client | gpt-4o-mini |
| callable | `transcribe` | client | whisper-1 |
| callable | `exportRecap` | client | — (server render) |
| callable | `exportAchievement` | client | — (server render) |
| trigger | `enrichIdea` | `onCreate ideas/user_ideas/{id}` + on text update | gpt-4o-mini + web_search |
| trigger | `classifyNote` | `onWrite notes/{id}` (category still sentinel) | gpt-4o-mini |
| trigger | `findNotesForCategory` | `onCreate note_categories/{id}` | gpt-4o-mini |
| trigger | `categoryFanout` | `onWrite todo_categories/{id}` + `note_categories/{id}` | — |
| trigger | `storageCascade` | `onDelete notes/{id}`, `recaps/{id}`, `achievements/{id}` | — |
| trigger | `provisionUser` | Auth `onCreate` | — |
| trigger | `deleteUserData` | Auth `onDelete` | — |

```
functions/src/
  index.ts            middleware/auth.ts            lib/openai.ts   lib/context.ts
  callable/{chat,classifyMultiInput,fetchRecommendations,generateEraInsight,transcribe,exportRecap,exportAchievement}.ts
  triggers/{enrichIdea,classifyNote,findNotesForCategory,categoryFanout,storageCascade,provisionUser,deleteUserData}.ts
```

## 2. Chat — server-side tool execution

`chat` runs the full tool loop inside the function and performs mutations via the Admin SDK against `/users/{uid}/...`.
The client does not execute tools; the UI updates reactively from its streams.

- Tools = the 9 write tools (`add_*`/`delete_*` + `add_recap`) **plus** read tools
  `list_todos / list_events / list_ideas / list_notes`, each returning id+summary rows so the model can choose ids.
- `add_idea` writes the idea doc only; the `enrichIdea` trigger enriches it. `add_note` relies on `classifyNote`.
- `add_recap` params are `{title, content}` and it writes a **`recaps`** doc via Admin SDK (`createdAt = serverTs`).
  There is **no `add_achievement` tool** — `achievements` are created only from the Recap page, never by chat/Smart Add.
- Loop guard: ≤6 rounds. On exhaustion, return the fixed reply `（AI 運算超出輪數限制，請再試）` — a canned string, with
  no extra model call.
- Inject the real date into the prompt, computed from `settings/app.tz` (default `Asia/Taipei`).
- `selfIntro` and `rules` are read from `users/{uid}/settings/app`.

```
chat(req={ message }) -> { reply: string }
  // load context (lib/context.ts), run loop, append the user + assistant messages to
  // chat_messages (single flat thread; no sessions), return final assistant text.
```

## 3. Bounded context (`lib/context.ts`)

Built server-side from windowed queries: pending todos, done-count, events −3…+30 days, notes updated in the last 7
days (deduped by dateKey), latest 20 ideas, the latest achievement's current+future content, and recent recaps.

## 4. Responses API mapping (every text function)

- `messages[system]` → `instructions`; `messages[user]` → `input` (string or typed-part array).
- `max_tokens`/`max_completion_tokens` → `max_output_tokens`; read text from `response.output_text`.
- JSON output → `text:{format:{type:"json_schema", schema:<exact schema>, strict:true}}` for `classifyMultiInput`,
  `classifyNote`, `findNotesForCategory`.
- chat `tools` → Responses function tools; tool calls arrive as `function_call`, feed results back as
  `function_call_output`; keep the loop.
- web search → `tools:[{type:"web_search"}]` on `gpt-4o-mini` for `enrichIdea` + `fetchRecommendations`, with
  `user_location = {type:'approximate', country:'TW', city:'Taipei', region:'Taipei', timezone:'Asia/Taipei'}`.
- multimodal → `input` array of `input_text` + `input_image` (data URI, `detail:"low"`).
- Whisper stays on `/v1/audio/transcriptions` (multipart).

## 4a. Prompt-port deltas (apply when porting the verbatim demo prompts / tool JSON)

The demo prompts and tool schemas in `firebase_port_extraction.md` are the porting source, but several fields are
dropped or changed for the new model. When porting, apply these deltas:

- **Recap (C2):** strip `era` and `date` from the `recap` classification schema and from the `add_recap` tool schema.
  The surviving recap fields are `title` + `content`/`description` only (written to `recaps`).
- **Era enum (C2):** normalize any `now` → `current`. Because `recap` classification no longer carries `era`, the only
  surviving era tokens are on the achievement path and are all `past | current | future`.
- **Categories (H2):** do **not** hard-code category names or the old `note_cat` ids `academic`/`sport`. Inject the
  user's categories as `{id, label}` at runtime (§5 / §6); the model chooses by label and returns the `id`, which the
  function validates (fallback `undefined`).
- **Todo priority (M1):** remove `priority` from the `todo` and `todo_with_time` classification schema and from any
  `add_todo` tool params. If a ported prompt still emits `priority`, the function must ignore it (do not write it).
- **DALL-E / era images (C2):** dropped entirely — there is no image-generation prompt or tool to port (see §1 and
  `Storage.md §6`; the only recap/achievement visual is the optional `exportRecap`/`exportAchievement` PDF).

## 5. Callable contracts

The Timeout column is the **per-OpenAI-request HTTP timeout** (each call retried 3×, §8). The Cloud Function
wall-clock `timeoutSeconds` is set separately in §7.

| Function | Server params | Request | Response | Req. timeout |
| --- | --- | --- | --- | --- |
| `chat` | temp 0.7, max_out 600, tools | `{message}` | `{reply}` | 30s |
| `classifyMultiInput` | temp 0.2, max_out 800, json_schema | `{text, images[b64], fileText, attachments[{i,type,name}], userSpecifiedCat}` | `{items:[ClassificationResult]}` | 30s |
| `fetchRecommendations` | max_out 600, web_search | `{ideaTexts[≤5]}` | `{resources:[{title,type,description,url}]}` | 30s |
| `generateEraInsight` | temp 0.78, max_out 120 | `{eraLabel, dataSummary}` | `{text}` | 20s |
| `transcribe` | language `zh`, format `text` | `{audioB64, filename}` | `{transcript}` | 60s |
| `exportRecap` | server render (no OpenAI) | `{recapId}` | `{storagePath}` | — |
| `exportAchievement` | server render (no OpenAI) | `{achievementId, era}` (era ∈ past/current/future) | `{storagePath}` | — |

- **`classifyMultiInput`** returns five item types (`todo, todo_with_time, idea, note, recap`); discriminator `type`;
  `attachment_indices` filtered to `0 ≤ i < count` and de-duplicated. Read the categories once before the loop, not per
  item. **Category injection:** inject the user's `todo_categories` (for `cat`) and `note_categories` (for `note_cat`)
  via Admin SDK as an array of `{id, label}` per type, using the real Firestore **auto-ids** (plus the fixed
  `undefined` sentinel id). Instruct the model to choose by `label` and **return the chosen `id`**; validate the
  returned id against the injected set, on miss → `undefined` sentinel. The prompt must **not** hard-code category
  names or the old `note_cat` ids `academic`/`sport`.
  The **`recap`** item type is `{title, description}` (no `era`, no `date`); the client writes it to **`recaps`** via
  `RecapRepo.add` (`content := description`).
- **`generateEraInsight`** returns a reflective summary; **routing is decided by the caller, not by
  `generateEraInsight`** (it is a stateless text generator). `eraLabel` cases:
  - **Achievement era call** → `eraLabel ∈ {past, current, future}` (or the zh-TW label 過去/現在/未來). The client
    writes the returned text to the matching `{era}Content` on the achievement doc.
  - **Recap (era-less) call** → `eraLabel := the recap's title` (or the literal `"recap"` if untitled). The client
    writes the returned text to that recap's `content`. Here `eraLabel` only flavors the prompt tone; it is not used
    for routing.
- **`exportRecap`** renders the recap (title + content) to a PDF/graphic server-side, uploads it to
  `/users/{uid}/recaps/{recapId}/export.{ext}`, and writes `exportStoragePath` onto the recap doc via Admin SDK.
- **`exportAchievement`** renders one era (`past`/`current`/`future`) of an achievement to a PDF/graphic, uploads it to
  `/users/{uid}/achievements/{achievementId}/{era}_export.{ext}`, and writes the matching
  `{era}ExportStoragePath` via Admin SDK.
- **`transcribe`** is called by Smart Add for audio before `classifyMultiInput`; the client stores the transcript in
  the note's `extracted_texts`. PDF text is extracted client-side (`pdfrx`) and passed as `fileText`.

## 6. Trigger contracts

- `enrichIdea` (`onCreate` + text `onUpdate`): if `settings/app.autoEnrich`, set `aiStatus=processing`, call OpenAI,
  then write `aiSummary`, `links[]`, `aiStatus=completed`; on failure `aiStatus=error`. Run only when `text` changed
  and `aiStatus != processing`.
- `classifyNote` (`onWrite`): if the note's category is still the `undefined` sentinel and content is non-empty, set
  `category` from OpenAI. Inject the user's `note_categories` as `{id, label}` pairs (real auto-ids + the `undefined`
  sentinel); the model returns the chosen `id`, validated against the injected set (fall back to `undefined`).
  **Caveat:** because `undefined` doubles as "please classify me," there is no way to pin a note as *permanently*
  uncategorized — `classifyNote` will reclassify any note left on the `undefined` sentinel with non-empty content.
  Acceptable for this release; revisit if a "keep uncategorized" UX is ever wanted.
- `findNotesForCategory` (`onCreate note_categories/{id}`): read the user's notes whose `category.id == "undefined"`,
  ask OpenAI (json_schema → `{match_ids:[...]}`) which match the new category's label, and set those notes' `category`
  to the new one. Only uncategorized notes are touched.
- `deleteUserData` (Auth `onDelete`): recursively delete `/users/{uid}/**` in Firestore and wipe the
  `/users/{uid}/**` Storage prefix. Fired when `AuthRepo.deleteAccount()` deletes the Auth user.
- `categoryFanout`, `storageCascade`, `provisionUser`: see `DataModel.md`, `Storage.md`, `Auth.md`.

## 7. Function configuration

```ts
export const chat = onCall(
  { region: kRegion, enforceAppCheck: true, timeoutSeconds: 120, memory: '512MiB',
    secrets: ['OPENAI_API_KEY'] }, handler);
```
- `kRegion = 'asia-east1'` (Taiwan; Firestore + Functions colocated).
- Cloud Function `timeoutSeconds`: `chat` 120 (multi-round loop); `transcribe` / `exportRecap` / `exportAchievement`
  120; all others 60. (Distinct from the per-request timeout in §5.)
- App Check enforced on all callables; triggers run privileged. The `exportRecap` / `exportAchievement` render
  functions carry no `OPENAI_API_KEY` secret.
- OpenAI key via Functions Secret Manager (`firebase functions:secrets:set OPENAI_API_KEY`).

## 8. Error taxonomy

Functions throw `HttpsError`: `unauthenticated`, `permission-denied` (App Check), `resource-exhausted` (rate limit),
`deadline-exceeded` (OpenAI timeout), `unavailable` (OpenAI 5xx after retries), `invalid-argument`, `internal`.
`CloudFunctionAiService` maps any `FirebaseFunctionsException` to `AiFailure`. Server retries OpenAI 3× with
exponential backoff before surfacing.

## 9. Rate limit

60 AI callable invocations / user / hour → `resource-exhausted`. Enforced with a **fixed 1-hour window** counter at
`users/{uid}/_internal/rateLimit` (`{windowStart, count}`), updated in a Firestore transaction at the start of each
AI callable: if `now − windowStart ≥ 1h`, reset to `{now, 1}`; else if `count ≥ 60`, throw `resource-exhausted`; else
increment. The `_internal` subtree is fn-only (denied to clients in `Security.md`).
