import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../models/idea.dart';
import '../models/ai_resource.dart';
import '../services/openai_service.dart';
import '../services/database_service.dart';
import '../widgets/mr_card.dart';
import '../widgets/mr_icon_button.dart';

enum IdeaSub { input, explore }

class IdeaPage extends StatefulWidget {
  final List<Idea> ideas;
  final Future<void> Function(String) onIdeaAdded;
  final Future<void> Function(int id) onIdeaDeleted;
  final Future<void> Function(int id, String text) onIdeaEdited;

  const IdeaPage({
    super.key,
    required this.ideas,
    required this.onIdeaAdded,
    required this.onIdeaDeleted,
    required this.onIdeaEdited,
  });

  @override
  State<IdeaPage> createState() => _IdeaPageState();
}

class _IdeaPageState extends State<IdeaPage> {
  IdeaSub _sub = IdeaSub.input;
  final _draftCtrl = TextEditingController();
  bool _adding = false;
  final Set<int> _expandedIds = {};

  List<AiResource>? _resources;
  bool _loadingResources = false;
  List<AiResource> _pinnedResources = [];

  @override
  void initState() {
    super.initState();
    _loadPinnedResources();
    if (widget.ideas.isNotEmpty) _loadResources();
  }

  @override
  void didUpdateWidget(IdeaPage old) {
    super.didUpdateWidget(old);
    if (_resources == null && widget.ideas.isNotEmpty) _loadResources();
  }

  @override
  void dispose() {
    _draftCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _addIdea() async {
    if (_draftCtrl.text.isEmpty || _adding) return;
    final text = _draftCtrl.text;
    _draftCtrl.clear();
    setState(() => _adding = true);
    try {
      await widget.onIdeaAdded(text);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteIdea(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('刪除靈感', style: AppText.body(size: 16, weight: FontWeight.w600)),
        content: Text(
          '確定刪除這份靈感？',
          style: AppText.body(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: AppText.body(size: 14, color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '刪除',
              style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.rose),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _expandedIds.remove(id));
      await widget.onIdeaDeleted(id);
    }
  }

  Future<void> _editIdea(Idea idea) async {
    final ctrl = TextEditingController(text: idea.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('編輯靈感', style: AppText.body(size: 16, weight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '更新你的靈感內容...',
            hintStyle: AppText.body(color: AppColors.muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.dark),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          style: AppText.body(size: 14, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: AppText.body(size: 14, color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx, t);
            },
            child: Text(
              '儲存',
              style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.dark),
            ),
          ),
        ],
      ),
    );
    if (newText != null && newText != idea.text) {
      await widget.onIdeaEdited(idea.id, newText);
    }
  }

  Future<void> _loadResources() async {
    if (_loadingResources) return;
    setState(() => _loadingResources = true);
    final texts = widget.ideas.take(5).map((i) => i.text).toList();
    final result = await OpenAIService.instance.fetchRecommendations(texts);
    if (mounted) setState(() { _resources = result; _loadingResources = false; });
  }

  Future<void> _loadPinnedResources() async {
    final pinned = await DatabaseService.instance.getPinnedResources();
    if (mounted) setState(() => _pinnedResources = pinned);
  }

  Future<void> _togglePin(AiResource r) async {
    final isPinned = _pinnedResources.any((p) => p.url == r.url);
    if (isPinned) {
      await DatabaseService.instance.unpinResource(r.url);
    } else {
      await DatabaseService.instance.pinResource(r);
    }
    await _loadPinnedResources();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Color _typeColor(String type) => switch (type) {
    '書籍' => AppColors.sage,
    '文章' => AppColors.blue,
    '工具' => AppColors.amber,
    '課程' => AppColors.rose,
    _      => AppColors.muted,
  };

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: IdeaSub.values.map((s) {
                final active = _sub == s;
                final labels = ['✦  記錄靈感', '⊹  探索資源'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _sub = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.dark : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          labels[s.index],
                          style: AppText.body(
                            size: 13,
                            weight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? Colors.white : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: _sub == IdeaSub.input ? _buildInput() : _buildExplore(),
        ),
      ],
    );
  }

  // ── 記錄靈感 ──────────────────────────────────────────────────────────────────

  Widget _buildInput() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        MrCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Focus(
                onKeyEvent: (kIsWeb &&
                        defaultTargetPlatform != TargetPlatform.android &&
                        defaultTargetPlatform != TargetPlatform.iOS)
                    ? (FocusNode _, KeyEvent event) {
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.enter ||
                             event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          _addIdea();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      }
                    : null,
                child: TextField(
                  controller: _draftCtrl,
                  maxLines: 2,
                  scrollPadding: const EdgeInsets.only(bottom: 120.0),
                  decoration: InputDecoration(
                    hintText: '記下你的靈感...',
                    hintStyle: AppText.body(color: AppColors.muted),
                    border: InputBorder.none,
                  ),
                  style: AppText.body(size: 14, height: 1.55),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _adding ? null : _addIdea,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _adding ? AppColors.dark.withOpacity(0.6) : AppColors.dark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _adding
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('新增', style: AppText.body(size: 13, weight: FontWeight.w500, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        ...widget.ideas.reversed.toList().asMap().entries.map((entry) {
          final i = entry.key;
          final idea = entry.value;
          final expanded = _expandedIds.contains(idea.id);
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: MrCard(
              onTap: () => setState(() {
                expanded ? _expandedIds.remove(idea.id) : _expandedIds.add(idea.id);
              }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: AppText.body(size: 13, weight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(idea.text, style: AppText.body(size: 14, height: 1.55)),
                      ),
                      const SizedBox(width: 8),
                      // Edit button — isolated from expand tap
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onIdeaEdited(idea.id, idea.text),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(LucideIcons.refreshCw  , size: 14, color: AppColors.muted),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _editIdea(idea),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(LucideIcons.pencil, size: 14, color: AppColors.muted),
                        ),
                      ),
                      // Delete button — isolated from expand tap
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _deleteIdea(idea.id),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(LucideIcons.trash2, size: 14, color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 15,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 12),
                    _buildAiPanel(idea),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAiPanel(Idea idea) {
    if (idea.aiSummary == null || idea.aiSummary! == '分析失敗，請稍後再試' || idea.aiSummary! == '使用者已停用此AI功能') {
      return Row(
        children: [
          Icon(LucideIcons.sparkles, size: 13, color: AppColors.amber.withOpacity(0.7)),
          const SizedBox(width: 6),
          Text(idea.aiSummary == null ? '分析中...' : idea.aiSummary!, style: AppText.caption(size: 12, color: AppColors.muted)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.sparkles, size: 13, color: AppColors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  idea.aiSummary!,
                  style: AppText.body(size: 13, color: Colors.white.withOpacity(0.9), height: 1.6),
                ),
              ),
            ],
          ),
          if (idea.links.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 10),
            ...idea.links.map((link) => GestureDetector(
              onTap: () => _launchUrl(link.url),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.link, size: 12, color: AppColors.amber.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  link.title,
                                  style: AppText.body(size: 12, weight: FontWeight.w600, color: Colors.white.withOpacity(0.9)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(LucideIcons.externalLink, size: 10, color: AppColors.amber.withOpacity(0.6)),
                            ],
                          ),
                          Text(
                            link.url,
                            style: AppText.caption(size: 11, color: AppColors.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  // ── 探索資源 ──────────────────────────────────────────────────────────────────

  Widget _buildExplore() {
    return RefreshIndicator(
      onRefresh: _loadResources,
      color: AppColors.dark,
      backgroundColor: Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text('推薦資源', style: AppText.display(size: 22, weight: FontWeight.w500)),
            ),
            MrIconButton(
              icon: LucideIcons.refreshCw,
              iconSize: 14,
              size: 32,
              onTap: _loadingResources ? null : _loadResources,
              iconColor: _loadingResources
                  ? AppColors.muted.withOpacity(0.4)
                  : AppColors.dark,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('根據你的靈感主題，AI 為你找到的相關資源', style: AppText.label(size: 12)),
        const SizedBox(height: 16),

        // Pinned section
        if (_pinnedResources.isNotEmpty) ...[
          Text(
            '已釘選',
            style: AppText.caption(size: 11, weight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          ..._pinnedResources.map((r) => _buildResourceCard(r, isPinned: true)),
          const SizedBox(height: 4),
          Divider(color: AppColors.border, height: 24),
        ],

        // AI recommendations
        if (_loadingResources)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_resources == null || _resources!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                widget.ideas.isEmpty ? '尚無靈感可分析，先記下你的想法吧！' : '推薦載入失敗，請稍後再試',
                style: AppText.label(size: 13, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ..._resources!.map((r) => _buildResourceCard(r, isPinned: _pinnedResources.any((p) => p.url == r.url))),

        const SizedBox(height: 4),
        Center(
          child: GestureDetector(
            onTap: _loadingResources ? null : _loadResources,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.refreshCw,
                  size: 13,
                  color: _loadingResources ? AppColors.muted.withOpacity(0.4) : AppColors.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  '重新推薦',
                  style: AppText.label(size: 12, color: _loadingResources ? AppColors.muted.withOpacity(0.4) : null),
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(AiResource r, {required bool isPinned}) {
    final color = _typeColor(r.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MrCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.fileText, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(r.title, style: AppText.body(size: 14, weight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(r.type, style: AppText.caption(size: 10, color: color)),
                      ),
                      const SizedBox(width: 6),
                      // Pin / unpin button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _togglePin(r),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            isPinned ? LucideIcons.bookmarkCheck: LucideIcons.bookmark,
                            size: 15,
                            color: isPinned ? AppColors.amber : AppColors.muted.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.desc, style: AppText.label(size: 12, color: AppColors.muted)),
                  if (r.url.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _launchUrl(r.url),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.url,
                              style: AppText.caption(size: 10, color: AppColors.blue.withOpacity(0.8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(LucideIcons.externalLink, size: 10, color: AppColors.blue.withOpacity(0.6)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
