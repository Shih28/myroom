import 'package:cloud_firestore/cloud_firestore.dart';

/// A single message in the user's flat `chat_messages` thread.
///
/// Clients never write `chat_messages` (the chat Cloud Function appends both the
/// user and assistant turns via the Admin SDK), so this model is read-only and
/// has no `toJson`.
class ChatMessage {
  final String id;

  /// One of `user`, `assistant`, `system`.
  final String role;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const {};
    return ChatMessage(
      id: doc.id,
      role: (d['role'] as String?) ?? 'assistant',
      content: (d['content'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
