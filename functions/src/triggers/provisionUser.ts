import * as functionsV1 from "firebase-functions/v1";
import { FieldValue } from "firebase-admin/firestore";

import { db } from "../lib/admin";
import {
  DEFAULT_NOTE_CATEGORIES,
  DEFAULT_TODO_CATEGORIES,
} from "../lib/defaultCategories";

// Auth `onCreate` trigger (classic v1 — Cloud Functions v2 has no native
// Auth onCreate). Region is project-global for Auth events; Firestore writes
// still land in the project's configured location regardless.
//
// Provisions a new user's root doc, settings singleton, and default
// todo/note categories (Auth.md §3). The client waits for /users/{uid} to
// exist before entering the shell.
export const provisionUser = functionsV1.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const userRef = db.collection("users").doc(uid);

  const batch = db.batch();

  batch.set(userRef, {
    email: user.email ?? "",
    createdAt: FieldValue.serverTimestamp(),
  });

  batch.set(userRef.collection("settings").doc("app"), {
    selfIntro: "",
    rules: "",
    autoEnrich: true,
    tz: "Asia/Taipei",
    tutorialSeen: false,
  });

  for (const cat of DEFAULT_TODO_CATEGORIES) {
    const ref = cat.id
      ? userRef.collection("todo_categories").doc(cat.id)
      : userRef.collection("todo_categories").doc();
    batch.set(ref, {
      label: cat.label,
      colorVal: cat.colorVal,
      sortOrder: cat.sortOrder,
    });
  }

  for (const cat of DEFAULT_NOTE_CATEGORIES) {
    const ref = cat.id
      ? userRef.collection("note_categories").doc(cat.id)
      : userRef.collection("note_categories").doc();
    batch.set(ref, {
      label: cat.label,
      colorVal: cat.colorVal,
      iconName: cat.iconName,
      sortOrder: cat.sortOrder,
    });
  }

  await batch.commit();
});
