# Testing Strategy

Minimum viable test surface, runnable in CI against the Firebase Emulator Suite. Test folder mirrors `lib/features/`.

## Layers

1. **Repository tests (emulator-based)** — the priority. For each `firebase_*_repo` (incl. `RecapRepo` and
   `AchievementRepo`), against the Auth/Firestore/Storage emulators: CRUD, stream emissions, `userId` scoping (user A
   cannot read user B), todo `reorder` sort keys, cascade delete (note → attachments
   + `extracted_texts`).
2. **Model serialization tests** — `fromFirestore`/`toJson` round-trips for every model; `ClassificationResult` JSON
   parsing (discriminator + 5 item types).
3. **Cloud Functions tests** (`functions/`):
   - **Callables** — auth-token + App Check rejection, request/response contract, retry/timeout (mock OpenAI), chat
     context-bounding, the server-side tool-call loop + stop conditions (incl. the canned round-limit reply),
     rate-limit `resource-exhausted`, `exportRecap`/`exportAchievement` persist to Storage and write
     `exportStoragePath`/`{era}ExportStoragePath`.
   - **Triggers** (emulator) — `provisionUser` creates the root doc + `settings/app` + default todo/note categories;
     `enrichIdea` sets `aiStatus` processing→completed/error and respects `settings.autoEnrich`; `classifyNote` only
     fires when the note is still the `undefined` note-cat; `findNotesForCategory` retro-assigns matching uncategorized
     notes on note-category create; `categoryFanout` refreshes denormalized copies for the matching item type +
     reassigns to that type's `undefined` sentinel on delete; `storageCascade` removes bytes for notes/recaps/
     achievements; `deleteUserData` wipes `/users/{uid}/**` in Firestore and Storage.
4. **Widget tests** — happy paths: Add overlay (multi-input → classification → routed writes), AI chat tool loop,
   calendar add/edit, todo reorder.
5. **Security-rules tests** — `@firebase/rules-unit-testing`: owner-vs-non-owner allow/deny; `createdAt` immutability;
   the 10 MB Storage cap; and the per-collection restrictions — client cannot write `messages`, cannot set/modify
   `aiSummary`/`aiStatus`/`links` on ideas, `exportStoragePath` on recaps, or `*ExportStoragePath` on achievements, and
   cannot touch `_internal`.

## Minimum bar

All repos covered (CRUD + scoping); `ClassificationResult` parsing covered; every Cloud Function has an
auth-rejection + happy-path test; rules tests for owner isolation, `createdAt` immutability, and the fn-field
restrictions; ≥1 widget test per feature. Coverage target: 60% on `lib/features/**/data` and `functions/src`.

## Tooling

- Flutter: `flutter_test`, `mocktail`/`mockito`; prefer the live emulator for repo tests, `fake_cloud_firestore` only
  for fast pure-logic unit tests.
- Functions: `jest`/`vitest` + `firebase-functions-test`.
- Web: run widget/unit tests headless; emulator-based repo tests are platform-agnostic.
- CI wiring in `DevOps.md`.

e2e/`integration_test` and golden tests are not specified for semi-prod.
