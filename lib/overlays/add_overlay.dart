import 'dart:async' show StreamSubscription;
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../theme.dart';
import '../services/openai_service.dart';
import '../services/database_service.dart';
import '../models/todo_item.dart';
import '../models/note_item.dart';

// ─── Attachment model ─────────────────────────────────────────────────────────

enum _AttachType { image, audio, textFile }

class _Attachment {
  final _AttachType type;
  final String name;
  final Uint8List bytes;
  final String? preExtractedText;

  const _Attachment({
    required this.type,
    required this.name,
    required this.bytes,
    this.preExtractedText,
  });
}

// ─── AddOverlay ───────────────────────────────────────────────────────────────

class AddOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<ClassificationResult> onItemClassified;

  const AddOverlay({
    super.key,
    required this.onClose,
    required this.onItemClassified,
  });

  @override
  State<AddOverlay> createState() => _AddOverlayState();
}

class _AddOverlayState extends State<AddOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final _textCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  final List<_Attachment> _attachments = [];
  StreamSubscription<Uint8List>? _streamSub;
  final List<int> _recordedChunks = [];

  bool _classifying = false;
  bool _recording = false;
  String? _summaryLabel;
  Set<String> _selectedPages = {};
  List<TodoCategory> _todoCategories = [];
  List<NoteCategory> _noteCategories = [];
  String? _selectedTodoCatId;
  String? _selectedNoteCatId;

  // Keyword preview map (instant, before AI confirms)
  static const _catKW = {
    '行程': ['會議', '約', '早上', '上午', '下午', '晚上', '今天', '明天', '預約', '安排', '點開'],
    '待辦': ['要', '需要', '記得', '買', '完成', '處理', '幫', '提醒', '做', '去'],
    '靈感': ['如果', '想法', '或許', '試', '發現', '感覺', '有趣'],
    '札記': ['上週', '上禮拜', '昨天', '感受', '可愛', '開心', '煩', '無聊', '覺得', '想到', '看到']
  };

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _loadCategories();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _textCtrl.dispose();
    _streamSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.length <= 4) {
      setState(() => _selectedPages = {});
      return;
    }
    final matches = _catKW.entries
        .where((e) => e.value.any((kw) => text.contains(kw)))
        .map((e) => e.key)
        .toSet();
    setState(() => _selectedPages = matches.isEmpty ? {} : matches);
  }

  Future<void> _loadCategories() async {
    final todos = await DatabaseService.instance.getCategories();
    final notes = await DatabaseService.instance.getNoteCategories();
    // if (mounted) setState(() { _todoCategories = todos; _noteCategories = notes; });
  }

  // ── File picker ──────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg', 'jpeg', 'png', 'gif', 'webp',
        'mp3', 'm4a', 'wav', 'ogg',
        'txt', 'md', 'pdf',
      ],
    );
    if (result == null || result.files.isEmpty) return;

    final newAttachments = <_Attachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final ext = (file.extension ?? '').toLowerCase();
      final name = file.name;

      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
        newAttachments.add(_Attachment(type: _AttachType.image, name: name, bytes: bytes));
      } else if (['mp3', 'm4a', 'wav', 'ogg'].contains(ext)) {
        newAttachments.add(_Attachment(type: _AttachType.audio, name: name, bytes: bytes));
      } else if (['txt', 'md'].contains(ext)) {
        final text = utf8.decode(bytes, allowMalformed: true);
        newAttachments.add(_Attachment(type: _AttachType.textFile, name: name, bytes: bytes, preExtractedText: text));
      } else if (ext == 'pdf') {
        final extracted = await _extractPdfText(bytes, name);
        newAttachments.add(_Attachment(type: _AttachType.textFile, name: name, bytes: bytes, preExtractedText: extracted));
      }
    }

    if (newAttachments.isNotEmpty && mounted) {
      setState(() => _attachments.addAll(newAttachments));
    }
  }

  Future<String> _extractPdfText(Uint8List bytes, String name) async {
    try {
      final doc = await PdfDocument.openData(bytes);
      final buf = StringBuffer();
      for (int i = 1; i <= doc.pages.length; i++) {
        final page = doc.pages[i - 1];
        final text = await page.loadText();
        buf.write(text?.fullText);
        buf.write('\n');
      }
      return buf.toString().trim();
    } catch (e) {
      debugPrint('PDF extraction error ($name): $e');
      return '';
    }
  }

  // ── Recording ────────────────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }
    _recordedChunks.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
    );
    _streamSub = stream.listen((chunk) => _recordedChunks.addAll(chunk));
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    await _streamSub?.cancel();
    _streamSub = null;
    if (!mounted) return;
    setState(() => _recording = false);

    if (_recordedChunks.isNotEmpty) {
      final bytes = Uint8List.fromList(_recordedChunks);
      _recordedChunks.clear();
      setState(() => _attachments.add(
        _Attachment(type: _AttachType.audio, name: 'recording.m4a', bytes: bytes),
      ));
    }
  }

  // ── Process & save ───────────────────────────────────────────────────────────

  Future<void> _processAndSave() async {
    final hasText = _textCtrl.text.trim().isNotEmpty;
    final hasAttachments = _attachments.isNotEmpty;
    if (_classifying || (!hasText && !hasAttachments)) return;

    setState(() { _classifying = true; _summaryLabel = null; });

    // 1. Transcribe audio attachments in parallel; keep results indexed by
    //    position in _attachments so we can pair them up later.
    final transcripts = <int, String?>{};
    final transcribeJobs = <Future<void>>[];
    for (int i = 0; i < _attachments.length; i++) {
      final a = _attachments[i];
      if (a.type != _AttachType.audio) continue;
      transcribeJobs.add(
        OpenAIService.instance.transcribeAudio(a.bytes, a.name).then((t) {
          transcripts[i] = t;
        }),
      );
    }
    await Future.wait(transcribeJobs);

    // 2. Build the combined text the AI sees. Audio transcripts and file
    //    texts are inlined so the model can read them; the attachment
    //    manifest passed separately lets it map them back to notes.
    final textParts = <String>[
      if (hasText) _textCtrl.text.trim(),
      for (int i = 0; i < _attachments.length; i++)
        if (_attachments[i].type == _AttachType.audio && transcripts[i] != null)
          '[音訊：${_attachments[i].name}] ${transcripts[i]}'
        else if (_attachments[i].type == _AttachType.textFile)
          '[檔案：${_attachments[i].name}]\n${_attachments[i].preExtractedText ?? ''}',
    ];
    final finalText = textParts.where((s) => s.isNotEmpty).join('\n\n');

    // 3. Build the attachment manifest with stable indices over all
    //    attachments (image | audio | textFile), in insertion order.
    final attachmentMetas = <AttachmentInputMeta>[
      for (int i = 0; i < _attachments.length; i++)
        AttachmentInputMeta(
          index: i,
          name: _attachments[i].name,
          type: switch (_attachments[i].type) {
            _AttachType.image    => 'image',
            _AttachType.audio    => 'audio',
            _AttachType.textFile => 'file',
          },
        ),
    ];

    // 4. Encode image attachments as base64 for vision input.
    final base64Images = [
      for (final a in _attachments)
        if (a.type == _AttachType.image) base64Encode(a.bytes),
    ];

    // 5. Call multi-item classification.
    final results = await OpenAIService.instance.classifyMultiInput(
      finalText.isNotEmpty ? finalText : null,
      base64Images: base64Images,
      attachments: attachmentMetas,
    );

    if (!mounted) return;

    // 6. Resolve attachment_indices on each ClassifiedNote into the actual
    //    bytes/transcript so downstream dispatch can persist them.
    final enriched = [
      for (final r in results)
        if (r is ClassifiedNote)
          ClassifiedNote(
            dateKey: r.dateKey,
            cat: "undefined",
            content: r.content,
            attachmentIndices: r.attachmentIndices,
            pendingAttachments: [
              for (final i in r.attachmentIndices)
                if (i >= 0 && i < _attachments.length)
                  PendingNoteAttachment(
                    type: switch (_attachments[i].type) {
                      _AttachType.image    => 'image',
                      _AttachType.audio    => 'audio',
                      _AttachType.textFile => 'file',
                    },
                    filename: _attachments[i].name,
                    bytes: _attachments[i].bytes,
                    extracted: _attachments[i].type == _AttachType.audio
                        ? transcripts[i]
                        : _attachments[i].preExtractedText,
                  ),
            ],
          )
        else
          r,
    ];

    // 7. Fire callback for each result.
    for (final r in enriched) {
      widget.onItemClassified(r);
    }

    // 8. Build summary chip.
    final summary = _buildSummary(enriched);
    setState(() { _classifying = false; _summaryLabel = summary; });

    await Future.delayed(const Duration(milliseconds: 1100));
    if (mounted) _close();
  }

  String _buildSummary(List<ClassificationResult> results) {
    if (results.isEmpty) return '✓ 已儲存';
    final hasError = results.any((r) => r is ClassificationError);
    if (hasError && results.length == 1) return '⚠ 無法分析，已儲存為札記';

    int todos = 0, events = 0, ideas = 0, notes = 0, recaps = 0;
    for (final r in results) {
      if (r is ClassifiedTodo) todos++;
      if (r is ClassifiedTodoWithTime) events++;
      if (r is ClassifiedIdea) ideas++;
      if (r is ClassifiedNote) notes++;
      if (r is ClassifiedRecap) recaps++;
    }

    final parts = <String>[];
    if (events > 0) parts.add('$events 行程');
    if (todos > 0) parts.add('$todos 待辦');
    if (ideas > 0) parts.add('$ideas 靈感');
    if (notes > 0) parts.add('$notes 札記');
    if (recaps > 0) parts.add('$recaps 回顧');
    return '✓ 新增 ${parts.join('、')}';
  }

  void _close() {
    _ctrl.reverse().then((_) => widget.onClose());
  }

  Widget _buildPageChip(String page) {
    final selected = _selectedPages.contains(page);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedPages.remove(page);
          if (page == '待辦') _selectedTodoCatId = null;
          if (page == '札記') _selectedNoteCatId = null;
        } else {
          _selectedPages.add(page);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.dark : AppColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          page,
          style: AppText.body(
            size: 13,
            weight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildSubCatChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.dark.withOpacity(0.85) : AppColors.border,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: AppText.caption(
            size: 12,
            color: selected ? Colors.white : AppColors.dark,
          ),
        ),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            color: AppColors.bg,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('新增', style: AppText.display(size: 28, weight: FontWeight.w500, italic: true)),
                        Text('輸入任何想記錄的東西', style: AppText.label(size: 12)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _close,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.x, size: 16, color: AppColors.dark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Text area + attachment strip ─────────────────────────────
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 20, offset: Offset(0, 4))],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            maxLines: null,
                            expands: true,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: '輸入任何東西...\n\n今天想到、看到、計畫的——都可以放這裡',
                              hintStyle: AppText.body(color: AppColors.muted, height: 1.7),
                              border: InputBorder.none,
                            ),
                            style: AppText.body(size: 15, height: 1.7),
                            onChanged: _onTextChanged,
                          ),
                        ),

                        // Attachment strip
                        if (_attachments.isNotEmpty) ...[
                          const Divider(height: 20),
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _attachments.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (_, i) => _AttachChip(
                                attachment: _attachments[i],
                                onRemove: () => setState(() => _attachments.removeAt(i)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Keyword preview badges ───────────────────────────────────
                // if (_suggested.isNotEmpty && !_classifying && _summaryLabel == null) ...[
                //   const SizedBox(height: 14),
                //   Text('預測分類', style: AppText.caption(size: 11, letterSpacing: 0.6)),
                //   const SizedBox(height: 6),
                //   Wrap(
                //     spacing: 8,
                //     children: _suggested.map((s) => Container(
                //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                //       decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(14)),
                //       child: Text(s, style: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.dark)),
                //     )).toList(),
                //   ),
                // ],

                
                // ── Page type selection (line 1) ─────────────────────────────
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['行程', '待辦', '靈感', '札記']
                      .map(_buildPageChip)
                      .toList(),
                ),

                // ── Sub-category selection (line 2) ──────────────────────────
                if (_selectedPages.contains('待辦') && _todoCategories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('待辦分類', style: AppText.caption(size: 11, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _todoCategories
                        .map((c) => _buildSubCatChip(
                              label: c.name,
                              selected: _selectedTodoCatId == c.id.toString(),
                              onTap: () => setState(() => _selectedTodoCatId =
                                  _selectedTodoCatId == c.id.toString()
                                      ? null
                                      : c.id.toString()),
                            ))
                        .toList(),
                  ),
                ],
                if (_selectedPages.contains('札記') && _noteCategories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('札記分類', style: AppText.caption(size: 11, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _noteCategories
                        .map((c) => _buildSubCatChip(
                              label: c.label,
                              selected: _selectedNoteCatId == c.id,
                              onTap: () => setState(() => _selectedNoteCatId =
                                  _selectedNoteCatId == c.id ? null : c.id),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 6),

                // ── Recording indicator ──────────────────────────────────────
                if (_recording) ...[
                  const SizedBox(height: 14),
                  _RecordingBadge(),
                ],

                // ── Result summary chip ──────────────────────────────────────
                if (_summaryLabel != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _summaryLabel!.startsWith('⚠')
                          ? AppColors.amber.withOpacity(0.12)
                          : AppColors.sage.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _summaryLabel!,
                      style: AppText.body(
                        size: 13,
                        color: _summaryLabel!.startsWith('⚠') ? AppColors.amber : AppColors.sage,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Action row ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _classifying ? null : _processAndSave,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _classifying ? AppColors.dark.withOpacity(0.5) : AppColors.dark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: _classifying
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text('儲存並分類',
                                    style: AppText.body(size: 14, weight: FontWeight.w600, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Upload / file picker button
                    if (!kIsWeb) ...[
                      _ActionBtn(
                        icon: LucideIcons.paperclip,
                        onTap: _classifying ? null : _pickFile,
                      ),
                      const SizedBox(width: 10),

                      // Mic / stop button
                      _ActionBtn(
                        icon: _recording ? LucideIcons.squareSlash : LucideIcons.mic,
                        iconColor: _recording ? AppColors.rose : null,
                        borderColor: _recording ? AppColors.rose.withOpacity(0.4) : null,
                        onTap: _classifying ? null : _toggleRecording,
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _AttachChip extends StatelessWidget {
  final _Attachment attachment;
  final VoidCallback onRemove;
  const _AttachChip({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final icon = switch (attachment.type) {
      _AttachType.image    => LucideIcons.image,
      _AttachType.audio    => LucideIcons.music,
      _AttachType.textFile => LucideIcons.fileText,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              attachment.name,
              style: AppText.caption(size: 11, color: AppColors.dark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(LucideIcons.x, size: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _RecordingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rose.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.rose.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(color: AppColors.rose, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('錄音中…', style: AppText.body(size: 13, color: AppColors.rose)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? borderColor;
  const _ActionBtn({required this.icon, this.onTap, this.iconColor, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor ?? AppColors.border),
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
        ),
        child: Icon(icon, size: 20, color: iconColor ?? AppColors.muted),
      ),
    );
  }
}
