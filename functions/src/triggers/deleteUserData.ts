import * as functionsV1 from "firebase-functions/v1";

import { db, storage } from "../lib/admin";

// Auth `onDelete` trigger (classic v1). Fired when `AuthRepo.deleteAccount()`
// deletes the Auth user. Recursively deletes /users/{uid}/** in Firestore and
// wipes the /users/{uid}/** Storage prefix (Auth.md §4, AI_proxy.md §6).
export const deleteUserData = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;

  // Firestore: recursive delete of the user document subtree.
  const userRef = db.collection("users").doc(uid);
  await db.recursiveDelete(userRef);

  // Storage: wipe everything under users/{uid}/.
  try {
    await storage.bucket().deleteFiles({ prefix: `users/${uid}/` });
  } catch (err) {
    console.error(`Storage cleanup failed for ${uid}:`, err);
  }
});
