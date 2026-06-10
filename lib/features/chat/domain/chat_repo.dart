import 'chat_message.dart';

/// Single flat `chat_messages` thread (no sessions). The client only reads;
/// messages are appended server-side by the chat Cloud Function (Phase 2).
abstract class ChatRepo {
  /// Page size for both the live tail and each [loadOlder] page.
  static const int pageSize = 50;

  /// Streams the latest [pageSize] messages in chronological order
  /// (oldest → newest).
  Stream<List<ChatMessage>> watchMessages();

  /// One-shot fetch of the page of messages immediately older than [cursor]
  /// (the oldest message currently displayed), returned in chronological order
  /// (oldest → newest) for prepending in the UI. Empty once the start of the
  /// thread has been reached.
  Future<List<ChatMessage>> loadOlder(ChatMessage cursor);
}
