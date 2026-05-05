import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Stores note attachment binaries on disk under
/// `<appDocs>/note_attachments/`. Only the relative path is persisted in
/// SQLite (`note_attachments.rel_path`); the absolute path is resolved at
/// read time so the data survives app moves.
///
/// Web is not supported — `path_provider` has no app-documents concept on
/// web, so callers must gate attachment features on `!kIsWeb`.
class AttachmentStorage {
  AttachmentStorage._();
  static final AttachmentStorage instance = AttachmentStorage._();

  static const _folderName = 'note_attachments';
  final _rng = Random();

  Future<Directory> _folder() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/$_folderName');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  /// Writes [bytes] under a unique filename with [ext] (no leading dot) and
  /// returns the path relative to the app documents directory.
  Future<String> save(Uint8List bytes, String ext) async {
    if (kIsWeb) throw UnsupportedError('AttachmentStorage is not supported on web');
    final folder = await _folder();
    final cleanExt = ext.startsWith('.') ? ext.substring(1) : ext;
    final name = '${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(1 << 32)}'
        '${cleanExt.isEmpty ? '' : '.$cleanExt'}';
    final file = File('${folder.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return '$_folderName/$name';
  }

  /// Resolves [relPath] (as returned by [save]) to an absolute [File].
  Future<File> file(String relPath) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$relPath');
  }

  /// Best-effort delete. Missing files are ignored.
  Future<void> delete(String relPath) async {
    try {
      final f = await file(relPath);
      if (await f.exists()) await f.delete();
    } catch (_) {/* ignore */}
  }
}
