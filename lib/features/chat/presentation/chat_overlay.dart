import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/app_errors.dart';
import '../../../core/theme/app_theme.dart';
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

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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

  /// Phase 1: sending is disabled (messages are written server-side in Phase 2).
  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'AI 助理即將推出',
            style: AppText.body(size: 13, color: Colors.white),
          ),
          backgroundColor: AppColors.dark,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<List<ChatMessage>>();
    if (messages.isNotEmpty) _scrollToBottom();

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
                    child: const Icon(LucideIcons.sparkles,
                        size: 17, color: AppColors.amber),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ask AI',
                          style: AppText.body(size: 15, weight: FontWeight.w600)),
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
                      child: const Icon(LucideIcons.x,
                          size: 16, color: AppColors.dark),
                    ),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      itemCount: messages.length,
                      itemBuilder: (_, idx) => _Bubble(message: messages[idx]),
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
                    onTap: _send,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.send,
                          size: 15, color: Colors.white),
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
              child: const Icon(LucideIcons.sparkles,
                  size: 24, color: AppColors.amber),
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
              style: AppText.body(size: 13, color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 6),
            Text(
              'AI 助理即將推出',
              textAlign: TextAlign.center,
              style: AppText.caption(size: 11),
            ),
          ],
        ),
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
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
