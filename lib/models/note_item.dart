import 'package:flutter/material.dart';

class NoteCategory {
  final String id;
  final String label;
  final String iconName; // key into kNoteIconMap in note_page.dart
  final Color color;
  final Color bg;
  final int sortOrder;

  const NoteCategory({
    required this.id,
    required this.label,
    required this.iconName,
    required this.color,
    required this.bg,
    required this.sortOrder,
  });
}

class NoteItem {
  final int id;
  final String dateKey;
  final String content;
  final String? catId; // null = primary date note
  final int updatedAt;

  const NoteItem({
    required this.id,
    required this.dateKey,
    required this.content,
    this.catId,
    required this.updatedAt,
  });
}

enum NoteAttachmentType { image, audio, file }

class NoteAttachment {
  final int id;
  final int noteId;
  final NoteAttachmentType type;
  final String filename;
  final String relPath;
  final String? extracted; // transcript (audio) or extracted text (file/pdf)
  final int createdAt;

  const NoteAttachment({
    required this.id,
    required this.noteId,
    required this.type,
    required this.filename,
    required this.relPath,
    this.extracted,
    required this.createdAt,
  });

  static NoteAttachmentType parseType(String s) => switch (s) {
        'image' => NoteAttachmentType.image,
        'audio' => NoteAttachmentType.audio,
        _       => NoteAttachmentType.file,
      };

  static String typeName(NoteAttachmentType t) => switch (t) {
        NoteAttachmentType.image => 'image',
        NoteAttachmentType.audio => 'audio',
        NoteAttachmentType.file  => 'file',
      };
}
