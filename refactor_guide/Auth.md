# Authentication & User Lifecycle

Firebase Auth, Email/Password + Google (+ Apple on iOS).

## 1. Core

- `AuthRepo` (abstract) → `FirebaseAuthRepo` in `shared/auth/`, provided in the root tier (`StateManagement.md`).
- Owns session + `userId`; every other repo is scoped to `/users/{userId}/...`.
- `authState: Stream<AppUser?>` drives the go_router redirect; `currentUserId` for the synchronous guard check.

```dart
class AppUser {
  final String uid;
  final String email;
  final String? displayName;
}
```

## 2. Sign-in methods

Email/Password + Google, plus **Sign in with Apple** on iOS (App Store rule, since Google ships). Web Google uses
`signInWithPopup`; mobile uses the native flows. Each maps to an `AuthRepo` method — `signIn`, `signUp`,
`signInWithGoogle`, `signInWithApple` (`Repositories.md`).

## 3. Provisioning — `provisionUser` (Auth `onCreate` trigger)

Account data is created server-side via Admin SDK; the client waits for `/users/{uid}` to exist before entering the
shell. `provisionUser` writes:

- `/users/{uid}` root doc: `email`, `createdAt = serverTs`.
- `/users/{uid}/settings/app`: `selfIntro:''`, `rules:''`, `autoEnrich:true`, `tutorialSeen:false`,
  `tz:'Asia/Taipei'`. (The trigger has no device-tz channel; the client patches `tz` to the device timezone via
  `SettingsRepo.updateSettings` right after the shell first loads.)
- Default categories. "Reuse the demo's constants" means reuse the demo's **color palette/theme tokens**, not a 1:1
  label mapping — keep the main color theme coherent. `無分類` uses a neutral grey. `工作`/`個人`/`學業` reuse the
  demo's color (and, for `學業`, note-icon) constants for those same labels.
  - `todo_categories`: `無分類` (id `undefined`, `sortOrder 0`), `工作` (`1`), `個人` (`2`). (Demo's `學習`/`健康`
    are dropped from the defaults.)
  - `note_categories`: `無分類` (id `undefined`, `sortOrder 0`), `學業` (`1`), `社團` (`2`); note categories also
    carry an `iconName`. `學業` reuses the demo's 學業 color + note-icon constant. **`社團` is new** (no demo
    constant): `iconName: 'users'` (lucide; community/club), `colorVal: 0xFF26A69A` (teal) — or the nearest existing
    theme accent token if one is free (e.g. the slot freed by dropping `運動`); the literal is a fallback.
  - The `無分類` sentinel is not user-deletable.
  - **Document ids:** the `無分類` sentinel has fixed id `undefined`; all other default categories get Firestore
    auto-ids (the AI category injection in `AI_proxy.md` passes `{id, label}`, so labels need not be slugs).

## 4. Flows

- **Sign up** — `createUserWithEmailAndPassword` (or Google/Apple) → `provisionUser` → enter shell at `/calendar`
  once the root doc exists.
- **First-run tutorial** — shown when `settings/app.tutorialSeen` is `false`; on dismiss, set it `true` via
  `SettingsRepo`. Port the demo's tutorial-overlay content/steps.
- **Login** — sign in → redirect `/calendar`.
- **Logout** — `AuthRepo.signOut`; user-tier providers unmount and cancel all streams.
- **Password reset** — Firebase `sendPasswordResetEmail` from the login screen.
- **Account deletion** — `AuthRepo.deleteAccount()` re-authenticates first (provider-specific
  `reauthenticateWithCredential`: password for email accounts, the OAuth credential for Google/Apple) and deletes the
  Auth user. The `deleteUserData` Auth `onDelete` trigger (`AI_proxy.md`) then recursively deletes `/users/{uid}/**`
  in Firestore and wipes the `/users/{uid}/**` Storage prefix.

## 5. Settings storage

Preferences live in `users/{uid}/settings/app` (`selfIntro`, `rules`, `autoEnrich`, `tz`, `tutorialSeen`). The
Settings page reads/writes via `SettingsRepo`; AI functions read via Admin SDK.
