import 'dart:typed_data';

import '../../core/result.dart';

/// Result of an upload — the persisted [storagePath] (saved into Firestore
/// metadata) plus a convenience [downloadUrl] for immediate in-session preview.
/// The URL is **not** persisted; later reads resolve a fresh URL on demand via
/// [StorageRepo.downloadUrl] (Storage.md §3).
class UploadedFile {
  final String storagePath;
  final String downloadUrl;
  const UploadedFile({required this.storagePath, required this.downloadUrl});
}

/// Firebase Storage surface (Storage.md §3). Binaries live under
/// `/users/{uid}/...`; Firestore stores only the `storagePath`.
abstract class StorageRepo {
  /// Uploads [bytes] to [path] (the full bucket-relative path, e.g.
  /// `users/{uid}/notes/{noteId}/{sha256}.{ext}`) and returns the stored path +
  /// a one-shot download URL. [uid] is the owner (already embedded in [path]).
  Future<Result<UploadedFile>> upload({
    required String uid,
    required String path,
    required Uint8List bytes,
    required String contentType,
  });

  /// Deletes the object at [storagePath].
  Future<Result<void>> delete(String storagePath);

  /// Downloads the raw bytes at [storagePath].
  Future<Uint8List> download(String storagePath);

  /// Resolves a fresh authenticated download URL for [storagePath] (cached in
  /// widget state by the caller for the session).
  Future<String> downloadUrl(String storagePath);
}
