import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_message.dart';

/// Single flat `chat_messages` thread (no sessions). The client only reads;
/// messages are appended server-side by the chat Cloud Function (Phase 2).
abstract class ChatRepo {
  /// Streams the latest messages in chronological order (oldest → newest).
  Stream<List<ChatMessage>> watchMessages();

  /// One-shot fetch of the page of messages older than [cursor], returned in
  /// chronological order (oldest → newest) for prepending in the UI.
  Future<List<ChatMessage>> loadOlder(
    DocumentSnapshot<Map<String, dynamic>> cursor,
  );
}
