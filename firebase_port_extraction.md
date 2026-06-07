# MyRoom — Exact Implementation Extraction for Firebase Port

> All snippets are verbatim from the source. File paths are relative to `lib/`.
> Nothing is proposed or refactored here — this is a read-only audit.

---

## 1. Full SQLite Schema

All `CREATE TABLE` statements are executed in `services/database_service.dart` inside `_onCreate(Database db, int version)` (lines 47–178). Schema version is hard-coded as `1` with no `_onUpgrade` handler.

**`todos`**
```sql
CREATE TABLE todos (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  text       TEXT    NOT NULL,
  done       INTEGER NOT NULL DEFAULT 0,
  cat        TEXT    NOT NULL,
  color      INTEGER NOT NULL,
  priority   INTEGER NOT NULL DEFAULT 3,
  created_at INTEGER NOT NULL
)
```
- `done`: 0/1 boolean
- `color`: Flutter `Color.toARGB32()` integer (32-bit ARGB)
- `priority`: 1 = highest, 4 = lowest; used as display sort order; mutated by drag-reorder
- No FK to `categories.name`; `cat` is stored as the category name string

**`categories`**
```sql
CREATE TABLE categories (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  TEXT    NOT NULL UNIQUE,
  color INTEGER NOT NULL
)
```

**`events`**
```sql
CREATE TABLE events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT    NOT NULL,
  start_year  INTEGER NOT NULL DEFAULT 2026,
  start_month INTEGER NOT NULL DEFAULT 4,
  start_day   INTEGER NOT NULL,
  start_hour  INTEGER NOT NULL,
  start_min   INTEGER NOT NULL,
  end_year    INTEGER NOT NULL DEFAULT 2026,
  end_month   INTEGER NOT NULL DEFAULT 4,
  end_day     INTEGER NOT NULL,
  end_hour    INTEGER NOT NULL,
  end_min     INTEGER NOT NULL,
  color       INTEGER NOT NULL,
  all_day     INTEGER NOT NULL DEFAULT 0,
  description TEXT,
  location    TEXT,
  created_at  INTEGER NOT NULL
)
```
- No single timestamp column. Range queries use `printf('%04d-%02d-%02d', start_year, start_month, start_day)`.
- `all_day`: 0/1 boolean
- `description`, `location`: nullable

**`ideas`**
```sql
CREATE TABLE ideas (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  text       TEXT    NOT NULL,
  ai_summary TEXT,
  links      TEXT,
  created_at INTEGER NOT NULL
)
```
- `ai_summary`: null until AI enrichment completes
- `links`: JSON string — `[{"title":"...","url":"..."}]` — or null

**`notes`**
```sql
CREATE TABLE notes (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  date_key   TEXT    NOT NULL,
  content    TEXT    NOT NULL,
  cat_id     TEXT,
  updated_at INTEGER NOT NULL
)
```
- No `UNIQUE` on `date_key` — multiple rows per date are allowed
- `cat_id` NULL = primary date note; non-null = categorised note
- `cat_id` is a `TEXT` FK (not enforced) to `note_categories.id`

**`note_categories`**
```sql
CREATE TABLE note_categories (
  id         TEXT    PRIMARY KEY,
  label      TEXT    NOT NULL,
  icon_name  TEXT    NOT NULL,
  color_val  INTEGER NOT NULL,
  bg_val     INTEGER NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
)
```
- `id` is a user-visible string slug (e.g. `'undefined'`, `'academic'`, `'sport'`), not an auto-incremented integer
- `icon_name`: key into `kNoteIconMap` in `note_page.dart`

**`note_attachments`**
```sql
CREATE TABLE note_attachments (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  note_id     INTEGER NOT NULL,
  type        TEXT    NOT NULL,
  filename    TEXT    NOT NULL,
  rel_path    TEXT    NOT NULL,
  extracted   TEXT,
  created_at  INTEGER NOT NULL
)
```
- `note_id`: FK (not enforced) to `notes.id`
- `type`: string — `'image'`, `'audio'`, or `'file'`
- `rel_path`: relative to app-documents directory (e.g. `note_attachments/1234567_42.jpg`)
- `extracted`: Whisper transcript (audio) or pdfium text extract (file/pdf); nullable

**`recap_items`**
```sql
CREATE TABLE recap_items (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  era              TEXT    NOT NULL,
  title            TEXT    NOT NULL,
  completed_date   TEXT,
  target_date      TEXT,
  desc             TEXT    NOT NULL,
  note_link        TEXT,
  created_at       INTEGER NOT NULL
)
```
- `era`: string — `'past'`, `'now'`, or `'future'`
- `completed_date`, `target_date`: free-form human strings (e.g. `'2026年1月'`, `'目標 2026年5月'`); not ISO dates
- `note_link`: `'diary'` | `'note'` | null — purely display metadata, not an FK

**`chat_messages`**
```sql
CREATE TABLE chat_messages (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  is_user    INTEGER NOT NULL,
  text       TEXT    NOT NULL,
  created_at INTEGER NOT NULL
)
```
- `is_user`: 0/1 boolean

**`pinned_resources`**
```sql
CREATE TABLE pinned_resources (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  title     TEXT    NOT NULL,
  type      TEXT    NOT NULL,
  desc      TEXT    NOT NULL,
  url       TEXT    NOT NULL UNIQUE,
  pinned_at INTEGER NOT NULL
)
```
- `url` has a `UNIQUE` constraint; `pinResource()` uses `ConflictAlgorithm.ignore`

**`user_profile`**
```sql
CREATE TABLE user_profile (
  id                INTEGER PRIMARY KEY DEFAULT 1,
  self_intro        TEXT    NOT NULL DEFAULT '',
  ai_instructions   TEXT    NOT NULL DEFAULT '',
  ai_enrich_enabled INTEGER NOT NULL DEFAULT 1
)
```
- Single-row table, `id` always = 1; `saveUserProfile()` uses `ConflictAlgorithm.replace`

**Indexes and foreign keys:** There are **no explicit indexes** and **no FOREIGN KEY constraints** declared anywhere in `_onCreate`. All relational links (e.g. `notes.cat_id` → `note_categories.id`, `note_attachments.note_id` → `notes.id`) are enforced only in application code.

**The 3 tables not named in the original handoff doc:**

The handoff doc listed 11 named tables and said "3 others". In reality there are exactly **11 tables** — no unnamed tables exist. The handoff doc's count of 14 was incorrect. The 11 tables are: `todos`, `categories`, `events`, `ideas`, `notes`, `note_categories`, `note_attachments`, `recap_items`, `chat_messages`, `pinned_resources`, `user_profile`.

---

## 2. Data Models

### `CalendarEvent` (`models/event.dart`)

```dart
class CalendarEvent {
  final int id;
  final String title;
  final int startYear;   // default: 2026
  final int startMonth;  // default: 4
  final int startDay;
  final int startHour;
  final int startMin;
  final int endYear;     // default: 2026
  final int endMonth;    // default: 4
  final int endDay;
  final int endHour;
  final int endMin;
  final Color color;
  final bool allDay;     // default: false
  final String? description;
  final String? location;
}
```
No `toMap`/`fromMap`. Serialization is inline in `DatabaseService._rowToEvent()`:
```dart
CalendarEvent _rowToEvent(Map<String, dynamic> r) => CalendarEvent(
  id: r['id'] as int,
  title: r['title'] as String,
  startYear:  (r['start_year']  as int?) ?? 2026,
  startMonth: (r['start_month'] as int?) ?? 4,
  startDay:   r['start_day']  as int,
  startHour:  r['start_hour'] as int,
  startMin:   r['start_min']  as int,
  endYear:    (r['end_year']   as int?) ?? 2026,
  endMonth:   (r['end_month']  as int?) ?? 4,
  endDay:     r['end_day']    as int,
  endHour:    r['end_hour']   as int,
  endMin:     r['end_min']    as int,
  color:      Color(r['color'] as int),
  allDay:     (r['all_day'] as int) == 1,
  description: r['description'] as String?,
  location:    r['location']    as String?,
);
```
Color stored as `e.color.toARGB32()` on insert.

---

### `TodoItem` + `TodoCategory` (`models/todo_item.dart`)

```dart
class TodoItem {
  final int id;
  final String text;
  final bool done;
  final String cat;      // category name string, not an id
  final Color color;
  final int priority;    // default: 3
  final int createdAt;   // milliseconds since epoch, default: 0
}

class TodoCategory {
  final int id;
  final String name;
  final Color color;
}
```
Deserialization in `DatabaseService._rowToTodo()`:
```dart
TodoItem _rowToTodo(Map<String, dynamic> r) => TodoItem(
  id: r['id'] as int,
  text: r['text'] as String,
  done: (r['done'] as int) == 1,
  cat: r['cat'] as String,
  color: Color(r['color'] as int),
  priority: (r['priority'] as int?) ?? 3,
  createdAt: (r['created_at'] as int?) ?? 0,
);
```

---

### `Idea` + `IdeaLink` (`models/idea.dart`)

```dart
class IdeaLink {
  final String title;
  final String url;
}

class Idea {
  final int id;
  final String text;
  final String? aiSummary;  // null = AI pending or failed
  final List<IdeaLink> links; // default: []
}
```
`links` is stored as JSON in `ideas.links`. Deserialization:
```dart
final linksJson = r['links'] as String?;
final links = linksJson != null
    ? (jsonDecode(linksJson) as List)
        .map((l) => IdeaLink(title: l['title'] as String, url: l['url'] as String))
        .toList()
    : <IdeaLink>[];
```
On insert:
```dart
final linksJson = i.links.isEmpty
    ? null
    : jsonEncode(i.links.map((l) => {'title': l.title, 'url': l.url}).toList());
```

---

### `NoteItem`, `NoteCategory`, `NoteAttachment` (`models/note_item.dart`)

```dart
class NoteCategory {
  final String id;         // user-visible slug, e.g. 'academic'
  final String label;
  final String iconName;   // key into kNoteIconMap in note_page.dart
  final Color color;
  final Color bg;
  final int sortOrder;
}

class NoteItem {
  final int id;
  final String dateKey;    // 'YYYY-MM-DD'
  final String content;
  final String? catId;     // null = primary date note
  final int updatedAt;     // milliseconds since epoch
}

enum NoteAttachmentType { image, audio, file }

class NoteAttachment {
  final int id;
  final int noteId;
  final NoteAttachmentType type;
  final String filename;
  final String relPath;    // relative to app documents directory
  final String? extracted; // Whisper transcript or PDF text
  final int createdAt;     // milliseconds since epoch
}
```
Type serialization:
```dart
static NoteAttachmentType parseType(String s) => switch (s) {
  'image' => NoteAttachmentType.image,
  'audio' => NoteAttachmentType.audio,
  _       => NoteAttachmentType.file,
};
static String typeName(NoteAttachmentType t) => switch (t) {
  NoteAttachmentType.image => 'image',
  NoteAttachmentType.audio => 'audio',
  NoteAttachmentType.file  => 'file',
};
```

---

### `RecapItem` (`models/recap_item.dart`)

```dart
enum Era { past, now, future }

class RecapItem {
  final String id;             // stored as int in DB, toString()d on read
  final Era era;
  final String title;
  final String? completedDate; // free-form human string, e.g. '2026年1月'
  final String? targetDate;    // free-form human string, e.g. '目標 2026年5月'
  final String desc;
  final String? noteLink;      // 'diary' | 'note' | null
}
String get displayDate => completedDate ?? targetDate ?? '';
```
Deserialization:
```dart
RecapItem _rowToRecap(Map<String, dynamic> r) => RecapItem(
  id: r['id'].toString(),   // ← int converted to String
  era: Era.values.firstWhere((e) => e.name == r['era']),
  ...
);
```
Note: `id` is a Dart `String` even though the DB column is `INTEGER`. On insert the returned `int` id is never used; seed data uses string ids like `'p1'`, `'n1'`, `'f1'` but the DB auto-increments to integers.

---

### `AiResource` (`models/ai_resource.dart`)

```dart
class AiResource {
  final String title;
  final String type;   // '書籍' | '文章' | '工具' | '課程' | '網站'
  final String desc;
  final String url;
}
```
No `toMap`/`fromMap`. Deserialized inline in `DatabaseService.getPinnedResources()`.

---

## 3. OpenAI Operations — Exact Request Bodies and Response Parsing

All calls go to `https://api.openai.com/v1/chat/completions` except Whisper and DALL-E which use their own endpoints.

### 3.1 `chat()`

**Request body:**
```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "<system prompt below>"},
    {"role": "user",   "content": "<user message>"},
    ...
  ],
  "temperature": 0.7,
  "max_tokens": 600,
  "tools": [ <9 tool definitions — see §4> ]
}
```
Tools are only included when `toolExecutor != null` (always true when called from `ai_chat_overlay.dart`).

**System prompt (verbatim):**
```
你是 MyRoom 個人助理。以下是使用者資料摘要（如需完整清單含 id，請使用 list_* 工具）：

{contextSummary}

【關於使用者】{selfIntro}     ← only if non-empty

【回覆指示】{aiInstructions}  ← only if non-empty

請用繁體中文回答，語氣簡潔友善。回答盡量不超過 150 字，除非需要【回覆指示】中要求。

你可以使用工具新增、刪除或查詢資料。你需要具備敏銳的洞察力，主動辨識出使用者的需求並使用工具，
不一定需要使用者明確要求。例如，當使用者提出想法，將想法加入靈感；當使用者表示心情低落時，自動新增筆記；
當使用者提出行程，依照時間的有無，加入行程或待辦事項。如需查詢完整清單或 id，請使用 list_* 工具。執行工具後，用繁體中文告知使用者結果。
今天日期：$todayKey()
```
(Note: `$todayKey()` is a literal Dart interpolation bug — the parentheses mean the string `"$todayKey()"` is emitted verbatim, not the actual date value.)

**Response parsing:**
```dart
final choice = body['choices'][0] as Map<String, dynamic>;
final finishReason = choice['finish_reason'] as String? ?? 'stop';
final message = choice['message'] as Map<String, dynamic>;
// if finishReason == 'tool_calls': process tool_calls, loop
// else: return message['content'] as String
```
**Timeout:** 30 seconds. **Max rounds:** 6.

---

### 3.2 `enrichIdea()`

**Request body:**
```json
{
  "model": "gpt-4o-mini-search-preview",
  "web_search_options": {},
  "messages": [
    {"role": "system", "content": "<system prompt below>"},
    {"role": "user",   "content": "<ideaText>"}
  ],
  "max_completion_tokens": 300
}
```
No `temperature` parameter. No `response_format`.

**System prompt (verbatim):**
```
你是一個知識整理助理。使用者輸入一個靈感或想法，你需要：
1. 用一句話（繁體中文，20-40字）概括這個靈感的核心洞察
2. 提供 2-3 個與此靈感相關的知名資源（書籍、論文、網站或工具）

回傳格式限制：以 JSON 格式輸出，回傳以 ```json 開頭，``` 結尾，僅包含 JSON，不含其他說明：
範例輸出： "```json\n{ "summary": "養貓有益身心健康", "links": [{"title":"養貓前需要知道什麼？","url":"https://www.royalcanin.com/tw/cats/products/kitten-growth-program"}] }"
summary 是 20-40 字這個靈感的核心洞察（繁體中文），title 是資源的標題或簡短說明（繁體中文），url 是資源的連結

規則：summary 必須是繁體中文，簡潔有力；links 最多 3 個；url 使用真實網址；只回傳 JSON；絕對符合JSON格式
```

**Expected response (with ```json fences):**
```json
{
  "summary": "20-40字洞察",
  "links": [
    {"title": "資源標題", "url": "https://..."}
  ]
}
```
Parsed by `_extractJson()` which strips ` ```json ` fences before `jsonDecode`. **Timeout:** 20 seconds.

---

### 3.3 `fetchRecommendations()`

**Request body:**
```json
{
  "model": "gpt-4o-mini-search-preview",
  "web_search_options": {},
  "messages": [
    {"role": "system", "content": "<system prompt below>"},
    {"role": "user",   "content": "我的靈感清單：\n1. <idea1>\n2. <idea2>..."}
  ],
  "max_completion_tokens": 600
}
```
Takes the first 5 ideas. No `temperature`.

**System prompt (verbatim):**
```
你是一個知識推薦助理。使用網路搜尋，根據使用者的靈感清單，
推薦 4-6 個目前仍可存取的最相關學習資源。

回傳嚴格 JSON（僅包含 JSON，不含其他文字）：
{"resources":[{"title":"...","type":"書籍|文章|工具|課程|網站",
"desc":"一句話說明（繁體中文，20字以內）","url":"https://..."}]}

規則：url 必須是目前可存取的真實網址；優先推薦有實際內容的頁面；只回傳 JSON
```

**Expected response:**
```json
{
  "resources": [
    {"title":"...", "type":"書籍", "desc":"...", "url":"https://..."}
  ]
}
```
Parsed via `_extractJson()` + `jsonDecode`. Items where `title.isEmpty` are filtered. **Timeout:** 30 seconds.

---

### 3.4 `classifyNoteToCategory()`

**Request body:**
```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "<system prompt below>"},
    {"role": "user",   "content": "分類清單：[{\"id\":\"academic\",\"label\":\"學業\"}, ...]\n\n筆記內容：<content>"}
  ],
  "response_format": {"type": "json_object"},
  "temperature": 0.2,
  "max_tokens": 50
}
```

**System prompt (verbatim):**
```
你是一個筆記分類引擎。給定一段筆記內容和可用分類清單，
判斷這則筆記最適合屬於哪個分類。

回傳嚴格 JSON（不含其他文字）：{"cat_id":"..."}

規則：cat_id 必須是提供清單中的其中一個 id；若都不合適，使用 "undefined"；只回傳 JSON
```

**Expected response:**
```json
{"cat_id": "academic"}
```
Validated: if `catId` is not in the provided category list, returns `null`. **Timeout:** 15 seconds.

---

### 3.5 `findNotesMatchingCategory()`

**Request body:**
```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "<system prompt below>"},
    {"role": "user",   "content": "新分類：<label>\n\n筆記清單（id|內容）：\n42|<content1>\n43|<content2>..."}
  ],
  "response_format": {"type": "json_object"},
  "temperature": 0.2,
  "max_tokens": 200
}
```

**System prompt (verbatim):**
```
你是一個筆記分類引擎。給定一個新分類的名稱，以及一組編號筆記，
判斷哪些筆記適合歸入此分類。

回傳嚴格 JSON（不含其他文字）：{"match_ids":[...]}

規則：match_ids 為適合歸入該分類的筆記 id 陣列（整數）；
不適合的不列出；若全不符合回傳空陣列；只回傳 JSON
```

**Expected response:**
```json
{"match_ids": [42, 43]}
```
Safety-filtered: only IDs present in the input `undefinedNotes` list are returned. **Timeout:** 20 seconds.

---

### 3.6 `generateEraInsight()`

**Request body:**
```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "<system prompt below>"},
    {"role": "user",   "content": "[過去 回顧]\n<dataSummary>"}
  ],
  "temperature": 0.78,
  "max_tokens": 120
}
```
`eraLabel` is one of `'過去'`, `'現在'`, `'未來'` (from `kEraLabel` in `seed_data.dart`).

**System prompt (verbatim):**
```
你是一個溫暖的個人成長教練。根據使用者的資料，用繁體中文寫 2 到 3 句鼓勵、真誠且具體的話。
語氣要有溫度，避免空泛制式。只回傳純文字，不要其他說明。
```

**Expected response:** Plain text string, 2–3 sentences. Parsed as `body['choices'][0]['message']['content'] as String?`. **Timeout:** 20 seconds.

---

### 3.7 `generateEraImage()`

**Endpoint:** `https://api.openai.com/v1/images/generations`

**Request body:**
```json
{
  "model": "dall-e-3",
  "prompt": "<caller-provided prompt string>",
  "n": 1,
  "size": "1792x1024",
  "style": "natural",
  "quality": "standard"
}
```

**Expected response:**
```dart
body['data'][0]['url'] as String?
```
Returns a URL string to the generated image. **Timeout:** 60 seconds.

---

### 3.8 `classifyMultiInput()`

**Request body:**
```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "<system prompt + injected categories below>"},
    {
      "role": "user",
      "content": [
        {"type": "text",      "text": "<combined text + attachment manifest>"},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,<b64>", "detail": "low"}},
        ...
      ]
    }
  ],
  "response_format": {"type": "json_object"},
  "temperature": 0.2,
  "max_tokens": 800
}
```
Images are embedded as data URIs with `detail: "low"`. **Timeout:** 30 seconds.

**System prompt base (verbatim)** — then appended at runtime with categories:
```
你是一個個人生產力助理，使用繁體中文。使用者的輸入可能包含多個不同主題的事項。
分析全部內容，拆解成數個彼此獨立的事項，每個事項都只能被分類到以下四種類型之一，並回傳 JSON。

回傳格式（嚴格 JSON，不含其他文字）：{"items":[...]}

每個 item 的結構：
- todo: {"type":"todo","text":"...","cat":"..."}
- todo_with_time: {"type":"todo_with_time","text":"...",
    "start_year":YYYY,"start_month":MM,"start_day":N,"start_hour":N,"start_min":N,
    "end_year":YYYY,  "end_month":MM,  "end_day":N,  "end_hour":N,  "end_min":N}
  （若沒有明確結束時間，預設 start+1 小時；start_year/start_month 若未跨月可省略，預設當月）
- idea: {"type":"idea","text":"..."}
- note: {"type":"note","date_key":"YYYY-MM-DD","note_cat":"...","content":"...","attachment_indices":[i,...]}
特別說明：
- todo 代表未指定時間的事項，例如「找個時間去買蘋果」
- todo_with_time 代表有明確時間的事項
- idea 紀錄突然非任務性、突然冒出的想法或想做的事情
- note 紀錄各類成就、情緒、對於某件事物的評論，通常是完整句子
- 若使用者提供了附件清單（attachments），每個附件都會以 [i:type:name] 標示其索引（i 從 0 開始）。
  將每個附件分配給最相關的「note」項目，於該 item 的 attachment_indices 中列出對應索引。
  attachment_indices 僅可出現在 type=="note" 的 item 上；其他類型不可使用此欄位。
  每個附件索引最多只能出現在一個 note 中；若一段輸入只產生一個 note，所有附件都歸於它；
  若沒有附件或沒有 note，attachment_indices 應為空陣列。

規則：
- 只回傳 JSON，不含其他文字
- 每個拆解出來的事項「只能對應一個 item」
- 每個 item「只能屬於一種類型」
- 類型僅限以下五種，且不可同時屬於多種：todo / todo_with_time / idea / note / recap
- 特別是 todo 與 todo_with_time 必須二擇一，不可同時出現或混用
- todo，todo_with_time，和idea的說明需刪除冗餘文字，例如"找個時間去買蘋果"應紀錄為"買蘋果"
- 若整體無法分類，回傳 {"items":[{"type":"note","date_key":"TODAY","content":"原文"}]}
```
Then appended dynamically:
```
-今天日期：{today}
- cat只能是：工作|學習|個人|健康
- note_cat只能是：undefined|academic|sport
其他說明：
使用者指定允許使用的類型：{userSpecifiedCat or '無限定'}
```

**Expected response:**
```json
{
  "items": [
    {"type": "todo",           "text": "買蘋果", "cat": "個人"},
    {"type": "todo_with_time", "text": "開會",   "cat": "工作",
     "start_year": 2026, "start_month": 6, "start_day": 7,
     "start_hour": 10,   "start_min": 0,
     "end_year": 2026,   "end_month": 6,  "end_day": 7,
     "end_hour": 11,     "end_min": 0},
    {"type": "idea",  "text": "靈感內容"},
    {"type": "note",  "date_key": "2026-06-07", "note_cat": "academic",
     "content": "筆記內容", "attachment_indices": [0, 1]},
    {"type": "recap", "era": "past", "title": "...", "desc": "...", "date": "2025年"}
  ]
}
```

---

### 3.9 Whisper transcription (`transcribeAudio()`)

**Endpoint:** `https://api.openai.com/v1/audio/transcriptions`

**Request:** `multipart/form-data` POST via `http.MultipartRequest`:
```
model:           whisper-1
language:        zh
response_format: text
file:            <audioBytes>  (filename from caller)
```

**Expected response:** Plain-text transcript string (not JSON). Decoded as `utf8.decode(response.bodyBytes).trim()`. **Timeout:** 60 seconds.

---

## 4. Chat Tool Definitions (Full JSON) and Loop Logic

### Full tool definitions array (`_chatTools` in `openai_service.dart`, lines 142–288)

```json
[
  {
    "type": "function",
    "function": {
      "name": "delete_event",
      "description": "刪除一個行程（取消某個 event）",
      "parameters": {
        "type": "object",
        "properties": {
          "id": {"type": "integer", "description": "行程的資料庫 id"}
        },
        "required": ["id"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "add_event",
      "description": "新增一個行程",
      "parameters": {
        "type": "object",
        "properties": {
          "title":       {"type": "string",  "description": "行程標題"},
          "start_year":  {"type": "integer", "description": "開始年份"},
          "start_month": {"type": "integer", "description": "開始月份"},
          "start_day":   {"type": "integer", "description": "開始日"},
          "start_hour":  {"type": "integer", "description": "開始小時（24h）"},
          "start_min":   {"type": "integer", "description": "開始分鐘"},
          "end_year":    {"type": "integer", "description": "結束年份"},
          "end_month":   {"type": "integer", "description": "結束月份"},
          "end_day":     {"type": "integer", "description": "結束日"},
          "end_hour":    {"type": "integer", "description": "結束小時（24h）"},
          "end_min":     {"type": "integer", "description": "結束分鐘"},
          "description": {"type": "string",  "description": "詳細說明"},
          "location":    {"type": "string",  "description": "地點"}
        },
        "required": ["title","start_year","start_month","start_day",
                     "start_hour","start_min","end_year","end_month",
                     "end_day","end_hour","end_min"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "delete_todo",
      "description": "刪除一個待辦事項",
      "parameters": {
        "type": "object",
        "properties": {
          "id": {"type": "integer", "description": "待辦的資料庫 id"}
        },
        "required": ["id"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "add_todo",
      "description": "新增一個待辦事項",
      "parameters": {
        "type": "object",
        "properties": {
          "text": {"type": "string", "description": "待辦內容"},
          "cat":  {"type": "string", "description": "分類：工作、學習、個人、健康"}
        },
        "required": ["text", "cat"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "delete_idea",
      "description": "刪除一個靈感",
      "parameters": {
        "type": "object",
        "properties": {
          "id": {"type": "integer", "description": "靈感的資料庫 id"}
        },
        "required": ["id"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "delete_note",
      "description": "刪除一則筆記",
      "parameters": {
        "type": "object",
        "properties": {
          "id": {"type": "integer", "description": "筆記的資料庫 id"}
        },
        "required": ["id"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "add_idea",
      "description": "新增一個靈感或想法（儲存後 AI 會自動生成摘要與資源連結）",
      "parameters": {
        "type": "object",
        "properties": {
          "text": {"type": "string", "description": "靈感內容"}
        },
        "required": ["text"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "add_note",
      "description": "新增一則筆記（儲存後 AI 會自動分類）",
      "parameters": {
        "type": "object",
        "properties": {
          "date_key": {"type": "string", "description": "日期 YYYY-MM-DD，預設今天"},
          "content":  {"type": "string", "description": "筆記內容"}
        },
        "required": ["content"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "add_recap",
      "description": "新增一個回顧項目（成就、進行中目標或未來計畫）",
      "parameters": {
        "type": "object",
        "properties": {
          "era":   {"type": "string", "description": "past、now、或 future"},
          "title": {"type": "string", "description": "標題"},
          "desc":  {"type": "string", "description": "描述"},
          "date":  {"type": "string", "description": "日期字串（如「2025年底」）"}
        },
        "required": ["era", "title"]
      }
    }
  }
]
```

**Note: there is no `list_*` read tool defined.** The system prompt references `list_todos / list_events / list_ideas / list_notes` tools as if they exist, but they are not in `_chatTools`. This is a bug — the AI is told about tools that don't exist.

### Loop logic (verbatim):

```dart
const maxRounds = 6;
for (int round = 0; round < maxRounds; round++) {
  // POST to OpenAI with current messages list
  final finishReason = choice['finish_reason'] as String? ?? 'stop';
  if (finishReason == 'tool_calls' && toolExecutor != null) {
    // append assistant message with tool_calls
    messages.add(Map<String, dynamic>.from(message));
    // for each tool call: execute, append tool result message
    messages.add({'role': 'tool', 'tool_call_id': toolCallId, 'content': result});
    // continue loop
  } else {
    return (reply: message['content'] as String? ?? '（無回應）', dataMutated: dataMutated);
  }
}
return (reply: '（AI 運算超出輪數限制，請再試）', dataMutated: dataMutated);
```

Stop conditions: `finish_reason != 'tool_calls'` **or** `toolExecutor == null` **or** `round >= 6`.

---

## 5. ClassificationResult Sealed-Class Hierarchy and JSON Contract

### Dart hierarchy

```dart
sealed class ClassificationResult {}

class ClassifiedTodo extends ClassificationResult {
  final String text;
  final String cat;   // category name string
}

class ClassifiedTodoWithTime extends ClassificationResult {
  final String text;
  final String cat;
  final int startYear, startMonth, startDay, startHour, startMin;
  final int endYear,   endMonth,   endDay,   endHour,   endMin;
  // startYear/endYear default to DateTime.now().year if null from AI
  // startMonth/endMonth default to DateTime.now().month if null from AI
}

class ClassifiedIdea extends ClassificationResult {
  final String text;
}

class ClassifiedNote extends ClassificationResult {
  final String dateKey;            // 'YYYY-MM-DD'
  final String content;
  final String cat;                // note_category id
  final List<int> attachmentIndices;      // indices into caller's attachment list
  final List<PendingNoteAttachment> pendingAttachments; // resolved after classification
}

class ClassifiedRecap extends ClassificationResult {
  final Era era;
  final String title;
  final String desc;
  final String date;  // free-form string from AI
}

class ClassificationError extends ClassificationResult {
  final String message;
  final String? rawText;  // original user input for fallback
}
```

### JSON discriminator and field names

The `"type"` field is the discriminator. Parsing is done in `_parseSingleItem()`:

| `"type"` value | Dart class | Required JSON fields |
|---|---|---|
| `"todo"` | `ClassifiedTodo` | `text`, `cat` |
| `"todo_with_time"` | `ClassifiedTodoWithTime` | `text`, `cat`, `start_day`, `start_hour`, `start_min`, `end_day`, `end_hour`, `end_min`; year/month optional |
| `"idea"` | `ClassifiedIdea` | `text` |
| `"note"` | `ClassifiedNote` | `date_key`, `note_cat` (maps to `cat`), `content`, `attachment_indices` (optional, default `[]`) |
| `"recap"` | `ClassifiedRecap` | `era`, `title`; `desc` and `date` optional |
| anything else | `ClassifiedNote` | falls through to default: `dateKey=today, cat="undefined", content=rawText` |

**`attachment_indices` safety:** only indices `>= 0` and `< attachmentCount` are kept. Duplicates are deduplicated with a `Set<int>`.

---

## 6. Image Model Conflict — Resolved

**`AppConfig.openAiImageModel` constant** (`lib/config.dart`, line 9):
```dart
static const openAiImageModel = 'dall-e-2';
```

**Actual model string passed in `generateEraImage()`** (`lib/services/openai_service.dart`, line 574):
```dart
body: jsonEncode({
  'model': 'dall-e-3',
  ...
}),
```

**Conclusion:** The constant `AppConfig.openAiImageModel` is **never used** in `generateEraImage()`. The string `'dall-e-3'` is hard-coded directly in the request body. DALL-E 3 is what actually runs. The constant `openAiImageModel = 'dall-e-2'` is a dead variable.

---

## 7. De-Facto Repository Surface — All Call Sites

### `lib/main.dart` (MyRoomShell callbacks)

**DatabaseService calls:**
- `getTodos()` — after every todo mutation
- `insertTodo(t)`
- `updateTodo(t)` — done toggle and text edit
- `deleteTodo(id)`
- `reorderTodos(orderedIds)`
- `getCategories()` — after category mutations
- `insertCategory(name, color)`
- `deleteCategory(id)`
- `getEvents()` — after every event mutation
- `insertEvent(e)`
- `deleteEvent(id)`
- `updateEvent(e)`
- `getIdeas()` — after idea mutations
- `insertIdea(text)` (returns new `id`)
- `updateIdeaAiResult(id, summary, linksJson)`
- `updateIdeaText(id, text)` + `getIdeas()`
- `deleteIdea(id)`
- `getNotes()` — after note mutations (returns `Map<String, String>`)

**OpenAIService calls:**
- `enrichIdea(text)` — triggered after `insertIdea` and after `updateIdeaText`
- `classifyNoteToCategory(content, categories)` — triggered after note upsert

---

### `lib/overlays/add_overlay.dart`

**DatabaseService calls:**
- `getCategories()` — to inject todo category names into classifier
- `getNoteCategories()` — to inject note category ids into classifier

**OpenAIService calls:**
- `transcribeAudio(bytes, filename)` — called once per audio attachment (`.then()` chain, fire-and-forget style before main classify call)
- `classifyMultiInput(text, base64Images, fileText, attachments, userSpecifiedCat)`

---

### `lib/overlays/ai_chat_overlay.dart`

**DatabaseService calls:**
- `getChatMessages(limit: 60)` — on overlay open
- `getUserProfile()` — on overlay open
- `buildContextSummary()` — before each AI call
- `insertChatMessage(true, text)` — save user message
- `insertChatMessage(false, reply)` — save AI reply
- `updateIdeaAiResult(ideaId, summary, linksJson)` — called from tool executor after `add_idea`

**OpenAIService calls:**
- `chat(history, contextSummary, selfIntro, aiInstructions, toolExecutor)`
- `enrichIdea(text)` — called from within the tool executor for `add_idea`
- `classifyNoteToCategory(content, categories)` — called from within tool executor for `add_note`

---

### `lib/pages/note_page.dart`

**DatabaseService calls (direct — bypasses shell):**
- `getNoteCategories()` — on init and after category mutations
- `getNotesByCategory(catId)` — for all categories on init, and on individual cat refresh
- `getNotesByDate(dateKey)` — when day panel opens
- `deleteNote(note.id)` — from two separate locations in the page
- `insertNoteCategory(NoteCategory(...))` — on new category creation
- `deleteNoteCategory(cat.id)` — on category deletion (also deletes child notes)

---

### `lib/pages/idea_page.dart`

**DatabaseService calls:**
- `getPinnedResources()` — after recommendations load
- `pinResource(r)`
- `unpinResource(r.url)`

**OpenAIService calls:**
- `fetchRecommendations(texts)` — where `texts` are idea text strings

---

### `lib/pages/setting_page.dart`

**DatabaseService calls:**
- `getUserProfile()` — on init
- `saveUserProfile(selfIntro, aiInstructions, aiEnrichEnabled)` — on back navigation

---

### `lib/pages/recap_page.dart`

**OpenAIService calls:**
- `generateEraInsight(kEraLabel[era]!, _dataSummary(era))` — lazy on first era tap
- `generateEraImage(_imagePrompt(era))` — lazy on first era tap

---

### `lib/services/openai_service.dart` (internal cross-calls)

- `classifyMultiInput()` → `DatabaseService.instance.getCategories()`
- `classifyMultiInput()` → `DatabaseService.instance.getNoteCategories()`
- `_parseSingleItem()` → `DatabaseService.instance.getCategories()` (called once per item in the result list — potential N+1)

---

## 8. Attachments

### File naming and write path (`services/attachment_storage.dart`)

```dart
static const _folderName = 'note_attachments';

Future<String> save(Uint8List bytes, String ext) async {
  final folder = await _folder(); // <appDocs>/note_attachments/
  final cleanExt = ext.startsWith('.') ? ext.substring(1) : ext;
  final name = '${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(1 << 32)}'
      '${cleanExt.isEmpty ? '' : '.$cleanExt'}';
  // → e.g.: "1748000000000_3141592653.jpg"
  final file = File('${folder.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return '$_folderName/$name';
  // → e.g.: "note_attachments/1748000000000_3141592653.jpg"
}
```

Absolute path is resolved at read time:
```dart
Future<File> file(String relPath) async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$relPath');
}
```

### `note_attachments` table columns

```sql
id          INTEGER PRIMARY KEY AUTOINCREMENT
note_id     INTEGER NOT NULL     -- FK to notes.id (unenforced)
type        TEXT    NOT NULL     -- 'image' | 'audio' | 'file'
filename    TEXT    NOT NULL     -- original user-visible filename
rel_path    TEXT    NOT NULL     -- relative path returned by AttachmentStorage.save()
extracted   TEXT                 -- Whisper transcript or pdfium text; nullable
created_at  INTEGER NOT NULL     -- milliseconds since epoch
```

### Delete and cleanup logic

**`deleteNote(id)`** in `DatabaseService` does cascade correctly:
```dart
Future<int> deleteNote(int id) async {
  // 1. Fetch all rel_paths for this note's attachments
  final attRows = await database.query('note_attachments',
      columns: ['rel_path'], where: 'note_id = ?', whereArgs: [id]);
  // 2. Delete each on-disk file via AttachmentStorage.delete()
  for (final r in attRows) {
    await AttachmentStorage.instance.delete(r['rel_path'] as String);
  }
  // 3. Delete attachment rows
  await database.delete('note_attachments', where: 'note_id = ?', whereArgs: [id]);
  // 4. Delete the note row
  return database.delete('notes', where: 'id = ?', whereArgs: [id]);
}
```

**`deleteNoteAttachment(id)`** also deletes the on-disk file before the row.

**`deleteNoteCategory(id)`** deletes child notes via `database.delete('notes', where: 'cat_id = ?', ...)` but does **not** clean up attachment files for those notes — only the `notes` rows and the `note_categories` row are deleted; `note_attachments` rows and on-disk files become orphans.

---

## 9. Seed Data

### What is seeded per table

`_seed()` in `DatabaseService` inserts from `SeedData` static getters. All `created_at` / `updated_at` values are set to `DateTime.now().millisecondsSinceEpoch` at seed time (not the values in the model objects).

| Table | Count | Content |
|---|---|---|
| `events` | 6 | 週組會議, 英文課, 讀書計畫, 健身房, 專案截止, 團隊活動 (all in May 2026) |
| `categories` | 4 | 工作 (blue), 學習 (sage), 個人 (rose), 健康 (amber); ids 1–4 |
| `todos` | 6 | Across all 4 categories, mix of done/undone |
| `ideas` | 3 | Pre-enriched with AI summaries and links |
| `notes` | 4 | Dates: 2026-05-01, 2026-05-04, 2026-04-28, 2026-04-22 |
| `note_categories` | 3 | `undefined`, `academic`, `sport` |
| `recap_items` | 9 | 4 past, 2 now, 3 future |

### Seeding trigger condition

`_seed()` is called unconditionally inside `_onCreate` (first-ever DB creation).

`seedIfEmpty()` is a **second** public method called from `main.dart` on startup:
```dart
Future<void> seedIfEmpty() async {
  final todoCount = ... 'SELECT COUNT(*) FROM todos' ...;
  final eventCount = ... 'SELECT COUNT(*) FROM events' ...;
  if (todoCount == 0 && eventCount == 0) {
    await _seed(database);    // full reseed
  } else if (eventCount == 0) {
    // events table wiped by migration — re-seed events only
    for (final e in SeedData.initEvents) { ... }
  }
}
```
Condition: **both** `todos` AND `events` must be empty to trigger a full reseed. If only `events` is empty, only events are reseeded. This means deleting all user todos would not trigger a reseed on next launch, but a fresh DB always seeds fully.

---

## 10. Dependencies and Config

### `pubspec.yaml` direct dependencies with resolved versions from `pubspec.lock`

| Package | Spec (pubspec.yaml) | Resolved (pubspec.lock) |
|---|---|---|
| `google_fonts` | `^8.0.2` | `8.1.0` |
| `lucide_icons_flutter` | `^3.1.13` | `3.1.13` |
| `sqflite` | `^2.4.1` | `2.4.2+1` |
| `sqflite_common_ffi` | `^2.3.4` | `2.4.0+3` |
| `sqflite_common_ffi_web` | `^1.1.1` | `1.1.1` |
| `path` | `^1.9.1` | `1.9.1` |
| `http` | `^1.2.2` | `1.6.0` |
| `url_launcher` | `^6.3.1` | *(not in lock excerpt — present in tree)* |
| `file_picker` | `^11.0.2` | `11.0.2` |
| `record` | `^6.0.0` | `6.2.0` |
| `permission_handler` | `^12.0.1` | `12.0.1` |
| `pdfrx` | `^2.2.24` | `2.2.24` |
| `path_provider` | `^2.1.4` | `2.1.5` |
| `flutter_lints` (dev) | `^6.0.0` | `6.0.0` |

Key transitive packages: `sqlite3` `3.3.1`, `pdfium_dart` `0.1.3`, `pdfium_flutter` `0.1.9`, `record_android` `1.5.1`, `record_ios` `1.2.0`, `record_windows` `1.0.7`, `rxdart` `0.28.0`, `http` `1.6.0`.

### `analysis_options.yaml` (verbatim)

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_final_fields: false

analyzer:
  errors:
    deprecated_member_use: ignore
    unnecessary_underscores: ignore
    unnecessary_brace_in_string_interps: ignore
    unused_element_parameter: ignore
```

The base ruleset is `flutter_lints/flutter.yaml`. Four analyzer errors are suppressed globally; one lint rule (`prefer_final_fields`) is disabled. There are no additional enabled rules.

---

## 11. Other Load-Bearing Implementation Details for Firebase Port

### 11.1 Custom datetime handling — no `DateTime` objects

Events have **no `DateTime` fields** anywhere. All six integer columns (`start_year`, `start_month`, `start_day`, `start_hour`, `start_min`, `created_at`) are stored and loaded separately. Default values in `CalendarEvent` constructor are hard-coded to year `2026`, month `4`. The `ClassifiedTodoWithTime` constructor defaults nulls to `DateTime.now().year` and `DateTime.now().month`.

Range queries in `getEventsInWindow()` construct a sortable string via SQLite's `printf('%04d-%02d-%02d', ...)`. Firebase will need a real timestamp field.

`created_at`, `updated_at`, `pinned_at` in all tables are Unix millisecond integers from `DateTime.now().millisecondsSinceEpoch`. There is **no timezone handling** — everything is local device time with no UTC conversion.

### 11.2 ID generation scheme

- `todos`, `events`, `categories`, `ideas`, `notes`, `note_attachments`, `recap_items`, `chat_messages`, `pinned_resources`: `INTEGER PRIMARY KEY AUTOINCREMENT` — SQLite-assigned integers
- `note_categories.id`: user-visible string slugs (`'undefined'`, `'academic'`, `'sport'`) assigned at creation time; generated in `note_page.dart` using UUID-style logic (not shown here — see `note_page.dart` directly)
- `user_profile.id`: always `1`
- `RecapItem.id` in Dart: stored as `String` even though the DB column is `INTEGER` — `r['id'].toString()` on read. This means Firebase's document ID would need to handle the type mismatch

The `add_todo` and `add_event` chat tools receive IDs from the DB on insert and use them in the context summary for subsequent deletion. Firebase auto-generated IDs would still work here as long as the context summary is rebuilt after each insert.

### 11.3 Ordering logic for drag-reorder

Todos use the `priority` column as a display sort index. `reorderTodos(List<int> orderedIds)` does a batch update setting `priority = i` for each id in position `i`:

```dart
for (int i = 0; i < orderedIds.length; i++) {
  batch.update('todos', {'priority': i}, where: 'id = ?', whereArgs: [orderedIds[i]]);
}
```

This means `priority` is not a semantic priority (1=urgent) in the reordering path — it becomes a dense positional index 0..N-1. The initial schema default of `3` and the seed data values (1–4) are overwritten after the first drag. Firebase port must preserve `priority` as an integer sort key and support atomic batch updates.

### 11.4 Context summary (`buildContextSummary`) vs `buildCompactSummary`

There are **two** context-building methods. `buildContextSummary()` is used in `ai_chat_overlay.dart` (line 317). It queries:
- `getTodosFiltered()` — all pending todos
- `_getDoneCount()` — count of done todos
- `getEventsInWindow(3, 30)` — events from 3 days ago to 30 days ahead
- `getRecentNoteItems(days: 7)` — notes updated in last 7 days, deduplicated by `date_key`
- `getIdeasPaged(limit: 20)` — latest 20 ideas
- `getActiveRecapItems()` — only `now` and `future` era items

`buildCompactSummary()` exists but is **not called anywhere** in the current codebase.

### 11.5 `getNotes()` return type mismatch with Firebase model

`getNotes()` returns `Map<String, String>` (one content string per `date_key`). This is used only to drive calendar dot indicators in `main.dart`. The return is **deduplicated** — it keeps only the first (most recently updated) note per `date_key`. The underlying `notes` table can have many rows per `date_key`. Firebase port must preserve this distinction between "at least one note exists on this date" (for dots) and the actual list of notes per date.

### 11.6 `upsertNote` semantics

`upsertNote(dateKey, content)` manages only the **primary** note (where `cat_id IS NULL`). If `content.isEmpty` it **deletes** the primary note. This upsert-or-delete pattern is called from `note_page.dart` when the user's text field is saved. Firebase port needs equivalent "write empty = delete" logic.

### 11.7 `_parseSingleItem` has an N+1 database call bug

```dart
Future<ClassificationResult> _parseSingleItem(...) async {
  final validCat = await DatabaseService.instance.getCategories(); // ← called per item
  ...
}
```

This is called once per item in the classification result list. A response with 5 items fires 5 separate `getCategories()` queries. Firebase port should hoist the categories lookup before the loop.

### 11.8 `todayKey()` is defined in `seed_data.dart`, not in a utility file

```dart
String todayKey() {
  final n = DateTime.now();
  return '${n.year}-${fmt2(n.month)}-${fmt2(n.day)}';
}
```
Also `_todayStr()` is duplicated privately in `openai_service.dart`. Both return local-device `YYYY-MM-DD`. Firebase port should centralize this and decide on UTC vs. local.

### 11.9 `Color` serialization

All color values are stored as `color.toARGB32()` (32-bit int) and read back as `Color(r['color'] as int)`. Flutter's `Color.toARGB32()` returns an integer in ARGB format. Firebase would store these as integers (Firestore `int` field) or convert to hex strings — either works but must be consistent.

### 11.10 Missing `list_*` tools referenced in system prompt

The `chat()` system prompt tells the AI to "use `list_todos / list_events / list_ideas / list_notes` tools to get the full list with IDs" but none of these tools are defined in `_chatTools`. The AI cannot call them. This is a functional gap — if the AI tries to call `list_todos`, the tool executor will not recognize the name and the call will fail silently.
