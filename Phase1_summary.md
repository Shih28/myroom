What Phase 1 did — "Core repos & feature port"

Every feature now runs on Firestore (domain model + abstract repo + FirebaseXRepo + page rebound to streams), with the entire SQLite layer deleted:

| Feature  | Key changes |
| --- | --- |
| Calendar | CalendarEvent now uses real DateTime start/endTime (was 6 int columns); month/week/day views + time picker on EventRepo streams |
| Todo | {isCompleted, sortOrder, embedded category}; drag-reorder via batched sortOrder; priority selector cut; todo_categories CRUD|
| Ideas| client writes only text (aiSummary/aiStatus/links are fn-only); Explore recommendations stubbed (Phase 2); pinned-resources CRUD|
| Notes| no more "primary note" bypass — every note is an ordinary doc; date + category modes; attachments upload via StorageRepo (sha256 paths); auto-classify deferred (defaults to 無分類) |
| Recap| rewritten to recaps + achievements collections (recap_items/era-images/DALL-E dropped); 3 editable era blocks + recap CRUD  |
| Chat | read-only ChatRepo stream (sending is Phase 2 / fn-only writes) |

Shared + infra: StorageRepo/FirebaseStorageRepo; ported MrCard/MrAddRow; all user-scoped repos wired into authenticated_scope; storageCascade Cloud Function
(onDelete cleanup of note attachments + extracted_texts, recap/achievement exports); pruned sqflite*/path/http from pubspec.

Verification: flutter analyze → No issues found; flutter test → green; tsc build clean. Repos audited against the data model and security rules (no createdAt
on update, fn-only fields excluded, exact field names/paths).

Notes & decisions for you

- Data-model ambiguity I resolved: user_ideas/pinned_resources can't both sit directly under ideas (Firestore needs an intervening doc), so they live at
users/{uid}/ideas/data/{…} — covered by the existing match /ideas/{document=**} rule. The Phase 2 enrichIdea trigger must target this same path.
- Not yet runtime-verified on a device: I can't launch the app — lib/firebase_options.dart is still the Phase 0 placeholder (needs flutterfire configure), and
a live project/emulator is required. Static checks pass, but a smoke run is the natural next check.
- Minor: the notes page opens one extra listener per category for count badges (fine for now); notes queries rely on the two composite indexes already in
firestore.indexes.json.