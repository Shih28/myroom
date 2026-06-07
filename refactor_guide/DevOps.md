# DevOps — Environments, Tooling, CI/CD

## Firebase project / environment

**One environment only — `prod`.** (Acknowledged as not ideal; accepted for the semi-production release.)

- `flutterfire configure` against the single project → `firebase_options.dart`.
- `.firebaserc` has the one `default` (prod) alias.
- `firebase.json` wires Firestore rules/indexes, Storage rules, Functions, and the emulator suite.
- Local dev and CI run strictly against the Emulator Suite so they never touch prod data.

## Targets

Android, iOS, Windows, Web (Chrome). No flavors needed; build per platform from the one config.

Verify on web in Phase 1: `record` needs `record_web`; `pdfrx` runs on pdfium-wasm (confirm + check bundle size);
`permission_handler` is browser-prompt-only; `path_provider` is unsupported (no local-file paths should remain).
`url_launcher`, `file_picker`, `lucide_icons_flutter` are web-supported.

## Dependencies & runtime

Flutter app — remove `sqflite`, `sqflite_common_ffi`, `sqflite_common_ffi_web`; keep `record`, `file_picker`, `pdfrx`,
`permission_handler`, `url_launcher`, `lucide_icons_flutter`, `http`; add:

| Package | Purpose |
| --- | --- |
| `firebase_core` | init |
| `firebase_auth` | Auth (E/P + Google) |
| `google_sign_in` | Google provider |
| `cloud_firestore` | data |
| `firebase_storage` | attachments |
| `cloud_functions` | callables |
| `firebase_app_check` | App Check |
| `go_router` | routing |
| `provider` | DI / streams |
| `crypto` | sha256 for content-addressed files |

Pin to the latest mutually-compatible stable at sprint start using the current FlutterFire BoM; commit `pubspec.lock`
and record the Flutter/Dart SDK constraint. No caret drift.

Functions (`functions/`): Node 20, TypeScript, `firebase-functions` v2 (`onCall`/`onWrite`/`onDelete`),
`firebase-admin`, `openai`. Commit `package-lock.json`.

## Local development

Firebase Emulator Suite (Auth + Firestore + Storage + Functions) for all local dev and tests; app connects to
emulators in debug builds.

## Secrets

OpenAI key → Functions Secret Manager (`firebase functions:secrets:set OPENAI_API_KEY`). `lib/config.dart` deleted.

## CI/CD (GitHub Actions)

1. `flutter analyze` + `dart format --set-exit-if-changed`.
2. `flutter test` against the Emulator Suite.
3. Functions: `npm ci && npm run build && npm test` in `functions/`.
4. Deploy on tag → prod: `firebase deploy --only firestore:rules,firestore:indexes,storage,functions` + build the app
   artifacts (Android/iOS/Windows/Web).

## Packaging

- Android: verify `permission_handler` Android 13+ perms; consider split APKs for pdfium size.
- iOS: `Info.plist` usage strings; add Sign in with Apple (Google ships).
- Windows: verify MSIX mic capability for audio.
- Web: Firebase Hosting; register the reCAPTCHA Enterprise App Check site key.
- App Check provider registration per platform (`Security.md`).
