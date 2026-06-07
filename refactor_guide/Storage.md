# Firebase Storage & Attachments

## 1. Layout

- Binary files (note images/audio/files, recap/achievement export assets) live in Firebase Storage under
  `/users/{userId}/...`. `StorageRepo` (abstract) → `FirebaseStorageRepo` in `shared/storage/`.
- Firestore stores metadata only, never bytes:
  - `notes.attachments[]` = `{ type, filename, storagePath }` (`type` ∈ `image|audio|file`, writer: client — set
    from the file's MIME/extension at upload time). No `url` field — the download URL is resolved on demand from
    `storagePath`.
  - Extracted text (PDF/audio transcripts) → `notes/{id}/extracted_texts/{attId}` (`filename`, `summary`).
  - `recaps.exportStoragePath` and `achievements.{past,current,future}ExportStoragePath` = a `storagePath`.

## 2. Path convention

Attachments are content-addressed; exports are deterministic per recap/era.

```
/users/{uid}/notes/{noteId}/{sha256(bytes)}.{ext}
/users/{uid}/recaps/{recapId}/export.{ext}
/users/{uid}/achievements/{achievementId}/{era}_export.{ext}    # era ∈ past|current|future
```
Store the resulting `storagePath` in the Firestore metadata.

## 3. StorageRepo surface

- `Future<Result<UploadedFile>> upload({uid, path, bytes, contentType})` → `{ storagePath, downloadUrl }`.
- `Future<Result<void>> delete(storagePath)`.
- `Future<Uint8List> download(storagePath)`.

Authenticated downloads (not public): the UI calls `ref(storagePath).getDownloadURL()` on demand and caches it in
widget state for the session. Do not store URLs in Firestore. The `downloadUrl` returned by `upload` is a convenience
for immediate in-session preview of the just-uploaded file; it is not persisted, and later reads use the on-demand
`getDownloadURL()` path.

## 4. Attachment write flow (Smart Add)

One canonical flow for all attachment types. Nothing is uploaded until classification routes an attachment to a note.

1. **In memory, before classification:** audio → `transcribe` callable → transcript; PDF → `pdfrx` (web: pdfium-wasm)
   → text. Concatenate as `fileText`. Images are base64-encoded.
2. Call `classifyMultiInput` with `text` + base64 images + `fileText` + the attachment manifest.
3. **For each attachment routed to a note** (via `attachment_indices`): hash the bytes (`sha256`) — this hash is the
   single id used three ways: it is the Storage filename (`{sha256}.{ext}`, §2), the attachment entry's `attId`, and the
   `extracted_texts` doc id. `StorageRepo.upload` → `storagePath`, write the note's `attachments[]` entry
   `{type, filename, storagePath, attId: sha256}`, and write the transcript/PDF text to that note's
   `extracted_texts/{attId}` (audio/file only — images have no transcript).
4. **Attachments not routed to a note** (classified as todo/idea/event, or unmatched) are discarded — never uploaded,
   no `extracted_texts` written, no orphans. (Attachments belong only to notes.)
5. `storageCascade` (`onDelete`) removes the bytes + `extracted_texts` when the note is later deleted.

## 5. Cascade cleanup — Cloud Function `onDelete`

- On `notes/{id}` delete → delete each `attachments[].storagePath` + the `extracted_texts` subcollection.
- On `recaps/{id}` delete → delete `exportStoragePath`.
- On `achievements/{id}` delete → delete `pastExportStoragePath` / `currentExportStoragePath` / `futureExportStoragePath`.
- Note-category delete does not touch Storage: `categoryFanout` reassigns the notes to `無分類`, so nothing is orphaned.

## 6. Recap & achievement exports

Recaps and achievements have **no inline image asset** — their visual deliverable is the optional exported
PDF/graphic. `content` is plain text (user-written or an AI summary from `generateEraInsight`, written by the client).

- `exportRecap` (`AI_proxy.md`) renders a recap's title + content to a PDF/graphic, uploads to
  `/users/{uid}/recaps/{recapId}/export.{ext}`, and writes `exportStoragePath`.
- `exportAchievement` renders one era (`past`/`current`/`future`) to a PDF/graphic, uploads to
  `/users/{uid}/achievements/{achievementId}/{era}_export.{ext}`, and writes the matching `{era}ExportStoragePath`.

## 7. Size limit

10 MB max per attachment, enforced in both the client pre-check and `storage.rules` (`Security.md`).

## 8. Platform notes

- iOS: `NSMicrophoneUsageDescription` + `NSDocumentsFolderUsageDescription` in `Info.plist`.
- Android: `RECORD_AUDIO`.
- Web (Chrome): uploads use in-memory bytes (`putData`). Mic capture needs `record_web`; PDF text extraction runs on
  pdfium-wasm — verify both in Phase 1.
- Windows: MSIX mic capability for audio.
