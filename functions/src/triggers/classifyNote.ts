// classifyNote (AI_proxy.md §6). onWrite of a note. If the note's category is
// still the `undefined` sentinel and content is non-empty, classify it from the
// user's note_categories (injected as {id,label}; model returns an id we
// validate). Writing a non-undefined category back makes the re-trigger a no-op,
// so there is no loop.
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

import { REGION } from "../lib/admin";
import {
  findNoteCat,
  loadNoteCats,
  toOptions,
  validateCatId,
} from "../lib/categories";
import { MODELS, REQ_TIMEOUT, UNDEFINED_CAT } from "../lib/config";
import { createResponse, extractJson } from "../lib/openai";
import { CLASSIFY_NOTE_SYSTEM, classifyNoteUser } from "../lib/prompts";
import { CLASSIFY_NOTE_SCHEMA, jsonFormat } from "../lib/schemas";

export const classifyNote = onDocumentWritten(
  {
    document: "users/{uid}/notes/{noteId}",
    region: REGION,
    secrets: ["OPENAI_API_KEY"],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) return; // deleted

    const data = after.data() ?? {};
    const category = data.category as { id?: string } | undefined;
    const catId = category?.id ?? UNDEFINED_CAT;
    const content = ((data.content as string) ?? "").trim();
    if (catId !== UNDEFINED_CAT || !content) return;

    const uid = event.params.uid as string;
    const noteCats = await loadNoteCats(uid);

    try {
      const res = await createResponse(
        {
          model: MODELS.noteClassify,
          instructions: CLASSIFY_NOTE_SYSTEM,
          input: classifyNoteUser(toOptions(noteCats), content),
          temperature: 0.2,
          max_output_tokens: 50,
          text: jsonFormat("note_category", CLASSIFY_NOTE_SCHEMA),
        },
        REQ_TIMEOUT.noteClassify
      );
      const parsed = extractJson<{ cat_id?: string }>(res.output_text) ?? {};
      const chosen = validateCatId(parsed.cat_id, noteCats);
      if (chosen === UNDEFINED_CAT) return; // no suitable category → leave as-is

      const cat = findNoteCat(chosen, noteCats);
      await after.ref.update({
        category: {
          id: cat.id,
          label: cat.label,
          colorVal: cat.colorVal,
          iconName: cat.iconName,
        },
      });
    } catch (err) {
      logger.error("classifyNote failed", err);
    }
  }
);
