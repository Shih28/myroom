import 'package:flutter_test/flutter_test.dart';
import 'package:myroom/features/chat/domain/chat_message.dart';

import '../../../support/firestore_helpers.dart';

void main() {
  group('ChatMessage', () {
    test('fromFirestore reads role/content/createdAt', () async {
      final snap = await snapshotOf({
        'role': 'user',
        'content': '你好',
        'createdAt': ts2026,
      }, id: 'm1');
      final m = ChatMessage.fromFirestore(snap);
      expect(m.id, 'm1');
      expect(m.role, 'user');
      expect(m.content, '你好');
      expect(m.isUser, true);
      expect(m.createdAt, ts2026.toDate());
    });

    test('assistant role is not a user message', () async {
      final snap = await snapshotOf({
        'role': 'assistant',
        'content': '哈囉',
        'createdAt': ts2026,
      });
      final m = ChatMessage.fromFirestore(snap);
      expect(m.isUser, false);
    });

    test('defaults role to assistant when missing', () async {
      final snap = await snapshotOf({'content': 'x'});
      expect(ChatMessage.fromFirestore(snap).role, 'assistant');
    });
  });
}
