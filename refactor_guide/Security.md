# Security Rules, Indexes & App Check

## Firestore rules

Per-collection, owner-only. Function-owned fields/subcollections are written only by Functions via the Admin SDK
(which bypasses rules); clients are blocked from forging them. There is **no permissive `{document=**}` catch-all** —
unmatched paths default to deny, and Firestore ORs matching rules, so a catch-all would defeat the per-collection
restrictions.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {

    function owner(uid) { return request.auth != null && request.auth.uid == uid; }
    function createdAtKept() {
      return resource == null
        || !request.resource.data.diff(resource.data).affectedKeys().hasAny(['createdAt']);
    }
    function notSetting(keys) {                      // client may not create-with / change these fn-only keys
      return resource == null
        ? !request.resource.data.keys().hasAny(keys)
        : !request.resource.data.diff(resource.data).affectedKeys().hasAny(keys);
    }

    match /users/{uid} {
      allow read: if owner(uid);
      allow write: if false;                         // root doc is provisioned by provisionUser (Admin SDK)

      match /settings/{doc}        { allow read, write: if owner(uid); }
      match /_internal/{doc=**}    { allow read, write: if false; }     // rate-limit etc., fn-only

      match /todo_categories/{id}  { allow read, write: if owner(uid); }
      match /note_categories/{id}  { allow read, write: if owner(uid); }

      match /events/{id} {
        allow read, delete: if owner(uid);
        allow create, update: if owner(uid) && createdAtKept();
      }
      match /todos/{id} {
        allow read, delete: if owner(uid);
        allow create, update: if owner(uid) && createdAtKept();
      }

      match /ideas/{document=**} {                   // user_ideas + pinned_resources
        allow read, delete: if owner(uid);
        allow create, update: if owner(uid) && createdAtKept()
          && notSetting(['aiSummary', 'aiStatus', 'links']);
      }

      match /notes/{nid} {
        allow read, delete: if owner(uid);
        allow create, update: if owner(uid) && createdAtKept();
        match /extracted_texts/{aid} { allow read, write: if owner(uid); }
      }

      match /recaps/{id} {
        allow read, delete: if owner(uid);
        allow create, update: if owner(uid) && createdAtKept()
          && notSetting(['exportStoragePath']);                  // written only by exportRecap (Admin SDK)
      }

      match /achievements/{id} {
        allow read, delete: if owner(uid);
        allow create, update: if owner(uid) && createdAtKept()
          && notSetting(['pastExportStoragePath', 'currentExportStoragePath', 'futureExportStoragePath']);
                                                                  // written only by exportAchievement (Admin SDK)
      }

      match /chat_messages/{mid} {
        allow read: if owner(uid);
        allow write: if false;                       // appended only by the chat function (Admin SDK)
      }
    }
  }
}
```

> The denormalized `category` snapshot on `todos`/`notes` is intentionally client-writable (the user picks the
> category); `categoryFanout` re-asserts the correct label on the next category edit.

## Storage rules

Owner-only, plus the 10 MB per-object size cap.

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId
        && request.resource.size < 10 * 1024 * 1024;
    }
  }
}
```

## Composite indexes (`firestore.indexes.json`)

| Collection | Query | Index |
| --- | --- | --- |
| `todos` | order by `sortOrder` | `sortOrder ASC` |
| `notes` | filter `dateKey`, order `createdAt` | `dateKey ASC, createdAt DESC` |
| `notes` | filter `category.id`, order `createdAt` | `category.id ASC, createdAt DESC` |
| `ideas/user_ideas` | order `createdAt`, limit 20 | `createdAt DESC` |
| `ideas/pinned_resources` | order `sortOrder` | `sortOrder ASC` |
| `chat_messages` | order `createdAt`, paginate | `createdAt DESC` |

`events`, `recaps`, and `achievements` need no entry — each is a single-field order/range (`startTime` / `createdAt`),
which is automatic. Confirm the composite set via emulator "index required" errors in Phase 1.

## App Check

Enforce on Firestore, Storage, and callable Functions:

- Android → Play Integrity; iOS → App Attest; Web (Chrome) → reCAPTCHA Enterprise.
- Windows: no official provider → use the debug provider, kept inside the enforced set.

## Stream scoping

Never stream whole collections where a windowed/filtered query suffices — calendar streams the visible range, ideas
the latest 20, chat the last N messages.
