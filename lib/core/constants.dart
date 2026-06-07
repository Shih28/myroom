/// Cloud Functions / Firestore region. Taiwan — Firestore + Functions colocated.
const String kFunctionsRegion = 'asia-east1';

/// Fixed document id of the per-user preferences singleton.
const String kSettingsDocId = 'app';

/// Fixed id of the "無分類" sentinel category (present in both
/// `todo_categories` and `note_categories`; never user-deletable).
const String kUndefinedCategoryId = 'undefined';

/// Default IANA timezone used until the client patches it to the device tz.
const String kDefaultTimezone = 'Asia/Taipei';

/// Max attachment size (bytes) — enforced client-side and in storage.rules.
const int kMaxAttachmentBytes = 10 * 1024 * 1024;
