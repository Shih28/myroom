// categoryFanout (DataModel.md "Denormalization upkeep", AI_proxy.md §6). Keeps
// the embedded category snapshot on items fresh so the client never fans out.
//   • onWrite todo_categories/{id} → fan out to todos {id,label,colorVal}
//   • onWrite note_categories/{id} → fan out to notes {id,label,colorVal,iconName}
//   • update → refresh the snapshot on every item whose category.id matches
//   • delete → reassign matching items to that type's `undefined` sentinel
// Batches are chunked ≤500 ops. Fan-out writes items (not categories), so it
// never re-triggers itself.
import {
  Change,
  DocumentSnapshot,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

import { db, REGION } from "../lib/admin";
import { UNDEFINED_CAT } from "../lib/config";

const GREY = 0xff9a8a7e;

type Kind = "todo" | "note";

function snapshotFor(
  kind: Kind,
  catId: string,
  doc: DocumentSnapshot
): Record<string, unknown> {
  const base = {
    id: catId,
    label: (doc.get("label") as string) ?? "",
    colorVal: (doc.get("colorVal") as number) ?? GREY,
  };
  if (kind === "note") {
    return { ...base, iconName: (doc.get("iconName") as string) ?? "" };
  }
  return base;
}

async function undefinedSnapshot(
  uid: string,
  kind: Kind
): Promise<Record<string, unknown>> {
  const col = kind === "todo" ? "todo_categories" : "note_categories";
  const snap = await db.doc(`users/${uid}/${col}/${UNDEFINED_CAT}`).get();
  const label = (snap.get("label") as string) ?? "無分類";
  const colorVal = (snap.get("colorVal") as number) ?? GREY;
  if (kind === "note") {
    return {
      id: UNDEFINED_CAT,
      label,
      colorVal,
      iconName: (snap.get("iconName") as string) ?? "tag",
    };
  }
  return { id: UNDEFINED_CAT, label, colorVal };
}

/** True when none of the snapshot-relevant fields changed (skip needless writes). */
function snapshotUnchanged(kind: Kind, change: Change<DocumentSnapshot>): boolean {
  const b = change.before;
  const a = change.after;
  if (!b.exists || !a.exists) return false;
  const same =
    b.get("label") === a.get("label") && b.get("colorVal") === a.get("colorVal");
  if (kind === "todo") return same;
  return same && b.get("iconName") === a.get("iconName");
}

async function fanout(
  kind: Kind,
  uid: string,
  catId: string,
  change: Change<DocumentSnapshot> | undefined
): Promise<void> {
  if (!change) return;
  // The sentinel itself is never fanned out (it is not user-editable/deletable
  // in a meaningful way, and reassigning to self on delete is moot).
  if (catId === UNDEFINED_CAT) return;

  const created = !change.before.exists && change.after.exists;
  if (created) return; // a brand-new category has no items referencing it yet
  if (change.after.exists && snapshotUnchanged(kind, change)) return;

  const snapshot = change.after.exists
    ? snapshotFor(kind, catId, change.after)
    : await undefinedSnapshot(uid, kind);

  const itemsCol = kind === "todo" ? "todos" : "notes";
  const matching = await db
    .collection(`users/${uid}/${itemsCol}`)
    .where("category.id", "==", catId)
    .get();
  if (matching.empty) return;

  const docs = matching.docs;
  for (let i = 0; i < docs.length; i += 450) {
    const batch = db.batch();
    for (const d of docs.slice(i, i + 450)) {
      batch.update(d.ref, { category: snapshot });
    }
    await batch.commit();
  }
  logger.info(
    `categoryFanout(${kind}): ${change.after.exists ? "refreshed" : "reassigned"} ${docs.length} item(s) for ${catId}`
  );
}

export const categoryFanoutTodo = onDocumentWritten(
  { document: "users/{uid}/todo_categories/{catId}", region: REGION },
  (event) =>
    fanout("todo", event.params.uid as string, event.params.catId as string, event.data)
);

export const categoryFanoutNote = onDocumentWritten(
  { document: "users/{uid}/note_categories/{catId}", region: REGION },
  (event) =>
    fanout("note", event.params.uid as string, event.params.catId as string, event.data)
);
