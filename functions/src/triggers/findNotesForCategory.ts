// findNotesForCategory (AI_proxy.md §6). onCreate of a note category. Reads the
// user's notes still on the `undefined` sentinel, asks OpenAI which match the new
// category's label (json_schema → {match_ids}), and reassigns those notes to the
// new category. Only uncategorized notes are touched.
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

import { db, REGION } from "../lib/admin";
import { MODELS, REQ_TIMEOUT, UNDEFINED_CAT } from "../lib/config";
import { createResponse, extractJson } from "../lib/openai";
import { FIND_NOTES_SYSTEM, findNotesUser } from "../lib/prompts";
import { FIND_NOTES_SCHEMA, jsonFormat } from "../lib/schemas";

const GREY = 0xff9a8a7e;

export const findNotesForCategory = onDocumentCreated(
  {
    document: "users/{uid}/note_categories/{catId}",
    region: REGION,
    secrets: ["OPENAI_API_KEY"],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const catId = event.params.catId as string;
    if (catId === UNDEFINED_CAT) return; // the sentinel is never a new category

    const label = ((snap.get("label") as string) ?? "").trim();
    if (!label) return;

    const uid = event.params.uid as string;
    const notesSnap = await db
      .collection(`users/${uid}/notes`)
      .where("category.id", "==", UNDEFINED_CAT)
      .get();
    const undefinedNotes = notesSnap.docs
      .map((d) => ({
        id: d.id,
        content: ((d.get("content") as string) ?? "").trim(),
      }))
      .filter((nNote) => nNote.content.length > 0);
    if (undefinedNotes.length === 0) return;

    try {
      const res = await createResponse(
        {
          model: MODELS.findNotes,
          instructions: FIND_NOTES_SYSTEM,
          input: findNotesUser(label, undefinedNotes),
          temperature: 0.2,
          max_output_tokens: 200,
          text: jsonFormat("match_notes", FIND_NOTES_SCHEMA),
        },
        REQ_TIMEOUT.findNotes
      );
      const parsed = extractJson<{ match_ids?: string[] }>(res.output_text) ?? {};
      const valid = new Set(undefinedNotes.map((nNote) => nNote.id));
      const matchIds = (parsed.match_ids ?? []).filter((id) => valid.has(id));
      if (matchIds.length === 0) return;

      const cat = {
        id: catId,
        label,
        colorVal: (snap.get("colorVal") as number) ?? GREY,
        iconName: (snap.get("iconName") as string) ?? "",
      };
      // Chunk batches ≤500 ops.
      for (let i = 0; i < matchIds.length; i += 450) {
        const batch = db.batch();
        for (const id of matchIds.slice(i, i + 450)) {
          batch.update(db.doc(`users/${uid}/notes/${id}`), { category: cat });
        }
        await batch.commit();
      }
    } catch (err) {
      logger.error("findNotesForCategory failed", err);
    }
  }
);
