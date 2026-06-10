import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/chat_message.dart';
import '../domain/chat_repo.dart';

class FirebaseChatRepo implements ChatRepo {
  FirebaseChatRepo(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('chat_messages');

  @override
  Stream<List<ChatMessage>> watchMessages() => _col
      .orderBy('createdAt', descending: true)
      .limit(ChatRepo.pageSize)
      .snapshots()
      .map(
        (s) => s.docs.map(ChatMessage.fromFirestore).toList().reversed.toList(),
      );

  @override
  Future<List<ChatMessage>> loadOlder(ChatMessage cursor) async {
    // Page strictly after the cursor doc (the oldest one displayed). Using the
    // doc snapshot as the cursor is collision-proof vs. a raw timestamp; if the
    // cursor was deleted, fall back to its createdAt value.
    final cursorDoc = await _col.doc(cursor.id).get();
    var q = _col.orderBy('createdAt', descending: true);
    q = cursorDoc.exists
        ? q.startAfterDocument(cursorDoc)
        : q.startAfter([Timestamp.fromDate(cursor.createdAt)]);
    final snap = await q.limit(ChatRepo.pageSize).get();
    return snap.docs.map(ChatMessage.fromFirestore).toList().reversed.toList();
  }
}
