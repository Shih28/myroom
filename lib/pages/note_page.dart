import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:myroom/models/note_item.dart';
import 'package:myroom/services/attachment_storage.dart';
import 'package:myroom/services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../data/seed_data.dart';
import '../widgets/mr_card.dart';
import '../widgets/mr_icon_button.dart';
import '../widgets/note_modal_sheet.dart';

enum NoteMode { date, category }

// ─── Icon / palette constants ─────────────────────────────────────────────────

const kNoteIconMap = {
  'tag':      LucideIcons.tag,
  'star':     LucideIcons.star,
  'pencil':   LucideIcons.pencil,
  'fileText': LucideIcons.fileText,
  'bookOpen': LucideIcons.bookOpen,
  'music':    LucideIcons.music,
  'heart':    LucideIcons.heart,
};

const kNoteIconKeys = [
  'tag', 'star', 'pencil', 'fileText', 'bookOpen', 'music', 'heart',
];

const kNoteCatPalette = [
  (Color(0xFFBFA97A), Color(0xFFFFF8ED)),
  (Color(0xFFBF7A8E), Color(0xFFF5EEF0)),
  (Color(0xFF7A8EBF), Color(0xFFEEF0F5)),
  (Color(0xFF9E9E9E), Color(0xFFF5F0E8)),
  (Color(0xFF7BAF8A), Color(0xFFEFF5F1)),
];

// ─── Attachment helpers (shared between date + category modes) ─────────────────

Future<Map<int, List<NoteAttachment>>> _loadAttachmentsFor(
  Iterable<NoteItem> notes,
) async {
  if (kIsWeb) return const {};
  final db = DatabaseService.instance;
  final result = <int, List<NoteAttachment>>{};
  for (final n in notes) {
    result[n.id] = await db.getNoteAttachments(n.id);
  }
  return result;
}

/// Persists a [NoteSheetResult] for a brand-new note. Returns the new note id.
Future<int> _persistNewNote(NoteSheetResult r, String dateKey) async {
  final db = DatabaseService.instance;
  late final int id;
  if (r.catId == null) {
    id = await db.upsertNote(dateKey, r.content);
  } else {
    id = await db.insertCatNote(dateKey, r.content, r.catId!);
  }
  if (id > 0 && !kIsWeb) {
    for (final a in r.added) {
      final relPath = await AttachmentStorage.instance.save(
        a.bytes,
        _extOf(a.filename),
      );
      await db.insertNoteAttachment(
        noteId: id,
        type: a.type,
        filename: a.filename,
        relPath: relPath,
        extracted: a.extracted,
      );
    }
  }
  return id;
}

/// Persists a [NoteSheetResult] for an existing note: updates content,
/// removes any dropped attachments, inserts any newly added ones.
Future<void> _persistEditedNote(NoteSheetResult r, NoteItem original) async {
  final db = DatabaseService.instance;
  await db.updateNoteContent(original.id, r.content, cat: r.catId);
  if (kIsWeb) return;
  final keptIds = r.keptExisting.map((a) => a.id).toSet();
  final existing = await db.getNoteAttachments(original.id);
  for (final a in existing) {
    if (!keptIds.contains(a.id)) {
      await db.deleteNoteAttachment(a.id);
    }
  }
  for (final a in r.added) {
    final relPath = await AttachmentStorage.instance.save(
      a.bytes,
      _extOf(a.filename),
    );
    await db.insertNoteAttachment(
      noteId: original.id,
      type: a.type,
      filename: a.filename,
      relPath: relPath,
      extracted: a.extracted,
    );
  }
}

String _extOf(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return '';
  return filename.substring(dot + 1).toLowerCase();
}

// ─── NotePage ─────────────────────────────────────────────────────────────────

class NotePage extends StatefulWidget {
  /// Sparse map of date_key → content used only for calendar dot indicators.
  final Map<String, String> notes;

  /// Called after any note mutation so main.dart can re-fetch _notes.
  final VoidCallback onNotesMutated;
  final VoidCallback? onSwipeBack;
  final VoidCallback? onSwipeForward;

  const NotePage({
    super.key,
    required this.notes,
    required this.onNotesMutated,
    this.onSwipeBack,
    this.onSwipeForward,
  });

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  NoteMode _mode = NoteMode.date;

  // ── Date mode ────────────────────────────────────────────────────────────
  int _year  = DateTime.now().year;
  int _month = DateTime.now().month - 1; // 0-indexed
  int _day = DateTime.now().day;
  int? _selectedDay;

  /// All notes (primary + categorized) for the currently selected day.
  List<NoteItem> _dayNotes = [];

  /// Attachments keyed by note id, for the selected day.
  Map<int, List<NoteAttachment>> _dayAttachments = {};

  /// Expanded state for note cards in the day panel.
  final Set<int> _dayNoteExpandedIds = {};

  // ── Category mode ────────────────────────────────────────────────────────
  String? _openCatId;
  List<NoteCategory> _categories = [];
  Map<String, List<NoteItem>> _catNotes = {};

  // ─────────────────────────────────────────────────────────────────────────

  String get _noteKey {
    final d = _selectedDay;
    if (d == null) return '';
    return '$_year-${fmt2(_month + 1)}-${fmt2(d)}';
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _selectDay(_day , '$_year-${fmt2(_month + 1)}-${fmt2(_day)}');
  }

  // ── Data loaders ─────────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    final cats = await DatabaseService.instance.getNoteCategories();
    final notesMap = <String, List<NoteItem>>{};
    for (final c in cats) {
      notesMap[c.id] = await DatabaseService.instance.getNotesByCategory(c.id);
    }
    if (mounted) {
      setState(() {
        _categories = cats;
        _catNotes = notesMap;
      });
    }
  }

  Future<void> _loadCatNotes(String catId) async {
    final notes = await DatabaseService.instance.getNotesByCategory(catId);
    if (mounted) setState(() => _catNotes[catId] = notes);
  }

  Future<void> _loadDayNotes(String dateKey) async {
    final notes = await DatabaseService.instance.getNotesByDate(dateKey);
    final attachments = await _loadAttachmentsFor(notes);
    if (!mounted) return;
    setState(() {
      _dayNotes = notes;
      _dayAttachments = attachments;
    });
  }

  // ── Note actions ──────────────────────────────────────────────────────────

  void _selectDay(int day, String key) {
    _dayNoteExpandedIds.clear();
    setState(() {
      _selectedDay = day;
      _dayNotes = [];
      _dayAttachments = {};
    });
    _loadDayNotes(key);
  }

  void _closeDayPanel() {
    _dayNoteExpandedIds.clear();
    setState(() {
      _selectedDay = null;
      _dayNotes = [];
      _dayAttachments = {};
    });
  }

  Future<void> _openAddNoteSheet() async {
    if (_noteKey.isEmpty) return;
    final result = await showNoteModalSheet(
      context,
      dateKey: _noteKey,
      categories: _categories,
    );
    if (result == null || !mounted) return;
    await _persistNewNote(result, _noteKey);
    await Future.wait([
      _loadDayNotes(_noteKey),
      if (result.catId != null) _loadCatNotes(result.catId!),
    ]);
    widget.onNotesMutated();
  }

  Future<void> _openEditNoteSheet(NoteItem note) async {
    final existing = _dayAttachments[note.id] ?? const <NoteAttachment>[];
    final result = await showNoteModalSheet(
      context,
      dateKey: note.dateKey,
      categories: _categories,
      initialContent: note.content,
      initialCatId: note.catId,
      existingAttachments: existing,
      isEditing: true,
    );
    if (result == null || !mounted) return;
    await _persistEditedNote(result, note);
    await Future.wait([
      _loadDayNotes(_noteKey),
      if (note.catId != null) _loadCatNotes(note.catId!),
      if (result.catId != null) _loadCatNotes(result.catId!),
    ]);
    widget.onNotesMutated();
  }

  Future<void> _deleteDayNote(NoteItem note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('刪除筆記', style: AppText.body(size: 16, weight: FontWeight.w600)),
        content: Text(
          '確定刪除這份筆記？',
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
      await DatabaseService.instance.deleteNote(note.id);
      await Future.wait([
        _loadDayNotes(_noteKey),
        if (note.catId != null) _loadCatNotes(note.catId!),
      ]);
      widget.onNotesMutated();
    }
  }

  void _showAddCategoryDialog() {
    final labelCtrl = TextEditingController();
    String selectedIcon = kNoteIconKeys[_categories.length % kNoteIconKeys.length];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: AppColors.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('新增分類', style: AppText.body(size: 16, weight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: labelCtrl,
                autofocus: true,
                decoration: _fieldDecoration('分類名稱'),
                style: AppText.body(size: 14),
              ),
              const SizedBox(height: 14),
              Text('選擇圖示', style: AppText.caption(size: 11, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: kNoteIconKeys.map((key) {
                  final isSelected = key == selectedIcon;
                  return GestureDetector(
                    onTap: () => setDialog(() => selectedIcon = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.dark : AppColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        kNoteIconMap[key]!, size: 16,
                        color: isSelected ? Colors.white : AppColors.muted,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: AppText.body(size: 14, color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                if (label.isEmpty) return;
                Navigator.pop(ctx);
                final idx = _categories.length;
                final palette = kNoteCatPalette[idx % kNoteCatPalette.length];
                final id = '${label.toLowerCase().replaceAll(' ', '_')}_'
                    '${DateTime.now().millisecondsSinceEpoch}';
                await DatabaseService.instance.insertNoteCategory(NoteCategory(
                  id: id, label: label, iconName: selectedIcon,
                  color: palette.$1, bg: palette.$2, sortOrder: idx,
                ));
                await _loadCategories();
              },
              child: Text(
                '新增',
                style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.dark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(NoteCategory cat) async {
    final noteCount = _catNotes[cat.id]?.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('刪除分類', style: AppText.body(size: 16, weight: FontWeight.w600)),
        content: Text(
          '確定刪除「${cat.label}」？'
          '${noteCount > 0 ? '\n\n此分類下的 $noteCount 則筆記也會一併刪除。' : ''}',
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
      await DatabaseService.instance.deleteNoteCategory(cat.id);
      await _loadCategories();
      widget.onNotesMutated();
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
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
  );

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_openCatId != null) {
      final cat = _categories.firstWhere(
        (c) => c.id == _openCatId,
        orElse: () => _categories.first,
      );
      return _CatDetail(
        category: cat,
        categories: _categories,
        notes: _catNotes[_openCatId] ?? [],
        onBack: () => setState(() => _openCatId = null),
        onMutated: () async {
          await _loadCatNotes(_openCatId!);
          widget.onNotesMutated();
        },
        loadDay: _loadDayNotes,
        loadCat: _loadCatNotes,
      );
    }

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
              children: NoteMode.values.map((m) {
                final active = _mode == m;
                final labels = ['日期', '分類'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _mode = m;
                      if (m == NoteMode.date) {
                        _year  = DateTime.now().year;
                        _month = DateTime.now().month - 1; // 0-indexed
                        _day = DateTime.now().day;
                        _selectDay(_day , '$_year-${fmt2(_month + 1)}-${fmt2(_day)}');
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.dark : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          labels[m.index],
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
          child: _mode == NoteMode.date
              ? _buildDateMode()
              : _buildCategoryMode(),
        ),
      ],
    );
  }

  // ── Date mode ────────────────────────────────────────────────────────────

  Widget _buildDateMode() {
    final daysInMonth = DateTime(_year, _month + 2, 0).day;
    final firstDow    = DateTime(_year, _month + 1, 1).weekday % 7;
    final now         = DateTime.now();
    final today       = DateTime(now.year, now.month, now.day);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        // Month / year navigation
        Row(
          children: [
            Text(
              '$_year年${_month + 1}月',
              style: AppText.body(size: 16, weight: FontWeight.w500),
            ),
            const Spacer(),
            MrIconButton(
              icon: LucideIcons.calendar,
              iconSize: 15,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _year = picked.year;
                    _month = picked.month - 1; // 0-indexed
                    _day = picked.day;
                    _selectDay(_day , '$_year-${fmt2(_month + 1)}-${fmt2(_day)}');
                  });
                }
              }
            ),
            const SizedBox(width: 6),
            MrIconButton(
              icon: LucideIcons.chevronLeft,
              iconSize: 15,
              onTap: () => setState(() {
                if (_month == 0) { _year--; _month = 11; } else { _month--; }
                _selectedDay = null;
              }),
            ),
            const SizedBox(width: 6),
            MrIconButton(
              icon: LucideIcons.chevronRight,
              iconSize: 15,
              onTap: () => setState(() {
                if (_month == 11) { _year++; _month = 0; } else { _month++; }
                _selectedDay = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Day-of-week header
        Row(
          children: kDow.map((d) => Expanded(
            child: Center(
              child: Text(d, style: AppText.caption(size: 10, weight: FontWeight.w600)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 4),

        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 42,
          ),
          itemCount: ((firstDow + daysInMonth) / 7).ceil() * 7,
          itemBuilder: (_, idx) {
            final day = idx - firstDow + 1;
            if (day < 1 || day > daysInMonth) return const SizedBox();

            final key = '$_year-${fmt2(_month + 1)}-${fmt2(day)}';
            final hasNote = widget.notes.containsKey(key) ||
                _catNotes.values.any((list) => list.any((n) => n.dateKey == key));
            final isSelected = _selectedDay == day;
            final cellDate  = DateTime(_year, _month + 1, day);
            final isToday   = cellDate == today;
            final isPast    = cellDate.isBefore(today);

            return GestureDetector(
              onTap: () {
                if (isSelected) {
                  _closeDayPanel();
                } else {
                  _selectDay(day, key);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.dark
                      : isToday
                          ? AppColors.dark.withOpacity(0.08)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: AppText.body(
                        size: 13,
                        weight: FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : isPast ? AppColors.muted : AppColors.dark,
                      ),
                    ),
                    if (hasNote)
                      Container(
                        width: 4, height: 4,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: const BoxDecoration(
                          color: AppColors.rose,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // ── Day panel ──────────────────────────────────────────────────────
        if (_selectedDay != null) ...[
          const SizedBox(height: 16),

          // Single dark "新增筆記" button — opens the modal sheet.
          GestureDetector(
            onTap: _openAddNoteSheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.dark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.plus, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '新增 ${_month + 1}月$_selectedDay日 的筆記',
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Notes for this day (primary + categorized).
          ..._dayNotes.map((note) => _buildDayNoteCard(note)),
        ],
      ],
    );
  }

  Widget _buildDayNoteCard(NoteItem note) {
    final isExpanded = _dayNoteExpandedIds.contains(note.id);
    final attachments = _dayAttachments[note.id] ?? const <NoteAttachment>[];
    final cat = _categories.firstWhere(
            (c) => c.id == note.catId,
            orElse: () => NoteCategory(
              id: '', label: '未分類', iconName: 'tag',
              color: AppColors.muted, bg: AppColors.border, sortOrder: 0,
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: MrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (cat.color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cat.label,
                    style: AppText.caption(size: 10, color: cat.color),
                  ),
                ),
                const Spacer(),
                _IconAction(
                  icon: isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  onTap: () => setState(() {
                    if (isExpanded) {
                      _dayNoteExpandedIds.remove(note.id);
                    } else {
                      _dayNoteExpandedIds.add(note.id);
                    }
                  }),
                ),
                _IconAction(
                  icon: LucideIcons.pencil,
                  onTap: () => _openEditNoteSheet(note),
                ),
                _IconAction(
                  icon: LucideIcons.trash2,
                  onTap: () => _deleteDayNote(note),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                if (isExpanded) {
                  _dayNoteExpandedIds.remove(note.id);
                } else {
                  _dayNoteExpandedIds.add(note.id);
                }
              }),
              child: Text(
                note.content,
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: AppText.label(size: 13, color: AppColors.muted),
              ),
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              _AttachmentRow(attachments: attachments),
            ],
          ],
        ),
      ),
    );
  }

  // ── Category mode ────────────────────────────────────────────────────────

  Widget _buildCategoryMode() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        ..._categories.map((c) {
          final icon  = kNoteIconMap[c.iconName] ?? LucideIcons.tag;
          final count = _catNotes[c.id]?.length ?? 0;
          return GestureDetector(
            onTap: () => setState(() => _openCatId = c.id),
            child: Container(
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [kCardShadow],
              ),
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: c.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: c.color),
                      ),
                      const Spacer(),
                      Text(c.label, style: AppText.body(size: 14, weight: FontWeight.w600)),
                      Text('$count 則筆記', style: AppText.caption(size: 11)),
                    ],
                  ),
                  // Delete button — top-right of card
                  Positioned(
                    top: 0, right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _confirmDeleteCategory(c),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          LucideIcons.trash2, size: 13,
                          color: AppColors.muted.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Add category card
        GestureDetector(
          onTap: _showAddCategoryDialog,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.plus, size: 20, color: AppColors.muted.withOpacity(0.6)),
                const SizedBox(height: 4),
                Text(
                  '新增分類',
                  style: AppText.label(size: 12, color: AppColors.muted.withOpacity(0.6)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Category Detail ──────────────────────────────────────────────────────────

class _CatDetail extends StatefulWidget {
  final NoteCategory category;
  final List<NoteCategory> categories;
  final List<NoteItem> notes;
  final VoidCallback onBack;
  final Future<void> Function() onMutated;
  final Future<void> Function(String) loadDay;
  final Future<void> Function(String) loadCat;

  const _CatDetail({
    required this.category,
    required this.categories,
    required this.notes,
    required this.onBack,
    required this.onMutated,
    required this.loadDay,
    required this.loadCat,
  });

  @override
  State<_CatDetail> createState() => _CatDetailState();
}

class _CatDetailState extends State<_CatDetail> {
  final Set<int> _expandedIds = {};
  Map<int, List<NoteAttachment>> _attachments = {};

  @override
  void initState() {
    super.initState();
    _refreshAttachments();
  }

  @override
  void didUpdateWidget(_CatDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notes != widget.notes) _refreshAttachments();
  }

  Future<void> _refreshAttachments() async {
    final attachments = await _loadAttachmentsFor(widget.notes);
    if (mounted) setState(() => _attachments = attachments);
  }

  String _formatDate(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length < 3) return dateKey;
    return '${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }

  Future<void> _openAddSheet() async {
    final result = await showNoteModalSheet(
      context,
      dateKey: todayKey(),
      categories: widget.categories,
      initialCatId: widget.category.id,
    );
    if (result == null || !mounted) return;
    await _persistNewNote(result, todayKey());
    await widget.onMutated();
  }

  Future<void> _openEditSheet(NoteItem note) async {
    final existing = _attachments[note.id] ?? const <NoteAttachment>[];
    final result = await showNoteModalSheet(
      context,
      dateKey: note.dateKey,
      categories: widget.categories,
      initialContent: note.content,
      initialCatId: note.catId,
      existingAttachments: existing,
      isEditing: true,
    );
    if (result == null || !mounted) return;
    await _persistEditedNote(result, note);
    await Future.wait([
      widget.loadDay(note.dateKey),
      if (result.catId != null) widget.loadCat(result.catId!),
    ]);
    await widget.onMutated();
  }

  Future<void> _confirmDeleteNote(NoteItem note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('刪除筆記', style: AppText.body(size: 16, weight: FontWeight.w600)),
        content: Text(
          '確定刪除這份筆記？',
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
      await DatabaseService.instance.deleteNote(note.id);
      await widget.onMutated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat  = widget.category;
    final icon = kNoteIconMap[cat.iconName] ?? LucideIcons.tag;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        // Header
        Row(
          children: [
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: cat.bg, borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.chevronLeft, size: 18, color: cat.color),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: cat.color),
            const SizedBox(width: 8),
            Text(cat.label, style: AppText.display(size: 24, weight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 16),

        ...widget.notes.map((note) {
          final expanded   = _expandedIds.contains(note.id);
          final attachments = _attachments[note.id] ?? const <NoteAttachment>[];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MrCard(
              onTap: () => setState(() {
                expanded ? _expandedIds.remove(note.id) : _expandedIds.add(note.id);
              }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(_formatDate(note.dateKey),
                            style: AppText.body(size: 14, weight: FontWeight.w600)),
                      ),
                      _IconAction(
                        icon: expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        onTap: () => setState(() {
                          expanded ? _expandedIds.remove(note.id) : _expandedIds.add(note.id);
                        }),
                      ),
                      _IconAction(
                        icon: LucideIcons.pencil,
                        onTap: () => _openEditSheet(note),
                      ),
                      _IconAction(
                        icon: LucideIcons.trash2,
                        onTap: () => _confirmDeleteNote(note),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.content,
                    maxLines: expanded ? null : 2,
                    overflow: expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: AppText.label(size: 13, color: AppColors.muted),
                  ),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _AttachmentRow(attachments: attachments),
                  ],
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 4),
        GestureDetector(
          onTap: _openAddSheet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.plus, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text('新增筆記',
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Small reusable widgets ──────────────────────────────────────────────────

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(icon, size: 14, color: AppColors.muted),
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final List<NoteAttachment> attachments;
  const _AttachmentRow({required this.attachments});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((a) {
        switch (a.type) {
          case NoteAttachmentType.image:
            return _ImageThumb(att: a);
          case NoteAttachmentType.audio:
            return _AttachInfoChip(
              icon: LucideIcons.music,
              label: a.filename,
              onTap: () => _openAttachment(a),
            );
          case NoteAttachmentType.file:
            return _AttachInfoChip(
              icon: LucideIcons.fileText,
              label: a.filename,
              onTap: () => _openAttachment(a),
            );
        }
      }).toList(),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final NoteAttachment att;
  const _ImageThumb({required this.att});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImageViewer(context, att),
      child: FutureBuilder<File>(
        future: AttachmentStorage.instance.file(att.relPath),
        builder: (_, snap) {
          if (snap.data == null) {
            return Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              snap.data!,
              width: 56, height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56, height: 56,
                color: AppColors.border,
                child: const Icon(LucideIcons.imageOff, size: 18, color: AppColors.muted),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageViewer(BuildContext context, NoteAttachment att) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: FutureBuilder<File>(
          future: AttachmentStorage.instance.file(att.relPath),
          builder: (_, snap) {
            if (snap.data == null) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return InteractiveViewer(
              child: Image.file(snap.data!, fit: BoxFit.contain),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _openAttachment(NoteAttachment att) async {
  final f = await AttachmentStorage.instance.file(att.relPath);
  final uri = Uri.file(f.path);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AttachInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _AttachInfoChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.muted),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                style: AppText.caption(size: 11, color: AppColors.dark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
