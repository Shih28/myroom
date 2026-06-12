import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

import { db, storage, REGION } from "../lib/admin";

// Cascade cleanup of Firebase Storage when a content document is deleted
// (Storage.md §5). Firestore deletes do not touch Storage or subcollections, so
// these onDelete triggers remove the orphaned bytes (and, for notes, the
// `extracted_texts` subcollection).

/** Best-effort delete of a list of Storage object paths. */
async function deleteStoragePaths(paths: string[]): Promise<void> {
  const bucket = storage.bucket();
  await Promise.all(
    paths
      .filter((p): p is string => typeof p === "string" && p.length > 0)
      .map(async (path) => {
        try {
          await bucket.file(path).delete();
        } catch (err) {
          // Missing object (already gone) or transient error — log and move on.
          logger.warn(`storageCascade: failed to delete ${path}`, err);
        }
      })
  );
}

// notes/{id} delete → delete each attachments[].storagePath + the
// `extracted_texts` subcollection.
export const storageCascadeNote = onDocumentDeleted(
  { document: "users/{uid}/notes/{noteId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();

    const attachments = (data.attachments as Array<Record<string, unknown>>) ?? [];
    const paths = attachments
      .map((a) => a.storagePath)
      .filter((p): p is string => typeof p === "string");
    await deleteStoragePaths(paths);

    // Subcollection docs are not auto-deleted with their parent.
    await db.recursiveDelete(snap.ref.collection("extracted_texts"));
  }
);

// recaps/{id} delete → delete exportStoragePath.
export const storageCascadeRecap = onDocumentDeleted(
  { document: "users/{uid}/recaps/{recapId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    await deleteStoragePaths([data.exportStoragePath as string]);
  }
);

// achievements/{id} delete → delete the three era export paths.
export const storageCascadeAchievement = onDocumentDeleted(
  { document: "users/{uid}/achievements/{achievementId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    await deleteStoragePaths([
      data.pastExportStoragePath as string,
      data.currentExportStoragePath as string,
      data.futureExportStoragePath as string,
    ]);
  }
);
