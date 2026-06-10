import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/app_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/ai/domain/ai_service.dart';
import '../domain/chat_message.dart';
import '../domain/chat_repo.dart';

/// AI Chat overlay — a pushed full-screen route (owns its own [Scaffold]).
///
/// Phase 1 is READ-ONLY over Firestore: it streams the latest messages from
/// [ChatRepo.watchMessages] and renders them as bubbles. Sending is Phase 2
/// (a server-side Cloud Function appends messages); the input stays visible but
/// submitting only shows a "coming soon" notice and never writes to Firestore.
class ChatOverlay extends StatelessWidget {
  const ChatOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamProvider<List<ChatMessage>>(
      create: (c) => c.read<ChatRepo>().watchMessages(),
      initialData: const [],
      catchError: (c, e) {
        AppErrors.present(e);
        return const <ChatMessage>[];
      },
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  // Pagination: older history paged in via [ChatRepo.loadOlder] and kept in
  // local state, merged with the live tail stream (DataModel.md §Pagination).
  final List<ChatMessage> _older = [];
  bool _loadingOlder = false;
  bool _hasMore = true;
  String? _newestId; // tail's newest message — drives autoscroll

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Pages in the 50 messages older than [cursor] (the oldest one shown).
  Future<void> _loadOlder(ChatMessage cursor) async {
    if (_loadingOlder || !_hasMore) return;
    setState(() => _loadingOlder = true);
    final older = await context.read<ChatRepo>().loadOlder(cursor);
    if (!mounted) return;
    setState(() {
      _loadingOlder = false;
      if (older.length < ChatRepo.pageSize) _hasMore = false;
      _older.addAll(older);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Sends the message through the `chat` Cloud Function. The function appends
  /// the user turn (shown immediately via the stream) and the assistant reply;
  /// while we await, a typing indicator shows and the input is disabled.
  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    _inputCtrl.clear();
    setState(() => _sending = true);
    await context.read<AiService>().chat(text);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final tail = context.watch<List<ChatMessage>>();
    // Merge paged-in history with the live tail; dedupe by id; sort oldest→newest.
    final byId = <String, ChatMessage>{for (final m in _older) m.id: m};
    for (final m in tail) {
      byId[m.id] = m;
    }
    final messages = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Autoscroll only when a new newest message arrives or we begin sending —
    // never when older history is prepended.
    final newestId = messages.isNotEmpty ? messages.last.id : null;
    if (_sending || newestId != _newestId) {
      _newestId = newestId;
      _scrollToBottom();
    }

    // Only offer "load more" once a full tail page is shown (so there might be
    // more) or history has already been paged in.
    final showLoadMore =
        _hasMore &&
        messages.isNotEmpty &&
        (tail.length >= ChatRepo.pageSize || _older.isNotEmpty);
    final headerCount = showLoadMore ? 1 : 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.dark,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.sparkles,
                      size: 17,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask AI',
                        style: AppText.body(size: 15, weight: FontWeight.w600),
                      ),
                      Text('你的個人助理', style: AppText.caption(size: 11)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.x,
                        size: 16,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: messages.isEmpty && !_sending
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      itemCount:
                          headerCount + messages.length + (_sending ? 1 : 0),
                      itemBuilder: (_, idx) {
                        if (showLoadMore && idx == 0) {
                          return _LoadMoreButton(
                            loading: _loadingOlder,
                            onTap: () => _loadOlder(messages.first),
                          );
                        }
                        final mIdx = idx - headerCount;
                        return mIdx < messages.length
                            ? _Bubble(message: messages[mIdx])
                            : const _TypingBubble();
                      },
                    ),
            ),

            // Input row
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: '輸入訊息...',
                        hintStyle: AppText.body(color: AppColors.muted),
                        border: InputBorder.none,
                      ),
                      style: AppText.body(size: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _sending
                            ? AppColors.dark.withOpacity(0.5)
                            : AppColors.dark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              LucideIcons.send,
                              size: 15,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                LucideIcons.sparkles,
                size: 24,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '你好！我是你的個人助理',
              textAlign: TextAlign.center,
              style: AppText.body(size: 15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '你可以問我今天的優先事項、週計畫，或讓我幫你整理靈感。',
              textAlign: TextAlign.center,
              style: AppText.body(
                size: 13,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-of-thread affordance to page in older messages (chat pagination).
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.muted,
                ),
              )
            : GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '載入更多訊息',
                    style: AppText.caption(size: 12, color: AppColors.muted),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Shown at the tail of the thread while the `chat` function is running.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [kCardShadow],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '思考中…',
                  style: AppText.body(size: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.dark : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: const [kCardShadow],
              ),
              child: Text(
                message.content,
                style: AppText.body(
                  size: 13,
                  color: isUser ? Colors.white : AppColors.dark,
                  height: 1.65,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
