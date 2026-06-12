import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/recaps/{id}` — a single titled review (e.g. "June with so many
/// joy"). `exportStoragePath` is fn-written (`exportRecap`); the client never
/// writes it.
class Recap {
  final String id;
  final String title;
  final String content;

  /// fn-written (`exportRecap`) — read-only on the client.
  final String? exportStoragePath;
  final DateTime createdAt;

  Recap({
    required this.id,
    required this.title,
    this.content = '',
    this.exportStoragePath,
    required this.createdAt,
  });

  factory Recap.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Recap(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      content: (d['content'] as String?) ?? '',
      exportStoragePath: d['exportStoragePath'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Client-writable data fields only. No `createdAt` (repo injects it) and no
  /// `exportStoragePath` (fn-only).
  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
      };
}
