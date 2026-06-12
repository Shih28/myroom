import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../core/app_errors.dart';
import '../../core/constants.dart';
import '../../core/firebase_failure.dart';
import '../../core/result.dart';
import 'storage_repo.dart';

class FirebaseStorageRepo implements StorageRepo {
  FirebaseStorageRepo(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<Result<UploadedFile>> upload({
    required String uid,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final ref = _storage.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      final url = await ref.getDownloadURL();
      return Ok(UploadedFile(storagePath: path, downloadUrl: url));
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }

  @override
  Future<Result<void>> delete(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
      return const Ok(null);
    } catch (e) {
      final f = mapFirebase(e);
      AppErrors.present(f);
      return Err(f);
    }
  }

  @override
  Future<Uint8List> download(String storagePath) async {
    final data = await _storage.ref(storagePath).getData(kMaxAttachmentBytes);
    return data ?? Uint8List(0);
  }

  @override
  Future<String> downloadUrl(String storagePath) =>
      _storage.ref(storagePath).getDownloadURL();
}
